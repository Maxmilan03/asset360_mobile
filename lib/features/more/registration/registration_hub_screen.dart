import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/app/theme/app_theme.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/live_registration_repository.dart';
import 'package:asset360_mobile/data/repositories/registration_drafts_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/features/more/registration/bulk_registration_panel.dart';
import 'package:asset360_mobile/features/more/registration/registration_logic.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';

/// Existing assets shown under Recent Scans as examples (labelled "Existing").
const _exampleScans = ['MTR-00123', 'FL-012', 'LAP-0098'];

/// Asset Registration hub: Single / Bulk toggle, capture tiles, My Drafts and Recent Scans.
/// API mode: My Drafts = GET /api/asset-registrations/drafts, a scanned code is checked with
/// GET …/lookup, Bulk CSV import and Recent Scans (mock register) are not available yet.
class RegistrationHubScreen extends ConsumerStatefulWidget {
  const RegistrationHubScreen({super.key, this.bulk = false});

  final bool bulk;

  @override
  ConsumerState<RegistrationHubScreen> createState() => _RegistrationHubScreenState();
}

class _RegistrationHubScreenState extends ConsumerState<RegistrationHubScreen> {
  late bool _bulk = widget.bulk;

  void _openForm([RegistrationPrefill? prefill]) => context.push(Routes.newRegistration, extra: prefill);

  Future<void> _scanQr() async {
    final code = await showScanCapture(
      context,
      title: 'Scan QR / Barcode',
      suggestions: const ['MTR-00123', 'QR-A360-000901'],
    );
    if (code == null || !mounted) return;
    if (apiMode) return _scannedLive(code);
    final owner = ref.read(assetsProvider.notifier).ownerOf(code);
    if (owner != null) {
      if (await confirmViewExisting(context, code, owner.id, owner.name) && mounted) {
        context.push(Routes.assetDetail(owner.id));
      }
      return;
    }
    context.showSnack('Barcode / QR $code captured');
    _openForm(RegistrationPrefill(barcode: code.toUpperCase()));
  }

  /// API mode: a code that already belongs to an asset offers View Asset; otherwise the form opens
  /// with the code as barcode.
  Future<void> _scannedLive(String code) async {
    try {
      final hit = await ref.read(assetsApiProvider).lookup(code);
      if (!mounted) return;
      if (hit != null) {
        final a = hit.asset;
        final id = a.assetRegistrationId;
        if (await confirmViewExisting(context, code, id, a.title) && mounted) {
          context.push(Routes.assetDetail(id));
        }
        return;
      }
      context.showSnack('Barcode / QR $code captured');
    } catch (e) {
      if (!mounted) return;
      context.showSnack('Could not check $code on the server (${ApiException.from(e).message}). Opening the form.');
    }
    _openForm(RegistrationPrefill(barcode: code.toUpperCase()));
  }

  Future<void> _scanRfid() async {
    final tag = await showRfidReadSheet(context, ref);
    if (tag == null || !mounted) return;
    _openForm(RegistrationPrefill(tagId: tag));
  }

  Future<void> _fromPhoto() async {
    final path = await pickPhoto(context);
    if (path == null || !mounted) return;
    _openForm(RegistrationPrefill(photo: path));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Asset Registration',
            subtitle: 'Register a new asset in the system',
            help:
                'Register one asset by scanning its tag, reading an RFID / NFC tag, taking a photo or typing the '
                'details. The form follows the web app: Basic Information, Classification, Location & Assignment, '
                'Purchase & Warranty and Additional Information, then Review. It checks that the Asset Tag, RFID '
                'Tag and Barcode are not used by another asset. Save as Draft keeps an unfinished form under '
                'My Drafts. Use Bulk Registration to import many assets from a CSV file.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.view_in_ar_rounded,
                  label: 'Single Asset',
                  selected: !_bulk,
                  onTap: () => setState(() => _bulk = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeCard(
                  icon: Icons.layers_outlined,
                  label: 'Bulk Registration',
                  selected: _bulk,
                  onTap: apiMode
                      ? () => showNotAvailableYet(context, 'Bulk CSV import')
                      : () => setState(() => _bulk = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_bulk)
            apiMode ? const AppCard(child: NotAvailableYet(feature: 'Bulk CSV import')) : const BulkRegistrationPanel()
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Capture Asset Information', style: AppText.sectionTitle),
                  const SizedBox(height: 3),
                  Text('Scan tag or enter details manually', style: AppText.secondary),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      ActionTile(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan QR / Barcode',
                        subtitle: 'Scan asset tag',
                        tone: TileTone.lavender,
                        labelSize: 13,
                        onTap: _scanQr,
                      ),
                      ActionTile(
                        icon: Icons.sensors_rounded,
                        label: 'Scan RFID / NFC',
                        subtitle: 'Tap to scan',
                        tone: TileTone.sky,
                        labelSize: 13,
                        onTap: _scanRfid,
                      ),
                      ActionTile(
                        icon: Icons.add_circle_rounded,
                        label: 'Manual Entry',
                        subtitle: 'Enter details manually',
                        tone: TileTone.mint,
                        labelSize: 13,
                        onTap: _openForm,
                      ),
                      ActionTile(
                        icon: Icons.photo_camera_rounded,
                        label: 'Capture from Photo',
                        subtitle: 'Use camera / gallery',
                        tone: TileTone.peach,
                        labelSize: 13,
                        onTap: _fromPhoto,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (apiMode) const _LiveDrafts() else ...[const _MyDrafts(), const _RecentScans()],
          ],
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.text, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This session's registrations ("New") plus three existing assets as examples ("Existing").
class _RecentScans extends ConsumerWidget {
  const _RecentScans();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);
    final scans = ref.watch(scanHistoryProvider);
    final items = <(String id, DateTime at, bool isNew)>[
      for (final r in ref.watch(sessionRegistrationsProvider)) (r.title, r.at, true),
      for (final id in _exampleScans)
        if (scans.firstWhereOrNull((s) => s.refId == id) case final s?) (id, s.at, false),
    ];
    final rows = [
      for (final (id, at, isNew) in items)
        if (assets.firstWhereOrNull((a) => a.id == id) case final a?) (a, at, isNew),
    ];
    return SectionCard(
      title: 'Recent Scans',
      actionLabel: 'View All',
      actionIcon: null,
      onAction: () => context.push(Routes.scanHistoryFrom(GoRouterState.of(context).uri.path)),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: rows.isEmpty
          ? EmptyState(
              icon: Icons.qr_code_scanner_rounded,
              title: 'No recent scans',
              message: 'Assets you scan or register appear here.',
              actionLabel: 'Open Scan History',
              onAction: () => context.push(Routes.scanHistoryFrom(GoRouterState.of(context).uri.path)),
            )
          : LoadingGate(
              rows: 3,
              card: false,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const Divider(indent: 76),
                    AssetListTile(
                      title: rows[i].$1.id,
                      subtitle: rows[i].$1.name,
                      imagePath: rows[i].$1.imagePath,
                      fallbackIcon: assetIcon(rows[i].$1),
                      details: [IconLine(icon: Icons.location_on_outlined, text: DemoClock.formatDateTime(rows[i].$2))],
                      trailingTop: rows[i].$3
                          ? const StatusChip('New', tone: ChipTone.green)
                          : const StatusChip('Existing', tone: ChipTone.grey),
                      onTap: () => context.push(Routes.assetDetail(rows[i].$1.id)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Saved Register Asset drafts: tap to resume on the step it was saved on, delete with confirm.
class _MyDrafts extends ConsumerWidget {
  const _MyDrafts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(registrationDraftsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        title: 'My Drafts (${drafts.length})',
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
        child: Column(
          children: [
            if (drafts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10, right: 8),
                child: IconLine(
                  icon: Icons.info_outline_rounded,
                  text: 'No drafts. Tap Save as Draft in Register Asset to finish it later.',
                ),
              ),
            for (var i = 0; i < drafts.length; i++) ...[
              if (i > 0) const Divider(indent: 52),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: IconSquare(icon: Icons.edit_note_rounded, tone: TileTone.lavender, size: 40),
                title: Text(drafts[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                subtitle: Text(
                  [
                    drafts[i].assetRegistrationId,
                    'Step ${drafts[i].currentStep.clamp(0, 5) + 1} · ${registrationStepTitles[drafts[i].currentStep.clamp(0, 5)]}',
                    if (drafts[i].updatedAt != null) 'Saved ${DemoClock.formatDateTime(drafts[i].updatedAt!)}',
                  ].join('\n'),
                  style: AppText.caption,
                ),
                trailing: IconButton(
                  tooltip: 'Delete draft',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Delete draft?',
                      message: '"${drafts[i].title}" will be removed from My Drafts.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (!ok) return;
                    await ref.read(registrationDraftsProvider.notifier).delete(drafts[i].assetRegistrationId);
                    if (context.mounted) context.showSnack('Draft deleted');
                  },
                ),
                onTap: () => context.push(
                  Routes.newRegistration,
                  extra: RegistrationPrefill(draftId: drafts[i].assetRegistrationId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// API mode My Drafts: GET /api/asset-registrations/drafts (shimmer, error with Retry, empty
/// state). Tap resumes the draft (GET /drafts/{id}); delete asks first, then DELETE /drafts/{id}.
class _LiveDrafts extends ConsumerWidget {
  const _LiveDrafts();

  static String _subtitle(AssetRegistration d) {
    final step = d.currentStep.clamp(1, 5);
    return [
      d.assetRegistrationId,
      'Step $step · ${registrationStepTitles[step - 1]}',
      if (d.updatedAt ?? d.createdAt case final at?) 'Saved ${DemoClock.formatDateTime(at.toLocal())}',
    ].join('\n');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AssetRegistration d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete draft?',
      message: '"${d.title}" (${d.assetRegistrationId}) will be removed from My Drafts.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(liveRegistrationProvider).delete(d.assetRegistrationId);
      if (context.mounted) context.showSnack('Draft deleted');
    } catch (e) {
      if (context.mounted) context.showSnack(ApiException.from(e).message);
    } finally {
      ref.invalidate(liveDraftsProvider);
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AssetRegistration d) async {
    await context.push(Routes.newRegistration, extra: RegistrationPrefill(draftId: d.assetRegistrationId));
    ref.invalidate(liveDraftsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(liveDraftsProvider);
    final list = drafts.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SectionCard(
        title: list == null ? 'My Drafts' : 'My Drafts (${list.length})',
        actionLabel: 'Refresh',
        actionIcon: Icons.refresh_rounded,
        onAction: () => ref.invalidate(liveDraftsProvider),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
        child: switch (drafts) {
          AsyncValue(isLoading: true, hasValue: false) => const ListSkeleton(rows: 2, card: false),
          AsyncError(:final error) => LoadErrorState(
            error: error,
            title: 'Could not load your drafts',
            onRetry: () => ref.invalidate(liveDraftsProvider),
          ),
          _ when list == null || list.isEmpty => const Padding(
            padding: EdgeInsets.only(bottom: 10, right: 8),
            child: IconLine(
              icon: Icons.info_outline_rounded,
              text: 'No drafts. Tap Save as Draft in Register Asset to finish it later.',
            ),
          ),
          _ => Column(
            children: [
              for (final (i, d) in list.indexed) ...[
                if (i > 0) const Divider(indent: 52),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconSquare(icon: Icons.edit_note_rounded, tone: TileTone.lavender, size: 40),
                  title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                  subtitle: Text(_subtitle(d), style: AppText.caption),
                  trailing: IconButton(
                    tooltip: 'Delete draft',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _delete(context, ref, d),
                  ),
                  onTap: () => _open(context, ref, d),
                ),
              ],
            ],
          ),
        },
      ),
    );
  }
}
