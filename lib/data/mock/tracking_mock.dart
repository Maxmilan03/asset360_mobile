import '../models/common.dart';
import '../models/tracking.dart';
import 'seed_utils.dart';

TrackingSummary seedTrackingSummary() =>
    const TrackingSummary(people: 24, equipment: 142, vehicles: 12, online: 166, offline: 12, lowBattery: 8, alerts: 6);

/// FL-012's route on the floor plan: Storage → aisle → Zone B → towards Dispatch.
const fl012Route = [
  TrendPoint(.20, .78),
  TrendPoint(.27, .70),
  TrendPoint(.33, .60),
  TrendPoint(.38, .52),
  TrendPoint(.45, .47),
  TrendPoint(.52, .42),
  TrendPoint(.58, .36),
  TrendPoint(.64, .31),
  TrendPoint(.70, .28),
  TrendPoint(.76, .30),
];

List<VehicleTelemetry> seedVehicles() => [
  VehicleTelemetry(
    assetId: 'FL-012',
    batteryPct: 78,
    speedKmh: 5,
    moving: true,
    hoursUsed: 4.2,
    loadTonnes: .8,
    rssiDbm: -62,
    voltage: 48.5,
    current: 12.8,
    motorTempC: 42,
    engineOn: true,
    zone: 'Zone B',
    lastUpdated: sep(25, 10, 24),
    route: fl012Route,
    routeIndex: 6,
    batteryTrend: [for (var h = 0; h <= 10; h++) TrendPoint(h.toDouble(), 92 - h * 1.3), const TrendPoint(10.4, 78)],
  ),
  VehicleTelemetry(
    assetId: 'FL-015',
    batteryPct: 18,
    speedKmh: 0,
    moving: false,
    hoursUsed: 6.8,
    loadTonnes: 0,
    rssiDbm: -70,
    voltage: 44.1,
    current: 2.1,
    motorTempC: 35,
    engineOn: false,
    zone: 'Zone B',
    lastUpdated: sep(25, 10, 25),
    batteryTrend: alertBatteryTrendFl015,
  ),
];

/// 95 % at 00:00 falling to 18 % at 10:24 (the low-battery alert trend).
const alertBatteryTrendFl015 = [
  TrendPoint(0, 95),
  TrendPoint(1, 91),
  TrendPoint(2, 86),
  TrendPoint(3, 80),
  TrendPoint(4, 73),
  TrendPoint(5, 66),
  TrendPoint(6, 58),
  TrendPoint(7, 49),
  TrendPoint(8, 40),
  TrendPoint(9, 30),
  TrendPoint(10, 22),
  TrendPoint(10.4, 18),
];

/// Sample pins on the floor plan (the counts come from [TrackingSummary]).
List<TrackedEntity> seedTrackedEntities() => [
  TrackedEntity(
    id: 'FL-012',
    label: 'Forklift FL-012',
    kind: TrackedKind.vehicle,
    x: .58,
    y: .36,
    zone: 'Zone B',
    assetId: 'FL-012',
    status: 'Moving',
    lastSeen: sep(25, 10, 29),
  ),
  TrackedEntity(
    id: 'FL-015',
    label: 'Forklift FL-015',
    kind: TrackedKind.vehicle,
    x: .66,
    y: .62,
    zone: 'Zone B',
    assetId: 'FL-015',
    status: 'Low Battery',
    lastSeen: sep(25, 10, 25),
  ),
  TrackedEntity(
    id: 'P-rakesh',
    label: 'Rakesh Kumar',
    kind: TrackedKind.person,
    x: .62,
    y: .40,
    zone: 'Zone B',
    lastSeen: sep(25, 10, 28),
  ),
  TrackedEntity(
    id: 'P-suresh',
    label: 'Suresh Kumar',
    kind: TrackedKind.person,
    x: .70,
    y: .66,
    zone: 'Zone B',
    lastSeen: sep(25, 10, 26),
  ),
  TrackedEntity(
    id: 'P-rafi',
    label: 'Mohammed Rafi',
    kind: TrackedKind.person,
    x: .15,
    y: .30,
    zone: 'Receiving',
    lastSeen: sep(25, 10, 21),
  ),
  TrackedEntity(
    id: 'P-ahmed',
    label: 'Ahmed Ali',
    kind: TrackedKind.person,
    x: .86,
    y: .22,
    zone: 'Dispatch',
    lastSeen: sep(25, 10, 27),
  ),
  TrackedEntity(
    id: 'P-ramesh',
    label: 'Ramesh Kumar',
    kind: TrackedKind.person,
    x: .30,
    y: .20,
    zone: 'Receiving',
    lastSeen: sep(25, 10, 18),
  ),
  TrackedEntity(
    id: 'CR-001',
    label: 'Cold Room CR-001',
    kind: TrackedKind.equipment,
    x: .18,
    y: .62,
    zone: 'Storage',
    assetId: 'CR-001',
    lastSeen: sep(25, 9, 45),
  ),
  TrackedEntity(
    id: 'TR-0458',
    label: 'Pallet TR-0458',
    kind: TrackedKind.equipment,
    x: .82,
    y: .55,
    zone: 'Dispatch',
    lastSeen: sep(25, 10, 25),
  ),
  TrackedEntity(
    id: 'CAB-011',
    label: 'Electrical Cabinet CAB-011',
    kind: TrackedKind.equipment,
    x: .44,
    y: .82,
    zone: 'Storage',
    assetId: 'CAB-011',
    lastSeen: sep(25, 7, 30),
  ),
  TrackedEntity(
    id: 'TL-034',
    label: 'Tool Box TL-034',
    kind: TrackedKind.alert,
    x: .50,
    y: .70,
    zone: 'Zone B',
    assetId: 'TL-034',
    status: 'Unauthorized Area',
    lastSeen: sep(25, 9, 30),
  ),
  TrackedEntity(
    id: 'CR-001-A',
    label: 'Temperature alert CR-001',
    kind: TrackedKind.alert,
    x: .22,
    y: .56,
    zone: 'Storage',
    assetId: 'CR-001',
    status: 'Alert',
    lastSeen: sep(25, 9, 45),
  ),
  TrackedEntity(
    id: 'TR-0461',
    label: 'Pallet TR-0461',
    kind: TrackedKind.equipment,
    x: .10,
    y: .88,
    zone: 'Storage',
    status: TrackStatus.offline,
    lastSeen: sep(25, 8, 12),
  ),
];

List<TrackActivity> seedTrackActivity() => [
  TrackActivity(
    title: 'Forklift FL-012',
    detail: 'Moved to Warehouse - Zone B',
    at: sep(25, 10, 29),
    assetId: 'FL-012',
  ),
  TrackActivity(title: 'Pallet TR-0458', detail: 'Exited Production Line 2', at: sep(25, 10, 25)),
  TrackActivity(title: 'Forklift FL-015', detail: 'Battery below 20%', at: sep(25, 10, 25), assetId: 'FL-015'),
  TrackActivity(title: 'Rakesh Kumar', detail: 'Entered Zone B', at: sep(25, 10, 12)),
  TrackActivity(
    title: 'Tool Box TL-034',
    detail: 'Moved to unauthorized area (Admin Block – 2nd Floor)',
    at: sep(25, 9, 30),
    assetId: 'TL-034',
  ),
];

/// Geofences on the warehouse plan (Tracking → Geofencing). TL-034 sits inside the restricted one.
const seedGeofences = [
  Geofence(id: 'GF-01', name: 'Main Warehouse', left: .02, top: .04, width: .70, height: .92, alertOnExit: true),
  Geofence(id: 'GF-02', name: 'Production Floor', left: .76, top: .04, width: .22, height: .92, alertOnEntry: true),
  Geofence(
    id: 'GF-03',
    name: 'Admin Block – Restricted',
    left: .42,
    top: .62,
    width: .24,
    height: .16,
    alertOnEntry: true,
    alertOnExit: true,
    restricted: true,
  ),
];

/// Geofences each tracked asset may enter (Asset Tracking → Geofence).
const seedAllowedZones = {
  'FL-012': {'GF-01', 'GF-02'},
  'FL-015': {'GF-01', 'GF-02'},
  'TL-034': {'GF-01'},
};

/// Zone entries / exits today (Asset Tracking → History), newest first.
List<ZoneEvent> seedZoneEvents() => [
  ZoneEvent(assetId: 'FL-012', zone: 'Zone B', entered: true, at: sep(25, 10, 29)),
  ZoneEvent(assetId: 'FL-012', zone: 'Storage', entered: false, at: sep(25, 10, 28)),
  ZoneEvent(assetId: 'FL-012', zone: 'Storage', entered: true, at: sep(25, 9, 12)),
  ZoneEvent(assetId: 'FL-012', zone: 'Receiving', entered: false, at: sep(25, 9, 11)),
  ZoneEvent(assetId: 'FL-012', zone: 'Receiving', entered: true, at: sep(25, 8, 5)),
  ZoneEvent(assetId: 'FL-015', zone: 'Zone B', entered: true, at: sep(25, 7, 40)),
  ZoneEvent(assetId: 'TL-034', zone: 'Admin Block – Restricted', entered: true, at: sep(25, 9, 30)),
];

/// Monitored sensors (Tracking → Sensors). Values come from the assets' telemetry / IoT devices.
final seedSensors = [
  const SensorDef(
    id: 'SN-T01',
    name: 'Cold Room Temperature',
    kind: SensorKind.temperature,
    assetId: 'CR-001',
    key: 'temperature',
    threshold: 8,
  ),
  const SensorDef(
    id: 'SN-T02',
    name: 'Generator Engine Temperature',
    kind: SensorKind.temperature,
    assetId: 'GEN-00045',
    key: 'temperature',
    threshold: 90,
  ),
  const SensorDef(
    id: 'SN-V01',
    name: 'Motor Vibration',
    kind: SensorKind.vibration,
    assetId: 'MTR-007',
    key: 'vibration',
    threshold: 7.1,
  ),
  const SensorDef(
    id: 'SN-V02',
    name: 'CNC Gateway Vibration',
    kind: SensorKind.vibration,
    assetId: 'CNC-021',
    key: 'vibration',
    threshold: 7.1,
  ),
  SensorDef(
    id: 'SN-D01',
    name: 'Electrical Cabinet Door',
    kind: SensorKind.door,
    assetId: 'CAB-011',
    threshold: 30,
    doorOpen: true,
    since: sep(25, 7, 30),
  ),
  const SensorDef(
    id: 'SN-B01',
    name: 'Forklift FL-015 Battery',
    kind: SensorKind.battery,
    assetId: 'FL-015',
    threshold: 20,
  ),
  const SensorDef(
    id: 'SN-B02',
    name: 'Forklift FL-012 Battery',
    kind: SensorKind.battery,
    assetId: 'FL-012',
    threshold: 20,
  ),
];
