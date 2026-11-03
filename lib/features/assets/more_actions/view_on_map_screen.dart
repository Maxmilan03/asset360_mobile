import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Current Location card and the floor plan with the asset's pin: floor selector, zoom, recenter,
/// fullscreen, and "Open in Tracking" for assets with an IoT device.
class ViewOnMapScreen extends ConsumerStatefulWidget {
  const ViewOnMapScreen({super.key, required this.assetId});

  final String? assetId;

  @override
  ConsumerState<ViewOnMapScreen> createState() => _ViewOnMapScreenState();
}

class _ViewOnMapScreenState extends ConsumerState<ViewOnMapScreen> {
  String? _floor; // null = the asset's floor

  Future<void> _pickFloor(List<String> floors, String current, String assetFloor) async {
    final f = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Select Floor', style: AppText.sectionTitle),
            ),
            for (final f in floors)
              ListTile(
                leading: Icon(Icons.layers_outlined, color: AppColors.primary),
                title: Text(f),
                subtitle: f == assetFloor ? const Text('Asset is here') : null,
                trailing: f == current ? Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, f),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (f != null) setState(() => _floor = f);
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    return MoreActionPage(
      action: MoreAction.viewOnMap,
      assetId: widget.assetId,
      builder: (context, a) {
        final place = assetFloor(a);
        final floor = _floor ?? place.floor;
        final variant = place.floors.indexOf(floor).clamp(0, 99);
        final onAssetFloor = floor == place.floor;
        final tracked = tracking.entities.firstWhereOrNull((e) => e.assetId == a.id);
        final pin = assetFloorPin(a, tracked);
        return [
          SectionCard(
            title: 'Current Location',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoRow(label: 'Location', value: [a.site, a.location].join(' › '), labelWidth: 96),
                InfoRow(label: 'Floor', value: '${place.building} · ${place.floor}', labelWidth: 96),
                InfoRow(label: 'Department', value: assetDepartment(a), labelWidth: 96),
                InfoRow(label: 'Address', value: siteAddress(a), labelWidth: 96),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Floor Plan', style: AppText.cardTitle)),
                    StatusChip(
                      floor,
                      tone: ChipTone.purple,
                      icon: Icons.layers_outlined,
                      trailingIcon: Icons.keyboard_arrow_down_rounded,
                      onTap: () => _pickFloor(place.floors, floor, place.floor),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 240,
                  child: ZoomableFloorPlan(
                    pins: onAssetFloor ? [pin] : const [],
                    variant: variant,
                    onFullscreen: () => _openFullscreen(context, a, pin, floor, variant, onAssetFloor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  onAssetFloor
                      ? (tracked == null
                            ? 'Last recorded position (no live tag)'
                            : 'Live position from ${a.iot?.model ?? 'tag'}')
                      : '${a.id} is on ${place.floor}, not on $floor',
                  style: AppText.caption,
                ),
                if (a.hasIot) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push(Routes.trackAsset(a.id)),
                      icon: const Icon(Icons.sensors_rounded, size: 18),
                      label: const Text('Open in Tracking'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ];
      },
    );
  }

  void _openFullscreen(BuildContext context, Asset a, TrackedEntity pin, String floor, int variant, bool show) {
    // On the tab's navigator, so the bottom bar stays visible.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text('${a.id} · $floor')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ZoomableFloorPlan(pins: show ? [pin] : const [], variant: variant),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floor plan in an InteractiveViewer with + / − zoom, recenter and (optionally) fullscreen buttons.
class ZoomableFloorPlan extends StatefulWidget {
  const ZoomableFloorPlan({super.key, required this.pins, this.variant = 0, this.onFullscreen});

  final List<TrackedEntity> pins;
  final int variant;
  final VoidCallback? onFullscreen;

  @override
  State<ZoomableFloorPlan> createState() => _ZoomableFloorPlanState();
}

class _ZoomableFloorPlanState extends State<ZoomableFloorPlan> {
  final _controller = TransformationController();
  static const _min = 1.0, _max = 4.0;
  Size _size = Size.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_min, _max);
    final f = next / current;
    final c = Offset(_size.width / 2, _size.height / 2);
    // Scale around the centre of the view.
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(f, f, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    setState(() => _controller.value = m * _controller.value);
  }

  void _recenter() => setState(() => _controller.value = Matrix4.identity());

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback onTap) => Material(
      color: AppColors.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tip,
          child: SizedBox.square(dimension: 34, child: Icon(icon, size: 20, color: AppColors.text)),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        _size = c.biggest;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: _min,
                  maxScale: _max,
                  child: FloorPlan(
                    entities: widget.pins,
                    variant: widget.variant,
                    showZoneLabels: true,
                    showLabels: true,
                    pinSize: 30,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Column(
                  children: [
                    button(Icons.add_rounded, 'Zoom in', () => _zoom(1.5)),
                    const SizedBox(height: 6),
                    button(Icons.remove_rounded, 'Zoom out', () => _zoom(1 / 1.5)),
                    const SizedBox(height: 6),
                    button(Icons.my_location_rounded, 'Recenter', _recenter),
                    if (widget.onFullscreen != null) ...[
                      const SizedBox(height: 6),
                      button(Icons.fullscreen_rounded, 'Fullscreen', widget.onFullscreen!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
