import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/features/more/local_data/local_data_screen.dart';

/// Detail of one saved scan (live: re-linking updates it): raw value with Copy, format, source,
/// UID, every NDEF record, match, time and device; Open asset / Link this tag / Delete.
Future<void> showScanDetailSheet(BuildContext context, int id) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ScanDetailSheet(id: id),
);

class _ScanDetailSheet extends ConsumerWidget {
  const _ScanDetailSheet({required this.id});

  final int id;

  Future<void> _link(BuildContext context, WidgetRef ref, ScanLogEntry row) async {
    final result = ScanResult(
      event: scanEventOf(row),
      matchType: row.matchType,
      matchId: row.matchId,
      matchLabel: row.matchLabel,
      logId: row.id,
    );
    final linked = await chooseTagLink(context, ref, result);
    if (linked != null && context.mounted) context.showSnack('Tag linked to ${linked.matchLabel}');
  }

  void _delete(BuildContext context, WidgetRef ref, ScanLogEntry row) {
    final db = ref.read(appDatabaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final margin = context.snackMargin;
    Navigator.pop(context);
    db.deleteScan(row.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: margin,
          content: Text('Scan "${row.value}" deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () => db.restoreScan(row)),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(scanLogEntryProvider(id)).value;
    if (row == null) return sheetFrame(context, [const SheetTitle('Scan deleted')]);
    final records = NdefRecordInfo.decodeList(row.nfcRecords);
    final known = row.matchType != MatchType.none;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: SingleChildScrollView(
        child: sheetFrame(context, [
          Row(
            children: [
              IconSquare(icon: scanTypeIcon(row.format, row.source), tone: scanTypeTone(row.format, row.source)),
              const SizedBox(width: 12),
              Expanded(child: Text('Scan details', style: AppText.sectionTitle)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Raw value', style: AppText.caption),
          Row(
            children: [
              Expanded(child: SelectableText(row.value, style: AppText.bodyStrong)),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: row.value));
                  context.showSnack('Copied to clipboard');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
          const Divider(),
          InfoRow(label: 'Format', value: row.format.toUpperCase()),
          InfoRow(label: 'Source', value: sourceLabel(row.source)),
          if (row.nfcUid != null) InfoRow(label: 'UID', value: row.nfcUid!),
          InfoRow(
            label: 'Match',
            value: known
                ? '${row.matchType.name[0].toUpperCase()}${row.matchType.name.substring(1)}: ${row.matchLabel}'
                : 'Unknown',
          ),
          InfoRow(label: 'Time', value: DemoClock.formatDateTime(row.scannedAt)),
          InfoRow(label: 'Device', value: row.deviceInfo),
          if (row.nfcUid != null) ...[
            const SizedBox(height: 10),
            Text(
              records.isEmpty ? 'NDEF records: none (blank or non-NDEF tag)' : 'NDEF records (${records.length})',
              style: AppText.bodyStrong,
            ),
            for (final (i, r) in records.indexed)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}. ${r.title}', style: AppText.caption.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    SelectableText(r.value.isEmpty ? '—' : r.value, style: AppText.body),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 18),
          if (row.matchType == MatchType.asset)
            DemoGuard(
              route: Routes.assetDetail(row.matchId!),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(Routes.assetDetail(row.matchId!));
                },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Open asset'),
              ),
            ),
          if (row.matchType == MatchType.asset) const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _link(context, ref, row),
            icon: const Icon(Icons.link_rounded),
            label: Text(known ? 'Change the link' : 'Link this tag'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => _delete(context, ref, row),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ]),
      ),
    );
  }
}

/// "Link to a location" / "Link to an asset" for the tag of [r]. Returns the linked result.
Future<ScanResult?> chooseTagLink(BuildContext context, WidgetRef ref, ScanResult r) async {
  final choice = await showModalBottomSheet<LinkTarget>(
    context: context,
    builder: (sheet) => sheetFrame(sheet, [
      SheetTitle('Link this tag', subtitle: r.event.tagKey),
      ListTile(
        leading: Icon(Icons.place_outlined, color: AppColors.primary),
        title: const Text('Link to a location'),
        onTap: () => Navigator.pop(sheet, LinkTarget.location),
      ),
      ListTile(
        leading: Icon(Icons.inventory_2_outlined, color: AppColors.primary),
        title: const Text('Link to an asset'),
        onTap: () => Navigator.pop(sheet, LinkTarget.asset),
      ),
    ]),
  );
  if (choice == null || !context.mounted) return null;
  return choice == LinkTarget.location ? linkTagToLocation(context, ref, r) : linkTagToAsset(context, ref, r);
}

/// A linked tag: tag key, type, what it opens, date; Change link / Unlink.
Future<void> showTagLinkSheet(BuildContext context, TagLink link) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _TagLinkSheet(link: link),
);

class _TagLinkSheet extends ConsumerWidget {
  const _TagLinkSheet({required this.link});

  final TagLink link;

  /// The tag as a scan event, so the same link code applies.
  ScanEvent get _event {
    final nfc = link.tagKey.startsWith('NFC:');
    return ScanEvent(
      value: link.tagKey,
      format: nfc ? 'nfc' : (link.tagType == TagType.qr ? 'qr' : 'barcode'),
      source: nfc ? ScanSource.nfc : ScanSource.camera,
      nfcUid: nfc ? link.tagKey.substring(4) : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return sheetFrame(context, [
      SheetTitle('Linked tag', subtitle: link.tagKey),
      InfoRow(label: 'Tag type', value: link.tagType.name.toUpperCase()),
      InfoRow(
        label: 'Linked to',
        value: '${link.targetType == LinkTarget.location ? 'Location' : 'Asset'}: ${link.label}',
      ),
      InfoRow(label: 'Linked on', value: DemoClock.formatDateTime(link.createdAt)),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () async {
          final r = ScanResult(event: _event, matchType: MatchType.none);
          final linked = await chooseTagLink(context, ref, r);
          if (linked != null && context.mounted) {
            Navigator.pop(context);
            context.showSnack('Tag now linked to ${linked.matchLabel}');
          }
        },
        icon: const Icon(Icons.link_rounded),
        label: const Text('Change link'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
        onPressed: () async {
          final ok = await showConfirmDialog(
            context,
            title: 'Unlink this tag?',
            message: '${link.tagKey} will no longer open ${link.label}. Scans already saved are kept.',
            confirmLabel: 'Unlink',
            destructive: true,
          );
          if (!ok || !context.mounted) return;
          await ref.read(appDatabaseProvider).unlinkTag(link.id);
          if (!context.mounted) return;
          Navigator.pop(context);
          context.showSnack('Tag unlinked');
        },
        icon: const Icon(Icons.link_off_rounded),
        label: const Text('Unlink'),
      ),
    ]);
  }
}
