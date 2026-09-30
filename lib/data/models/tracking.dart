import 'common.dart';

class TrackingSummary {
  const TrackingSummary({
    required this.people,
    required this.equipment,
    required this.vehicles,
    required this.online,
    required this.offline,
    required this.lowBattery,
    required this.alerts,
  });

  final int people;
  final int equipment;
  final int vehicles;
  final int online;
  final int offline;
  final int lowBattery;
  final int alerts;

  int get tracked => people + equipment + vehicles;
}

enum TrackedKind { person, equipment, vehicle, alert }

/// A pin on the indoor floor plan. [x] and [y] are 0–1 fractions of the plan.
class TrackedEntity {
  const TrackedEntity({
    required this.id,
    required this.label,
    required this.kind,
    required this.x,
    required this.y,
    required this.zone,
    this.assetId,
    this.status = 'Online',
  });

  final String id;
  final String label;
  final TrackedKind kind;
  final double x;
  final double y;
  final String zone;
  final String? assetId;
  final String status;

  TrackedEntity copyWith({double? x, double? y, String? zone, String? status}) => TrackedEntity(
    id: id,
    label: label,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    zone: zone ?? this.zone,
    assetId: assetId,
    status: status ?? this.status,
  );
}

/// Live data for a tracked vehicle (FL-012, FL-015).
class VehicleTelemetry {
  const VehicleTelemetry({
    required this.assetId,
    required this.batteryPct,
    required this.speedKmh,
    required this.moving,
    required this.hoursUsed,
    required this.loadTonnes,
    required this.rssiDbm,
    required this.voltage,
    required this.current,
    required this.motorTempC,
    required this.engineOn,
    required this.zone,
    required this.lastUpdated,
    this.route = const [],
    this.routeIndex = 0,
    this.batteryTrend = const [],
  });

  final String assetId;
  final int batteryPct;
  final double speedKmh;
  final bool moving;
  final double hoursUsed;
  final double loadTonnes;
  final int rssiDbm;
  final double voltage;
  final double current;
  final double motorTempC;
  final bool engineOn;
  final String zone;
  final DateTime lastUpdated;

  /// Route across the floor plan (0–1 fractions) and where the vehicle is on it.
  final List<TrendPoint> route;
  final int routeIndex;
  final List<TrendPoint> batteryTrend;

  String get loadStatus => loadTonnes > 0 ? 'Loaded' : 'No Load';
  String get motion => moving ? 'Moving' : 'Idle';

  VehicleTelemetry copyWith({int? routeIndex, String? zone, DateTime? lastUpdated, double? speedKmh, bool? moving}) =>
      VehicleTelemetry(
        assetId: assetId,
        batteryPct: batteryPct,
        speedKmh: speedKmh ?? this.speedKmh,
        moving: moving ?? this.moving,
        hoursUsed: hoursUsed,
        loadTonnes: loadTonnes,
        rssiDbm: rssiDbm,
        voltage: voltage,
        current: current,
        motorTempC: motorTempC,
        engineOn: engineOn,
        zone: zone ?? this.zone,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        route: route,
        routeIndex: routeIndex ?? this.routeIndex,
        batteryTrend: batteryTrend,
      );
}

class TrackActivity {
  const TrackActivity({required this.title, required this.detail, required this.at, this.assetId});

  final String title;
  final String detail;
  final DateTime at;
  final String? assetId;
}
