import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/alert.dart';
import '../../data/repositories/assets_repository.dart';
import '../assets/asset_ui.dart';

/// Severity colours (design 11): Critical red, High orange, Medium amber, Low green.
ChipTone severityTone(String severity) => switch (severity) {
  Severity.critical => ChipTone.red,
  Severity.high => ChipTone.orange,
  Severity.medium => ChipTone.amber,
  _ => ChipTone.green,
};

/// Icon for an alert type.
IconData alertIcon(String type) {
  final t = type.toLowerCase();
  if (t.contains('battery')) return Icons.warning_rounded;
  if (t.contains('maintenance')) return Icons.build_rounded;
  if (t.contains('temperature')) return Icons.device_thermostat_rounded;
  if (t.contains('moved') || t.contains('geofence') || t.contains('zone')) return Icons.location_on_rounded;
  if (t.contains('vibration')) return Icons.error_rounded;
  if (t.contains('door')) return Icons.check_circle_rounded;
  if (t.contains('offline') || t.contains('signal')) return Icons.wifi_off_rounded;
  if (t.contains('pressure')) return Icons.speed_rounded;
  if (t.contains('power')) return Icons.bolt_rounded;
  if (t.contains('issue')) return Icons.report_rounded;
  return Icons.notifications_active_rounded;
}

/// Icon square tinted by severity.
class AlertIconSquare extends StatelessWidget {
  const AlertIconSquare({super.key, required this.alert, this.size = 40});

  final AlertItem alert;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = severityTone(alert.severity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(size * .26)),
      child: Icon(alertIcon(alert.type), color: tone.foreground, size: size * .55),
    );
  }
}

/// Alerts list row: severity icon, asset photo, type, "ID | name", location, severity chip, time ago.
class AlertRow extends ConsumerWidget {
  const AlertRow({
    super.key,
    required this.alert,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  final AlertItem alert;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final a = alert;
    final asset = ref.watch(assetByIdProvider(a.assetId));
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (selecting) Checkbox(value: selected, onChanged: (_) => onTap()) else AlertIconSquare(alert: a),
              const SizedBox(width: 8),
              AssetThumb(
                imagePath: asset?.imagePath,
                fallbackIcon: asset == null ? Icons.sensors_rounded : assetIcon(asset),
                size: 52,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.assetId}  |  ${asset?.type ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    IconLine(
                      icon: Icons.location_on_outlined,
                      text: a.location == '—' ? asset?.location ?? '—' : a.location,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(a.severity, tone: severityTone(a.severity)),
                  const SizedBox(height: 10),
                  Text(DemoClock.timeAgo(a.at), style: AppText.caption.copyWith(fontSize: 11)),
                  if (!a.requiresAction) ...[
                    const SizedBox(height: 2),
                    Text(
                      AlertStatus.label(a.status),
                      style: AppText.caption.copyWith(fontSize: 10.5, color: AppColors.green),
                    ),
                  ],
                ],
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add a note (optional)" dialog for Acknowledge / Resolve. Returns null when cancelled.
Future<String?> askAlertNote(BuildContext context, {required String title, required String action}) =>
    showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _NoteDialog(title: title, action: action),
    );

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.title, required this.action});

  final String title;
  final String action;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLines: 2,
        decoration: const InputDecoration(hintText: 'Add a note (optional)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _text.text.trim()), child: Text(widget.action)),
      ],
    );
  }
}
