import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/document.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/inspections_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';

/// Full-width primary button under a tab's cards.
class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton.icon(onPressed: onPressed, icon: Icon(icon, size: 20), label: Text(label)),
  );
}

/// Rows separated by dividers inside a card, or an empty message.
class _RowList extends StatelessWidget {
  const _RowList({required this.children, required this.empty});

  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(empty, textAlign: TextAlign.center, style: AppText.secondary),
      );
    }
    return LoadingGate(
      rows: children.length.clamp(1, 3),
      card: false,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(), children[i]],
        ],
      ),
    );
  }
}

/// Tappable two-line row: leading widget, title/subtitle, trailing widget.
class _Row extends StatelessWidget {
  const _Row({required this.leading, required this.title, this.subtitle, this.trailing, this.onTap});

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ================================================================ Location

class AssetLocationTab extends ConsumerWidget {
  const AssetLocationTab({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracked = ref.watch(trackingProvider).entities.firstWhereOrNull((e) => e.assetId == asset.id);
    // Assets without a live tag get a fixed pin from their ID so it stays put between visits.
    final h = asset.id.codeUnits.fold<int>(7, (s, c) => (s * 31 + c) % 997);
    final pin =
        tracked ??
        TrackedEntity(
          id: asset.id,
          label: asset.id,
          kind: TrackedKind.equipment,
          x: .40 + (h % 28) / 100,
          y: .32 + (h % 38) / 100,
          zone: locationArea(asset.location),
          assetId: asset.id,
        );
    final parts = locationParts(asset);
    final history = asset.locationHistory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Current Location',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0) Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                    StatusChip(
                      parts[i],
                      tone: i == parts.length - 1 ? ChipTone.purple : ChipTone.grey,
                      icon: i == 0 ? Icons.apartment_rounded : null,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              InfoRow(label: 'Custodian', value: asset.custodian, labelWidth: 110),
              InfoRow(
                label: 'Since',
                value: history.isEmpty ? '—' : '${DemoClock.formatDate(history.first.at)} (${history.first.by})',
                labelWidth: 110,
              ),
              if (tracked != null) InfoRow(label: 'Live status', value: tracked.status, labelWidth: 110),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Floor Plan',
          actionLabel: tracked == null ? null : 'Live',
          actionIcon: Icons.sensors_rounded,
          onAction: () => context.push(Routes.trackAsset(asset.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 170,
                child: FloorPlan(
                  entities: [pin],
                  showZoneLabels: true,
                  pinSize: 30,
                  onPinTap: (e) => context.showSnack('${asset.id} · ${e.zone} · ${asset.location}'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tracked == null
                    ? 'Last recorded position (no live tag)'
                    : 'Live position from ${asset.iot?.model ?? 'tag'}',
                style: AppText.caption,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.trackAsset(asset.id)),
                icon: const Icon(Icons.map_outlined, size: 20),
                label: const Text('View on Map'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Location History (${history.length})',
          child: Column(
            children: [
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('No location changes recorded yet.', style: AppText.secondary),
                ),
              for (var i = 0; i < history.length; i++)
                _TimelineRow(
                  icon: Icons.location_on_rounded,
                  color: i == 0 ? AppColors.primary : AppColors.textMuted,
                  title: history[i].location,
                  subtitle: '${DemoClock.formatDate(history[i].at)} · ${history[i].by}',
                  last: i == history.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================ Maintenance

class AssetMaintenanceTab extends ConsumerWidget {
  const AssetMaintenanceTab({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final wos = [...ref.watch(workOrdersProvider).forAsset(asset.id)]..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    final pms = [...ref.watch(pmSchedulesProvider).where((p) => p.assetId == asset.id)]
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final open = wos.where((w) => w.isActive).length;
    final overdue = wos.where((w) => w.isActive && DemoClock.isOverdue(w.dueAt)).length;
    final pm = pms.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(value: '$open', label: 'Open', color: AppColors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(value: '$overdue', label: 'Overdue', color: AppColors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(value: '${wos.length - open}', label: 'Completed', color: AppColors.green),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Next Preventive Maintenance',
          child: pm == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No PM schedule for this asset.', style: AppText.secondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconSquare(icon: Icons.event_repeat_rounded, tone: TileTone.lavender),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pm.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                              Text(
                                '${pm.frequency} · Last done ${DemoClock.formatDate(pm.lastDone)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption,
                              ),
                            ],
                          ),
                        ),
                        DueLabel(pm.nextDue),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        final id = ref.read(pmSchedulesProvider.notifier).generateWorkOrder(pm.id);
                        context.showSnack('$id generated from ${pm.id}');
                        context.push(Routes.workOrder(id));
                      },
                      icon: const Icon(Icons.playlist_add_rounded, size: 20),
                      label: const Text('Generate PM Work Order'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Work Orders (${wos.length})',
          actionLabel: 'View All',
          onAction: () => context.go(Routes.maintenance),
          child: _RowList(
            empty: 'No work orders for ${asset.id} yet.',
            children: [
              for (final w in wos)
                _Row(
                  leading: SizedBox(width: 70, child: PriorityChip(w.priority)),
                  title: '${w.id} · ${w.title}',
                  subtitle: w.isActive
                      ? '${w.workType} · ${DemoClock.dueLabel(w.dueAt)}'
                      : '${w.workType} · Completed ${w.completedAt == null ? '' : DemoClock.formatDate(w.completedAt!)}',
                  trailing: StatusChip(w.status),
                  onTap: () => context.push(Routes.workOrder(w.id)),
                ),
            ],
          ),
        ),
        _TabButton(
          icon: Icons.build_rounded,
          label: 'Create Work Order',
          onPressed: () => context.push(Routes.createWorkOrder(assetId: asset.id)),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        Text(value, style: AppText.kpiNumber.copyWith(color: color, fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption),
      ],
    ),
  );
}

// ================================================================ Inspection

class AssetInspectionTab extends ConsumerWidget {
  const AssetInspectionTab({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final list = [...ref.watch(inspectionsProvider).forAsset(asset.id)]..sort((a, b) => b.dueAt.compareTo(a.dueAt));
    final people = ref.watch(peopleProvider);
    final open = list.where((i) => !i.isCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(value: '$open', label: 'Open', color: AppColors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(
                value: '${list.where((i) => !i.isCompleted && DemoClock.isOverdue(i.dueAt)).length}',
                label: 'Overdue',
                color: AppColors.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(value: '${list.length - open}', label: 'Completed', color: AppColors.green),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Inspections (${list.length})',
          actionLabel: 'View All',
          onAction: () => context.go(Routes.inspection),
          child: _RowList(
            empty: 'No inspections for ${asset.id} yet.',
            children: [
              for (final i in list)
                _Row(
                  leading: IconSquare(icon: Icons.fact_check_outlined, tone: TileTone.mint, size: 36),
                  title: '${i.id} · ${i.title}',
                  subtitle: [
                    i.type,
                    people.firstWhereOrNull((p) => p.id == i.inspectorId)?.name ?? '',
                    i.isCompleted
                        ? 'Completed ${DemoClock.formatDate(i.completedAt ?? i.dueAt)}'
                        : DemoClock.dueLabel(i.dueAt),
                  ].where((s) => s.isNotEmpty).join(' · '),
                  trailing: StatusChip(!i.isCompleted && DemoClock.isOverdue(i.dueAt) ? 'Overdue' : i.status),
                  onTap: () => context.push(Routes.inspectionDetail(i.id)),
                ),
            ],
          ),
        ),
        _TabButton(
          icon: Icons.assignment_outlined,
          label: 'Create Inspection',
          onPressed: () => context.push(Routes.withAsset(Routes.createInspection, asset.id)),
        ),
      ],
    );
  }
}

// ================================================================ Financial

class AssetFinancialTab extends ConsumerWidget {
  const AssetFinancialTab({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final a = asset;
    final deprPct = a.purchaseCost == 0 ? 0 : (a.accumulatedDepreciation / a.purchaseCost * 100).round();
    final segments = [
      ('Acquisition', a.purchaseCost, AppColors.primary),
      ('Maintenance', a.costs.maintenance, AppColors.iconBlue),
      ('Spare Parts', a.costs.spares, AppColors.iconOrange),
      ('Labour', a.costs.labor, AppColors.iconTeal),
      ('Energy', a.costs.energy, AppColors.iconGreen),
    ].where((s) => s.$2 > 0).toList();
    final gross = segments.fold<double>(0, (s, e) => s + e.$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            KpiTile(
              icon: Icons.shopping_cart_outlined,
              value: formatAed(a.purchaseCost),
              label: 'Purchase Cost',
              caption: DemoClock.formatDate(a.purchaseDate),
              tone: TileTone.lavender,
            ),
            KpiTile(
              icon: Icons.account_balance_wallet_outlined,
              value: formatAed(a.bookValue),
              label: 'Current Book Value',
              caption: '−$deprPct% depreciated',
              tone: TileTone.sky,
            ),
            KpiTile(
              icon: Icons.handshake_outlined,
              value: a.amcCost == null || a.amc == null ? 'No AMC' : '${formatAed(a.amcCost!)}/yr',
              label: 'AMC Cost',
              caption: a.amc == null ? 'Not under contract' : '${formatAed(a.amcCostToDate)} to date',
              tone: TileTone.peach,
            ),
            KpiTile(
              icon: Icons.build_circle_outlined,
              value: formatAed(a.costs.maintenance),
              label: 'Maintenance to Date',
              caption: '+ ${formatAed(a.costs.spares + a.costs.labor)} parts & labour',
              tone: TileTone.mint,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Depreciation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoRow(label: 'Method', value: 'Straight-line'),
              InfoRow(label: 'Useful life', value: '${a.usefulLifeYears} years (${a.ageLabel} used)'),
              InfoRow(label: 'Salvage value', value: formatAed(a.salvageValue)),
              InfoRow(label: 'Per year', value: formatAed(a.depreciationPerYear)),
              InfoRow(label: 'Accumulated', value: formatAed(a.accumulatedDepreciation)),
              InfoRow(label: 'Book value', value: formatAed(a.bookValue), valueColor: AppColors.primary),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: deprPct / 100,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
                ),
              ),
              const SizedBox(height: 4),
              Text('$deprPct% of the purchase cost written off', style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Total Cost of Ownership',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(formatAed(a.tco), style: AppText.kpiNumber),
              Text('Acquisition + maintenance + spares + labour + energy − resale', style: AppText.caption),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (final (_, v, c) in segments)
                        Expanded(
                          flex: (v / gross * 1000).round().clamp(1, 1000),
                          child: Container(color: c),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final (label, v, c) in segments)
                _CostLine(color: c, label: label, value: formatAed(v), pct: v / gross * 100),
              _CostLine(color: AppColors.textMuted, label: 'Less resale value', value: '− ${formatAed(a.resaleValue)}'),
              const Divider(height: 18),
              Row(
                children: [
                  Expanded(child: Text('TCO', style: AppText.bodyStrong)),
                  Text(formatAed(a.tco), style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CostLine extends StatelessWidget {
  const _CostLine({required this.color, required this.label, required this.value, this.pct});

  final Color color;
  final String label;
  final String value;
  final double? pct;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppText.body.copyWith(fontSize: 13))),
        if (pct != null) SizedBox(width: 44, child: Text('${pct!.toStringAsFixed(0)}%', style: AppText.caption)),
        Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13)),
      ],
    ),
  );
}

// ================================================================ Documents

class AssetDocumentsTab extends ConsumerWidget {
  const AssetDocumentsTab({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = [...ref.watch(documentsProvider).forAsset(asset.id)]
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Documents (${docs.length})',
          actionLabel: '+ Add',
          actionIcon: null,
          onAction: () => context.push(Routes.withAsset(Routes.addDocument, asset.id)),
          child: _RowList(
            empty: 'No documents linked to ${asset.id}. Tap “+ Add” to upload one.',
            children: [for (final d in docs) _DocRow(doc: d)],
          ),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});

  final AssetDocument doc;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = doc.isImage
        ? (Icons.image_outlined, TileTone.sky)
        : doc.isPdf
        ? (Icons.picture_as_pdf_outlined, TileTone.pink)
        : (Icons.description_outlined, TileTone.lavender);
    final days = doc.expiry == null ? null : DemoClock.daysUntil(doc.expiry!);
    return _Row(
      leading: IconSquare(icon: icon, tone: tone, size: 36),
      title: doc.name,
      subtitle: '${doc.type} · ${doc.sizeLabel} · ${DemoClock.formatDate(doc.uploadedAt)}',
      trailing: days == null
          ? null
          : days < 0
          ? const StatusChip('Expired', tone: ChipTone.red)
          : days <= 90
          ? const StatusChip('Expiring', tone: ChipTone.amber)
          : null,
      onTap: () => context.push(Routes.documentDetail(doc.id)),
    );
  }
}

// ================================================================ History

class AssetHistoryTab extends ConsumerWidget {
  const AssetHistoryTab({super.key, required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = asset.id;
    final events = <_Event>[
      for (final e in asset.events)
        _Event(e.at, e.title, [e.note, e.by].whereType<String>().join(' · '), Icons.history_rounded, AppColors.primary),
      for (final w in ref.watch(workOrdersProvider).forAsset(id)) ...[
        _Event(
          w.openedAt,
          'Work order ${w.id} raised',
          w.title,
          Icons.build_rounded,
          AppColors.iconBlue,
          Routes.workOrder(w.id),
        ),
        if (w.completedAt != null)
          _Event(
            w.completedAt!,
            'Work order ${w.id} completed',
            w.resolution ?? w.title,
            Icons.task_alt_rounded,
            AppColors.green,
            Routes.workOrder(w.id),
          ),
      ],
      for (final i in ref.watch(inspectionsProvider).forAsset(id))
        if (i.completedAt != null)
          _Event(
            i.completedAt!,
            'Inspection ${i.id} completed',
            i.title,
            Icons.fact_check_outlined,
            AppColors.iconGreen,
            Routes.inspectionDetail(i.id),
          ),
      for (final m in ref.watch(movementsProvider).forAsset(id))
        _Event(
          m.createdAt,
          '${m.type} ${m.id} · ${m.status}',
          [m.to.name, if (m.newCustodian != null) 'to ${m.newCustodian}'].join(' · '),
          Icons.swap_horiz_rounded,
          AppColors.iconOrange,
          Routes.movementRequest(m.id),
        ),
      for (final i in ref.watch(issuesProvider).forAsset(id))
        _Event(
          i.reportedAt,
          'Issue ${i.id} reported',
          i.title,
          Icons.warning_amber_rounded,
          AppColors.red,
          Routes.issueDetail(i.id),
        ),
    ]..sort((a, b) => b.at.compareTo(a.at));

    return SectionCard(
      title: 'History (${events.length})',
      child: events.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('No history recorded for $id yet.', textAlign: TextAlign.center, style: AppText.secondary),
            )
          : LoadingGate(
              rows: 3,
              card: false,
              child: Column(
                children: [
                  for (var i = 0; i < events.length; i++)
                    _TimelineRow(
                      icon: events[i].icon,
                      color: events[i].color,
                      title: events[i].title,
                      subtitle: [
                        DemoClock.formatDateTime(events[i].at),
                        events[i].detail,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      last: i == events.length - 1,
                      onTap: events[i].route == null ? null : () => context.push(events[i].route!),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Event {
  const _Event(this.at, this.title, this.detail, this.icon, this.color, [this.route]);

  final DateTime at;
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final String? route;
}

/// Dot + connecting line + text, used by the location history and History tab.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.last,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                  child: Icon(icon, size: 15, color: color),
                ),
                if (!last) Expanded(child: Container(width: 1.5, color: AppColors.divider)),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
