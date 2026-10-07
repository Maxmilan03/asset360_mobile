import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/features/more/documents/document_widgets.dart';

/// Tile filters (not tabs).
enum DocTile { all, expiring, compliant, pending }

/// Documents (left screen of design/14_documents.jpg).
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key, this.initialTab});

  /// all, manuals, warranty, certificates, others — or a tile: expiring, compliant, pending.
  final String? initialTab;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  static const _buckets = ['Manuals', 'Warranty', 'Certificates', 'Others'];
  int _tab = 0;
  DocTile _tile = DocTile.all;
  String _query = '';
  final _search = TextEditingController();
  FilterSelection _filters = const {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _expiryFilters = ['Expired', 'Within 30 days', 'Within 6 months', 'No expiry'];

  @override
  void initState() {
    super.initState();
    _apply(widget.initialTab);
  }

  @override
  void didUpdateWidget(DocumentsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) _apply(widget.initialTab);
  }

  void _apply(String? t) {
    final tile = DocTile.values.where((x) => x.name == t).firstOrNull;
    if (tile != null) {
      _tile = tile;
      _tab = 0;
      return;
    }
    final i = _buckets.indexWhere((b) => b.toLowerCase() == t);
    _tab = i + 1;
  }

  bool _expiryMatch(AssetDocument d, String f) {
    final days = d.expiry == null ? null : DemoClock.daysUntil(d.expiry!);
    return switch (f) {
      'Expired' => days != null && days < 0,
      'Within 30 days' => days != null && days >= 0 && days <= 30,
      'Within 6 months' => days != null && days >= 0 && days <= 183,
      _ => days == null,
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final st = ref.watch(documentsProvider);
    final s = st.summary;
    final base = switch (_tile) {
      DocTile.expiring => st.expiring,
      DocTile.compliant => st.compliantDocs,
      DocTile.pending => st.pendingDocs,
      DocTile.all => _tab == 0 ? st.docs : st.inBucket(_buckets[_tab - 1]),
    };
    final total = switch (_tile) {
      DocTile.expiring => st.expiringSoon,
      DocTile.compliant => st.compliant,
      DocTile.pending => st.pending,
      DocTile.all => _tab == 0 ? s.total : s.byBucket[_buckets[_tab - 1]] ?? 0,
    };
    final rows = st
        .search(base, _query)
        .where(
          (d) =>
              (_filters['Type']?.contains(d.type) ?? true) &&
              (_filters['Asset']?.contains(d.assetId) ?? true) &&
              (_filters['Expiry']?.any((f) => _expiryMatch(d, f)) ?? true),
        )
        .toList();
    final tiles = [
      (DocTile.all, Icons.description_rounded, 'All Documents', s.total, TileTone.lavender),
      (DocTile.expiring, Icons.schedule_rounded, 'Expiring Soon', st.expiringSoon, TileTone.pink),
      (DocTile.compliant, Icons.check_circle_rounded, 'Compliant', st.compliant, TileTone.mint),
      (DocTile.pending, Icons.hourglass_bottom_rounded, 'Pending', st.pending, TileTone.peach),
    ];
    return AppScaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add Document',
        onPressed: () => context.push(Routes.addDocument),
        child: const Icon(Icons.add_rounded),
      ),
      body: LazyListPage(
        padding: context.pagePadding.copyWith(bottom: context.pagePadding.bottom + 64),
        header: [
          const PageTitle(
            title: 'Documents',
            subtitle: 'Manage all asset related documents and files',
            help:
                'The organisation has 64 documents; sample records are listed. Expiring Soon = expiry within 30 days. '
                'Compliant = valid for more than 30 days. Pending = waiting for review.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (n, (t, icon, label, value, tone)) in tiles.indexed) ...[
                if (n > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _tile == t ? tone.foreground : Colors.transparent, width: 1.5),
                    ),
                    child: KpiTile(
                      icon: icon,
                      value: '$value',
                      label: label,
                      tone: tone,
                      onTap: () => setState(() {
                        _tile = t;
                        _tab = 0;
                      }),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by file name, document type or asset...',
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            filterGroups: [
              const FilterGroup(title: 'Type', options: DocType.all),
              FilterGroup(title: 'Asset', options: {for (final d in st.docs) d.assetId}.toList()..sort()),
              const FilterGroup(title: 'Expiry', options: _expiryFilters),
            ],
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 6),
          SegmentTabs(
            tabs: [
              SegmentTab('All', count: s.total),
              for (final b in _buckets) SegmentTab(b, count: s.byBucket[b]),
            ],
            selected: _tile == DocTile.all ? _tab : -1,
            onChanged: (i) => setState(() {
              _tab = i;
              _tile = DocTile.all;
            }),
          ),
          if (_tile != DocTile.all) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                InputChip(
                  label: Text('${tiles[_tile.index].$3} ($total)'),
                  onDeleted: () => setState(() => _tile = DocTile.all),
                  deleteButtonTooltipMessage: 'Show all',
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
        ],
        list: SliverLoadingGate(
          rows: 5,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.folder_off_outlined,
                      title: 'No documents match',
                      message: 'Try another search, tab or filter.',
                      actionLabel: _query.isEmpty && _filters.isEmpty && _tile == DocTile.all ? null : 'Clear filters',
                      onAction: () => setState(() {
                        _search.clear();
                        _query = '';
                        _filters = const {};
                        _tile = DocTile.all;
                      }),
                    ),
                  ),
                )
              : SliverCardList(
                  itemCount: rows.length,
                  indent: 76,
                  itemBuilder: (_, i) => DocRow(doc: rows[i]),
                ),
        ),
        footer: [
          const SizedBox(height: 8),
          Text(
            'Showing ${rows.length} of $total',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
