import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../app/theme/app_theme.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/models/tracking.dart';
import '../../data/repositories/repo_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import '../assets/asset_ui.dart';
import 'tracking_map.dart';
import 'tracking_widgets.dart';

enum HubTab {
  map('Live Map', Icons.location_on_rounded),
  list('Asset List', Icons.format_list_bulleted_rounded),
  sensors('Sensors', Icons.sensors_rounded),
  zones('Geofencing', Icons.fence_rounded);

  const HubTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Online / Offline / Low Battery / Alerts counter filter.
enum _Counter { online, offline, lowBattery, alerts }

/// Tracking & IoT hub (left screen of design/06_tracking_iot.jpg).
class TrackingHubScreen extends ConsumerStatefulWidget {
  const TrackingHubScreen({super.key, this.initialTab});

  /// HubTab name, e.g. "sensors".
  final String? initialTab;

  @override
  ConsumerState<TrackingHubScreen> createState() => _TrackingHubScreenState();
}

class _TrackingHubScreenState extends ConsumerState<TrackingHubScreen> {
  late HubTab _tab = HubTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => HubTab.map);
  String _query = '';
  FilterSelection _filters = const {};
  _Counter? _counter;
  TrackedKind? _category;
  MapLayers _layers = const MapLayers();
  String? _selected = 'FL-012';

  static const _filterGroups = [
    FilterGroup(title: 'Type', options: ['People', 'Equipment', 'Vehicles', 'Alerts']),
    FilterGroup(title: 'Zone', options: ['Receiving', 'Storage', 'Zone B', 'Dispatch']),
    FilterGroup(title: 'Status', options: ['Online', 'Offline', 'Moving', 'Low Battery']),
  ];

  static const _kindNames = {
    TrackedKind.person: 'People',
    TrackedKind.equipment: 'Equipment',
    TrackedKind.vehicle: 'Vehicles',
    TrackedKind.alert: 'Alerts',
  };

  @override
  void didUpdateWidget(TrackingHubScreen old) {
    super.didUpdateWidget(old);
    // Opening /more/tracking?tab=… while the hub is already open switches the tab.
    if (widget.initialTab != old.initialTab) {
      _tab = HubTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => _tab);
    }
  }

  bool _matchesQuery(String text) => _query.isEmpty || text.toLowerCase().contains(_query.toLowerCase());

  List<TrackedEntity> _pins(TrackingState t) => [
    for (final e in t.entities)
      if (_layers.shows(e.kind) &&
          (_category == null || e.kind == _category) &&
          switch (_counter) {
            null => true,
            _Counter.online => e.online,
            _Counter.offline => !e.online,
            _Counter.lowBattery => e.status == TrackStatus.lowBattery,
            _Counter.alerts => e.kind == TrackedKind.alert,
          } &&
          _matchesQuery('${e.label} ${e.id} ${e.zone}') &&
          (_filters['Type']?.contains(_kindNames[e.kind]) ?? true) &&
          (_filters['Zone']?.contains(e.zone) ?? true) &&
          (_filters['Status']?.any((s) => s == 'Online' ? e.online : (s == 'Offline' ? !e.online : e.status == s)) ??
              true))
        e,
  ];

  List<Asset> _assets(List<Asset> all, TrackingState t) => [
    for (final a in all)
      if (_matchesQuery('${a.id} ${a.name} ${a.location}') &&
          switch (_counter) {
            null => true,
            _Counter.online => a.iot!.online,
            _Counter.offline => !a.iot!.online,
            _Counter.lowBattery => a.iot!.batteryPct < 20,
            _Counter.alerts => t.hasAlert(a.id),
          })
        a,
  ];

  void _openEntity(TrackedEntity e) {
    if (e.assetId != null) {
      context.push(Routes.trackAsset(e.assetId!));
    } else {
      context.showSnack('${e.label} · ${e.zone} · ${e.status} (no asset record – live position only)');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trackingLiveProvider);
    final t = ref.watch(trackingProvider);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Tracking & IoT',
            subtitle: 'Real-time location, telemetry and asset monitoring',
            help:
                'Live indoor positions from RTLS tags and IoT trackers. Tap a pin for details, use the counters and '
                'chips to filter, and open Geofencing to set alerts when assets enter or leave a zone.',
          ),
          const SizedBox(height: 14),
          _HubTabs(selected: _tab, onChanged: (v) => setState(() => _tab = v)),
          const SizedBox(height: 14),
          if (_tab == HubTab.map || _tab == HubTab.list) ...[
            SearchFilterBar(
              hint: 'Search by asset name, ID or location...',
              onChanged: (v) => setState(() => _query = v),
              filterGroups: _tab == HubTab.map ? _filterGroups : const [],
              selection: _filters,
              onFiltersChanged: _tab == HubTab.map ? (f) => setState(() => _filters = f) : null,
            ),
            const SizedBox(height: 12),
            _Counters(
              summary: t.summary,
              selected: _counter,
              onTap: (c) => setState(() => _counter = _counter == c ? null : c),
            ),
            const SizedBox(height: 12),
          ],
          ...switch (_tab) {
            HubTab.map => _mapTab(t),
            HubTab.list => [
              LoadingGate(
                key: const ValueKey('gate-list'),
                child: _AssetList(assets: _assets(ref.watch(trackedAssetsProvider), t), total: t.summary.tracked),
              ),
            ],
            HubTab.sensors => [const LoadingGate(key: ValueKey('gate-sensors'), child: _SensorsTab())],
            HubTab.zones => [const _GeofencingTab()],
          },
        ],
      ),
    );
  }

  List<Widget> _mapTab(TrackingState t) {
    final pins = _pins(t);
    final s = t.summary;
    final chips = [
      (null, 'All Assets (${s.tracked})'),
      (TrackedKind.person, 'People (${s.people})'),
      (TrackedKind.equipment, 'Equipment (${s.equipment})'),
      (TrackedKind.vehicle, 'Vehicles (${s.vehicles})'),
    ];
    return [
      SizedBox(
        height: 270,
        child: TrackingMap(
          entities: pins,
          geofences: _layers.zones ? t.geofences : const [],
          selectedId: pins.any((p) => p.id == _selected) ? _selected : null,
          onPinTap: (e) => setState(() => _selected = _selected == e.id ? null : e.id),
          onCalloutTap: _openEntity,
          calloutDetail: (e) {
            final ago = e.lastSeen == null ? '' : ' · ${DemoClock.timeAgo(e.lastSeen!)}';
            return '${e.kind == TrackedKind.vehicle ? 'Main Warehouse' : e.zone}$ago';
          },
          onLayers: () async {
            final next = await showLayersSheet(context, _layers);
            if (next != null) setState(() => _layers = next);
          },
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Showing ${pins.length} live pins of ${s.tracked} tracked · updates every ${liveStep.inSeconds} s',
        style: AppText.caption,
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (kind, label) in chips)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconFilterChip(
                  label: label,
                  selected: _category == kind,
                  onTap: () => setState(() => _category = kind),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      // Design 06: the header sits on the page and each event is its own card.
      SectionHeader(
        title: 'Recent Activity',
        actionLabel: 'View All',
        actionIcon: null,
        onAction: () => context.push(Routes.trackingActivity),
      ),
      const SizedBox(height: 8),
      if (t.activity.isEmpty)
        const AppCard(
          child: EmptyState(icon: Icons.timeline_rounded, title: 'No movement yet today'),
        ),
      for (var i = 0; i < t.activity.length && i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: TrackActivityRow(activity: t.activity[i]),
          ),
        ),
    ];
  }
}

// ---------------------------------------------------------------- Top tabs and counters

class _HubTabs extends StatelessWidget {
  const _HubTabs({required this.selected, required this.onChanged});

  final HubTab selected;
  final ValueChanged<HubTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in HubTab.values) ...[
          if (t.index > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: t == selected ? AppColors.tileLavender : AppColors.tileSky.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(AppRadius.tile),
              child: InkWell(
                onTap: () => onChanged(t),
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border(
                      bottom: BorderSide(color: t == selected ? AppColors.primary : Colors.transparent, width: 2.5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon, color: AppColors.primary, size: 24),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.text,
                            fontWeight: t == selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.summary, required this.selected, required this.onTap});

  final TrackingSummary summary;
  final _Counter? selected;
  final ValueChanged<_Counter> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_Counter.online, Icons.battery_full_rounded, summary.online, 'Online', TileTone.mint),
      (_Counter.offline, Icons.battery_alert_rounded, summary.offline, 'Offline', TileTone.pink),
      (_Counter.lowBattery, Icons.signal_cellular_alt_rounded, summary.lowBattery, 'Low Battery', TileTone.peach),
      (_Counter.alerts, Icons.warning_rounded, summary.alerts, 'Alerts', TileTone.sky),
    ];
    return Row(
      children: [
        for (final (i, (c, icon, n, label, tone)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Material(
              color: tone.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: selected == c ? tone.foreground : Colors.transparent, width: 1.5),
              ),
              child: InkWell(
                onTap: () => onTap(c),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    children: [
                      Icon(icon, color: tone.foreground, size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$n', style: AppText.bodyStrong.copyWith(fontSize: 15, color: tone.foreground)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(label, style: AppText.caption.copyWith(fontSize: 10.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Asset List

class _AssetList extends ConsumerWidget {
  const _AssetList({required this.assets, required this.total});

  final List<Asset> assets;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (assets.isEmpty) {
      return const EmptyState(icon: Icons.search_off_rounded, title: 'No tracked assets match');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < assets.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 90),
                _trackedRow(context, assets[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Showing ${assets.length} of $total tracked', textAlign: TextAlign.center, style: AppText.caption),
      ],
    );
  }

  Widget _trackedRow(BuildContext context, Asset a) {
    final iot = a.iot!;
    return AssetListTile(
      title: a.id,
      subtitle: a.name,
      location: a.location,
      imagePath: a.imagePath,
      fallbackIcon: assetIcon(a),
      details: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: iot.online ? AppColors.green : AppColors.red),
            const SizedBox(width: 4),
            Text(iot.online ? 'Online' : 'Offline', style: AppText.caption),
            const SizedBox(width: 10),
            Icon(
              iot.batteryPct < 20 ? Icons.battery_alert_rounded : Icons.battery_5_bar_rounded,
              size: 13,
              color: iot.batteryPct < 20 ? AppColors.red : AppColors.green,
            ),
            Text(' ${iot.batteryPct}%', style: AppText.caption),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                DemoClock.timeAgo(iot.lastSeen),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ],
      onTap: () => context.push(Routes.trackAsset(a.id)),
    );
  }
}

// ---------------------------------------------------------------- Sensors

class _SensorsTab extends ConsumerWidget {
  const _SensorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sensors = ref.watch(sensorsProvider);
    final tracking = ref.watch(trackingProvider);
    final alerts = sensors.where((s) => s.alert).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${sensors.length} sensors · $alerts over threshold', style: AppText.secondary),
        const SizedBox(height: 10),
        if (sensors.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.sensors_off_rounded,
              title: 'No sensors',
              message: 'Link an IoT sensor to an asset to see its readings here.',
            ),
          ),
        for (final s in sensors)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SensorCard(
              reading: s,
              history: () {
                final metric = metricsFor(
                  s.asset,
                  tracking.vehicle(s.asset.id),
                  sensors: sensors,
                ).firstWhereOrNull((m) => m.key == s.metricKey);
                return metric == null
                    ? const <double>[]
                    : [for (final p in telemetryHistory(s.asset.id, metric, TelemetryRange.day)) p.value];
              }(),
            ),
          ),
      ],
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({required this.reading, required this.history});

  final SensorReading reading;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final s = reading;
    final (icon, color) = sensorLook(s.def.kind);
    return AppCard(
      onTap: () => context.push(Routes.trackChart(s.asset.id, s.metricKey)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.def.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.asset.id} · ${s.asset.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  s.thresholdLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
                if (history.length > 1) ...[const SizedBox(height: 6), Sparkline(values: history, color: color)],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(s.valueLabel, style: AppText.cardTitle.copyWith(color: s.alert ? AppColors.red : AppColors.text)),
              const SizedBox(height: 6),
              StatusChip(s.alert ? 'Alert' : 'Normal', tone: s.alert ? ChipTone.red : ChipTone.green),
            ],
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Geofencing

class _GeofencingTab extends ConsumerWidget {
  const _GeofencingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trackingProvider);
    final notifier = ref.read(trackingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 210,
          child: TrackingMap(
            entities: t.entities,
            geofences: t.geofences,
            pinSize: 22,
            onPinTap: (e) {
              final inside = [
                for (final g in t.geofences)
                  if (g.contains(e.x, e.y)) g.name,
              ];
              context.showSnack('${e.label} is in ${inside.isEmpty ? 'no geofence' : inside.join(', ')}');
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Zones (${t.geofences.length})', style: AppText.sectionTitle)),
            FilledButton.icon(
              onPressed: () => context.push(Routes.addGeofence),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Zone'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (t.geofences.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.fence_rounded,
              title: 'No zones yet',
              message: 'Draw a geofence to get alerts when assets enter or leave it.',
              actionLabel: 'Add Zone',
              onAction: () => context.push(Routes.addGeofence),
            ),
          ),
        LoadingGate(
          card: true,
          rows: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in t.geofences)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              g.restricted ? Icons.block_rounded : Icons.fence_rounded,
                              color: g.restricted ? AppColors.red : AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyStrong,
                              ),
                            ),
                            if (g.restricted) const StatusChip('Restricted', tone: ChipTone.red),
                            const SizedBox(width: 6),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 34, top: 2),
                          child: Text(
                            '${t.entities.where((e) => e.kind != TrackedKind.alert && g.contains(e.x, e.y)).length} '
                            'tracked inside now',
                            style: AppText.caption,
                          ),
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 34),
                          title: const Text('Alert on exit'),
                          value: g.alertOnExit,
                          onChanged: (v) {
                            notifier.setFenceAlert(g.id, onExit: v);
                            context.showSnack('${g.name}: exit alerts ${v ? 'on' : 'off'}');
                          },
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 34),
                          title: const Text('Alert on entry'),
                          value: g.alertOnEntry,
                          onChanged: (v) {
                            notifier.setFenceAlert(g.id, onEntry: v);
                            context.showSnack('${g.name}: entry alerts ${v ? 'on' : 'off'}');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
