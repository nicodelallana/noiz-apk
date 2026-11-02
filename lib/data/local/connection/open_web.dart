import 'dart:io' show File;

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';
import 'package:sqlite3/wasm.dart';

const _dbPath = '/transit.sqlite';

/// Browser build: loads the bundled `transit.sqlite` into an in-memory VFS
/// on every visit, so it always matches the deployed asset. Saved trips live
/// only for the session. Needs `web/sqlite3.wasm` (same version as sqlite3).
QueryExecutor openTransitDatabase({File? file}) {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    final fs = InMemoryFileSystem();
    final data = await rootBundle.load('assets/db/transit.sqlite');
    fs.xOpen(
      Sqlite3Filename(_dbPath),
      SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
    ).file
      ..xWrite(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), 0)
      ..xClose();
    sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
    return WasmDatabase(sqlite3: sqlite3, path: _dbPath);
  });
}
