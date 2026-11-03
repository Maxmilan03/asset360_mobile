import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/features/more/local_data/local_data_sheets.dart';

/// Local Data (More → Local Data): every scan saved in SQLite on this device and the tags linked
/// to locations or assets. Live through drift `.watch()`; survives app restarts.
class LocalDataScreen extends ConsumerStatefulWidget {
  const LocalDataScreen({super.key});

  @override
  ConsumerState<LocalDataScreen> createState() => _LocalDataScreenState();
}

enum _Tab { all, codes, nfc, links }

const _sourceLabels = {
  ScanSource.camera: 'Camera',
  ScanSource.nfc: 'NFC',
  ScanSource.hht: 'HHT scanner',
  ScanSource.manual: 'Manual',
};
const _matchLabels = {
  MatchType.asset: 'Asset',
  MatchType.location: 'Location',
  MatchType.part: 'Part',
  MatchType.none: 'Unknown',
};
const _dates = ['Today', 'Last 7 days', 'Last 30 days'];

class _LocalDataScreenState extends ConsumerState<LocalDataScreen> {
  _Tab _tab = _Tab.all;
  String _query = '';
  FilterSelection _filters = {};

  ScanFilter get _filter {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = _filters['Date']?.firstOrNull;
    return ScanFilter(
      query: _query,
      nfcOnly: switch (_tab) {
        _Tab.codes => false,
        _Tab.nfc => true,
        _ => null,
      },
      sources: {
        for (final e in _sourceLabels.entries)
          if (_filters['Source']?.contains(e.value) ?? false) e.key,
      },
      formats: _filters['Format'] ?? const {},
      matches: {
        for (final e in _matchLabels.entries)
          if (_filters['Match']?.contains(e.value) ?? false) e.key,
      },
      from: switch (date) {
        'Today' => today,
        'Last 7 days' => today.subtract(const Duration(days: 6)),
        'Last 30 days' => today.subtract(const Duration(days: 29)),
        _ => null,
      },
    );
  }

  Future<void> _clearAll() async {
    final total = ref.read(scanStatsProvider).value?.total ?? 0;
    if (total == 0) {
      context.showSnack('No scans saved on this device');
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Clear all scans?',
      message: 'All $total scans are deleted from this device. Linked tags are kept, so those tags still resolve.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(appDatabaseProvider).clearScans();
    if (mounted) context.showSnack('All scans cleared');
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(scanStatsProvider).value;
    final formats = ref.watch(scanFormatsProvider).value ?? const <String>[];
    final tabs = [
      SegmentTab('All', count: stats?.total),
      SegmentTab('QR & Barcode', count: stats?.codes),
      SegmentTab('NFC', count: stats?.nfc),
      SegmentTab('Linked Tags', count: stats?.links),
    ];
    return AppScaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
            child: PageTitle(
              title: 'Local Data',
              subtitle: 'Scans and tags saved on this device',
              trailing: PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (v) => switch (v) {
                  'clear' => _clearAll(),
                  _ => DemoGuard.push(context, Routes.scannerSettings)?.call(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: ListTile(leading: Icon(Icons.delete_sweep_outlined), title: Text('Clear all scans')),
                  ),
                  PopupMenuItem(
                    value: 'scanner',
                    enabled: demoCanOpen(Routes.scannerSettings),
                    child: const ListTile(
                      leading: Icon(Icons.settings_remote_outlined),
                      title: Text('Scanner settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                for (final (i, (icon, value, label, tone, tab)) in [
                  (Icons.storage_rounded, stats?.total, 'Total scans', TileTone.lavender, _Tab.all),
                  (Icons.today_rounded, stats?.today, 'Today', TileTone.sky, null),
                  (Icons.nfc_rounded, stats?.nfc, 'NFC', TileTone.cyan, _Tab.nfc),
                  (Icons.qr_code_2_rounded, stats?.codes, 'QR/Barcode', TileTone.mint, _Tab.codes),
                  (Icons.link_rounded, stats?.links, 'Linked tags', TileTone.peach, _Tab.links),
                ].indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: KpiTile(
                      icon: icon,
                      value: '${value ?? 0}',
                      label: label,
                      tone: tone,
                      onTap: () => setState(() {
                        if (tab != null) {
                          _tab = tab;
                          _filters = {..._filters}..remove('Date');
                        } else {
                          _tab = _Tab.all;
                          _filters = {
                            ..._filters,
                            'Date': {'Today'},
                          };
                        }
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SegmentTabs(tabs: tabs, selected: _tab.index, onChanged: (i) => setState(() => _tab = _Tab.values[i])),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: SearchFilterBar(
              hint: _tab == _Tab.links ? 'Search tag or linked label' : 'Search value or label',
              onChanged: (v) => setState(() => _query = v),
              filterGroups: _tab == _Tab.links
                  ? const []
                  : [
                      FilterGroup(title: 'Source', options: _sourceLabels.values.toList()),
                      if (formats.isNotEmpty) FilterGroup(title: 'Format', options: formats),
                      FilterGroup(title: 'Match', options: _matchLabels.values.toList()),
                      const FilterGroup(title: 'Date', options: _dates, multiSelect: false),
                    ],
              selection: _filters,
              onFiltersChanged: (f) => setState(() => _filters = f),
            ),
          ),
          Expanded(
            child: _tab == _Tab.links
                ? _LinkedTagsList(query: _query, onShowScans: () => setState(() => _tab = _Tab.all))
                : _ScanList(filter: _filter, filtered: _query.isNotEmpty || _filters.values.any((s) => s.isNotEmpty)),
          ),
        ],
      ),
    );
  }
}

/// Saved scans, newest first, built lazily. Swipe left to delete (Undo).
class _ScanList extends ConsumerWidget {
  const _ScanList({required this.filter, required this.filtered});

  final ScanFilter filter;
  final bool filtered;

  void _delete(BuildContext context, WidgetRef ref, ScanLogEntry row) {
    final db = ref.read(appDatabaseProvider);
    db.deleteScan(row.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: context.snackMargin,
          content: Text('Scan "${row.value}" deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () => db.restoreScan(row)),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scans = ref.watch(scanLogProvider(filter));
    final rows = scans.value;
    if (rows == null) return const ListSkeleton(rows: 5);
    if (rows.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: 24 + context.bottomInset),
        children: [
          EmptyState(
            icon: Icons.qr_code_scanner_rounded,
            title: filtered ? 'No scans match' : 'No scans saved yet',
            message: filtered
                ? 'Try another search or clear the filters.'
                : 'Every QR code, barcode, NFC tag and scanner read is saved here.',
            actionLabel: filtered ? null : 'Scan now',
            onAction: filtered ? null : DemoGuard.push(context, Routes.scanFrom(Routes.more)),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: 24 + context.bottomInset),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return Dismissible(
          key: ValueKey('scan-${row.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: AppColors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) => _delete(context, ref, row),
          child: ScanLogRow(row: row, onTap: () => showScanDetailSheet(context, row.id)),
        );
      },
    );
  }
}

/// One saved scan: type icon, value, format / source chips, match and time.
class ScanLogRow extends StatelessWidget {
  const ScanLogRow({super.key, required this.row, this.onTap});

  final ScanLogEntry row;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final known = row.matchType != MatchType.none;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            IconSquare(
              icon: scanTypeIcon(row.format, row.source),
              tone: scanTypeTone(row.format, row.source),
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusChip(row.format.toUpperCase(), tone: ChipTone.purple),
                      StatusChip(sourceLabel(row.source), tone: ChipTone.blue),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        switch (row.matchType) {
                          MatchType.asset => Icons.inventory_2_outlined,
                          MatchType.location => Icons.place_outlined,
                          MatchType.part => Icons.settings_outlined,
                          MatchType.none => Icons.help_outline_rounded,
                        },
                        size: 14,
                        color: known ? AppColors.green : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          known ? row.matchLabel ?? row.matchId ?? '' : 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption.copyWith(color: known ? AppColors.text : AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(deviceTimeAgo(row.scannedAt), style: AppText.caption),
          ],
        ),
      ),
    );
  }
}

/// Tags linked to a location or an asset.
class _LinkedTagsList extends ConsumerWidget {
  const _LinkedTagsList({required this.query, required this.onShowScans});

  final String query;
  final VoidCallback onShowScans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(tagLinksProvider).value;
    final q = query.trim().toLowerCase();
    final links = all == null
        ? null
        : [
            for (final l in all)
              if (q.isEmpty || l.tagKey.toLowerCase().contains(q) || l.label.toLowerCase().contains(q)) l,
          ];
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 4, 0, 24 + context.bottomInset),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: LocalDataBadge(onTap: onShowScans),
        ),
        if (links == null)
          const ListSkeleton(rows: 3)
        else if (links.isEmpty)
          EmptyState(
            icon: Icons.link_off_rounded,
            title: q.isEmpty ? 'No linked tags yet' : 'No linked tag matches',
            message: 'Scan an unknown tag and choose "Link to a location" or "Link to an asset".',
          )
        else
          for (final l in links)
            InkWell(
              onTap: () => showTagLinkSheet(context, l),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    IconSquare(
                      icon: l.tagType == TagType.nfc
                          ? Icons.nfc_rounded
                          : l.tagType == TagType.qr
                          ? Icons.qr_code_2_rounded
                          : Icons.view_week_outlined,
                      tone: l.targetType == LinkTarget.location ? TileTone.peach : TileTone.sky,
                      size: 42,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.tagKey, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              StatusChip(l.tagType.name.toUpperCase(), tone: ChipTone.purple),
                              const SizedBox(width: 6),
                              Icon(
                                l.targetType == LinkTarget.location ? Icons.place_outlined : Icons.inventory_2_outlined,
                                size: 14,
                                color: AppColors.green,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.caption.copyWith(color: AppColors.text),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(deviceTimeAgo(l.createdAt), style: AppText.caption),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

String sourceLabel(ScanSource s) => _sourceLabels[s]!;

IconData scanTypeIcon(String format, ScanSource source) => format == 'nfc' || source == ScanSource.nfc
    ? Icons.nfc_rounded
    : format == 'qr'
    ? Icons.qr_code_2_rounded
    : source == ScanSource.manual
    ? Icons.keyboard_alt_outlined
    : Icons.view_week_outlined;

TileTone scanTypeTone(String format, ScanSource source) => format == 'nfc' || source == ScanSource.nfc
    ? TileTone.cyan
    : format == 'qr'
    ? TileTone.lavender
    : TileTone.mint;

/// Real device time (scans are not demo data): "Just now", "2 min ago", "3 h ago", then the date.
String deviceTimeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return DemoClock.formatDate(t);
}
