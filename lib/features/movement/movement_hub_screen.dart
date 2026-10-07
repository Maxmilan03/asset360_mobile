import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/movement.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/movements_repository.dart';
import '../../data/repositories/session_repository.dart';
import 'movement_widgets.dart';

/// Date windows used by the movement filters.
const moveDateRanges = {'Today': 0, 'Last 7 days': 7, 'Last 30 days': 30};

bool inDateRange(DateTime at, String range) {
  final days = moveDateRanges[range]!;
  final from = DemoClock.today.subtract(Duration(days: days == 0 ? 0 : days - 1));
  return !at.isBefore(from);
}

/// Movement & Custody hub (left screen of design/07_movement_custody.jpg).
class MovementHubScreen extends ConsumerStatefulWidget {
  const MovementHubScreen({super.key, this.initialTab});

  /// 0 My Requests, 1 Pending Approval, 2 Completed.
  final int? initialTab;

  @override
  ConsumerState<MovementHubScreen> createState() => _MovementHubScreenState();
}

class _MovementHubScreenState extends ConsumerState<MovementHubScreen> {
  late int _tab = widget.initialTab ?? 0;
  String _query = '';
  FilterSelection _filters = const {};

  static final _filterGroups = [
    const FilterGroup(
      title: 'Status',
      options: [
        MoveStatus.pending,
        MoveStatus.approved,
        MoveStatus.inTransit,
        MoveStatus.completed,
        MoveStatus.rejected,
        MoveStatus.cancelled,
      ],
    ),
    const FilterGroup(
      title: 'Type',
      options: [MoveType.transfer, MoveType.checkOut, MoveType.checkIn, MoveType.assign, MoveType.returnAsset],
    ),
    FilterGroup(title: 'Date', options: moveDateRanges.keys.toList(), multiSelect: false),
  ];

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).id;
    final all = ref.watch(movementsProvider);
    final assets = ref.watch(assetsProvider);
    final tabs = [all.mine(me), all.pending, all.completed];
    String nameOf(String id) => assets.byCode(id)?.name ?? '';
    final rows = tabs[_tab]
        .search(_query, nameOf)
        .where(
          (m) =>
              (_filters['Status']?.contains(m.status) ?? true) &&
              (_filters['Type']?.contains(m.type) ?? true) &&
              (_filters['Date']?.every((d) => inDateRange(m.createdAt, d)) ?? true),
        )
        .toList();
    final tiles = [
      (Icons.swap_horiz_rounded, 'Transfer Asset', TileTone.lavender, Routes.transferAsset),
      (Icons.person_rounded, 'Check Out', TileTone.sky, Routes.checkOut),
      (Icons.download_rounded, 'Check In', TileTone.mint, Routes.checkIn),
      (Icons.groups_rounded, 'Assign Custodian', TileTone.peach, Routes.assignCustodian),
      (Icons.undo_rounded, 'Return Asset', TileTone.sky, Routes.returnAsset),
      (Icons.history_rounded, 'Movement History', TileTone.lavender, Routes.movementHistory),
    ];
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Movement & Custody',
            subtitle: 'Transfer, assign and track asset movement',
            help:
                'Transfers need approval: Submitted → Approved → In Transit → Completed. Check Out, Check In, '
                'Assign Custodian and Return take effect at once and are recorded in Movement History.',
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              for (final (icon, label, tone, route) in tiles)
                ActionTile(icon: icon, label: label, tone: tone, onTap: () => context.push(route)),
            ],
          ),
          const SizedBox(height: 14),
          SegmentTabs(
            tabs: [
              SegmentTab('My Requests', count: tabs[0].length),
              SegmentTab('Pending Approval', count: tabs[1].length),
              const SegmentTab('Completed'),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          SearchFilterBar(
            hint: 'Search by Asset ID, Name or Request No.',
            onChanged: (v) => setState(() => _query = v),
            filterGroups: _filterGroups,
            selection: _filters,
            onFiltersChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 12),
          LoadingGate(
            key: ValueKey('gate-tab-$_tab'),
            rows: 3,
            child: rows.isEmpty
                ? const AppCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No requests',
                      message: 'Nothing matches this tab, search and filter.',
                    ),
                  )
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 90),
                          MovementRow(request: rows[i]),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            '${rows.length} of ${tabs[_tab].length} requests',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
