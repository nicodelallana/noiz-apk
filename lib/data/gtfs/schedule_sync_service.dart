import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/transit_constants.dart';

/// Status of the schedule pack synchronization process.
enum SyncStatus {
  upToDate,
  downloadedAndUnpacked,
  offlineFallback,
  failed,
}

/// Result metadata for a schedule sync operation.
class SyncResult {
  const SyncResult({
    required this.status,
    required this.databasePath,
    this.version,
    this.message,
    this.bytesDownloaded = 0,
  });

  final SyncStatus status;
  final String databasePath;
  final String? version;
  final String? message;
  final int bytesDownloaded;

  bool get isReady =>
      status == SyncStatus.upToDate ||
      status == SyncStatus.downloadedAndUnpacked ||
      status == SyncStatus.offlineFallback;

  @override
  String toString() =>
      'SyncResult(status: $status, path: $databasePath, version: $version)';
}

/// Manifest representation matching backend build_transit_db.py output.
class ScheduleManifest {
  const ScheduleManifest({
    required this.version,
    required this.compressedSha256,
    required this.compressedBytes,
    required this.uncompressedSha256,
    required this.uncompressedBytes,
  });

  factory ScheduleManifest.fromJson(Map<String, dynamic> json) {
    final uncompressed = json['uncompressed'] as Map<String, dynamic>? ?? {};
    final compressed = json['compressed'] as Map<String, dynamic>? ?? {};

    return ScheduleManifest(
      version: json['version'] as String? ?? '',
      compressedSha256: compressed['sha256'] as String? ?? '',
      compressedBytes: (compressed['bytes'] as num?)?.toInt() ?? 0,
      uncompressedSha256: uncompressed['sha256'] as String? ?? '',
      uncompressedBytes: (uncompressed['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  final String version;
  final String compressedSha256;
  final int compressedBytes;
  final String uncompressedSha256;
  final int uncompressedBytes;

  Map<String, dynamic> toJson() => {
        'version': version,
        'uncompressed': {
          'bytes': uncompressedBytes,
          'sha256': uncompressedSha256,
        },
        'compressed': {
          'bytes': compressedBytes,
          'sha256': compressedSha256,
        },
      };
}

/// Service managing the offline GTFS SQLite bundle download and integrity.
class ScheduleSyncService {
  ScheduleSyncService({
    Dio? dioClient,
    String? storageBaseUrl,
    Future<Directory> Function()? documentsDirectoryProvider,
  })  : _dio = dioClient ??
            Dio(
              BaseOptions(
                connectTimeout: TransitConstants.connectTimeout,
                receiveTimeout: TransitConstants.receiveTimeout,
              ),
            ),
        _storageBaseUrl =
            storageBaseUrl ?? TransitConstants.defaultStorageBucketUrl,
        _directoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Dio _dio;
  final String _storageBaseUrl;
  final Future<Directory> Function() _directoryProvider;

  /// Returns the target database directory.
  Future<Directory> getDatabaseDirectory() async => _directoryProvider();

  /// Returns the target SQLite file path.
  Future<String> getDatabasePath() async {
    final dir = await getDatabaseDirectory();
    return p.join(dir.path, TransitConstants.sqliteDbFileName);
  }

  /// Checks if a valid SQLite database file exists locally.
  Future<bool> isDatabasePresent() async {
    final dbPath = await getDatabasePath();
    final file = File(dbPath);
    return file.existsSync() && file.lengthSync() > 1024;
  }

  /// Fetches remote manifest, compares checksums, and updates local database if needed.
  Future<SyncResult> sync({
    void Function(int received, int total)? onProgress,
    bool forceDownload = false,
  }) async {
    final dir = await getDatabaseDirectory();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final dbPath = p.join(dir.path, TransitConstants.sqliteDbFileName);
    final manifestPath =
        p.join(dir.path, TransitConstants.manifestMetaFileName);
    final dbFile = File(dbPath);
    final manifestFile = File(manifestPath);

    // If database does not exist or is legacy > 10MB single-operator pack, seed bundled DB
    if (!dbFile.existsSync() || dbFile.lengthSync() < 1024 || dbFile.lengthSync() > 10 * 1024 * 1024) {
      try {
        final data = await rootBundle.load('assets/db/transit.sqlite');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await dbFile.writeAsBytes(bytes, flush: true);
      } catch (_) {}
    }

    ScheduleManifest? localManifest;
    if (manifestFile.existsSync()) {
      try {
        final content = manifestFile.readAsStringSync();
        localManifest = ScheduleManifest.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
      } catch (_) {
        localManifest = null;
      }
    }

    // 1. Fetch remote manifest
    ScheduleManifest remoteManifest;
    try {
      final manifestUrl =
          '$_storageBaseUrl/${TransitConstants.manifestFileName}';
      final response = await _dio.get<Map<String, dynamic>>(
        manifestUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.data == null) {
        throw const FormatException('Empty manifest response from storage');
      }

      remoteManifest = ScheduleManifest.fromJson(response.data!);
    } catch (e) {
      // Offline fallback: if network fails but local DB exists, use existing schedule
      if (dbFile.existsSync() && dbFile.lengthSync() > 1024) {
        return SyncResult(
          status: SyncStatus.offlineFallback,
          databasePath: dbPath,
          version: localManifest?.version,
          message: 'Offline fallback: could not reach CDN ($e)',
        );
      }
      return SyncResult(
        status: SyncStatus.failed,
        databasePath: dbPath,
        message: 'Failed to download manifest and no local cache exists: $e',
      );
    }

    // 2. Check if local database is already identical to remote
    final bool hasValidLocalDb =
        dbFile.existsSync() && dbFile.lengthSync() > 1024;

    // Avoid overwriting multi-operator DB with legacy remote pack
    if (remoteManifest.version.startsWith('1.') && hasValidLocalDb) {
      return SyncResult(
        status: SyncStatus.upToDate,
        databasePath: dbPath,
        version: '2.0.0-multi-operator',
        message: 'Local multi-operator database is active and up to date',
      );
    }

    final bool hashMatches = localManifest != null &&
        localManifest.compressedSha256 == remoteManifest.compressedSha256 &&
        localManifest.uncompressedSha256 == remoteManifest.uncompressedSha256;

    if (!forceDownload && hasValidLocalDb && hashMatches) {
      return SyncResult(
        status: SyncStatus.upToDate,
        databasePath: dbPath,
        version: remoteManifest.version,
        message: 'Local database is up to date',
      );
    }

    // 3. Download compressed transit.sqlite.gz to temporary file
    final gzTempPath =
        p.join(dir.path, '${TransitConstants.compressedDbFileName}.part');
    final gzTempFile = File(gzTempPath);
    if (gzTempFile.existsSync()) {
      gzTempFile.deleteSync();
    }

    final downloadUrl =
        '$_storageBaseUrl/${TransitConstants.compressedDbFileName}';

    try {
      await _dio.download(
        downloadUrl,
        gzTempPath,
        onReceiveProgress: onProgress,
      );

      // Verify SHA-256 of downloaded archive
      final gzBytes = gzTempFile.readAsBytesSync();
      final downloadedHash = sha256.convert(gzBytes).toString();
      if (remoteManifest.compressedSha256.isNotEmpty &&
          downloadedHash.toLowerCase() !=
              remoteManifest.compressedSha256.toLowerCase()) {
        gzTempFile.deleteSync();
        throw StateError(
          'Checksum mismatch: expected ${remoteManifest.compressedSha256}, got $downloadedHash',
        );
      }

      // 4. Decompress using GZipCodec to temporary SQLite file
      final uncompressedTempPath =
          p.join(dir.path, '${TransitConstants.sqliteDbFileName}.part');
      final uncompressedTempFile = File(uncompressedTempPath);
      if (uncompressedTempFile.existsSync()) {
        uncompressedTempFile.deleteSync();
      }

      final decompressedBytes = gzip.decode(gzBytes);
      uncompressedTempFile.writeAsBytesSync(decompressedBytes, flush: true);

      // Verify uncompressed SHA-256 if provided
      if (remoteManifest.uncompressedSha256.isNotEmpty) {
        final decompressedHash = sha256.convert(decompressedBytes).toString();
        if (decompressedHash.toLowerCase() !=
            remoteManifest.uncompressedSha256.toLowerCase()) {
          uncompressedTempFile.deleteSync();
          gzTempFile.deleteSync();
          throw StateError('Decompressed database checksum mismatch');
        }
      }

      // 5. Atomic swap: rename temporary file to target database file
      if (dbFile.existsSync()) {
        try {
          dbFile.deleteSync();
        } catch (_) {}
      }
      uncompressedTempFile.renameSync(dbPath);

      // Clean up temp compressed file
      if (gzTempFile.existsSync()) {
        gzTempFile.deleteSync();
      }

      // Persist local manifest metadata
      manifestFile.writeAsStringSync(
        jsonEncode(remoteManifest.toJson()),
        flush: true,
      );

      return SyncResult(
        status: SyncStatus.downloadedAndUnpacked,
        databasePath: dbPath,
        version: remoteManifest.version,
        bytesDownloaded: gzBytes.length,
        message: 'Successfully downloaded and unpacked transit schedule bundle',
      );
    } catch (e) {
      if (gzTempFile.existsSync()) {
        gzTempFile.deleteSync();
      }

      // If local DB exists, fallback
      if (dbFile.existsSync() && dbFile.lengthSync() > 1024) {
        return SyncResult(
          status: SyncStatus.offlineFallback,
          databasePath: dbPath,
          version: localManifest?.version,
          message: 'Download error, falling back to local database: $e',
        );
      }

      return SyncResult(
        status: SyncStatus.failed,
        databasePath: dbPath,
        message: 'Download and unpacking failed: $e',
      );
    }
  }
}
