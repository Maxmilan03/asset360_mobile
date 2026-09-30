import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/tracking_mock.dart';
import '../models/tracking.dart';
import 'repo_utils.dart';

class TrackingState {
  const TrackingState({required this.summary, required this.entities, required this.vehicles, required this.activity});

  final TrackingSummary summary;
  final List<TrackedEntity> entities;
  final List<VehicleTelemetry> vehicles;
  final List<TrackActivity> activity;

  VehicleTelemetry? vehicle(String assetId) => vehicles.firstWhereOrNull((v) => v.assetId == assetId);
  List<TrackedEntity> ofKind(TrackedKind k) => entities.where((e) => e.kind == k).toList();

  TrackingState copyWith({
    List<TrackedEntity>? entities,
    List<VehicleTelemetry>? vehicles,
    List<TrackActivity>? activity,
  }) => TrackingState(
    summary: summary,
    entities: entities ?? this.entities,
    vehicles: vehicles ?? this.vehicles,
    activity: activity ?? this.activity,
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
  );

  /// Moves a vehicle one step along its route (called by the live simulation).
  /// Logs an activity entry when it enters a new zone.
  void advance(String assetId) {
    final v = state.vehicle(assetId);
    if (v == null || v.route.isEmpty) return;
    final i = (v.routeIndex + 1) % v.route.length;
    final p = v.route[i];
    final zone = zoneAt(p.x, p.y);
    final now = DemoClock.now;
    state = state.copyWith(
      vehicles: [
        for (final x in state.vehicles)
          x.assetId == assetId ? x.copyWith(routeIndex: i, zone: zone, lastUpdated: now) : x,
      ],
      entities: [
        for (final e in state.entities)
          e.assetId == assetId && e.kind == TrackedKind.vehicle ? e.copyWith(x: p.x, y: p.y, zone: zone) : e,
      ],
      activity: zone == v.zone
          ? state.activity
          : [
              TrackActivity(
                title: 'Forklift $assetId',
                detail: 'Moved to Warehouse - $zone',
                at: now,
                assetId: assetId,
              ),
              ...state.activity,
            ],
    );
  }
}

final trackingProvider = NotifierProvider<TrackingNotifier, TrackingState>(TrackingNotifier.new);
