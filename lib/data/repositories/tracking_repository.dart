import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/tracking_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

class TrackingState {
  const TrackingState({
    required this.summary,
    required this.entities,
    required this.vehicles,
    required this.activity,
    required this.geofences,
    required this.allowed,
    required this.zoneEvents,
  });

  final TrackingSummary summary;
  final List<TrackedEntity> entities;
  final List<VehicleTelemetry> vehicles;

  /// Newest first.
  final List<TrackActivity> activity;
  final List<Geofence> geofences;

  /// Geofence IDs each asset may enter.
  final Map<String, Set<String>> allowed;

  /// Newest first.
  final List<ZoneEvent> zoneEvents;

  VehicleTelemetry? vehicle(String assetId) => vehicles.firstWhereOrNull((v) => v.assetId == assetId);
  List<TrackedEntity> ofKind(TrackedKind k) => entities.where((e) => e.kind == k).toList();

  /// The asset's own pin (not an alert pin about it).
  TrackedEntity? entityFor(String assetId) =>
      entities.firstWhereOrNull((e) => e.assetId == assetId && e.kind != TrackedKind.alert);
  bool hasAlert(String assetId) => entities.any((e) => e.assetId == assetId && e.kind == TrackedKind.alert);
  List<ZoneEvent> zoneHistory(String assetId) => zoneEvents.where((z) => z.assetId == assetId).toList();
  bool isAllowed(String assetId, String fenceId) => allowed[assetId]?.contains(fenceId) ?? false;

  TrackingState copyWith({
    List<TrackedEntity>? entities,
    List<VehicleTelemetry>? vehicles,
    List<TrackActivity>? activity,
    List<Geofence>? geofences,
    Map<String, Set<String>>? allowed,
    List<ZoneEvent>? zoneEvents,
  }) => TrackingState(
    summary: summary,
    entities: entities ?? this.entities,
    vehicles: vehicles ?? this.vehicles,
    activity: activity ?? this.activity,
    geofences: geofences ?? this.geofences,
    allowed: allowed ?? this.allowed,
    zoneEvents: zoneEvents ?? this.zoneEvents,
  );
}

/// Zone of a floor-plan point (the plan is split Storage | Zone B | Dispatch, with Receiving top-left).
String zoneAt(double x, double y) {
  if (x < .33) return y < .45 ? 'Receiving' : 'Storage';
  if (x < .74) return 'Zone B';
  return 'Dispatch';
}

class TrackingNotifier extends Notifier<TrackingState> {
  @override
  TrackingState build() => TrackingState(
    summary: seedTrackingSummary(),
    entities: seedTrackedEntities(),
    vehicles: seedVehicles(),
    activity: seedTrackActivity(),
    geofences: seedGeofences,
    allowed: {
      for (final e in seedAllowedZones.entries) e.key: {...e.value},
    },
    zoneEvents: seedZoneEvents(),
  );

  /// Moves a vehicle one step along its route (called by the live simulation).
  /// Logs an activity entry and zone exit / entry when it enters a new zone.
  void advance(String assetId) {
    final v = state.vehicle(assetId);
    if (v == null || v.route.isEmpty) return;
    final moved = v.copyWith(routeIndex: (v.routeIndex + 1) % v.loopLength, lastUpdated: DemoClock.now);
    final p = moved.position!;
    final zone = zoneAt(p.x, p.y);
    final now = DemoClock.now;
    final changed = zone != v.zone;
    final label = state.entityFor(assetId)?.label ?? assetId;
    state = state.copyWith(
      vehicles: [for (final x in state.vehicles) x.assetId == assetId ? moved.copyWith(zone: zone) : x],
      entities: [
        for (final e in state.entities)
          e.assetId == assetId && e.kind == TrackedKind.vehicle
              ? e.copyWith(x: p.x, y: p.y, zone: zone, lastSeen: now)
              : e,
      ],
      activity: changed
          ? [
              TrackActivity(title: label, detail: 'Moved to Warehouse - $zone', at: now, assetId: assetId),
              ...state.activity,
            ]
          : null,
      zoneEvents: changed
          ? [
              ZoneEvent(assetId: assetId, zone: zone, entered: true, at: now),
              ZoneEvent(assetId: assetId, zone: v.zone, entered: false, at: now),
              ...state.zoneEvents,
            ]
          : null,
    );
  }

  void setFenceAlert(String fenceId, {bool? onEntry, bool? onExit}) => state = state.copyWith(
    geofences: [
      for (final g in state.geofences) g.id == fenceId ? g.copyWith(alertOnEntry: onEntry, alertOnExit: onExit) : g,
    ],
  );

  /// Adds a drawn geofence (fractions of the plan). Returns its ID.
  String addGeofence(
    String name, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final id = nextId('GF-', state.geofences.map((g) => g.id), width: 2);
    state = state.copyWith(
      geofences: [
        ...state.geofences,
        Geofence(id: id, name: name, left: left, top: top, width: width, height: height, alertOnEntry: true),
      ],
    );
    return id;
  }

  void setAllowed(String assetId, String fenceId, bool allowed) {
    final next = {
      for (final e in state.allowed.entries) e.key: {...e.value},
    };
    final set = next.putIfAbsent(assetId, () => {});
    allowed ? set.add(fenceId) : set.remove(fenceId);
    state = state.copyWith(allowed: next);
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);

/// Live simulation: while a tracking screen watches this, FL-012 moves one step every 3 s.
final trackingLiveProvider = Provider.autoDispose<void>((ref) {
  final timer = Timer.periodic(liveStep, (_) => ref.read(trackingProvider.notifier).advance('FL-012'));
  ref.onDispose(timer.cancel);
});

/// How often the live simulation moves the vehicles.
const liveStep = Duration(seconds: 3);

/// Assets with an IoT tracker (Tracking → Asset List), online first.
final trackedAssetsProvider = Provider<List<Asset>>((ref) {
  final list = ref.watch(assetsProvider).where((a) => a.iot != null).toList();
  list.sort((a, b) => (a.iot!.online == b.iot!.online) ? a.id.compareTo(b.id) : (a.iot!.online ? -1 : 1));
  return list;
});

// ---------------------------------------------------------------- Sensors

class SensorReading {
  const SensorReading({required this.def, required this.asset, required this.value, required this.unit});

  final SensorDef def;
  final Asset asset;
  final double value;
  final String unit;

  /// Over the threshold (battery: under it; door: open longer than the threshold in minutes).
  bool get alert => switch (def.kind) {
    SensorKind.battery => value < def.threshold,
    SensorKind.door => def.doorOpen && openMinutes > def.threshold,
    _ => value > def.threshold,
  };

  int get openMinutes => def.since == null ? 0 : DemoClock.now.difference(def.since!).inMinutes;

  String get valueLabel => switch (def.kind) {
    SensorKind.door => def.doorOpen ? 'Open' : 'Closed',
    SensorKind.battery => '${value.round()} $unit',
    _ => '${value.toStringAsFixed(value.abs() >= 20 ? 0 : 1)} $unit',
  };

  String get thresholdLabel => switch (def.kind) {
    SensorKind.door => 'Alert if open > ${def.threshold.round()} min',
    SensorKind.battery => 'Alert below ${def.threshold.round()} $unit',
    _ => 'Alert above ${def.threshold} $unit',
  };

  /// Metric key for the telemetry chart.
  String get metricKey => def.key ?? def.kind.name;
}

final sensorsProvider = Provider<List<SensorReading>>((ref) {
  final assets = ref.watch(assetsProvider);
  final tracking = ref.watch(trackingProvider);
  return [
    for (final d in seedSensors)
      if (assets.firstWhereOrNull((a) => a.id == d.assetId) case final a?)
        switch (d.kind) {
          SensorKind.battery => SensorReading(
            def: d,
            asset: a,
            value: (tracking.vehicle(a.id)?.batteryPct ?? a.iot?.batteryPct ?? 0).toDouble(),
            unit: '%',
          ),
          SensorKind.door => SensorReading(def: d, asset: a, value: d.doorOpen ? 1 : 0, unit: ''),
          _ => SensorReading(
            def: d,
            asset: a,
            value: a.telemetry.firstWhereOrNull((t) => t.key == d.key)?.value ?? 0,
            unit: a.telemetry.firstWhereOrNull((t) => t.key == d.key)?.unit ?? '',
          ),
        },
  ];
});

// ---------------------------------------------------------------- Telemetry metrics and history

/// Tiles of the Telemetry tab. Vehicles get the full set (design 06); other assets get their
/// sensor readings plus battery, signal and location from the IoT device.
List<TrackMetric> metricsFor(Asset asset, VehicleTelemetry? v, {List<SensorReading> sensors = const []}) {
  if (v != null) {
    return [
      TrackMetric(
        key: 'battery',
        label: 'Battery Level',
        value: v.batteryPct.toDouble(),
        unit: '%',
        decimals: 0,
        spread: 1.5,
        slope: 1.3,
        min: 0,
        max: 100,
      ),
      TrackMetric(
        key: 'hours',
        label: 'Operating Hours',
        value: v.hoursUsed,
        unit: 'h',
        spread: .05,
        slope: -.45,
        min: 0,
        max: 8,
      ),
      TrackMetric(
        key: 'motorTemp',
        label: 'Motor Temperature',
        value: v.motorTempC,
        unit: '°C',
        decimals: 0,
        spread: 3,
        min: 20,
        max: 80,
      ),
      TrackMetric(
        key: 'voltage',
        label: 'Voltage',
        value: v.voltage,
        unit: 'V',
        spread: .6,
        slope: .12,
        min: 40,
        max: 52,
      ),
      TrackMetric(key: 'current', label: 'Current', value: v.current, unit: 'A', spread: 3, min: 0, max: 40),
      TrackMetric(key: 'load', label: 'Load', value: v.loadTonnes, unit: 't', spread: .35, min: 0, max: 2),
      TrackMetric(
        key: 'speed',
        label: 'Speed',
        value: v.speedKmh,
        unit: 'km/h',
        decimals: 0,
        spread: 3,
        min: 0,
        max: 12,
      ),
      TrackMetric(key: 'location', label: 'Location', value: 0, unit: '', text: 'Main Warehouse\n${v.zone}'),
      TrackMetric(
        key: 'signal',
        label: 'Signal Strength',
        value: v.rssiDbm.toDouble(),
        unit: 'dBm',
        decimals: 0,
        spread: 4,
        min: -95,
        max: -40,
      ),
    ];
  }
  final iot = asset.iot;
  return [
    for (final t in asset.telemetry)
      TrackMetric(
        key: t.key,
        label: t.label,
        value: t.value,
        unit: t.unit,
        decimals: t.value.abs() >= 100 ? 0 : 1,
        spread: math.max(t.value.abs() * .08, .2),
        min: 0,
      ),
    for (final s in sensors)
      if (s.asset.id == asset.id && s.def.kind == SensorKind.door)
        TrackMetric(
          key: 'door',
          label: 'Door (1 = open)',
          value: s.value,
          unit: '',
          decimals: 0,
          spread: .6,
          min: 0,
          max: 1,
        ),
    if (iot != null) ...[
      TrackMetric(
        key: 'battery',
        label: 'Battery Level',
        value: iot.batteryPct.toDouble(),
        unit: '%',
        decimals: 0,
        spread: 1,
        slope: .4,
        min: 0,
        max: 100,
      ),
      TrackMetric(
        key: 'signal',
        label: 'Signal Strength',
        value: iot.signalDbm.toDouble(),
        unit: 'dBm',
        decimals: 0,
        spread: 4,
        min: -95,
        max: -40,
      ),
    ],
    TrackMetric(key: 'location', label: 'Location', value: 0, unit: '', text: asset.location),
  ];
}

/// History of [m] over [range], ending at [end] with the current value. Deterministic per
/// asset, metric and range, so the same range always shows the same curve.
List<TimedValue> telemetryHistory(String assetId, TrackMetric m, TelemetryRange range, {DateTime? end}) {
  final last = end ?? DemoClock.now;
  final n = range.span.inMinutes ~/ range.step.inMinutes;
  final rand = math.Random(_stableHash('$assetId/${m.key}/${range.name}'));
  final phase = rand.nextDouble() * 6;
  double clampWrap(double v) {
    final lo = m.min, hi = m.max;
    if (lo != null && hi != null) {
      final band = (hi - lo) * .7;
      while (v > hi) {
        v -= band;
      }
      while (v < lo) {
        v += band;
      }
    } else if (lo != null && v < lo) {
      v = lo;
    }
    return v;
  }

  final pow = math.pow(10, m.decimals);
  return [
    for (var i = 0; i <= n; i++)
      () {
        final at = last.subtract(range.step * (n - i));
        if (i == n) return (at: at, value: m.value);
        final hoursBefore = last.difference(at).inMinutes / 60;
        final noise = m.spread * (.6 * math.sin(i * .7 + phase) + .4 * (rand.nextDouble() * 2 - 1));
        final v = clampWrap(m.value + m.slope * hoursBefore + noise);
        return (at: at, value: (v * pow).round() / pow);
      }(),
  ];
}

int _stableHash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x3fffffff);

/// Recorded positions of a vehicle over [range] (View History playback), oldest first.
List<({DateTime at, double x, double y})> routePlayback(VehicleTelemetry v, TelemetryRange range) {
  if (v.route.isEmpty) return const [];
  final steps = switch (range) {
    TelemetryRange.hour => 20,
    TelemetryRange.day => 60,
    TelemetryRange.week => 120,
  };
  final end = v.lastUpdated;
  final dt = range.span ~/ steps;
  return [
    for (var i = 0; i <= steps; i++)
      () {
        final p = v.route[v.pointAt(v.routeIndex - (steps - i))];
        return (at: end.subtract(dt * (steps - i)), x: p.x, y: p.y);
      }(),
  ];
}
