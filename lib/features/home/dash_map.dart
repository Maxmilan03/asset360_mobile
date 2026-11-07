import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';

/// OpenStreetMap map of assets with coordinates (GET /api/dashboards/mobile/asset-locations), one
/// pin per asset coloured by status group. [interactive] false = the small Home preview.
class DashAssetMap extends StatelessWidget {
  const DashAssetMap({
    super.key,
    required this.assets,
    this.center,
    this.selectedId,
    this.onPinTap,
    this.onMapTap,
    this.interactive = true,
    this.controller,
  });

  final List<DashLocatedAsset> assets;
  final DashGeoPoint? center;
  final String? selectedId;
  final ValueChanged<DashLocatedAsset>? onPinTap;
  final VoidCallback? onMapTap;
  final bool interactive;
  final MapController? controller;

  /// OSM tiles for now (a hosted tile service / API key can replace it later).
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const userAgent = 'com.purpleiq.asset360_mobile';

  static LatLng point(DashLocatedAsset a) => LatLng(a.latitude, a.longitude);

  @override
  Widget build(BuildContext context) {
    final points = [for (final a in assets) point(a)];
    final c = center == null
        ? (points.isEmpty ? const LatLng(25.2048, 55.2708) : points.first)
        : LatLng(center!.latitude, center!.longitude);
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: c,
        initialZoom: 13,
        initialCameraFit: points.length > 1
            ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(36), maxZoom: 17)
            : null,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onTap: onMapTap == null ? null : (_, _) => onMapTap!(),
      ),
      children: [
        TileLayer(urlTemplate: tileUrl, userAgentPackageName: userAgent),
        MarkerLayer(
          markers: [
            for (final a in assets)
              Marker(
                point: point(a),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: _Pin(
                  color: dashStatusColor(a.statusGroup),
                  selected: a.assetRegistrationId == selectedId,
                  label: a.assetName ?? a.assetTag ?? a.assetRegistrationId,
                  onTap: onPinTap == null ? null : () => onPinTap!(a),
                ),
              ),
          ],
        ),
        if (interactive)
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => AppLauncher.openUrl('https://openstreetmap.org/copyright'),
              ),
            ],
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.selected, required this.label, this.onTap});

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.location_on_rounded,
        size: selected ? 40 : 34,
        color: color,
        shadows: [Shadow(color: AppColors.text.withValues(alpha: .35), blurRadius: 4)],
      ),
    ),
  );
}
