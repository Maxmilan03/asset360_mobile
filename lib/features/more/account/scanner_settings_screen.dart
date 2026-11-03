import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/scanning/hht_scanner.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';

/// Settings → Scanner: how the handheld terminal's scanner reaches the app (broadcast intents and /
/// or keyboard input), the intent preset, and a Test scanner box. While this screen is showing,
/// scanner reads only appear in the test box (nothing opens).
class ScannerSettingsScreen extends ConsumerStatefulWidget {
  const ScannerSettingsScreen({super.key});

  @override
  ConsumerState<ScannerSettingsScreen> createState() => _ScannerSettingsScreenState();
}

class _ScannerSettingsScreenState extends ConsumerState<ScannerSettingsScreen> {
  final _action = TextEditingController();
  final _extra = TextEditingController();

  /// Test mode: every read is shown in the box instead of being opened.
  late final _target = ScanTarget(accepts: ScanTarget.all, onScan: (_) {}, debugLabel: 'Scanner test');

  @override
  void initState() {
    super.initState();
    final s = ref.read(scannerSettingsProvider);
    _action.text = s.customAction;
    _extra.text = s.customExtra;
  }

  @override
  void dispose() {
    _action.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _update(ScannerSettings s) => ref.read(scannerSettingsProvider.notifier).update(s);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(scannerSettingsProvider);
    final last = ref.watch(lastHardwareReadProvider);
    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(title.toUpperCase(), style: AppText.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: .6)),
    );
    return ScanTargetScope(
      target: _target,
      child: AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: [
            const PageTitle(
              title: 'Scanner',
              subtitle: 'Handheld terminal (HHT) barcode scanner',
              help:
                  'Broadcast: the scanner service sends each read as an Android intent (Zebra DataWedge, Honeywell, '
                  'Urovo or your own action / extra). Keyboard: the scanner types the code and presses Enter. Auto '
                  'listens for both. Reads work on every screen.',
            ),
            section('Mode'),
            AppCard(
              padding: EdgeInsets.zero,
              child: RadioGroup<HhtMode>(
                groupValue: s.mode,
                onChanged: (m) => m == null ? null : _update(s.copyWith(mode: m)),
                child: Column(
                  children: [
                    for (final m in HhtMode.values)
                      RadioListTile<HhtMode>(
                        value: m,
                        title: Text(m.label, style: AppText.bodyStrong),
                        subtitle: Text(m.description, style: AppText.caption),
                      ),
                  ],
                ),
              ),
            ),
            if (s.mode != HhtMode.keyboard) ...[
              section('Broadcast intent'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      label: 'Scanner preset',
                      child: DropdownButtonFormField<String>(
                        initialValue: s.presetId,
                        isExpanded: true,
                        items: [for (final p in HhtPreset.all) DropdownMenuItem(value: p.id, child: Text(p.label))],
                        onChanged: (v) => v == null ? null : _update(s.copyWith(presetId: v)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (s.isCustom) ...[
                      LabeledField(
                        label: 'Intent action',
                        required: true,
                        child: TextField(
                          controller: _action,
                          decoration: const InputDecoration(hintText: 'e.g. com.example.SCAN'),
                          onChanged: (v) => _update(s.copyWith(customAction: v)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LabeledField(
                        label: 'Data extra key',
                        required: true,
                        child: TextField(
                          controller: _extra,
                          decoration: const InputDecoration(hintText: 'e.g. barcode_data'),
                          onChanged: (v) => _update(s.copyWith(customExtra: v)),
                        ),
                      ),
                    ] else ...[
                      InfoRow(label: 'Action', value: s.action),
                      InfoRow(label: 'Extra', value: s.extraKey),
                      if (s.preset.note != null) ...[
                        const SizedBox(height: 6),
                        Text(s.preset.note!, style: AppText.caption),
                      ],
                    ],
                    if (!HhtBroadcast.supported) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Broadcast intents are Android only. On this device use Keyboard mode.',
                        style: AppText.caption.copyWith(color: AppColors.orange),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            section('Test scanner'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconSquare(icon: Icons.qr_code_scanner_rounded, tone: TileTone.lavender, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Press the scanner trigger and point it at any barcode. The value appears below.',
                          style: AppText.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: last == null ? AppColors.background : AppColors.greenBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: last == null ? AppColors.border : AppColors.green),
                    ),
                    child: last == null
                        ? Text('Waiting for a scan…', textAlign: TextAlign.center, style: AppText.secondary)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last received (${last.via})', style: AppText.caption),
                              const SizedBox(height: 4),
                              SelectableText(last.value, style: AppText.sectionTitle),
                              const SizedBox(height: 4),
                              Text(DateFormat('HH:mm:ss').format(last.at), style: AppText.caption),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
