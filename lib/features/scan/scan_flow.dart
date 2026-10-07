import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/asset.dart';
import '../../data/models/audit.dart';
import '../../data/models/scan_record.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/audits_repository.dart';
import '../../data/repositories/scans_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../assets/asset_ui.dart';
import '../registration/registration_widgets.dart';

/// How a code reached the app (stored on the scan history record).
abstract final class ScanMethod {
  static const qr = 'QR';
  static const barcode = 'Barcode';
  static const nfc = 'NFC';
  static const rfid = 'RFID';
  static const ble = 'BLE';
  static const manual = 'Manual';
}

/// Handles one scanned code from any mode: a known asset / part / location is added to
/// the top of Scan History and opened (asset → Asset Identified); an unknown code shows
/// the "Tag not registered" sheet. Completes when the user comes back to the scanner.
/// Returns the target, or null when the code was not registered.
Future<ScanTarget?> openScannedCode(BuildContext context, WidgetRef ref, String code, {required String method}) async {
  final history = ref.read(scanHistoryProvider.notifier);
  final target = history.resolve(code);
  scanFeedback(ref, recognised: target != null);
  if (target == null) {
    await _showUnregisteredSheet(context, code.trim(), method);
    return null;
  }
  history.add(target.kind, target.refId, method: method);
  final here = GoRouterState.of(context).uri.path;
  switch (target.kind) {
    case ScanKind.asset:
      await context.push(Routes.scanResultFrom(here, target.refId));
    case ScanKind.part:
      await context.push(Routes.partDetail(target.refId));
    case ScanKind.location:
      context.showSnack('Location ${target.refId} – showing assets on the floor plan');
      await context.push(Routes.tracking);
  }
  return target;
}

/// Settings → Scanning: beep and / or vibrate when a code is read.
void scanFeedback(WidgetRef ref, {bool recognised = true}) {
  final s = ref.read(appSettingsProvider);
  if (s.beep) SystemSound.play(recognised ? SystemSoundType.click : SystemSoundType.alert);
  if (s.vibrate) recognised ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
}

/// "Tag not registered" with Register this asset (→ registration, prefilled) and Scan again.
Future<void> _showUnregisteredSheet(BuildContext context, String code, String method) async {
  final register = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => sheetFrame(context, [
      Icon(Icons.qr_code_2_rounded, size: 52, color: AppColors.textSecondary),
      const SizedBox(height: 10),
      Text('Tag not registered', textAlign: TextAlign.center, style: AppText.sectionTitle),
      const SizedBox(height: 6),
      Text(
        'No asset, part or location in Asset360 matches "$code".',
        textAlign: TextAlign.center,
        style: AppText.secondary,
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, true),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Register this asset'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(context, false),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan again'),
      ),
    ]),
  );
  if (register != true || !context.mounted) return;
  final rfid = method == ScanMethod.nfc || method == ScanMethod.rfid;
  await context.push(
    Routes.newRegistration,
    extra: rfid ? RegistrationPrefill(tagId: code) : RegistrationPrefill(barcode: code.toUpperCase()),
  );
}

// ---------------------------------------------------------------- Manual entry

/// Asset ID field that suggests matching assets as you type. Returns the code entered.
Future<String?> showManualEntrySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ManualEntrySheet(),
  );
}

class _ManualEntrySheet extends ConsumerStatefulWidget {
  const _ManualEntrySheet();

  @override
  ConsumerState<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<_ManualEntrySheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    final code = (value ?? _text.text).trim();
    if (code.isNotEmpty) Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final q = _text.text.trim();
    final matches = q.isEmpty ? const <Asset>[] : ref.watch(assetsProvider).search(q).take(5).toList();
    return sheetFrame(context, [
      const SheetTitle('Manual Entry', subtitle: 'Type the asset ID printed on the tag'),
      TextField(
        controller: _text,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Asset ID',
          hintText: 'e.g. MTR-00123',
          prefixIcon: const Icon(Icons.keyboard_alt_outlined),
          suffixIcon: q.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: () => setState(_text.clear),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: _submit,
      ),
      if (matches.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final a in matches)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 40),
            title: Text(a.id, style: AppText.bodyStrong),
            subtitle: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            trailing: Icon(Icons.north_west_rounded, size: 18, color: AppColors.textSecondary),
            onTap: () => _submit(a.id),
          ),
      ] else if (q.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('No asset matches "$q". Find anyway to register it.', style: AppText.secondary),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: q.isEmpty ? null : _submit,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Find Asset'),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Multi scan

/// List of the assets scanned in Multi Scan with bulk Move / Audit.
/// Returns true when a bulk action was taken (the batch is then cleared).
Future<bool> showMultiScanSummary(BuildContext context, WidgetRef ref, List<String> assetIds) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        ref.watch(assetsProvider);
        final repo = ref.read(assetsProvider.notifier);
        final assets = [for (final id in assetIds) ?repo.byId(id)];
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          child: sheetFrame(context, [
            SheetTitle(
              'Multi Scan',
              subtitle: '${assets.length} asset${assets.length == 1 ? '' : 's'} scanned. Choose a bulk action.',
            ),
            for (final a in assets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 40),
                title: Text(a.id, style: AppText.bodyStrong),
                subtitle: Text(
                  '${a.name} · ${a.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                trailing: StatusChip(a.status),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, 'move'),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Move'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    onPressed: () => Navigator.pop(context, 'audit'),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Audit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Keep scanning')),
          ]),
        );
      },
    ),
  );
  if (!context.mounted) return false;
  switch (action) {
    case 'move':
      context.push(Routes.withAssets(Routes.transferAsset, assetIds));
      return true;
    case 'audit':
      return _bulkAudit(context, ref, assetIds);
  }
  return false;
}

/// Marks every scanned asset Verified (at its recorded location) in an open audit of the user's.
Future<bool> _bulkAudit(BuildContext context, WidgetRef ref, List<String> assetIds) async {
  final me = ref.read(currentUserProvider);
  final open = ref.read(auditsProvider).assigned(me.id);
  if (open.isEmpty) {
    context.showSnack('You have no open audits. Start one in Asset Audit.');
    return false;
  }
  final audit = open.length == 1
      ? open.first
      : await showModalBottomSheet<Audit>(
          context: context,
          builder: (context) => sheetFrame(context, [
            const SheetTitle('Add to Audit', subtitle: 'Choose the audit these assets belong to'),
            for (final a in open)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconSquare(icon: Icons.fact_check_outlined, tone: TileTone.mint, size: 38),
                title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                subtitle: Text(
                  '${a.id} · ${a.site} · ${a.done} of ${a.totalAssets} done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, a),
              ),
          ]),
        );
  if (audit == null || !context.mounted) return false;
  final audits = ref.read(auditsProvider.notifier);
  for (final id in assetIds) {
    final asset = ref.read(assetsProvider.notifier).byId(id);
    audits.record(
      audit.id,
      AuditEntry(
        assetId: id,
        result: AuditResult.verified,
        at: DemoClock.now,
        location: asset?.location,
        expectedLocation: asset?.location,
        condition: asset?.condition,
        method: AuditMethod.multiScan,
        by: me.name,
      ),
    );
  }
  context.showSnack('${assetIds.length} asset${assetIds.length == 1 ? '' : 's'} verified in ${audit.name}');
  context.push(Routes.auditSession(audit.id));
  return true;
}
