import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/tracking.dart';

/// Icon and colour of a telemetry metric tile (design 06, right screen).
(IconData, Color) metricLook(String key) => switch (key) {
  'battery' => (Icons.battery_5_bar_rounded, AppColors.iconGreen),
  'hours' || 'runtime' => (Icons.schedule_rounded, AppColors.purple),
  'motorTemp' || 'temperature' => (Icons.device_thermostat_rounded, AppColors.red),
  'voltage' || 'energy' => (Icons.bolt_rounded, AppColors.iconOrange),
  'current' || 'vibration' => (Icons.monitor_heart_outlined, AppColors.purple),
  'load' => (Icons.scale_outlined, AppColors.iconBlue),
  'speed' || 'spindle' || 'feedRate' => (Icons.speed_rounded, AppColors.iconGreen),
  'location' => (Icons.location_on_rounded, AppColors.iconBlue),
  'signal' => (Icons.signal_cellular_alt_rounded, AppColors.iconGreen),
  'door' => (Icons.sensor_door_outlined, AppColors.iconOrange),
  _ => (Icons.sensors_rounded, AppColors.grey),
};

(IconData, Color) sensorLook(SensorKind k) => switch (k) {
  SensorKind.temperature => metricLook('temperature'),
  SensorKind.vibration => metricLook('vibration'),
  SensorKind.door => metricLook('door'),
  SensorKind.battery => metricLook('battery'),
};

/// Online / Offline chip with a dot.
class OnlineChip extends StatelessWidget {
  const OnlineChip({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) =>
      StatusChip(online ? 'Online' : 'Offline', tone: online ? ChipTone.green : ChipTone.red);
}

/// "Forklift FL-012 / Moved to Warehouse - Zone B / 1 min ago"; opens the asset when it has one.
class TrackActivityRow extends StatelessWidget {
  const TrackActivityRow({super.key, required this.activity});

  final TrackActivity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final (icon, color) = switch (a.title) {
      final t when t.startsWith('Forklift') => (Icons.forklift, AppColors.iconOrange),
      final t when t.startsWith('Pallet') => (Icons.inventory_2_rounded, AppColors.iconBlue),
      final t when t.startsWith('Tool') => (Icons.warning_rounded, AppColors.red),
      _ => (Icons.person_rounded, AppColors.iconBlue),
    };
    return InkWell(
      onTap: () => a.assetId == null
          ? context.showSnack('${a.title}: ${a.detail} (${DemoClock.formatTime(a.at)})')
          : context.push(Routes.trackAsset(a.assetId!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(a.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(DemoClock.timeAgo(a.at), style: AppText.caption),
          ],
        ),
      ),
    );
  }
}

/// Which pin kinds and overlays the map shows.
class MapLayers {
  const MapLayers({
    this.people = true,
    this.equipment = true,
    this.vehicles = true,
    this.alerts = true,
    this.zones = false,
  });

  final bool people;
  final bool equipment;
  final bool vehicles;
  final bool alerts;
  final bool zones;

  bool shows(TrackedKind k) => switch (k) {
    TrackedKind.person => people,
    TrackedKind.equipment => equipment,
    TrackedKind.vehicle => vehicles,
    TrackedKind.alert => alerts,
  };

  MapLayers copyWith({bool? people, bool? equipment, bool? vehicles, bool? alerts, bool? zones}) => MapLayers(
    people: people ?? this.people,
    equipment: equipment ?? this.equipment,
    vehicles: vehicles ?? this.vehicles,
    alerts: alerts ?? this.alerts,
    zones: zones ?? this.zones,
  );
}

/// Layers sheet: toggles for People / Equipment / Vehicles / Alerts / Zones. Returns the new layers.
Future<MapLayers?> showLayersSheet(BuildContext context, MapLayers current) {
  return showModalBottomSheet<MapLayers>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      var layers = current;
      return StatefulBuilder(
        builder: (context, setState) {
          Widget row(IconData icon, Color color, String label, bool value, MapLayers Function(bool) apply) =>
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(icon, color: color),
                title: Text(label, style: AppText.bodyStrong),
                value: value,
                onChanged: (v) => setState(() => layers = apply(v)),
              );
          return sheetFrame(context, [
            const SheetTitle('Map Layers', subtitle: 'Choose what the floor plan shows'),
            row(Icons.person_rounded, AppColors.iconBlue, 'People', layers.people, (v) => layers.copyWith(people: v)),
            row(
              Icons.shopping_cart_rounded,
              AppColors.iconGreen,
              'Equipment',
              layers.equipment,
              (v) => layers.copyWith(equipment: v),
            ),
            row(Icons.forklift, AppColors.iconOrange, 'Vehicles', layers.vehicles, (v) => layers.copyWith(vehicles: v)),
            row(Icons.warning_rounded, AppColors.red, 'Alerts', layers.alerts, (v) => layers.copyWith(alerts: v)),
            row(
              Icons.fence_rounded,
              AppColors.primary,
              'Zones (geofences)',
              layers.zones,
              (v) => layers.copyWith(zones: v),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, layers), child: const Text('Apply')),
          ]);
        },
      );
    },
  );
}

/// Signal bars for an RSSI value (4 = strong).
class SignalBars extends StatelessWidget {
  const SignalBars({super.key, required this.rssi, this.height = 18});

  final int rssi;
  final double height;

  int get bars => rssi >= -55
      ? 4
      : rssi >= -65
      ? 3
      : rssi >= -75
      ? 2
      : 1;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Signal $bars of 4',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 1; i <= 6; i++)
            Container(
              width: 4,
              height: height * (.35 + .65 * i / 6),
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i <= (bars * 1.5).round() ? AppColors.iconGreen : AppColors.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
