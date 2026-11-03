import 'dart:async';
import 'dart:ffi';

import 'package:asset360_mobile/app/client_demo.dart';
import 'package:asset360_mobile/data/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

/// Runs before every test file: the module tests exercise the full app whatever
/// `kUseClientDemo` says. Client demo tests set `debugClientDemo = true` themselves.
/// The on-device database is replaced by a fresh in-memory SQLite database per container.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugClientDemo = false;
  // Linux hosts often have only the runtime library (libsqlite3.so.0), not the dev symlink.
  open.overrideFor(OperatingSystem.linux, () {
    try {
      return DynamicLibrary.open('libsqlite3.so');
    } on ArgumentError {
      return DynamicLibrary.open('libsqlite3.so.0');
    }
  });
  openAppDatabase = () => DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true);
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  await testMain();
}
