import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/scanning/hardware_scan_listener.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// How a code reached the app (stored on the scan history record).
abstract final class ScanMethod {
  static const qr = 'QR';
  static const barcode = 'Barcode';
  static const nfc = 'NFC';
  static const rfid = 'RFID';
  static const ble = 'BLE';
  static const manual = 'Manual';
  static const scanner = 'Scanner';

  static String of(ScanEvent e) => switch (e.source) {
    ScanSource.nfc => nfc,
    ScanSource.manual => manual,
    ScanSource.hht => scanner,
    ScanSource.camera => e.format == 'qr' ? qr : barcode,
  };
}

/// What the Scan screen does with a result: a known asset / part / location is added to the top of
/// Scan History and opened (asset → Asset Identified, location → location sheet); an unknown tag
/// shows "This tag isn't linked yet" (link it, save it, or register a new asset). Completes when the
/// user comes back to the scanner.
Future<void> openScanFromScanScreen(BuildContext context, WidgetRef ref, ScanResult r, {String? method}) async {
  var result = r;
  if (!result.isKnown) {
    final linked = await showUnknownTagSheet(
      context,
      ref,
      result,
      onRegister: demoCanOpen(Routes.newRegistration) ? () => _register(context, result.event) : null,
    );
    if (linked == null || !context.mounted) return;
    result = linked;
  }
  final kind = switch (result.matchType) {
    MatchType.asset => ScanKind.asset,
    MatchType.part => ScanKind.part,
    _ => ScanKind.location,
  };
  final refId = result.location?.path ?? result.matchId!;
  ref.read(scanHistoryProvider.notifier).add(kind, refId, method: method ?? ScanMethod.of(result.event));
  if (result.matchType == MatchType.asset) {
    final here = GoRouterState.of(context).uri.path;
    // The client demo skips Asset Identified and opens the asset itself.
    final route = Routes.scanResultFrom(here, result.matchId!);
    await context.push(demoCanOpen(route) ? route : Routes.assetDetail(result.matchId!));
    return;
  }
  await openScanResult(context, result);
}

/// Register this asset (→ registration, prefilled with the tag or barcode).
void _register(BuildContext context, ScanEvent e) {
  final code = e.value.trim();
  context.push(
    Routes.newRegistration,
    extra: e.isNfc ? RegistrationPrefill(tagId: e.nfcUid ?? code) : RegistrationPrefill(barcode: code.toUpperCase()),
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
      // A keyboard-wedge scanner may type into this field: its read is submitted at once.
      ScanFieldScope(
        onScan: _submit,
        child: TextField(
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
                  child: DemoGuard(
                    route: Routes.transferAsset,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, 'move'),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Move'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DemoGuard(
                    route: Routes.audit,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                      onPressed: () => Navigator.pop(context, 'audit'),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('Audit'),
                    ),
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
