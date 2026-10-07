import 'dart:math' as math;

enum ScanKind { asset, part, location }

class ScanRecord {
  const ScanRecord({required this.id, required this.kind, required this.refId, required this.at, this.method = 'QR'});

  final String id;
  final ScanKind kind;

  /// Asset ID, part number or location code.
  final String refId;
  final DateTime at;

  /// QR, Barcode, NFC, RFID, BLE or Manual.
  final String method;
}

/// A BLE beacon fitted to an asset, as heard by the phone (simulated BLE scan).
class BleBeacon {
  const BleBeacon({required this.assetId, required this.rssi});

  final String assetId;

  /// Received signal strength, dBm (−40 is very close, −90 is at the edge of range).
  final int rssi;

  /// Distance estimate from a log-distance path-loss model (−59 dBm at 1 m, n = 2).
  double get distanceM => math.pow(10, (-59 - rssi) / 20).toDouble();

  /// 1 – 4 bars for the signal icon.
  int get bars => rssi >= -55
      ? 4
      : rssi >= -65
      ? 3
      : rssi >= -75
      ? 2
      : 1;
}
