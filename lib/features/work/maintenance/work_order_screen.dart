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
import 'package:asset360_mobile/data/models/work_order.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/documents_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_actions.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_tasks_tab.dart';
import 'package:asset360_mobile/features/work/maintenance/wo_widgets.dart';

enum WoTab {
  overview('Overview'),
  tasks('Tasks'),
  parts('Parts'),
  history('History'),
  documents('Documents');

  const WoTab(this.label);
  final String label;
}

/// Work order detail (middle and right screens of design/08_maintenance.jpg).
class WorkOrderScreen extends ConsumerStatefulWidget {
  const WorkOrderScreen({super.key, required this.woId, this.initialTab});

  final String woId;
  final String? initialTab;

  @override
  ConsumerState<WorkOrderScreen> createState() => _WorkOrderScreenState();
}

class _WorkOrderScreenState extends ConsumerState<WorkOrderScreen> {
  late WoTab _tab = _initial(WoTab.overview);

  /// The tab from the route, or [fallback]; the client demo only opens Overview.
  WoTab _initial(WoTab fallback) {
    final t = WoTab.values.firstWhere((t) => t.name == widget.initialTab, orElse: () => fallback);
    return t == WoTab.overview || demoCanDo(DemoAction.woOtherTabs) ? t : WoTab.overview;
  }

  @override
  void didUpdateWidget(WorkOrderScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialTab != old.initialTab) {
      _tab = _initial(_tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wo = ref.watch(workOrderByIdProvider(widget.woId));
    if (wo == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Work order not found',
          message: '${widget.woId} does not exist.',
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      );
    }
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          _Header(wo: wo),
          const SizedBox(height: 6),
          SegmentTabs(
            tabs: [
              for (final t in WoTab.values)
                SegmentTab(
                  t.label,
                  enabled: t == WoTab.overview || demoCanDo(DemoAction.woOtherTabs),
                  count: switch (t) {
                    WoTab.parts => wo.parts.isEmpty ? null : wo.parts.length,
                    WoTab.documents => wo.documentIds.isEmpty ? null : wo.documentIds.length,
                    _ => null,
                  },
                ),
            ],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = WoTab.values[i]),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            WoTab.overview => _Overview(wo: wo),
            WoTab.tasks => WoTasksTab(wo: wo),
            // List tabs show a loading shimmer the first time they open.
            WoTab.parts => LoadingGate(
              key: const ValueKey('parts'),
              rows: 2,
              child: _PartsTab(wo: wo),
            ),
            WoTab.history => LoadingGate(
              key: const ValueKey('history'),
              rows: 3,
              child: _HistoryTab(wo: wo),
            ),
            WoTab.documents => LoadingGate(
              key: const ValueKey('documents'),
              rows: 2,
              child: _DocumentsTab(wo: wo),
            ),
          },
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(Icons.camera_alt_outlined, color: AppColors.text, size: 22),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(wo.id, style: AppText.pageTitle.copyWith(fontSize: 20)),
                  PriorityChip(wo.priority),
                ],
              ),
              const SizedBox(height: 2),
              Text(wo.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.pageSubtitle),
            ],
          ),
        ),
        DemoGuard(
          action: DemoAction.woStatus,
          child: PopupMenuButton<String>(
            key: const ValueKey('wo-status'),
            tooltip: 'Change status',
            initialValue: wo.status,
            onSelected: (s) => changeWoStatus(context, ref, wo, s),
            itemBuilder: (_) => [
              for (final s in WoStatus.all)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Expanded(child: Text(s)),
                      if (s == wo.status) Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
            ],
            child: StatusChip(wo.status, trailingIcon: Icons.keyboard_arrow_down_rounded),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Overview

class _Overview extends ConsumerStatefulWidget {
  const _Overview({required this.wo});

  final WorkOrder wo;

  @override
  ConsumerState<_Overview> createState() => _OverviewState();
}

class _OverviewState extends ConsumerState<_Overview> {
  bool _editing = false;
  late final _description = TextEditingController(text: widget.wo.description);

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wo = widget.wo;
    final asset = ref.watch(assetByIdProvider(wo.assetId));
    final assignee = ref.watch(personByIdProvider(wo.assigneeId));
    final reporter = ref.watch(personByIdProvider(wo.reporterId));
    final notifier = ref.read(workOrdersProvider.notifier);
    final closed = !wo.isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (asset != null) _AssetCard(asset: asset),
        const SizedBox(height: 10),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _field('Open Date', Text(DemoClock.formatDateTime(wo.openedAt), style: _value))),
              Expanded(
                child: _field('Priority', Align(alignment: Alignment.centerLeft, child: PriorityChip(wo.priority))),
              ),
              Expanded(
                flex: 2,
                child: _field(
                  'Due Date',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DemoClock.formatDateTime(wo.dueAt),
                        style: _value.copyWith(color: wo.isActive ? AppColors.red : AppColors.text),
                      ),
                      if (wo.isActive) ...[const SizedBox(height: 6), DueCountdownChip(dueAt: wo.dueAt)],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: closed
                          ? null
                          : DemoGuard.tap(DemoAction.woReassign, () => showReassignSheet(context, ref, wo)),
                      child: _iconField(Icons.engineering_outlined, 'Assigned To', PersonLine(person: assignee)),
                    ),
                  ),
                  Expanded(
                    child: _iconField(Icons.person_outline_rounded, 'Reported By', PersonLine(person: reporter)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _iconField(Icons.build_outlined, 'Category', Text(wo.category, style: _value))),
                  Expanded(child: _iconField(Icons.handyman_outlined, 'Work Type', Text(wo.workType, style: _value))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _iconField(Icons.timer_outlined, 'SLA', Text(wo.sla ?? '—', style: _value))),
                  Expanded(
                    child: _iconField(
                      Icons.circle,
                      'Status',
                      Text(wo.holdReason == null ? wo.status : '${wo.status} – ${wo.holdReason}', style: _value),
                      iconColor: ChipTone.forStatus(wo.status).foreground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Issue Description',
                actionLabel: _editing || closed ? null : 'Edit',
                actionIcon: Icons.edit_outlined,
                onAction: DemoGuard.tap(
                  DemoAction.woEditDescription,
                  () => setState(() {
                    _description.text = wo.description;
                    _editing = true;
                  }),
                ),
              ),
              const SizedBox(height: 8),
              if (_editing) ...[
                TextField(controller: _description, maxLines: 4, autofocus: true),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final text = _description.text.trim();
                        if (text.isEmpty) {
                          context.showSnack('The description cannot be empty');
                          return;
                        }
                        notifier.updateDescription(wo.id, text);
                        setState(() => _editing = false);
                        context.showSnack('Description saved');
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ] else
                Text(wo.description.isEmpty ? 'No description' : wo.description, style: AppText.body),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: DemoGuard(
            action: DemoAction.woPhotos,
            child: PhotoStrip(
              title: 'Photos',
              photos: wo.photos,
              onAdd: closed
                  ? null
                  : (p) {
                      notifier.addPhoto(wo.id, p);
                      context.showSnack('Photo added to ${wo.id}');
                    },
              onRemove: closed ? null : (i) => notifier.removePhoto(wo.id, i),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (closed)
          _ClosedCard(wo: wo)
        else
          Row(
            children: [
              Expanded(
                child: DemoGuard(
                  action: DemoAction.woStatus,
                  child: OutlinedButton(
                    onPressed: () => showUpdateStatusSheet(context, ref, wo),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [Text('Update Status'), SizedBox(width: 6), Icon(Icons.keyboard_arrow_down_rounded)],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DemoGuard(
                  action: DemoAction.woClose,
                  child: FilledButton(
                    // Looks disabled until every task is done; a tap explains why.
                    style: wo.allTasksDone
                        ? null
                        : FilledButton.styleFrom(
                            backgroundColor: AppColors.greyBg,
                            foregroundColor: AppColors.textMuted,
                          ),
                    onPressed: () => startCloseWorkOrder(context, ref, wo),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Close Work Order')),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static final _value = AppText.body.copyWith(fontSize: 12.5, color: AppColors.text);

  Widget _field(String label, Widget value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption),
      const SizedBox(height: 4),
      value,
    ],
  );

  Widget _iconField(IconData icon, String label, Widget value, {Color? iconColor}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: _field(label, value)),
    ],
  );
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    return AppCard(
      onTap: DemoGuard.push(context, Routes.assetDetail(a.id)),
      child: Row(
        children: [
          AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 92),
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
                    Flexible(child: StatusChip(a.status)),
                  ],
                ),
                Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                const SizedBox(height: 4),
                InfoRow(label: 'Serial No.', value: a.serialNo ?? '—', labelWidth: 72),
                InfoRow(label: 'Location', value: a.location, labelWidth: 72),
                InfoRow(label: 'Asset Type', value: a.type, labelWidth: 72),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_rounded, color: AppColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${wo.status}${wo.completedAt == null ? '' : ' on ${DemoClock.formatDateTime(wo.completedAt!)}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
              ),
            ],
          ),
          if (wo.resolution != null) InfoRow(label: 'Resolution', value: wo.resolution!, labelWidth: 96),
          if (wo.labourHours != null) InfoRow(label: 'Labour', value: '${wo.labourHours} h', labelWidth: 96),
          if (wo.signature.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Signature', style: AppText.caption),
            Container(
              height: 90,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: CustomPaint(painter: SignaturePainter.saved(wo.signature)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Parts

class _PartsTab extends ConsumerWidget {
  const _PartsTab({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wo.parts.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.settings_outlined,
              title: 'No parts yet',
              message: 'Reserve spare parts from inventory for this job.',
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, wp) in wo.parts.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 76),
                  if (ref.watch(partByIdProvider(wp.partId)) case final part?)
                    AssetListTile(
                      title: part.id,
                      subtitle: part.name,
                      imagePath: part.imagePath,
                      fallbackIcon: Icons.settings_outlined,
                      details: [
                        Text(
                          'Qty ${wp.qty} ${part.unit} · ${part.available} available in stock',
                          style: AppText.caption,
                        ),
                      ],
                      trailingTop: StatusChip(wp.status),
                      showChevron: false,
                      onTap: wp.status == 'Reserved' && wo.isActive
                          ? () async {
                              final ok = await showConfirmDialog(
                                context,
                                title: 'Remove ${part.id}?',
                                message: 'The ${wp.qty} reserved go back to available stock.',
                                confirmLabel: 'Remove',
                                destructive: true,
                              );
                              if (ok && context.mounted) {
                                ref.read(workOrdersProvider.notifier).removePart(wo.id, part.id);
                                context.showSnack('${part.id} reservation released');
                              }
                            }
                          : DemoGuard.push(context, Routes.partDetail(part.id)),
                    ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (wo.isActive)
          OutlinedButton.icon(
            onPressed: () => showAddPartSheet(context, ref, wo),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Part'),
          ),
        const SizedBox(height: 6),
        Text(
          'Tap a reserved part to release it. Reserved parts are issued from stock when the WO is closed.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- History

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context) {
    final log = wo.history.reversed.toList();
    if (log.isEmpty) {
      return const AppCard(
        child: EmptyState(icon: Icons.history_rounded, title: 'No history yet', message: 'Status changes appear here.'),
      );
    }
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < log.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0 ? AppColors.primary : AppColors.illustration,
                        ),
                      ),
                      if (i < log.length - 1) Expanded(child: Container(width: 2, color: AppColors.divider)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log[i].title, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                          if (log[i].note != null) Text(log[i].note!, style: AppText.body.copyWith(fontSize: 12.5)),
                          Text([DemoClock.formatDateTime(log[i].at), ?log[i].by].join(' · '), style: AppText.caption),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Documents

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    final linked = [for (final id in wo.documentIds) ?docs.doc(id)];
    final assetDocs = docs.forAsset(wo.assetId).where((d) => !wo.documentIds.contains(d.id)).toList();
    Widget row(AssetDocument d) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(
        d.isPdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined,
        color: d.isPdf ? AppColors.red : AppColors.primary,
      ),
      title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
      subtitle: Text(
        '${d.type} · ${d.sizeLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: DemoGuard.push(context, Routes.documentDetail(d.id)),
    );
    if (linked.isEmpty && assetDocs.isEmpty) {
      return AppCard(
        child: DemoGuard(
          route: Routes.addDocument,
          child: EmptyState(
            icon: Icons.description_outlined,
            title: 'No documents',
            message: 'Manuals, reports and certificates of ${wo.assetId} appear here.',
            actionLabel: 'Add Document',
            onAction: () => context.push(Routes.withAsset(Routes.addDocument, wo.assetId)),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Linked to this work order', style: AppText.bodyStrong),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: linked.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('No documents linked', style: AppText.secondary),
                )
              : Column(children: [for (final d in linked) row(d)]),
        ),
        if (assetDocs.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Asset documents (${assetDocs.length})', style: AppText.bodyStrong),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [for (final d in assetDocs) row(d)]),
          ),
        ],
      ],
    );
  }
}
