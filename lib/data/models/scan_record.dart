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
