import 'dart:async';
import 'dart:ffi';

import 'package:asset360_mobile/app/client_demo.dart';
import 'package:asset360_mobile/data/api/dashboard/network_status_live.dart';
import 'package:asset360_mobile/data/db/app_database.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
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
  // Home's Live Devices card never opens a real WebSocket in tests: an idle socket that connects
  // and stays quiet (test/live/dashboard_test.dart drives the reconnect logic with its own fake).
  LiveDevicesNotifier.debugConnector = (_, _) => IdleLiveSocket();
  await testMain();
}

/// Connects at once, sends nothing, closes when asked.
class IdleLiveSocket implements LiveSocket {
  final _messages = StreamController<Object?>();

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> close() => _messages.close();
}
