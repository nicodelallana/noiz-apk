import 'dart:convert';
import 'dart:io';

import 'package:bizkaia_transit/data/gtfs/schedule_sync_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScheduleManifest', () {
    test('parses json correctly and round-trips', () {
      final json = {
        'version': '2026-09-29T16:00:00Z',
        'uncompressed': {'bytes': 1000, 'sha256': 'abc123uncompressed'},
        'compressed': {'bytes': 400, 'sha256': 'def456compressed'},
      };

      final manifest = ScheduleManifest.fromJson(json);
      expect(manifest.version, '2026-09-29T16:00:00Z');
      expect(manifest.uncompressedSha256, 'abc123uncompressed');
      expect(manifest.uncompressedBytes, 1000);
      expect(manifest.compressedSha256, 'def456compressed');
      expect(manifest.compressedBytes, 400);

      final exported = manifest.toJson();
      expect(exported['version'], manifest.version);
      expect(
        (exported['compressed'] as Map<String, dynamic>)['sha256'],
        manifest.compressedSha256,
      );
    });
  });

  group('ScheduleSyncService End-to-End', () {
    late Directory tempDir;
    late HttpServer testServer;
    late String serverBaseUrl;
    late List<int> sampleDbBytes;
    late List<int> sampleGzBytes;
    late String sampleDbHash;
    late String sampleGzHash;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('schedule_sync_test_');

      // Create realistic dummy payload
      sampleDbBytes = utf8.encode(
        'SQLite format 3\u0000' + ('DUMMY TRANSIT DATA' * 200),
      );
      sampleDbHash = sha256.convert(sampleDbBytes).toString();

      sampleGzBytes = gzip.encode(sampleDbBytes);
      sampleGzHash = sha256.convert(sampleGzBytes).toString();

      // Start local loopback test server
      testServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverBaseUrl = 'http://${testServer.address.address}:${testServer.port}';

      testServer.listen((HttpRequest request) async {
        if (request.uri.path == '/manifest.json') {
          final manifestJson = {
            'version': '2026-09-29T18:00:00Z',
            'uncompressed': {
              'bytes': sampleDbBytes.length,
              'sha256': sampleDbHash,
            },
            'compressed': {
              'bytes': sampleGzBytes.length,
              'sha256': sampleGzHash,
            },
          };
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(manifestJson));
          await request.response.close();
        } else if (request.uri.path == '/transit.sqlite.gz') {
          request.response
            ..headers.contentType = ContentType('application', 'gzip')
            ..add(sampleGzBytes);
          await request.response.close();
        } else {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
    });

    tearDown(() async {
      await testServer.close(force: true);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('downloads, verifies checksum, and unpacks transit database',
        () async {
      final service = ScheduleSyncService(
        storageBaseUrl: serverBaseUrl,
        documentsDirectoryProvider: () async => tempDir,
      );

      expect(await service.isDatabasePresent(), isFalse);

      final result = await service.sync();
      expect(result.status, SyncStatus.downloadedAndUnpacked);
      expect(result.isReady, isTrue);

      final dbPath = await service.getDatabasePath();
      final dbFile = File(dbPath);
      expect(dbFile.existsSync(), isTrue);
      expect(dbFile.readAsBytesSync(), equals(sampleDbBytes));
      expect(await service.isDatabasePresent(), isTrue);
    });

    test('skips download if local database and manifest hash are identical',
        () async {
      final service = ScheduleSyncService(
        storageBaseUrl: serverBaseUrl,
        documentsDirectoryProvider: () async => tempDir,
      );

      // First sync downloads
      final firstResult = await service.sync();
      expect(firstResult.status, SyncStatus.downloadedAndUnpacked);

      // Second sync reuses existing file
      final secondResult = await service.sync();
      expect(secondResult.status, SyncStatus.upToDate);
      expect(secondResult.bytesDownloaded, 0);
    });

    test('falls back to local database when network fails', () async {
      final service = ScheduleSyncService(
        storageBaseUrl: serverBaseUrl,
        documentsDirectoryProvider: () async => tempDir,
      );

      // Initial download
      await service.sync();

      // Shut down server to simulate total network outage
      await testServer.close(force: true);

      final offlineResult = await service.sync();
      expect(offlineResult.status, SyncStatus.offlineFallback);
      expect(offlineResult.isReady, isTrue);
    });
  });
}
