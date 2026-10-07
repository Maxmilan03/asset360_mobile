import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/asset_actions.dart';

/// Icon and tile tone per telemetry key (design: blue, blue, violet / blue, green, violet).
(IconData, TileTone) _look(String key) => switch (key) {
  'runtime' => (Icons.schedule_rounded, TileTone.sky),
  'spindle' => (Icons.speed_rounded, TileTone.sky),
  'temperature' => (Icons.thermostat_rounded, TileTone.lavender),
  'vibration' => (Icons.monitor_heart_outlined, TileTone.sky),
  'energy' => (Icons.bolt_rounded, TileTone.mint),
  'feedRate' => (Icons.trending_up_rounded, TileTone.lavender),
  _ => (Icons.sensors_rounded, TileTone.grey),
};

/// Seed values per asset, so the live walk stays close to the recorded readings.
final _seeds = <String, Map<String, double>>{};

bool _whole(double v) => v == v.roundToDouble() && v.abs() >= 10;

String _format(TelemetryReading r, Map<String, double> seeds) {
  final whole = _whole(seeds[r.key] ?? r.value);
  return whole ? NumberFormat('#,##0').format(r.value) : r.value.toStringAsFixed(1);
}

/// IoT tab: live telemetry that ticks every 5 s, a 24-hour trend chart and device details.
class AssetIotTab extends ConsumerStatefulWidget {
  const AssetIotTab({super.key, required this.asset});

  final Asset asset;

  @override
  ConsumerState<AssetIotTab> createState() => _AssetIotTabState();
}

class _AssetIotTabState extends ConsumerState<AssetIotTab> {
  final _rand = math.Random();
  Timer? _timer;
  String? _metric;

  Map<String, double> get _seed =>
      _seeds.putIfAbsent(widget.asset.id, () => {for (final r in widget.asset.telemetry) r.key: r.value});

  @override
  void initState() {
    super.initState();
    _seed;
    final charted = [
      for (final r in widget.asset.telemetry)
        if (widget.asset.trends.containsKey(r.key)) r.key,
    ];
    _metric = charted.contains('temperature') ? 'temperature' : charted.firstOrNull;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final a = ref.read(assetByIdProvider(widget.asset.id));
    if (a == null || a.iot == null || !a.iot!.online || a.telemetry.isEmpty) return;
    final readings = [
      for (final r in a.telemetry)
        if (r.key == 'runtime')
          r.copyWith(value: r.value + 5 / 3600) // hour meter only climbs
        else
          r.copyWith(value: _walk(r.value, _seed[r.key] ?? r.value)),
    ];
    ref.read(assetsProvider.notifier).setTelemetry(a.id, readings);
  }

  /// ±1.5 % step, kept within ±6 % of the seed value.
  double _walk(double v, double seed) {
    final next = v + seed * .015 * (_rand.nextDouble() * 2 - 1);
    final clamped = next.clamp(seed * .94, seed * 1.06).toDouble();
    return _whole(seed) ? clamped.roundToDouble() : double.parse(clamped.toStringAsFixed(2));
  }

  void _select(TelemetryReading r) {
    if (!widget.asset.trends.containsKey(r.key)) {
      context.showSnack('No 24-hour trend is recorded for ${r.label}');
      return;
    }
    setState(() => _metric = r.key);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    final iot = a.iot;
    if (iot == null) {
      return AppCard(
        child: EmptyState(
          icon: Icons.sensors_off_rounded,
          title: 'No IoT device linked',
          message: 'Link a gateway or sensor to see live telemetry, trends and alerts for ${a.id}.',
          actionLabel: 'Link IoT Device',
          onAction: () => showLinkIotSheet(context, ref, a),
        ),
      );
    }
    final metric = a.telemetry.firstWhere(
      (r) => r.key == _metric,
      orElse: () => TelemetryReading(key: _metric ?? '', label: _metric ?? '', value: 0, unit: ''),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LiveTelemetry(asset: a, seeds: _seed, selected: _metric, onSelect: _select),
        if (a.trends.isNotEmpty && _metric != null) ...[
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Live Data Trend (Last 24 Hours)', style: AppText.bodyStrong)),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _metric,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        items: [
                          for (final r in a.telemetry)
                            if (a.trends.containsKey(r.key))
                              DropdownMenuItem(
                                value: r.key,
                                child: Text(
                                  '${_shortLabel(r.label)} (${r.unit})',
                                  style: AppText.body.copyWith(fontSize: 12),
                                ),
                              ),
                        ],
                        onChanged: (v) => setState(() => _metric = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 160,
                  child: TrendChart(points: a.trends[_metric]!, unit: metric.unit),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _DeviceInfo(device: iot),
      ],
    );
  }
}

/// "Vibration (RMS)" → "Vibration"; "Energy Consumption" → "Energy".
String _shortLabel(String label) => label.split(' (').first.replaceAll(' Consumption', '');

class _LiveTelemetry extends StatelessWidget {
  const _LiveTelemetry({required this.asset, required this.seeds, required this.selected, required this.onSelect});

  final Asset asset;
  final Map<String, double> seeds;
  final String? selected;
  final ValueChanged<TelemetryReading> onSelect;

  @override
  Widget build(BuildContext context) {
    final iot = asset.iot!;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Live Telemetry', style: AppText.bodyStrong)),
              _OnlineChip(online: iot.online),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Last Updated: ${DemoClock.formatDateTime(iot.lastSeen)}',
              style: AppText.caption.copyWith(fontSize: 10.5),
            ),
          ),
          const SizedBox(height: 10),
          if (asset.telemetry.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'This device reports location and status only — no sensor readings.',
                textAlign: TextAlign.center,
                style: AppText.secondary,
              ),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.12,
              children: [
                for (final r in asset.telemetry)
                  _TelemetryTile(
                    reading: r,
                    value: _format(r, seeds),
                    selected: r.key == selected,
                    onTap: () => onSelect(r),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OnlineChip extends StatelessWidget {
  const _OnlineChip({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final tone = online ? ChipTone.green : ChipTone.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: tone.foreground),
          const SizedBox(width: 5),
          Text(online ? 'Online' : 'Offline', style: AppText.chip.copyWith(color: tone.foreground)),
        ],
      ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({required this.reading, required this.value, required this.selected, required this.onTap});

  final TelemetryReading reading;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _look(reading.key);
    return Material(
      color: tone.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24, color: tone.foreground),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: FittedBox(
                  key: ValueKey(value),
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('$value ${reading.unit}', style: AppText.bodyStrong.copyWith(fontSize: 14.5)),
                ),
              ),
              Text(
                reading.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceInfo extends StatelessWidget {
  const _DeviceInfo({required this.device});

  final IotDevice device;

  @override
  Widget build(BuildContext context) {
    final bars = switch (device.signalDbm) {
      >= -60 => 4,
      >= -70 => 3,
      >= -80 => 2,
      _ => 1,
    };
    final batteryColor = device.batteryPct < 20
        ? AppColors.red
        : device.batteryPct < 50
        ? AppColors.amber
        : AppColors.green;
    Widget row(IconData icon, String label, Widget value, {VoidCallback? onLongPress}) => InkWell(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            SizedBox(width: 132, child: Text(label, style: AppText.secondary)),
            Expanded(child: value),
          ],
        ),
      ),
    );
    Widget text(String v) => Text(
      v,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12.5, color: AppColors.text),
    );

    return SectionCard(
      title: 'Device Information',
      child: Column(
        children: [
          row(Icons.router_outlined, 'IoT Device', text(device.model)),
          row(Icons.devices_other_outlined, 'Device Type', text(device.type)),
          row(Icons.qr_code_2_rounded, 'IMEI', text(device.imei)),
          row(
            Icons.sim_card_outlined,
            'SIM / ICCID',
            Tooltip(message: 'Long-press to copy', child: text(device.iccid)),
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: device.iccid));
              if (context.mounted) context.showSnack('ICCID copied to clipboard');
            },
          ),
          row(
            Icons.battery_std_rounded,
            'Battery Level',
            Row(
              children: [
                SizedBox(width: 38, child: text('${device.batteryPct}%')),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: device.batteryPct / 100,
                      minHeight: 7,
                      color: batteryColor,
                      backgroundColor: AppColors.divider,
                    ),
                  ),
                ),
              ],
            ),
          ),
          row(
            Icons.signal_cellular_alt_rounded,
            'Signal Strength',
            Row(
              children: [
                Expanded(child: text('${device.signalDbm} dBm')),
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 4,
                    height: 5.0 + i * 3,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      color: i < bars ? AppColors.green : AppColors.border,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
          ),
          row(Icons.access_time_rounded, 'Last Seen', text(DemoClock.formatDateTime(device.lastSeen))),
          row(Icons.memory_rounded, 'Firmware Version', text(device.firmware)),
          row(
            Icons.wifi_tethering_rounded,
            'Connectivity Status',
            Row(
              children: [
                Icon(Icons.circle, size: 9, color: device.online ? AppColors.green : AppColors.red),
                const SizedBox(width: 6),
                Flexible(child: text(device.online ? 'Online' : 'Offline')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
