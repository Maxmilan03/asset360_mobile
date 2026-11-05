import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/features/assets/scan/scan_flow.dart';

/// Hub row: photo, MOV number, asset, From → To, status chip and date.
class MovementRow extends ConsumerWidget {
  const MovementRow({super.key, required this.request});

  final MovementRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = request;
    final asset = ref.watch(assetByIdProvider(m.assetId));
    return AssetListTile(
      title: m.id,
      subtitle: asset?.name ?? m.assetId,
      imagePath: asset?.imagePath,
      fallbackIcon: asset == null ? Icons.inventory_2_outlined : assetIcon(asset),
      details: [_line('From:', m.from.name), _line('To:', m.to.name, icon: true)],
      trailingTop: StatusChip(m.status),
      trailingBottom: DemoClock.formatDate(m.createdAt),
      onTap: DemoGuard.push(context, Routes.movementRequest(m.id)),
    );
  }

  Widget _line(String label, String value, {bool icon = false}) => Row(
    children: [
      if (icon) Icon(Icons.location_on_outlined, size: 12, color: AppColors.textSecondary),
      SizedBox(
        width: icon ? 30 : 42,
        child: Text(label, style: AppText.caption),
      ),
      Expanded(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: AppColors.text),
        ),
      ),
    ],
  );
}

/// From / To card: building icon, name and address lines.
class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, required this.tone});

  final MovePlace place;
  final TileTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconSquare(icon: Icons.apartment_rounded, tone: tone, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 12),
                ),
                for (final l in place.lines)
                  Text(
                    l,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 10.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Review layout (Transfer step 5), also used read-only by Request detail.
/// Edit buttons appear when [onEditAsset] / [onEditDetails] are given.
class MovementSummary extends StatelessWidget {
  const MovementSummary({
    super.key,
    required this.request,
    required this.asset,
    this.onEditAsset,
    this.onEditDetails,
    this.extraAssets = const [],
  });

  final MovementRequest request;
  final Asset asset;
  final VoidCallback? onEditAsset;
  final VoidCallback? onEditDetails;

  /// Other assets moved with the same request (multi-scan transfers).
  final List<Asset> extraAssets;

  @override
  Widget build(BuildContext context) {
    final m = request;
    final a = asset;
    final isTransfer = m.type == MoveType.transfer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: isTransfer ? 'Transfer Summary' : '${m.type} Summary',
          actionLabel: onEditAsset == null ? null : 'Edit',
          actionIcon: Icons.edit_outlined,
          onAction: onEditAsset,
          child: Column(
            children: [
              InkWell(
                onTap: DemoGuard.tap(DemoAction.movementAssetLink, DemoGuard.push(context, Routes.assetDetail(a.id))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 72),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                          const SizedBox(height: 2),
                          Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                        ],
                      ),
                    ),
                    AssetStatusChip(a.status),
                  ],
                ),
              ),
              if (extraAssets.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+ ${extraAssets.map((e) => e.id).join(', ')} (one request each)',
                    style: AppText.caption.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              InfoRow(label: 'Serial Number', value: a.serialNo ?? '—'),
              InfoRow(label: 'Tag ID (RFID)', value: a.tagId ?? '—'),
              InfoRow(label: 'Category', value: a.category),
              InfoRow(label: 'Current Location', value: m.from.name),
              InfoRow(label: 'Current Custodian', value: m.fromCustodian ?? a.custodian),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: isTransfer ? 'Transfer Details' : 'Details',
          actionLabel: onEditDetails == null ? null : 'Edit',
          actionIcon: Icons.edit_outlined,
          onAction: onEditDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _labelled('From', PlaceCard(place: m.from, tone: TileTone.sky)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 18, 6, 0),
                      child: Center(child: Icon(Icons.arrow_circle_right_outlined, color: AppColors.primary, size: 26)),
                    ),
                    Expanded(
                      child: _labelled('To', PlaceCard(place: m.to, tone: TileTone.mint)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (m.newCustodian != null) InfoRow(label: 'New Custodian', value: m.newCustodian!),
              if (m.requiredDate != null)
                InfoRow(
                  label: m.type == MoveType.checkOut
                      ? 'Expected Return'
                      : m.type == MoveType.assign
                      ? 'Effective Date'
                      : 'Required Date',
                  value: DemoClock.formatDate(m.requiredDate!),
                ),
              if (m.reason != null) InfoRow(label: 'Reason', value: m.reason!),
              if (m.condition != null) InfoRow(label: 'Condition', value: m.condition!),
              if (m.remarks != null) InfoRow(label: 'Remarks', value: m.remarks!),
              if (m.rejectReason != null)
                InfoRow(label: 'Rejection reason', value: m.rejectReason!, valueColor: AppColors.red),
            ],
          ),
        ),
        if (m.attachments.isNotEmpty || onEditDetails != null) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Attachments (${m.attachments.length})',
            actionLabel: onEditDetails == null ? null : 'Edit',
            actionIcon: Icons.edit_outlined,
            onAction: onEditDetails,
            child: m.attachments.isEmpty
                ? Text('No attachments', style: AppText.secondary)
                : Column(
                    children: [
                      for (final f in m.attachments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AttachmentTile(attachment: f),
                        ),
                    ],
                  ),
          ),
        ],
        if (m.photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Photos (${m.photos.length})',
            child: PhotoStrip(photos: m.photos),
          ),
        ],
      ],
    );
  }

  Widget _labelled(String label, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: AppText.bodyStrong.copyWith(fontSize: 12.5)),
      const SizedBox(height: 4),
      Expanded(child: child),
    ],
  );
}

/// Submitted → Approved → In Transit → Completed, with times; Rejected / Cancelled end it early.
class MoveStatusTimeline extends StatelessWidget {
  const MoveStatusTimeline({super.key, required this.request});

  final MovementRequest request;

  @override
  Widget build(BuildContext context) {
    final m = request;
    final ended = m.status == MoveStatus.rejected || m.status == MoveStatus.cancelled;
    final steps = m.type == MoveType.transfer
        ? ['Submitted', 'Approved', 'In Transit', 'Completed']
        : ['Submitted', 'Completed'];
    final rows = [
      for (final s in steps)
        if (!ended || m.timeline.any((t) => t.title == s)) s,
      if (ended) m.status,
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          () {
            final entry = m.timeline.lastWhereOrNull((t) => t.title == rows[i]);
            final done = entry != null;
            final bad = rows[i] == MoveStatus.rejected || rows[i] == MoveStatus.cancelled;
            final color = bad ? AppColors.red : (done ? AppColors.green : AppColors.border);
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? color : AppColors.surface,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: done
                            ? Icon(bad ? Icons.close_rounded : Icons.check_rounded, size: 14, color: Colors.white)
                            : null,
                      ),
                      if (i < rows.length - 1)
                        Expanded(child: Container(width: 2, color: done ? AppColors.green : AppColors.border)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[i],
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 13.5,
                              color: done ? AppColors.text : AppColors.textMuted,
                            ),
                          ),
                          if (entry != null)
                            Text(
                              [
                                DemoClock.formatDateTime(entry.at),
                                if (entry.by != null) entry.by!,
                                if (entry.note != null) entry.note!,
                              ].join(' · '),
                              style: AppText.caption,
                            )
                          else
                            Text('Waiting', style: AppText.caption),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

/// "Reject MOV-…?" with a required reason. Rejects the request and shows a SnackBar.
Future<void> rejectMovement(BuildContext context, WidgetRef ref, MovementRequest request) async {
  final reason = await showReasonDialog(
    context,
    title: 'Reject ${request.id}?',
    message: 'Tell the requester why this request is rejected.',
  );
  if (reason == null || !context.mounted) return;
  ref.read(movementsProvider.notifier).reject(request.id, reason);
  context.showSnack('${request.id} rejected');
}

/// Resolves a scanned / typed code to an asset ID, or shows a SnackBar and returns null.
String? assetIdForCode(BuildContext context, WidgetRef ref, String code, {List<String>? allowed}) {
  final a = ref.read(assetsProvider).byCode(code);
  if (a == null) {
    context.showSnack('No asset matches "$code"');
    return null;
  }
  if (allowed != null && !allowed.contains(a.id)) {
    context.showSnack('${a.id} is not in this list');
    return null;
  }
  return a.id;
}

/// Compact asset chooser for the custody flows: the selected asset card, or Scan / Search / ID buttons.
/// [candidates] limits the choice (e.g. only checked-out assets for Check In).
class AssetChooser extends ConsumerWidget {
  const AssetChooser({super.key, required this.assetId, required this.onChanged, this.candidates, this.error});

  final String? assetId;
  final ValueChanged<String> onChanged;
  final List<String>? candidates;
  final String? error;

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final code = await showScanCapture(context, suggestions: candidates?.take(4).toList() ?? const ['LAP-0098']);
    if (code == null || !context.mounted) return;
    final id = assetIdForCode(context, ref, code, allowed: candidates);
    if (id != null) onChanged(id);
  }

  Future<void> _search(BuildContext context, WidgetRef ref) async {
    if (candidates != null) {
      final assets = ref.read(assetsProvider);
      final id = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => sheetFrame(context, [
          SheetTitle('Select Asset', subtitle: '${candidates!.length} assets'),
          for (final id in candidates!)
            if (assets.byCode(id) case final a?)
              AssetListTile(
                title: a.id,
                subtitle: a.name,
                location: a.location,
                imagePath: a.imagePath,
                fallbackIcon: assetIcon(a),
                details: [IconLine(icon: Icons.person_outline_rounded, text: a.custodian)],
                showChevron: false,
                onTap: () => Navigator.pop(context, a.id),
              ),
        ]),
      );
      if (id != null) onChanged(id);
      return;
    }
    final id = await showAssetPicker(context, selectedId: assetId);
    if (id != null) onChanged(id);
  }

  Future<void> _manual(BuildContext context, WidgetRef ref) async {
    final code = await showManualEntrySheet(context);
    if (code == null || !context.mounted) return;
    final id = assetIdForCode(context, ref, code, allowed: candidates);
    if (id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = assetId == null ? null : ref.watch(assetByIdProvider(assetId!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a != null) ...[SelectedAssetCard(asset: a), const SizedBox(height: 8)],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _scan(context, ref),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Scan Tag'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _search(context, ref),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(a == null ? 'Search' : 'Change'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _manual(context, ref),
                icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                label: const Text('ID'),
              ),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(error!, style: AppText.caption.copyWith(color: AppColors.red)),
          ),
      ],
    );
  }
}

/// "Selected Asset" card: photo, ID, name, serial, current location / custodian, status. Tap → Asset detail.
class SelectedAssetCard extends StatelessWidget {
  const SelectedAssetCard({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    return AppCard(
      onTap: DemoGuard.tap(DemoAction.movementAssetLink, DemoGuard.push(context, Routes.assetDetail(a.id))),
      child: Row(
        children: [
          AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                    ),
                    Flexible(child: AssetStatusChip(a.status)),
                  ],
                ),
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                const SizedBox(height: 4),
                _kv('Serial No.', a.serialNo ?? '—'),
                _kv('Current Location', a.location),
                _kv('Current Custodian', a.custodian),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$k :  ', style: AppText.caption.copyWith(fontSize: 11)),
          TextSpan(
            text: v,
            style: AppText.caption.copyWith(fontSize: 11, color: AppColors.text),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
