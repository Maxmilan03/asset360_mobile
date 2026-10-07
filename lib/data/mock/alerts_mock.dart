import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/mock/assets_mock.dart';
import 'package:asset360_mobile/data/mock/seed_utils.dart';
import 'package:asset360_mobile/data/mock/tracking_mock.dart';

/// 45 alerts: Critical 8, High 12, Medium 18, Low 7.
List<AlertItem> seedAlerts() {
  final named = <AlertItem>[
    AlertItem(
      id: 'ALT-2026-0245',
      type: 'Low Battery',
      severity: Severity.critical,
      assetId: 'FL-015',
      message: 'Asset battery level has fallen below 20%',
      at: sep(25, 10, 25),
      location: 'Main Warehouse / Zone B',
      threshold: '< 20%',
      value: '18%',
      description: 'Battery level has dropped to 18%. Please charge the asset to avoid downtime.',
      trend: alertBatteryTrendFl015,
      trendLabel: 'Battery Level Trend (Last 24 Hours)',
    ),
    AlertItem(
      id: 'ALT-2026-0244',
      type: 'High Temperature',
      severity: Severity.critical,
      assetId: 'GEN-00045',
      message: 'High temperature detected (85°C)',
      at: sep(25, 10, 24),
      location: seedLocationOf('GEN-00045'),
      threshold: '> 80°C',
      value: '85°C',
      description: 'Engine temperature is above the 80 °C limit.',
    ),
    AlertItem(
      id: 'ALT-2026-0243',
      type: 'Maintenance Due',
      severity: Severity.high,
      assetId: 'GEN-00045',
      message: 'GEN-00045 is due for scheduled maintenance on 28 Sep 2026',
      at: sep(25, 10, 0),
      location: seedLocationOf('GEN-00045'),
      reportedBy: 'System (PM Schedule)',
      description: 'Monthly scheduled maintenance is due on 28 Sep 2026.',
    ),
    AlertItem(
      id: 'ALT-2026-0242',
      type: 'Temperature Out of Range',
      severity: Severity.critical,
      assetId: 'CR-001',
      message: 'CR-001 temperature is 12°C (threshold: 2–8°C)',
      at: sep(25, 9, 45),
      location: 'Storage Area',
      status: AlertStatus.acknowledged,
      threshold: '2–8°C',
      value: '12°C',
      description: 'Cold room temperature is above the allowed range. Stored goods may be affected.',
      trend: hourly(5, 1.5, bumps: {9: 6, 10: 7}, seed: 11),
      trendLabel: 'Temperature Trend (Last 24 Hours)',
      history: [LogEntry(at: sep(25, 9, 52), title: 'Acknowledged', by: 'Suresh Kumar')],
    ),
    AlertItem(
      id: 'ALT-2026-0241',
      type: 'Vibration Threshold Exceeded',
      severity: Severity.high,
      assetId: 'CNC-021',
      message: 'Vibration level above threshold',
      at: sep(25, 9, 15),
      location: 'Main Plant / Production Floor 1',
      threshold: '> 4.5 mm/s',
      value: '6.1 mm/s',
    ),
    AlertItem(
      id: 'ALT-2026-0240',
      type: 'Asset Moved to Unauthorized Area',
      severity: Severity.medium,
      assetId: 'TL-034',
      message: 'TL-034 moved to unauthorized area (Admin Block – 2nd Floor)',
      at: sep(25, 9, 30),
      location: seedLocationOf('TL-034'),
      reportedBy: 'System (Geofence)',
    ),
    AlertItem(
      id: 'ALT-2026-0239',
      type: 'Asset Moved to Unauthorized Zone',
      severity: Severity.medium,
      assetId: 'FL-012',
      message: 'Asset moved to unauthorized zone',
      at: sep(25, 8, 42),
      location: seedLocationOf('FL-012'),
      reportedBy: 'System (Geofence)',
    ),
    AlertItem(
      id: 'ALT-2026-0238',
      type: 'Vibration Threshold Exceeded',
      severity: Severity.medium,
      assetId: 'MTR-007',
      message: 'MTR-007 vibration level exceeded 8.5 mm/s',
      at: sep(25, 8, 30),
      location: 'Production Line 2',
      threshold: '> 7.1 mm/s',
      value: '8.5 mm/s',
      trend: hourly(5.2, 1.5, bumps: {8: 3.3}, seed: 9),
      trendLabel: 'Vibration Trend (Last 24 Hours)',
    ),
    AlertItem(
      id: 'ALT-2026-0237',
      type: 'Door Opened',
      severity: Severity.low,
      assetId: 'CAB-011',
      message: 'Electrical cabinet door opened',
      at: sep(25, 7, 30),
      location: 'Utility Room',
      reportedBy: 'System (Door Sensor)',
    ),
  ];

  // Generated history to reach the totals. Older alerts are acknowledged or resolved.
  const templates = {
    Severity.critical: [
      ('Offline Device', 'CNC-00123', 'Gateway lost connection for 15 minutes'),
      ('Fire Pump Pressure Low', 'FP-0021', 'Discharge pressure dropped below 6 bar'),
      ('Temperature Out of Range', 'CR-001', 'Cold room temperature above 8°C'),
      ('High Temperature', 'GEN-00046', 'Engine temperature above 80°C during test'),
      ('Low Battery', 'FL-015', 'Battery level below 20%'),
    ],
    Severity.high: [
      ('Maintenance Due', 'AHU-02', 'Quarterly maintenance is due'),
      ('Vibration Threshold Exceeded', 'MTR-00123', 'Vibration above 4.5 mm/s'),
      ('Filter Pressure High', 'AHU-03', 'Filter differential pressure high'),
      ('Maintenance Overdue', 'FL-015', 'Battery replacement WO is overdue'),
      ('Power Fluctuation', 'CAB-011', 'Voltage fluctuation detected'),
    ],
    Severity.medium: [
      ('Geofence Exit', 'FL-012', 'Left the Zone B geofence'),
      ('Signal Weak', 'TL-034', 'BLE tag signal weak'),
      ('Idle Too Long', 'FL-015', 'Idle for more than 2 hours'),
      ('Runtime Limit', 'CNC-021', 'Continuous runtime above 10 hours'),
      ('Humidity High', 'CR-001', 'Humidity above 85%'),
    ],
    Severity.low: [
      ('Door Opened', 'CAB-011', 'Cabinet door opened'),
      ('Firmware Update', 'CNC-00123', 'Firmware v1.2.6 available'),
      ('Battery Replaced', 'TL-034', 'Tag battery replaced'),
    ],
  };
  const targets = {Severity.critical: 8, Severity.high: 12, Severity.medium: 18, Severity.low: 7};
  final all = [...named];
  var seq = 236;
  var hoursBack = 4;
  for (final sev in Severity.all) {
    final have = all.where((a) => a.severity == sev).length;
    final list = templates[sev]!;
    for (var i = 0; have + i < targets[sev]!; i++) {
      final t = list[i % list.length];
      final at = sep(25, 10, 30).subtract(Duration(hours: hoursBack));
      hoursBack += 3;
      all.add(
        AlertItem(
          id: 'ALT-2026-${(seq--).toString().padLeft(4, '0')}',
          type: t.$1,
          severity: sev,
          assetId: t.$2,
          message: t.$3,
          at: at,
          location: seedLocationOf(t.$2),
          status: i.isEven ? AlertStatus.resolved : AlertStatus.acknowledged,
        ),
      );
    }
  }
  all.sort((a, b) => b.at.compareTo(a.at));
  return all;
}

const _sys = NotificationCategory.system;
const _wo = NotificationCategory.workOrders;

/// 18 notifications, 12 unread; all System, 6 also Work Orders.
List<AppNotification> seedNotifications() => [
  AppNotification(
    id: 'N-018',
    kind: 'lowBattery',
    title: 'Low Battery Alert',
    message: 'FL-015 battery level is 18% (below 20%)',
    at: sep(25, 10, 25),
    categories: const {_sys},
    refType: 'alert',
    refId: 'ALT-2026-0245',
  ),
  AppNotification(
    id: 'N-017',
    kind: 'woCreated',
    title: 'Work Order Created',
    message: 'WO-2026-0046 created from ISS-2026-0056 (GEN-00046)',
    at: sep(25, 10, 27),
    categories: const {_sys, _wo},
    refType: 'workOrder',
    refId: 'WO-2026-0046',
  ),
  AppNotification(
    id: 'N-016',
    kind: 'issue',
    title: 'Issue Reported',
    message: 'ISS-2026-0056 Generator not starting (Critical)',
    at: sep(25, 10, 24),
    categories: const {_sys},
    refType: 'issue',
    refId: 'ISS-2026-0056',
  ),
  AppNotification(
    id: 'N-015',
    kind: 'temperature',
    title: 'High Temperature',
    message: 'GEN-00045 temperature is 85°C (above 80°C)',
    at: sep(25, 10, 24),
    categories: const {_sys},
    refType: 'alert',
    refId: 'ALT-2026-0244',
  ),
  AppNotification(
    id: 'N-014',
    kind: 'woStarted',
    title: 'Work Order Started',
    message: 'Mohammed Rafi started WO-2026-0045 (GEN-00045)',
    at: sep(25, 10, 26),
    categories: const {_sys, _wo},
    refType: 'workOrder',
    refId: 'WO-2026-0045',
  ),
  AppNotification(
    id: 'N-013',
    kind: 'woAssigned',
    title: 'Work Order Assigned',
    message: 'WO-2026-0138 assigned to you for Chiller service (CH-00021)',
    at: sep(25, 10, 18),
    categories: const {_sys, _wo},
    refType: 'workOrder',
    refId: 'WO-2026-0138',
  ),
  AppNotification(
    id: 'N-012',
    kind: 'maintenanceDue',
    title: 'Maintenance Due',
    message: 'GEN-00045 is due for scheduled maintenance on 28 Sep 2026',
    at: sep(25, 10, 0),
    categories: const {_sys},
    refType: 'alert',
    refId: 'ALT-2026-0243',
  ),
  AppNotification(
    id: 'N-011',
    kind: 'approval',
    title: 'Approval Request',
    message: 'MOV-2026-0047 from Ahmed Ali is waiting for your approval',
    at: sep(25, 9, 55),
    categories: const {_sys},
    refType: 'movement',
    refId: 'MOV-2026-0047',
  ),
  AppNotification(
    id: 'N-010',
    kind: 'temperature',
    title: 'Temperature Out of Range',
    message: 'CR-001 temperature is 12°C (threshold: 2-8°C)',
    at: sep(25, 9, 45),
    categories: const {_sys},
    refType: 'alert',
    refId: 'ALT-2026-0242',
  ),
  AppNotification(
    id: 'N-009',
    kind: 'inspection',
    title: 'Inspection Overdue',
    message: 'INS-2026-0045 Fire Pump – Routine Inspection was due at 09:00 AM',
    at: sep(25, 9, 0),
    categories: const {_sys},
    refType: 'inspection',
    refId: 'INS-2026-0045',
  ),
  AppNotification(
    id: 'N-008',
    kind: 'assetMoved',
    title: 'Asset Moved',
    message: 'TL-034 moved to unauthorized area (Admin Block – 2nd Floor)',
    at: sep(25, 9, 30),
    categories: const {_sys},
    refType: 'alert',
    refId: 'ALT-2026-0240',
  ),
  AppNotification(
    id: 'N-007',
    kind: 'approval',
    title: 'Approval Request',
    message: 'MOV-2026-0046 from Fatima Noor is waiting for your approval',
    at: sep(25, 8, 40),
    categories: const {_sys},
    refType: 'movement',
    refId: 'MOV-2026-0046',
  ),
  // Read
  AppNotification(
    id: 'N-006',
    kind: 'woCompleted',
    title: 'Work Order Completed',
    message: 'WO-2026-0125 for AHU-03 marked as completed',
    at: sep(25, 8, 30),
    read: true,
    categories: const {_sys, _wo},
    refType: 'workOrder',
    refId: 'WO-2026-0125',
  ),
  AppNotification(
    id: 'N-005',
    kind: 'vibration',
    title: 'Vibration Alert',
    message: 'MTR-007 vibration level exceeded 8.5 mm/s',
    at: sep(25, 7, 30),
    read: true,
    categories: const {_sys},
    refType: 'alert',
    refId: 'ALT-2026-0238',
  ),
  AppNotification(
    id: 'N-004',
    kind: 'stockLow',
    title: 'Stock Level Low',
    message: 'V-Belt VB-1120 stock below reorder point',
    at: sep(25, 6, 30),
    read: true,
    categories: const {_sys},
    refType: 'part',
    refId: 'VB-1120',
  ),
  AppNotification(
    id: 'N-003',
    kind: 'woOverdue',
    title: 'Work Order Overdue',
    message: 'WO-2026-0029 Forklift – Battery replacement is overdue',
    at: sep(24, 17, 0),
    read: true,
    categories: const {_sys, _wo},
    refType: 'workOrder',
    refId: 'WO-2026-0029',
  ),
  AppNotification(
    id: 'N-002',
    kind: 'woAssigned',
    title: 'Work Order Assigned',
    message: 'WO-2026-0038 assigned to you for Tool calibration (TL-034)',
    at: sep(24, 9, 5),
    read: true,
    categories: const {_sys, _wo},
    refType: 'workOrder',
    refId: 'WO-2026-0038',
  ),
  AppNotification(
    id: 'N-001',
    kind: 'sync',
    title: 'Items Waiting to Sync',
    message: '8 items saved offline are waiting to be synced',
    at: sep(22, 16, 20),
    read: true,
    categories: const {_sys},
    refType: 'sync',
  ),
];

/// The simulated live alerts (type, severity, asset, message, location).
const liveAlertTemplates = [
  (
    'Vibration Threshold Exceeded',
    Severity.high,
    'MTR-00123',
    'Vibration 5.2 mm/s (limit 4.5)',
    'Main Plant / Production Floor 1, Dubai',
  ),
  ('Temperature Out of Range', Severity.critical, 'CR-001', 'Cold room 9.4°C (allowed 2–8°C)', 'Storage Area'),
  ('Geofence Exit', Severity.medium, 'FL-012', 'Forklift left the Zone B geofence', 'Main Warehouse / Zone B'),
  ('Door Opened', Severity.low, 'CAB-011', 'Electrical cabinet door opened', 'Utility Room'),
];
