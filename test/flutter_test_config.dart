import 'dart:async';

import 'package:asset360_mobile/app/client_demo.dart';

/// Runs before every test file: the module tests exercise the full app whatever
/// `kUseClientDemo` says. Client demo tests set `debugClientDemo = true` themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugClientDemo = false;
  await testMain();
}
