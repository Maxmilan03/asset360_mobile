import '../models/scan_record.dart';
import 'seed_utils.dart';

/// The 6 scans shown in design/05_scan_identify.jpg (GEN-01 there is GEN-00045).
List<ScanRecord> seedScans() => [
  ScanRecord(id: 'SCN-006', kind: ScanKind.asset, refId: 'MTR-00123', at: sep(25, 10, 24)),
  ScanRecord(id: 'SCN-005', kind: ScanKind.asset, refId: 'FL-012', at: sep(25, 10, 18), method: 'RFID'),
  ScanRecord(id: 'SCN-004', kind: ScanKind.asset, refId: 'FP-0021', at: sep(25, 10, 12)),
  ScanRecord(id: 'SCN-003', kind: ScanKind.asset, refId: 'LAP-0098', at: sep(25, 10, 5), method: 'Barcode'),
  ScanRecord(id: 'SCN-002', kind: ScanKind.asset, refId: 'AHU-03', at: sep(25, 9, 58), method: 'NFC'),
  ScanRecord(id: 'SCN-001', kind: ScanKind.asset, refId: 'GEN-00045', at: sep(25, 9, 50)),
];
