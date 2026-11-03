import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/home_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/home/drilldowns/drilldown_page.dart';
import 'package:asset360_mobile/features/home/home_style.dart';

/// Status chips of the map (null = All).
const _statusChips = <String?>[null, AssetStatus.active, AssetStatus.underMaintenance, AssetStatus.inactive];

Color _pinColor(String status) => assetStatusColors[status] ?? AppColors.blue;

/// Metres walked from the floor's "You are here" marker to [p] along the L route.
int _distanceMetres(MapPin p) {
  final (yx, yy) = p.floor.youAreHere;
  final w = p.floor.widthMetres;
  return ((p.x - yx).abs() * w + (p.y - yy).abs() * w * .6).round();
}

/// Home "Asset Location (Live)" → View Map: every detailed asset as a status pin on the
/// floor plans, tracked assets moving live.
class AssetLocationScreen extends ConsumerStatefulWidget {
  const AssetLocationScreen({super.key});

  @override
  ConsumerState<AssetLocationScreen> createState() => _AssetLocationScreenState();
}

class _AssetLocationScreenState extends ConsumerState<AssetLocationScreen> {
  final _search = TextEditingController();
  final _zoom = TransformationController();
  String _query = '';
  String? _status;
  late String _floorId = _defaultFloor();
  String? _selected;
  bool _directions = false;
  bool _zoneLabels = true;
  bool _pinLabels = false;
  bool _youAreHere = true;

  String _defaultFloor() {
    final site = ref.read(sessionProvider).site;
    final pins = ref.read(mapPinsProvider);
    for (final f in mapFloors) {
      if (f.site == site && pins.any((p) => p.floor.id == f.id)) return f.id;
    }
    return 'wh';
  }

  @override
  void dispose() {
    _search.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _zoomBy(double f, Size size) {
    final current = _zoom.value.getMaxScaleOnAxis();
    final target = (current * f).clamp(1.0, 4.0);
    final s = target / current;
    final c = Offset(size.width / 2, size.height / 2);
    _zoom.value = _zoom.value.clone()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    if (target == 1) _zoom.value = Matrix4.identity();
  }

  void _recenter() => setState(() {
    _zoom.value = Matrix4.identity();
    _directions = false;
  });

  void _select(MapPin p) => setState(() {
    _selected = p.asset.id;
    _directions = false;
  });

  void _openResult(MapPin p) {
    FocusScope.of(context).unfocus();
    setState(() {
      _search.clear();
      _query = '';
      _floorId = p.floor.id;
      if (_status != null && _status != p.asset.status) _status = null;
      _selected = p.asset.id;
      _directions = false;
      _zoom.value = Matrix4.identity();
    });
  }

  void _setFloor(String id) => setState(() {
    _floorId = id;
    _selected = null;
    _directions = false;
    _zoom.value = Matrix4.identity();
  });

  Future<void> _showLayers() => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        Widget toggle(String label, String sub, bool value, void Function(bool) set) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: AppText.bodyStrong),
          subtitle: Text(sub, style: AppText.caption),
          value: value,
          onChanged: (v) {
            setState(() => set(v));
            setSheet(() {});
          },
        );
        return sheetFrame(ctx, [
          const SheetTitle('Map layers'),
          toggle('Zone labels', 'Room and zone names on the plan', _zoneLabels, (v) => _zoneLabels = v),
          toggle('Pin labels', 'Asset ID above each pin', _pinLabels, (v) => _pinLabels = v),
          toggle('You are here', 'Your position marker', _youAreHere, (v) => _youAreHere = v),
        ]);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(trackingLiveProvider); // FL-012 moves every few seconds while the map is open
    ref.watch(trackingProvider);
    final all = ref.watch(mapPinsProvider);
    final floor = mapFloors.firstWhere((f) => f.id == _floorId);
    final onFloor = all.where((p) => p.floor.id == floor.id).toList();
    final shown = onFloor.where((p) => _status == null || p.asset.status == _status).toList();
    final selected = shown.where((p) => p.asset.id == _selected).firstOrNull;
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? const <MapPin>[]
        : all
              .where(
                (p) =>
                    p.asset.id.toLowerCase().contains(q) ||
                    p.asset.name.toLowerCase().contains(q) ||
                    p.asset.location.toLowerCase().contains(q),
              )
              .toList();

    return DrilldownPage(
      title: 'Asset Location (Live)',
      subtitle: 'Where your assets are right now',
      skeletonRows: 3,
      children: [
        SearchFilterBar(
          controller: _search,
          hint: 'Search by Asset ID, name or location',
          onChanged: (v) => setState(() => _query = v),
        ),
        if (q.isNotEmpty) ...[const SizedBox(height: 8), _SearchResults(results: results, onTap: _openResult)],
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in _statusChips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PillChip(
                    label:
                        '${s ?? 'All'} (${s == null ? onFloor.length : onFloor.where((p) => p.asset.status == s).length})',
                    selected: _status == s,
                    onTap: () => setState(() {
                      _status = s;
                      _directions = false;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FloorPicker(floor: floor, onSelected: _setFloor),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ColorDot(color: AppColors.green),
                const SizedBox(width: 5),
                Text(
                  'Live · updated ${DemoClock.formatTime(DemoClock.now)}',
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.2,
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: InteractiveViewer(
                        transformationController: _zoom,
                        maxScale: 4,
                        child: _MapLayer(
                          size: size,
                          floor: floor,
                          pins: shown,
                          selected: selected,
                          directions: _directions,
                          zoneLabels: _zoneLabels,
                          pinLabels: _pinLabels,
                          youAreHere: _youAreHere || _directions,
                          onPin: _select,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Column(
                        children: [
                          _MapButton(icon: Icons.layers_outlined, tooltip: 'Layers', onTap: _showLayers),
                          const SizedBox(height: 8),
                          _MapButton(icon: Icons.my_location_rounded, tooltip: 'Recenter', onTap: _recenter),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        elevation: 2,
                        child: Column(
                          children: [
                            IconButton(
                              tooltip: 'Zoom in',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _zoomBy(1.5, size),
                              icon: const Icon(Icons.add_rounded),
                            ),
                            const SizedBox(width: 28, child: Divider(height: 1)),
                            IconButton(
                              tooltip: 'Zoom out',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _zoomBy(1 / 1.5, size),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SeriesLegend(
          items: [
            for (final s in _statusChips.whereType<String>()) (s, _pinColor(s)),
            (AssetStatus.inTransit, _pinColor(AssetStatus.inTransit)),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          EmptyState(
            icon: Icons.location_off_outlined,
            title: 'No assets here',
            message: 'No ${_status ?? ''} assets on ${floor.name}.',
            actionLabel: 'Show all',
            onAction: () => setState(() => _status = null),
          )
        else if (selected == null)
          Text('Tap a pin to see the asset and get directions.', style: AppText.secondary, textAlign: TextAlign.center)
        else
          _AssetCard(
            pin: selected,
            directions: _directions,
            onDirections: () => setState(() => _directions = !_directions),
          ),
      ],
    );
  }
}

class _FloorPicker extends StatelessWidget {
  const _FloorPicker({required this.floor, required this.onSelected});

  final MapFloor floor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Select site / floor',
      initialValue: floor.id,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final f in mapFloors) PopupMenuItem(value: f.id, child: Text('${f.site} · ${f.name}'))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.layers_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${floor.site} · ${floor.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.results, required this.onTap});

  final List<MapPin> results;
  final ValueChanged<MapPin> onTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyState(icon: Icons.search_off_rounded, title: 'No matching assets');
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < math.min(6, results.length); i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              dense: true,
              leading: Icon(Icons.location_on_rounded, color: _pinColor(results[i].asset.status)),
              title: Text(
                '${results[i].asset.id} · ${results[i].asset.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${results[i].floor.name} · ${results[i].zone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onTap(results[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// The plan, route, "You are here" marker, pins and the callout of the selected pin.
class _MapLayer extends StatelessWidget {
  const _MapLayer({
    required this.size,
    required this.floor,
    required this.pins,
    required this.selected,
    required this.directions,
    required this.zoneLabels,
    required this.pinLabels,
    required this.youAreHere,
    required this.onPin,
  });

  final Size size;
  final MapFloor floor;
  final List<MapPin> pins;
  final MapPin? selected;
  final bool directions;
  final bool zoneLabels;
  final bool pinLabels;
  final bool youAreHere;
  final ValueChanged<MapPin> onPin;

  static const _pin = 28.0;

  @override
  Widget build(BuildContext context) {
    final w = size.width, h = size.height;
    final (yx, yy) = floor.youAreHere;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FloorPlanPainter(showZoneLabels: zoneLabels, variant: floor.variant),
            ),
          ),
          if (directions && selected != null)
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(from: Offset(yx, yy), to: Offset(selected!.x, selected!.y)),
              ),
            ),
          if (youAreHere)
            Positioned(
              left: (yx * w - 40).clamp(0, w - 80),
              top: (yy * h - 9).clamp(0, h - 36),
              width: 80,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [BoxShadow(color: Color(0x552F6BD8), blurRadius: 8, spreadRadius: 3)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'You are here',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.blue),
                  ),
                ],
              ),
            ),
          for (final p in pins) ...[
            if (pinLabels)
              Positioned(
                left: p.x * w - 40,
                width: 80,
                top: p.y * h - _pin - 16,
                child: Center(
                  child: Text(
                    p.asset.id,
                    style: AppText.caption.copyWith(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                ),
              ),
            Positioned(
              left: p.x * w - _pin / 2,
              top: p.y * h - _pin,
              child: GestureDetector(
                key: ValueKey('pin-${p.asset.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onPin(p),
                child: AnimatedScale(
                  scale: p.asset.id == selected?.asset.id ? 1.3 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: _pin,
                    color: _pinColor(p.asset.status),
                    shadows: const [Shadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ],
          if (selected case final s?)
            Positioned(
              left: (s.x * w - 85).clamp(4, w - 174),
              top: s.y * h - _pin - 70 < 4 ? s.y * h + 6 : s.y * h - _pin - 70,
              width: 170,
              child: _Callout(pin: s),
            ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(Routes.assetDetail(pin.asset.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pin.asset.id, style: AppText.bodyStrong.copyWith(fontSize: 12)),
              Text(
                pin.asset.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontSize: 10.5),
              ),
              Text(
                pin.asset.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.pin, required this.directions, required this.onDirections});

  final MapPin pin;
  final bool directions;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final a = pin.asset;
    final metres = _distanceMetres(pin);
    final minutes = math.max(1, (metres / 80).ceil());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              a.imagePath == null
                  ? IconSquare(icon: assetIcon(a), tone: TileTone.lavender, size: 56)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        a.imagePath!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => IconSquare(icon: assetIcon(a), tone: TileTone.lavender, size: 56),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.id, style: AppText.cardTitle.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(a.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              StatusChip(a.status),
            ],
          ),
          if (directions) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.directions_walk_rounded, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$metres m · ~$minutes min walk',
                          style: AppText.bodyStrong.copyWith(fontSize: 13, color: AppColors.blue),
                        ),
                        Text('${pin.floor.name} · ${pin.zone}', style: AppText.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(Routes.assetDetail(a.id)),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDirections,
                  icon: Icon(directions ? Icons.close_rounded : Icons.directions_rounded, size: 18),
                  label: Text(directions ? 'Clear Route' : 'Get Directions'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dashed L route (horizontal, then vertical) from [from] to [to] (0–1 fractions).
class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    Offset px(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    final points = [px(from), px(Offset(to.dx, from.dy)), px(to)];
    final paint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final len = (b - a).distance;
      if (len == 0) continue;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += 12) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + 7, len), paint);
      }
    }
    canvas.drawCircle(points.last, 6, Paint()..color = AppColors.blue.withValues(alpha: .25));
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.from != from || old.to != to;
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.tooltip, required this.onTap, required this.icon});

  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 38, child: Icon(icon, size: 20, color: AppColors.text)),
        ),
      ),
    );
  }
}
