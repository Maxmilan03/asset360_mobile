import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/scanning/nfc_reader.dart';
import 'package:asset360_mobile/core/scanning/scan_service.dart';
import 'package:asset360_mobile/core/widgets/asset_picker.dart';
import 'package:asset360_mobile/core/widgets/demo_guard.dart';
import 'package:asset360_mobile/core/widgets/dialogs.dart';
import 'package:asset360_mobile/core/widgets/feedback.dart';
import 'package:asset360_mobile/core/widgets/location_field.dart';
import 'package:asset360_mobile/core/widgets/pulse_rings.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/repositories/settings_repository.dart';

export 'package:asset360_mobile/core/scanning/nfc_reader.dart';
export 'package:asset360_mobile/core/scanning/scan_service.dart';

/// Settings → Scanning: beep and / or vibrate on every scan.
void scanFeedback(WidgetRef ref, {bool recognised = true}) {
  final s = ref.read(appSettingsProvider);
  if (s.beep) SystemSound.play(recognised ? SystemSoundType.click : SystemSoundType.alert);
  if (s.vibrate) recognised ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
}

/// Saves [e] through ScanService and delivers the result. [requester] (the control that started
/// the scan) gets it first when it accepts the match. Null when [e] was a duplicate.
Future<ScanResult?> handleScanEvent(BuildContext context, WidgetRef ref, ScanEvent e, {ScanTarget? requester}) async {
  final r = await ref.read(scanServiceProvider).submit(e);
  if (r == null || !context.mounted) return null;
  scanFeedback(ref, recognised: r.isKnown);
  await deliverScan(context, ref, r, requester: requester);
  return r;
}

/// Routes a result: the topmost registered target that accepts it, else the default
/// (asset → Asset detail, part → Part detail, location → location sheet, unknown → link sheet).
Future<void> deliverScan(BuildContext context, WidgetRef ref, ScanResult r, {ScanTarget? requester}) async {
  final targets = ref.read(scanTargetsProvider);
  ScanTarget? pick(MatchType t) => requester != null && requester.accepts.contains(t) ? requester : targets.topFor(t);
  if (pick(r.matchType) case final t?) return t.onScan(r);
  if (r.matchType == MatchType.none) {
    final linked = await showUnknownTagSheet(context, ref, r);
    if (linked == null || !context.mounted) return;
    if (pick(linked.matchType) case final t?) return t.onScan(linked);
    context.showSnack('Tag linked to ${linked.matchLabel}');
    return;
  }
  // A form is open but nothing on it takes this kind of tag.
  if (requester != null || !targets.isEmpty) {
    context.showSnack('${r.matchLabel} – not used on this screen');
    return;
  }
  await openScanResult(context, r);
}

/// Default handling of a known tag.
Future<void> openScanResult(BuildContext context, ScanResult r) async {
  switch (r.matchType) {
    case MatchType.asset:
      final route = Routes.assetDetail(r.matchId!);
      if (demoCanOpen(route)) await context.push(route);
    case MatchType.part:
      final route = Routes.partDetail(r.matchId!);
      if (demoCanOpen(route)) await context.push(route);
    case MatchType.location:
      if (r.location case final loc?) await showLocationSheet(context, loc);
    case MatchType.none:
      break;
  }
}

// ---------------------------------------------------------------- Target registration

/// Registers [target] while this subtree is visible (not covered by another page, not on a
/// hidden tab), so the HHT trigger and scans reach it.
class ScanTargetScope extends ConsumerStatefulWidget {
  const ScanTargetScope({super.key, required this.target, required this.child});

  final ScanTarget target;
  final Widget child;

  @override
  ConsumerState<ScanTargetScope> createState() => _ScanTargetScopeState();
}

class _ScanTargetScopeState extends ConsumerState<ScanTargetScope> {
  late final ScanTargets _targets = ref.read(scanTargetsProvider);
  bool? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.of(context);
    if (visible == _visible) return;
    _visible = visible;
    visible ? _targets.register(widget.target) : _targets.unregister(widget.target);
  }

  @override
  void didUpdateWidget(ScanTargetScope old) {
    super.didUpdateWidget(old);
    if (identical(old.target, widget.target)) return;
    _targets.unregister(old.target);
    if (_visible ?? false) _targets.register(widget.target);
  }

  @override
  void dispose() {
    _targets.unregister(widget.target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ---------------------------------------------------------------- NFC

/// Reads one NFC tag with a "Hold your phone near the tag" sheet. Handles NFC unsupported
/// (message), NFC off (dialog → NFC settings) and timeouts. Null when nothing was read.
Future<ScanEvent?> readNfcWithSheet(BuildContext context, WidgetRef ref) async {
  final reader = ref.read(nfcReaderProvider);
  final state = await reader.availability();
  if (!context.mounted) return null;
  if (state == NfcState.unsupported) {
    context.showSnack('This device has no NFC reader. Use the camera or Manual Entry.');
    return null;
  }
  if (state == NfcState.disabled) {
    await showNfcOffDialog(context);
    return null;
  }
  final read = reader.readOnce();
  var sheetOpen = true;
  final sheet =
      showModalBottomSheet<void>(
        context: context,
        builder: (sheet) => sheetFrame(sheet, [
          const Center(
            child: PulseRings(icon: Icons.nfc_rounded, size: 150, active: true, color: AppColors.illustration),
          ),
          const SizedBox(height: 12),
          Text('Hold your phone near the tag', textAlign: TextAlign.center, style: AppText.sectionTitle),
          const SizedBox(height: 6),
          Text(
            'Keep the back of the phone within 4 cm of the NFC tag',
            textAlign: TextAlign.center,
            style: AppText.secondary,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => Navigator.pop(sheet), child: const Text('Cancel')),
        ]),
      ).whenComplete(() {
        sheetOpen = false;
        reader.cancel();
      });
  try {
    final e = await read;
    if (sheetOpen && context.mounted) Navigator.of(context).pop();
    return e;
  } on NfcReadException catch (e) {
    if (sheetOpen && context.mounted) Navigator.of(context).pop();
    await sheet;
    if (!context.mounted) return null;
    switch (e.failure) {
      case NfcFailure.timeout:
        context.showSnack('No NFC tag found. Tap to Read and hold the phone on the tag.');
      case NfcFailure.disabled:
        await showNfcOffDialog(context);
      case NfcFailure.unsupported:
        context.showSnack('This device has no NFC reader.');
      case NfcFailure.error:
        context.showSnack('Could not read the tag${e.message == null ? '' : ' (${e.message})'}. Try again.');
      case NfcFailure.cancelled:
        break;
    }
    return null;
  }
}

Future<void> showNfcOffDialog(BuildContext context) async {
  final open = await showConfirmDialog(
    context,
    title: 'NFC is turned off',
    message: 'Turn on NFC in the system settings to read NFC tags.',
    confirmLabel: 'Open NFC settings',
  );
  if (!open) return;
  final ok = await AppLauncher.openNfcSettings();
  if (!ok && context.mounted) context.showSnack('Open Settings → Connected devices → NFC and turn it on');
}

// ---------------------------------------------------------------- Sheets

/// "Location: Floor 2 – Building A" for a location tag scanned outside a form.
Future<void> showLocationSheet(BuildContext context, DbLocation loc) => showModalBottomSheet<void>(
  context: context,
  builder: (sheet) => sheetFrame(sheet, [
    Icon(Icons.place_rounded, size: 48, color: AppColors.primary),
    const SizedBox(height: 8),
    Text('Location: ${loc.label}', textAlign: TextAlign.center, style: AppText.sectionTitle),
    const SizedBox(height: 6),
    Text('${loc.site} · ${loc.path}', textAlign: TextAlign.center, style: AppText.secondary),
    const SizedBox(height: 4),
    Text('Code ${loc.code}', textAlign: TextAlign.center, style: AppText.caption),
    const SizedBox(height: 18),
    DemoGuard(
      route: Routes.tracking,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.pop(sheet);
          GoRouter.of(context).go(Routes.tracking);
        },
        icon: const Icon(Icons.map_outlined),
        label: const Text('Show assets on the map'),
      ),
    ),
    const SizedBox(height: 8),
    OutlinedButton(onPressed: () => Navigator.pop(sheet), child: const Text('Close')),
  ]),
);

enum _UnknownChoice { location, asset, save, register }

/// "This tag isn't linked yet": Link to a location / Link to an asset / Just save (the scan is already
/// in Local Data). [onRegister] adds "Register as new asset". Returns the linked result, or null.
Future<ScanResult?> showUnknownTagSheet(
  BuildContext context,
  WidgetRef ref,
  ScanResult r, {
  VoidCallback? onRegister,
  String title = "This tag isn't linked yet",
}) async {
  final e = r.event;
  final choice = await showModalBottomSheet<_UnknownChoice>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => sheetFrame(sheet, [
      Icon(e.isNfc ? Icons.nfc_rounded : Icons.qr_code_2_rounded, size: 48, color: AppColors.textSecondary),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: AppText.sectionTitle),
      const SizedBox(height: 6),
      SelectableText(e.value, textAlign: TextAlign.center, style: AppText.bodyStrong),
      if (e.nfcUid != null && e.value != nfcTagKey(e.nfcUid!))
        Text('UID ${e.nfcUid}', textAlign: TextAlign.center, style: AppText.caption),
      const SizedBox(height: 4),
      Text(
        'No asset or location uses this tag. Link it so the next scan resolves instantly.',
        textAlign: TextAlign.center,
        style: AppText.secondary,
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => Navigator.pop(sheet, _UnknownChoice.location),
        icon: const Icon(Icons.place_outlined),
        label: const Text('Link to a location'),
      ),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: () => Navigator.pop(sheet, _UnknownChoice.asset),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Link to an asset'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.pop(sheet, _UnknownChoice.save),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Just save'),
      ),
      if (onRegister != null)
        TextButton.icon(
          onPressed: () => Navigator.pop(sheet, _UnknownChoice.register),
          icon: const Icon(Icons.add_box_outlined),
          label: const Text('Register as new asset'),
        ),
    ]),
  );
  if (!context.mounted) return null;
  switch (choice) {
    case _UnknownChoice.location:
      return linkTagToLocation(context, ref, r);
    case _UnknownChoice.asset:
      return linkTagToAsset(context, ref, r);
    case _UnknownChoice.save:
      context.showSnack('Saved on this device (Local Data)');
    case _UnknownChoice.register:
      onRegister?.call();
    case null:
      break;
  }
  return null;
}

Future<ScanResult?> linkTagToLocation(BuildContext context, WidgetRef ref, ScanResult r) async {
  final loc = await showLinkLocationSheet(context);
  if (loc == null || !context.mounted) return null;
  return ref.read(scanServiceProvider).linkToLocation(r, loc);
}

Future<ScanResult?> linkTagToAsset(BuildContext context, WidgetRef ref, ScanResult r) async {
  final id = await showAssetPicker(context, title: 'Link Tag to Asset');
  if (id == null || !context.mounted) return null;
  return ref.read(scanServiceProvider).linkToAsset(r, id);
}

/// Pick Site → Building → Floor → (Room) and Save. Returns the deepest chosen row.
Future<DbLocation?> showLinkLocationSheet(BuildContext context, {LocationValue initial = LocationValue.empty}) =>
    showModalBottomSheet<DbLocation>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LinkLocationSheet(initial: initial),
    );

class _LinkLocationSheet extends ConsumerStatefulWidget {
  const _LinkLocationSheet({required this.initial});

  final LocationValue initial;

  @override
  ConsumerState<_LinkLocationSheet> createState() => _LinkLocationSheetState();
}

class _LinkLocationSheetState extends ConsumerState<_LinkLocationSheet> {
  late LocationValue _value = widget.initial;
  bool _tried = false;

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(locationsProvider).value ?? const <DbLocation>[];
    final row = _value.floor == null ? null : _value.rowIn(rows);
    return sheetFrame(context, [
      const SheetTitle('Link to a location', subtitle: 'Site › Building › Floor › Room (optional)'),
      LocationSelector(value: _value, onChanged: (v) => setState(() => _value = v)),
      if (_tried && row == null)
        Text('Choose at least the site, building and floor', style: AppText.caption.copyWith(color: AppColors.red)),
      if (row != null) Text('Tag will open ${row.label} (${row.code})', style: AppText.caption),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: () {
          if (row == null) return setState(() => _tried = true);
          Navigator.pop(context, row);
        },
        child: const Text('Save'),
      ),
    ]);
  }
}
