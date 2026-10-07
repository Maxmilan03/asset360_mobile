import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/mock/seed_utils.dart';

/// The 6 scans shown in design/05_scan_identify.jpg (GEN-01 there is GEN-00045).
List<ScanRecord> seedScans() => [
  ScanRecord(id: 'SCN-006', kind: ScanKind.asset, refId: 'MTR-00123', at: sep(25, 10, 24)),
  ScanRecord(id: 'SCN-005', kind: ScanKind.asset, refId: 'FL-012', at: sep(25, 10, 18), method: 'RFID'),
  ScanRecord(id: 'SCN-004', kind: ScanKind.asset, refId: 'FP-0021', at: sep(25, 10, 12)),
  ScanRecord(id: 'SCN-003', kind: ScanKind.asset, refId: 'LAP-0098', at: sep(25, 10, 5), method: 'Barcode'),
  ScanRecord(id: 'SCN-002', kind: ScanKind.asset, refId: 'AHU-03', at: sep(25, 9, 58), method: 'NFC'),
  ScanRecord(id: 'SCN-001', kind: ScanKind.asset, refId: 'GEN-00045', at: sep(25, 9, 50)),
];

/// BLE beacons around the demo user on Production Floor 1 (Scan → BLE), strongest first.
const seedBeacons = [
  BleBeacon(assetId: 'MTR-00123', rssi: -48),
  BleBeacon(assetId: 'CNC-00123', rssi: -58),
  BleBeacon(assetId: 'CNC-021', rssi: -67),
  BleBeacon(assetId: 'AHU-02', rssi: -79),
];

/// A printed tag that is not in the register (Developer → Print demo tags).
const demoUnregisteredTag = 'QR-A360-000901';

/// Prefix of location QR codes ("LOC:Main Plant / Production Floor 1 – Line 1").
const locationCodePrefix = 'LOC:';
