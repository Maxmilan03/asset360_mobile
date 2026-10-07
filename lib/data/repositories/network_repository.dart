import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetType { wifi, mobile, none }

class NetworkState {
  const NetworkState({this.real = NetType.wifi, this.simulatedOffline = false});

  /// What the device reports (connectivity_plus). Wi-Fi until the first report arrives.
  final NetType real;

  /// Developer → "Simulate offline".
  final bool simulatedOffline;

  NetType get type => simulatedOffline ? NetType.none : real;
  bool get online => type != NetType.none;

  NetworkState copyWith({NetType? real, bool? simulatedOffline}) =>
      NetworkState(real: real ?? this.real, simulatedOffline: simulatedOffline ?? this.simulatedOffline);
}

/// Real connectivity plus the demo "Simulate offline" switch.
class NetworkNotifier extends Notifier<NetworkState> {
  /// Tests turn the platform listener off (there is no plugin there).
  static bool listenToDevice = true;

  @override
  NetworkState build() {
    if (listenToDevice && _hasBinding()) {
      StreamSubscription<List<ConnectivityResult>>? sub;
      try {
        final c = Connectivity();
        sub = c.onConnectivityChanged.listen(_report, onError: (_) {});
        c.checkConnectivity().then(_report, onError: (_) {});
      } catch (_) {
        // No plugin (tests, unsupported platform): stay online.
      }
      ref.onDispose(() => sub?.cancel());
    }
    return const NetworkState();
  }

  /// Plain Dart tests have no Flutter binding (and no plugin): stay online there.
  static bool _hasBinding() {
    try {
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _report(List<ConnectivityResult> r) {
    final t = r.contains(ConnectivityResult.wifi) || r.contains(ConnectivityResult.ethernet)
        ? NetType.wifi
        : r.contains(ConnectivityResult.mobile)
        ? NetType.mobile
        : r.isEmpty || r.every((x) => x == ConnectivityResult.none)
        ? NetType.none
        // VPN / Bluetooth / other: treat as Wi-Fi.
        : NetType.wifi;
    if (t != state.real) state = state.copyWith(real: t);
  }

  void setSimulatedOffline(bool v) => state = state.copyWith(simulatedOffline: v);

  /// Tests: pretend the device moved to [t].
  void debugSetReal(NetType t) => state = state.copyWith(real: t);
}

final networkProvider = NotifierProvider<NetworkNotifier, NetworkState>(NetworkNotifier.new);

/// True while the app has no connection (real or simulated).
final isOfflineProvider = Provider<bool>((ref) => !ref.watch(networkProvider).online);
