import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/more/registration/registration_widgets.dart';
import 'package:asset360_mobile/features/work/audit/audit_widgets.dart';

// ---------------------------------------------------------------- Create Audit Campaign

class CreateAuditScreen extends ConsumerStatefulWidget {
  const CreateAuditScreen({super.key});

  @override
  ConsumerState<CreateAuditScreen> createState() => _CreateAuditScreenState();
}

class _CreateAuditScreenState extends ConsumerState<CreateAuditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _site;
  final _locations = <String>{};
  final _categories = <String>{};
  DateTime? _start;
  DateTime? _end;
  late final Set<String> _auditors = {ref.read(currentUserProvider).id};
  bool _blind = false;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Audit _draft() => Audit(
    id: '',
    name: '',
    site: _site ?? '',
    start: _start ?? DemoClock.today,
    end: _end ?? DemoClock.today,
    totalAssets: 0,
    status: AuditStatus.pending,
    auditorId: '',
    scopeLocations: _locations.toList(),
    scopeCategories: _categories.toList(),
  );

  Future<void> _pickAuditors() async {
    final people = ref.read(peopleProvider);
    final chosen = Set.of(_auditors);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          builder: (context, scroll) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SheetTitle('Auditors', subtitle: '${chosen.length} selected'),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: people.length,
                  itemBuilder: (context, i) {
                    final p = people[i];
                    return CheckboxListTile(
                      value: chosen.contains(p.id),
                      onChanged: (v) => setSheet(() => v == true ? chosen.add(p.id) : chosen.remove(p.id)),
                      secondary: CircleAvatar(
                        backgroundColor: AppColors.tileLavender,
                        child: Text(p.initials, style: TextStyle(color: AppColors.primary, fontSize: 13)),
                      ),
                      title: Text(p.name, style: AppText.bodyStrong),
                      subtitle: Text([p.role, ?p.department].join(' · '), style: AppText.caption),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Done')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        _auditors
          ..clear()
          ..addAll(chosen);
      });
    }
  }

  void _save() {
    setState(() => _submitted = true);
    final ok = _formKey.currentState!.validate();
    final inScope = auditScope(_draft(), ref.read(assetsProvider)).length;
    if (!ok || _site == null || _start == null || _end == null || _auditors.isEmpty || inScope == 0) {
      context.showSnack(inScope == 0 && _site != null ? 'No assets in that scope' : 'Complete the required fields');
      return;
    }
    final id = ref
        .read(auditsProvider.notifier)
        .create(
          name: _name.text.trim(),
          site: _site!,
          start: _start!,
          end: _end!,
          scopeLocations: _locations.toList(),
          scopeCategories: _categories.toList(),
          auditorIds: _auditors.toList(),
          blindCount: _blind,
        );
    context.showSnack('$id created as Pending – tap Start Audit to begin');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final assets = ref.watch(assetsProvider);
    final people = ref.watch(peopleProvider);
    final buildings = _site == null ? <String>[] : locationTree[_site]?.keys.toList() ?? <String>[];
    final categories = _site == null
        ? <String>[]
        : ({for (final a in assets.where((a) => a.site == _site)) a.category}.toList()..sort());
    final inScope = _site == null ? 0 : auditScope(_draft(), assets).length;
    Widget chips(List<String> options, Set<String> selected) => Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final o in options)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            onSelected: (v) => setState(() => v ? selected.add(o) : selected.remove(o)),
          ),
      ],
    );
    return AppScaffold(
      bottomActions: Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _save, child: const Text('Create Audit')),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const PageTitle(
              title: 'Create Audit Campaign',
              subtitle: 'Plan a physical verification of assets',
              help:
                  'Pick the site, then optionally narrow the scope to buildings and asset categories (none = all). '
                  'Total Assets is the number of registered assets in scope. A new audit is Pending until you '
                  'tap Start Audit. Blind count hides the registered location and custodian from auditors.',
            ),
            const SizedBox(height: 12),
            const FieldLabel('Audit Name', required: true),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Q4 Warehouse Audit'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the audit name' : null,
            ),
            const SizedBox(height: 14),
            const FieldLabel('Site', required: true),
            DropdownButtonFormField<String>(
              initialValue: _site,
              isExpanded: true,
              hint: const Text('Select site'),
              items: [for (final s in locationTree.keys) DropdownMenuItem(value: s, child: Text(s))],
              validator: (v) => v == null ? 'Select the site' : null,
              onChanged: (v) => setState(() {
                _site = v;
                _locations.clear();
                _categories.clear();
              }),
            ),
            const SizedBox(height: 14),
            // One child each, so the fields below keep their list position.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_site != null) ...[
                  const FieldLabel('Scope – Locations'),
                  chips(buildings, _locations),
                  const SizedBox(height: 10),
                  const FieldLabel('Scope – Asset Categories'),
                  chips(categories, _categories),
                  const SizedBox(height: 6),
                  Text(
                    '$inScope asset${inScope == 1 ? '' : 's'} in scope',
                    style: AppText.caption.copyWith(color: inScope == 0 ? AppColors.red : AppColors.primary),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
            FieldPair(
              LabeledField(
                label: 'Start Date',
                required: true,
                child: DateBox(
                  value: _start,
                  firstDate: DemoClock.today,
                  error: _submitted && _start == null ? 'Select the start' : null,
                  onPicked: (d) => setState(() {
                    _start = d;
                    if (_end != null && _end!.isBefore(d)) _end = null;
                  }),
                ),
              ),
              LabeledField(
                label: 'End Date',
                required: true,
                child: DateBox(
                  value: _end,
                  firstDate: _start ?? DemoClock.today,
                  error: _submitted && _end == null ? 'Select the end' : null,
                  onPicked: (d) => setState(() => _end = d),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Auditors', required: true),
            AppCard(
              onTap: _pickAuditors,
              child: Row(
                children: [
                  Expanded(
                    child: _auditors.isEmpty
                        ? Text('Select auditors', style: hintStyle.copyWith(color: _submitted ? AppColors.red : null))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final p in people.where((p) => _auditors.contains(p.id)))
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  avatar: CircleAvatar(
                                    backgroundColor: AppColors.tileLavender,
                                    child: Text(p.initials, style: const TextStyle(fontSize: 10)),
                                  ),
                                  label: Text(p.name),
                                ),
                            ],
                          ),
                  ),
                  Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _blind,
              onChanged: (v) => setState(() => _blind = v),
              title: Text('Blind count', style: AppText.bodyStrong),
              subtitle: Text('Auditors do not see the registered location and custodian', style: AppText.caption),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Result lists

/// Assets with one result (a result tile on the audit session).
class AuditResultsScreen extends ConsumerWidget {
  const AuditResultsScreen({super.key, required this.id, required this.result});

  final String id;
  final String result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(auditByIdProvider(id));
    if (a == null) {
      return const AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Audit not found'),
      );
    }
    final rows = a.entriesFor(result);
    final look = auditResultLook(result);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            leading: Icon(look.icon, color: look.color, size: 26),
            title: '$result (${formatCount(a.count(result))})',
            subtitle: a.name,
          ),
          const SizedBox(height: 12),
          LoadingGate(
            rows: 4,
            child: rows.isEmpty
                ? AppCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No assets with this result yet',
                      message: 'Scan assets in the audit to record results.',
                      actionLabel: 'Back to the audit',
                      onAction: () => context.pop(),
                    ),
                  )
                : AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                          AuditEntryTile(entry: rows[i]),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            'Showing ${rows.length} of ${formatCount(a.count(result))}',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// One audit result: asset (or unregistered item), where it was found and when.
class AuditEntryTile extends ConsumerWidget {
  const AuditEntryTile({super.key, required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = entry;
    final asset = ref.watch(assetByIdProvider(e.assetId));
    final lines = [
      if (e.result == AuditResult.wrongLocation) 'Expected: ${e.expectedLocation ?? '—'}',
      if (e.result == AuditResult.notFound) 'Registered at: ${e.expectedLocation ?? asset?.location ?? '—'}',
      if (e.location != null) 'Found at: ${e.location}${e.locationUpdated ? ' (location updated)' : ''}',
      [auditTime(e.at), ?e.by, ?e.method].join(' · '),
      ?e.remarks,
    ];
    return ListTile(
      onTap: asset != null
          ? () => context.push(Routes.assetDetail(asset.id))
          : () => context.push(Routes.newRegistration, extra: RegistrationPrefill(photo: e.photos.firstOrNull)),
      leading: asset != null
          ? AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 44)
          : IconSquare(icon: Icons.add_box_outlined, tone: TileTone.lavender, size: 44),
      title: Text(
        asset == null ? '${e.assetId} · ${e.description ?? 'Unregistered'}' : '${asset.id} · ${asset.name}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.bodyStrong.copyWith(fontSize: 13),
      ),
      subtitle: Text(lines.join('\n'), style: AppText.caption),
      trailing: asset == null
          ? const Tooltip(message: 'Register now', child: Icon(Icons.app_registration_rounded))
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

// ---------------------------------------------------------------- Report

class AuditReportScreen extends ConsumerWidget {
  const AuditReportScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(auditByIdProvider(id));
    if (a == null) {
      return const AppScaffold(
        body: EmptyState(icon: Icons.search_off_rounded, title: 'Audit not found'),
      );
    }
    final people = ref.watch(peopleProvider);
    final auditors = [
      for (final pid in a.allAuditors) people.where((p) => p.id == pid).firstOrNull?.name ?? pid,
    ].join(', ');
    final accuracy = a.done == 0 ? 0 : (a.verified * 100 / a.done).round();
    void share() {
      final text = [
        'Audit Report – ${a.name} (${a.id})',
        '${a.site} · ${auditDateRange(a)} · ${a.status}',
        'Audited ${formatCount(a.done)} of ${formatCount(a.totalAssets)} (${(a.progress * 100).round()}%)',
        for (final r in AuditResult.all) '$r: ${formatCount(a.count(r))}',
        if (a.remaining > 0) 'Not scanned: ${formatCount(a.remaining)}',
      ].join('\n');
      unawaited(Clipboard.setData(ClipboardData(text: text)));
      context.showSnack('Report summary copied. The PDF would open in the share sheet here (demo).');
    }

    return AppScaffold(
      bottomActions: FilledButton.icon(
        onPressed: share,
        icon: const Icon(Icons.share_rounded),
        label: const Text('Share'),
      ),
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            title: 'Audit Report',
            subtitle: '${a.name} · ${a.id}',
            trailing: IconButton(tooltip: 'Share report', onPressed: share, icon: const Icon(Icons.share_outlined)),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Summary',
            child: Column(
              children: [
                InfoRow(label: 'Site', value: a.site),
                InfoRow(label: 'Period', value: auditDateRange(a)),
                InfoRow(label: 'Status', value: a.status),
                if (a.completedAt != null) InfoRow(label: 'Completed', value: auditTime(a.completedAt!)),
                InfoRow(label: 'Auditors', value: auditors),
                InfoRow(
                  label: 'Scope',
                  value: [
                    a.scopeLocations.isEmpty ? 'Whole site' : a.scopeLocations.join(', '),
                    a.scopeCategories.isEmpty ? 'all categories' : a.scopeCategories.join(', '),
                  ].join(' · '),
                ),
                if (a.blindCount) const InfoRow(label: 'Method', value: 'Blind count'),
                InfoRow(
                  label: 'Audited',
                  value: '${formatCount(a.done)} of ${formatCount(a.totalAssets)} (${(a.progress * 100).round()}%)',
                ),
                InfoRow(label: 'Accuracy', value: '$accuracy% verified at the registered location'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Results',
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 34,
                      sectionsSpace: 2,
                      sections: [
                        for (final r in AuditResult.all)
                          if (a.count(r) > 0)
                            PieChartSectionData(
                              value: a.count(r).toDouble(),
                              color: auditResultLook(r).color,
                              radius: 26,
                              showTitle: false,
                            ),
                        if (a.remaining > 0)
                          PieChartSectionData(
                            value: a.remaining.toDouble(),
                            color: AppColors.divider,
                            radius: 26,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final r in AuditResult.all)
                        _Legend(color: auditResultLook(r).color, label: r, value: a.count(r), total: a.totalAssets),
                      if (a.remaining > 0)
                        _Legend(
                          color: AppColors.divider,
                          label: 'Not scanned',
                          value: a.remaining,
                          total: a.totalAssets,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final r in [AuditResult.wrongLocation, AuditResult.notFound, AuditResult.unregistered]) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: '$r (${formatCount(a.count(r))})',
              actionLabel: a.entriesFor(r).isEmpty ? null : 'View All',
              onAction: () => context.push(Routes.auditResults(a.id, r)),
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: a.entriesFor(r).isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('No discrepancies', style: AppText.secondary),
                    )
                  : Column(
                      children: [
                        for (final e in a.entriesFor(r).take(5)) AuditEntryTile(entry: e),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Showing ${a.entriesFor(r).take(5).length} of ${formatCount(a.count(r))}',
                            style: AppText.caption,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.value, required this.total});

  final Color color;
  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : value * 100 / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: AppText.caption.copyWith(color: AppColors.text)),
          ),
          Text('${formatCount(value)} · ${pct.toStringAsFixed(pct < 10 && pct > 0 ? 1 : 0)}%', style: AppText.caption),
        ],
      ),
    );
  }
}
