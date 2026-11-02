import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/transit_constants.dart';

/// Opens `transit.sqlite`, first copying the bundled asset into the
/// documents directory when it is missing or differs in size.
QueryExecutor openTransitDatabase({File? file}) {
  if (file != null) {
    return NativeDatabase.createInBackground(file);
  }
  return LazyDatabase(() async {
    final docs = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docs.path, TransitConstants.sqliteDbFileName));
    try {
      final data = await rootBundle.load('assets/db/transit.sqlite');
      if (!dbFile.existsSync() || dbFile.lengthSync() != data.lengthInBytes) {
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await dbFile.writeAsBytes(bytes, flush: true);
      }
    } catch (_) {
      if (!dbFile.existsSync() || dbFile.lengthSync() < 1024) {
        try {
          final data = await rootBundle.load('assets/db/transit.sqlite');
          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await dbFile.writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }
    }
    return NativeDatabase.createInBackground(dbFile);
  });
}
