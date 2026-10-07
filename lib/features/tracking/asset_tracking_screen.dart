import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/models/common.dart';
import '../../data/models/tracking.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/repo_utils.dart';
import '../../data/repositories/tracking_repository.dart';
import '../assets/asset_actions.dart';
import '../assets/asset_ui.dart';
import 'telemetry_view.dart';
import 'tracking_map.dart';
import 'tracking_widgets.dart';

enum TrackTab {
  live('Live Tracking'),
  details('Details'),
  telemetry('Telemetry'),
  history('History'),
  geofence('Geofence');

  const TrackTab(this.label);
  final String label;
}

/// Asset Tracking (middle and right screens of design/06_tracking_iot.jpg).
class AssetTrackingScreen extends ConsumerStatefulWidget {
  const AssetTrackingScreen({super.key, required this.assetId, this.initialTab});

  final String assetId;

  /// TrackTab name, e.g. "telemetry".
  final String? initialTab;

  @override
  ConsumerState<AssetTrackingScreen> createState() => _AssetTrackingScreenState();
}

class _AssetTrackingScreenState extends ConsumerState<AssetTrackingScreen> {
  late TrackTab _tab = TrackTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => TrackTab.live);
  MapLayers _layers = const MapLayers();

  @override
  void didUpdateWidget(AssetTrackingScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      _tab = TrackTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => _tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(trackingLiveProvider);
    final asset = ref.watch(assetsProvider).firstWhereOrNull((a) => a.id == widget.assetId);
    if (asset == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Asset not found',
          message: '${widget.assetId} is not in the asset register.',
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      );
    }
    final t = ref.watch(trackingProvider);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(title: 'Asset Tracking', subtitle: 'Real-time location and live telemetry'),
          const SizedBox(height: 12),
          _AssetCard(asset: asset),
          const SizedBox(height: 8),
          SegmentTabs(
            tabs: [for (final x in TrackTab.values) SegmentTab(x.label)],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = TrackTab.values[i]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            TrackTab.live => _liveTab(asset, t),
            TrackTab.details => _DetailsTab(asset: asset, tracking: t),
            TrackTab.telemetry => TelemetryView(assetId: asset.id),
            TrackTab.history => LoadingGate(
              key: const ValueKey('gate-history'),
              rows: 4,
              child: _HistoryTab(events: t.zoneHistory(asset.id)),
            ),
            TrackTab.geofence => _GeofenceTab(asset: asset, tracking: t),
          },
        ],
      ),
    );
  }

  Widget _liveTab(Asset asset, TrackingState t) {
    final iot = asset.iot;
    final v = t.vehicle(asset.id);
    final own = t.entityFor(asset.id);
    if (iot == null && own == null) {
      return EmptyState(
        icon: Icons.location_off_outlined,
        title: 'No tracker on this asset',
        message: 'Link an IoT device or RTLS tag to see ${asset.id} on the floor plan.',
        actionLabel: 'Link IoT Device',
        onAction: () => showLinkIotSheet(context, ref, asset),
      );
    }
    final updated = v?.lastUpdated ?? iot?.lastSeen ?? own?.lastSeen ?? DemoClock.now;
    final tiles = v != null
        ? [
            (Icons.speed_rounded, AppColors.iconGreen, 'Speed', '${v.speedKmh.toStringAsFixed(0)} km/h'),
            (Icons.battery_5_bar_rounded, AppColors.iconGreen, 'Battery', '${v.batteryPct}%'),
            (Icons.schedule_rounded, AppColors.iconBlue, 'Hours Used', '${v.hoursUsed} h'),
            (Icons.settings_input_component_rounded, AppColors.iconBlue, 'Engine Status', v.engineOn ? 'ON' : 'OFF'),
            (Icons.inventory_2_rounded, AppColors.iconBlue, 'Load Status', v.loadStatus),
            (Icons.signal_cellular_alt_rounded, AppColors.iconGreen, 'RSSI', '${v.rssiDbm} dBm'),
          ]
        : [
            if (iot != null) ...[
              (Icons.battery_5_bar_rounded, AppColors.iconGreen, 'Battery', '${iot.batteryPct}%'),
              (Icons.signal_cellular_alt_rounded, AppColors.iconGreen, 'RSSI', '${iot.signalDbm} dBm'),
              (Icons.wifi_tethering_rounded, AppColors.iconBlue, 'Status', iot.online ? 'Online' : 'Offline'),
            ],
            (Icons.location_on_rounded, AppColors.iconBlue, 'Zone', own?.zone ?? asset.location),
            (Icons.schedule_rounded, AppColors.iconBlue, 'Last Seen', DemoClock.timeAgo(updated)),
            if (iot != null) (Icons.sensors_rounded, AppColors.purple, 'Device', iot.type),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (own == null)
          AppCard(
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${asset.id} is outside the RTLS floor plan. Last known location: ${asset.location}.',
                    style: AppText.secondary,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 240,
            child: TrackingMap(
              entities: [
                for (final e in t.entities)
                  if (e.id == own.id || _layers.shows(e.kind)) e,
              ],
              geofences: _layers.zones ? t.geofences : const [],
              trail: v?.trail ?? const <TrendPoint>[],
              selectedId: own.id,
              bubble: v == null ? null : '${v.motion} · ${v.speedKmh.toStringAsFixed(0)} km/h',
              onPinTap: (e) => e.id == own.id
                  ? context.showSnack('${e.label} · ${e.zone} · ${e.status}')
                  : e.assetId != null && e.kind != TrackedKind.alert
                  ? context.push(Routes.trackAsset(e.assetId!))
                  : context.showSnack('${e.label} · ${e.zone} · ${e.status}'),
              onLayers: () async {
                final next = await showLayersSheet(context, _layers);
                if (next != null) setState(() => _layers = next);
              },
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Last Updated: ${DemoClock.formatStamp(updated)}',
                  style: AppText.caption.copyWith(color: AppColors.text),
                ),
              ),
              Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                (iot?.online ?? true) ? 'Live' : 'Offline',
                style: AppText.bodyStrong.copyWith(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: [
            for (final (icon, color, label, value) in tiles)
              AppCard(
                padding: const EdgeInsets.all(10),
                onTap: () => setState(() => _tab = TrackTab.telemetry),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(fontSize: 10.5),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(value, style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: v == null
                    ? () => setState(() => _tab = TrackTab.history)
                    : () => showRoutePlayback(context, ref, asset.id),
                icon: const Icon(Icons.history_rounded),
                label: const Text('View History'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push(Routes.createWorkOrder(assetId: asset.id)),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Create Work Order'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssetCard extends ConsumerWidget {
  const _AssetCard({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => context.push(Routes.assetDetail(asset.id)),
      child: Row(
        children: [
          AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 92),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        asset.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle.copyWith(fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (asset.iot != null) OnlineChip(online: asset.iot!.online),
                  ],
                ),
                const SizedBox(height: 4),
                Text(asset.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                const SizedBox(height: 6),
                IconLine(icon: Icons.location_on_outlined, text: asset.location),
                const SizedBox(height: 4),
                IconLine(icon: Icons.person_outline_rounded, text: 'Assigned to: ${asset.custodian}'),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.asset, required this.tracking});

  final Asset asset;
  final TrackingState tracking;

  @override
  Widget build(BuildContext context) {
    final iot = asset.iot;
    final pin = tracking.entityFor(asset.id);
    final rows = [
      ('Asset ID', asset.id),
      ('Name', asset.name),
      ('Type', asset.type),
      ('Category', asset.category),
      ('Manufacturer / Model', asset.manufacturerModel),
      ('Serial No.', asset.serialNo ?? '—'),
      ('Tag ID (RFID)', asset.tagId ?? '—'),
      ('Location', asset.location),
      ('Current Zone', pin?.zone ?? '—'),
      ('Site', asset.site),
      ('Assigned To', asset.custodian),
      ('Status', asset.status),
      if (iot != null) ...[('Tracker', '${iot.model} (${iot.type})'), ('IMEI', iot.imei), ('Firmware', iot.firmware)],
    ];
    return AppCard(
      child: Column(
        children: [
          for (final (label, value) in rows) InfoRow(label: label, value: value),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(Routes.assetDetail(asset.id)),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Asset 360°'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.events});

  final List<ZoneEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_rounded,
        title: 'No zone history',
        message: 'Zone entries and exits appear here once the asset moves between zones.',
      );
    }
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: events[i].entered ? AppColors.greenBg : AppColors.orangeBg,
                        ),
                        child: Icon(
                          events[i].entered ? Icons.login_rounded : Icons.logout_rounded,
                          size: 15,
                          color: events[i].entered ? AppColors.green : AppColors.orange,
                        ),
                      ),
                      if (i < events.length - 1) Expanded(child: Container(width: 2, color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16, top: 3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${events[i].entered ? 'Entered' : 'Exited'} ${events[i].zone}',
                            style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                          ),
                          const SizedBox(height: 2),
                          Text(DemoClock.formatDateTime(events[i].at), style: AppText.caption),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GeofenceTab extends ConsumerWidget {
  const _GeofenceTab({required this.asset, required this.tracking});

  final Asset asset;
  final TrackingState tracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pin = tracking.entityFor(asset.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Zones ${asset.id} may enter. Entering any other zone raises an alert.', style: AppText.secondary),
        const SizedBox(height: 10),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, g) in tracking.geofences.indexed) ...[
                if (i > 0) const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    g.restricted ? Icons.block_rounded : Icons.fence_rounded,
                    color: g.restricted ? AppColors.red : AppColors.primary,
                  ),
                  title: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  subtitle: Text(
                    [
                      tracking.isAllowed(asset.id, g.id) ? 'Allowed' : 'Not allowed',
                      if (pin != null && g.contains(pin.x, pin.y)) 'Inside now',
                    ].join(' · '),
                    style: AppText.caption,
                  ),
                  value: tracking.isAllowed(asset.id, g.id),
                  onChanged: (v) {
                    ref.read(trackingProvider.notifier).setAllowed(asset.id, g.id, v);
                    context.showSnack('${asset.id} ${v ? 'allowed in' : 'blocked from'} ${g.name}');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- View History playback

/// Route playback: pick a time range, scrub with the slider or press play.
Future<void> showRoutePlayback(BuildContext context, WidgetRef ref, String assetId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) => _PlaybackSheet(assetId: assetId),
  );
}

class _PlaybackSheet extends ConsumerStatefulWidget {
  const _PlaybackSheet({required this.assetId});

  final String assetId;

  @override
  ConsumerState<_PlaybackSheet> createState() => _PlaybackSheetState();
}

class _PlaybackSheetState extends ConsumerState<_PlaybackSheet> {
  TelemetryRange _range = TelemetryRange.hour;
  late List<({DateTime at, double x, double y})> _track;
  double _pos = 0;
  Timer? _play;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final v = ref.read(trackingProvider).vehicle(widget.assetId);
    _track = v == null ? const [] : routePlayback(v, _range);
    _pos = 0;
  }

  void _toggle() {
    if (_play != null) {
      _stop();
      return;
    }
    if (_pos >= _track.length - 1) setState(() => _pos = 0);
    _play = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (!mounted) return t.cancel();
      if (_pos >= _track.length - 1) return _stop();
      setState(() => _pos++);
    });
    setState(() {});
  }

  void _stop() {
    _play?.cancel();
    _play = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _play?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entity = ref.watch(trackingProvider).entityFor(widget.assetId);
    if (_track.isEmpty || entity == null) {
      return sheetFrame(context, [const SheetTitle('View History', subtitle: 'No recorded route for this asset')]);
    }
    final i = _pos.round();
    final now = _track[i];
    final from = _track.take(i + 1).toList();
    return sheetFrame(context, [
      SheetTitle('Route History · ${widget.assetId}', subtitle: 'Play back where the asset drove'),
      Align(
        alignment: Alignment.centerLeft,
        child: RangeDropdown(
          value: _range,
          onChanged: (r) {
            _stop();
            setState(() {
              _range = r;
              _load();
            });
          },
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 220,
        child: TrackingMap(
          entities: [entity.copyWith(x: now.x, y: now.y)],
          trail: [for (final p in from.skip(from.length > 12 ? from.length - 12 : 0)) TrendPoint(p.x, p.y)],
          selectedId: entity.id,
          bubble: DemoClock.formatTime(now.at),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton.filled(
            tooltip: _play == null ? 'Play' : 'Pause',
            onPressed: _toggle,
            icon: Icon(_play == null ? Icons.play_arrow_rounded : Icons.pause_rounded),
          ),
          Expanded(
            child: Slider(
              value: _pos,
              max: (_track.length - 1).toDouble(),
              divisions: _track.length - 1,
              label: DemoClock.formatTime(now.at),
              onChanged: (v) {
                _stop();
                setState(() => _pos = v);
              },
            ),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              DemoClock.formatDateTime(_track.first.at),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              DemoClock.formatDateTime(_track.last.at),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppText.caption,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        '${DemoClock.formatDateTime(now.at)} · ${zoneAt(now.x, now.y)}',
        textAlign: TextAlign.center,
        style: AppText.bodyStrong,
      ),
    ]);
  }
}
