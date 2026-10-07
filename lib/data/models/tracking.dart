import 'package:asset360_mobile/data/models/common.dart';

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

abstract final class TrackStatus {
  static const moving = 'Moving';
  static const offline = 'Offline';
  static const lowBattery = 'Low Battery';
}

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
    this.lastSeen,
  });

  final String id;
  final String label;
  final TrackedKind kind;
  final double x;
  final double y;
  final String zone;
  final String? assetId;

  /// Online, Moving, Idle, Offline, Low Battery, Alert, Unauthorized Area …
  final String status;
  final DateTime? lastSeen;

  bool get online => status != TrackStatus.offline;

  TrackedEntity copyWith({double? x, double? y, String? zone, String? status, DateTime? lastSeen}) => TrackedEntity(
    id: id,
    label: label,
    kind: kind,
    x: x ?? this.x,
    y: y ?? this.y,
    zone: zone ?? this.zone,
    assetId: assetId,
    status: status ?? this.status,
    lastSeen: lastSeen ?? this.lastSeen,
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

  /// Route across the floor plan (0–1 fractions). The vehicle drives it there and back:
  /// [routeIndex] counts steps around that loop (0 … [loopLength] − 1).
  final List<TrendPoint> route;
  final int routeIndex;
  final List<TrendPoint> batteryTrend;

  String get loadStatus => loadTonnes > 0 ? 'Loaded' : 'No Load';
  String get motion => moving ? 'Moving' : 'Idle';

  int get loopLength => route.length < 2 ? 1 : route.length * 2 - 2;

  /// Index into [route] for a loop step.
  int pointAt(int step) {
    if (route.length < 2) return 0;
    final s = step % loopLength;
    return s < route.length ? s : loopLength - s;
  }

  /// Current position on the plan (null for vehicles without a route).
  TrendPoint? get position => route.isEmpty ? null : route[pointAt(routeIndex)];

  /// True while driving from the first route point towards the last.
  bool get outbound => routeIndex % loopLength < route.length - 1;

  /// The dotted trail: route points driven on the current leg, oldest first, ending at [position].
  List<TrendPoint> get trail {
    if (route.isEmpty) return const [];
    final i = pointAt(routeIndex);
    return outbound ? route.sublist(0, i + 1) : route.sublist(i).reversed.toList();
  }

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

/// A geofence drawn on the floor plan ([left], [top], [width], [height] are 0–1 fractions).
class Geofence {
  const Geofence({
    required this.id,
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.alertOnEntry = false,
    this.alertOnExit = false,
    this.restricted = false,
  });

  final String id;
  final String name;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool alertOnEntry;
  final bool alertOnExit;

  /// Only listed assets may enter (shown red on the map).
  final bool restricted;

  bool contains(double x, double y) => x >= left && x <= left + width && y >= top && y <= top + height;

  Geofence copyWith({bool? alertOnEntry, bool? alertOnExit}) => Geofence(
    id: id,
    name: name,
    left: left,
    top: top,
    width: width,
    height: height,
    alertOnEntry: alertOnEntry ?? this.alertOnEntry,
    alertOnExit: alertOnExit ?? this.alertOnExit,
    restricted: restricted,
  );
}

/// An asset entering or leaving a floor-plan zone (Asset Tracking → History).
class ZoneEvent {
  const ZoneEvent({required this.assetId, required this.zone, required this.entered, required this.at});

  final String assetId;
  final String zone;
  final bool entered;
  final DateTime at;
}

enum SensorKind { temperature, vibration, door, battery }

/// A monitored sensor (Tracking → Sensors). Temperature / vibration values come from the
/// asset's telemetry ([key]), battery from its IoT device; a door sensor has its own [doorOpen].
class SensorDef {
  const SensorDef({
    required this.id,
    required this.name,
    required this.kind,
    required this.assetId,
    required this.threshold,
    this.key,
    this.doorOpen = false,
    this.since,
  });

  final String id;
  final String name;
  final SensorKind kind;
  final String assetId;

  /// Telemetry key on the asset (temperature / vibration).
  final String? key;

  /// Alert above this value (temperature, vibration), below it (battery), or minutes open (door).
  final double threshold;
  final bool doorOpen;

  /// Door: when it was opened.
  final DateTime? since;
}

/// One metric of a tracked asset (Telemetry tab tile and chart). [spread] and [slope] shape the
/// generated history: values wander by ±[spread] and change by [slope] per hour going back in time.
class TrackMetric {
  const TrackMetric({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    this.decimals = 1,
    this.spread = 0,
    this.slope = 0,
    this.min,
    this.max,
    this.text,
  });

  final String key;
  final String label;
  final double value;
  final String unit;
  final int decimals;
  final double spread;
  final double slope;
  final double? min;
  final double? max;

  /// Shown instead of a number (Location: "Main Warehouse / Zone B"); no chart.
  final String? text;

  bool get chartable => text == null;
  String get display => text ?? '${value.toStringAsFixed(decimals)}${unit.isEmpty ? '' : ' $unit'}';
}

/// Time range of the telemetry charts. Changing it regenerates the history.
enum TelemetryRange {
  hour('Last 1 Hour', Duration(hours: 1), Duration(minutes: 5)),
  day('Last 24 Hours', Duration(hours: 24), Duration(minutes: 30)),
  week('Last 7 Days', Duration(days: 7), Duration(hours: 4));

  const TelemetryRange(this.label, this.span, this.step);
  final String label;
  final Duration span;
  final Duration step;
}

/// One point of a generated telemetry history.
typedef TimedValue = ({DateTime at, double value});
