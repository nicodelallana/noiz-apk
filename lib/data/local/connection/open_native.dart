import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/transit_constants.dart';

/// Opens `transit.sqlite`, first copying or decompressing the bundled asset
/// into the documents directory when it is missing or empty.
QueryExecutor openTransitDatabase({File? file}) {
  if (file != null) {
    return NativeDatabase.createInBackground(file);
  }
  return LazyDatabase(() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docs.path, TransitConstants.sqliteDbFileName));

    if (!dbFile.existsSync() || dbFile.lengthSync() < 1024) {
      // 1. Try compressed bundle first (smaller APK size)
      var loaded = false;
      try {
        final gzData = await rootBundle.load('assets/db/transit.sqlite.gz');
        final bytes = gzData.buffer
            .asUint8List(gzData.offsetInBytes, gzData.lengthInBytes);
        final decompressed = gzip.decode(bytes);
        await dbFile.writeAsBytes(decompressed, flush: true);
        loaded = true;
      } catch (_) {}

      // 2. Fallback to uncompressed sqlite if available
      if (!loaded) {
        try {
          final data = await rootBundle.load('assets/db/transit.sqlite');
          final bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await dbFile.writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }
    }
    return NativeDatabase.createInBackground(dbFile);
  });
}
