import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/admin_mock.dart';
import '../../data/mock/registration_mock.dart';
import '../../data/models/person.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/session_repository.dart';

const _tabs = ['users', 'roles', 'sites', 'master'];

/// Administration: Users, Roles & Permissions, Sites & Locations, Master Data.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late int _tab = _tabs.indexOf(widget.initialTab ?? '').clamp(0, _tabs.length - 1);

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final master = ref.watch(masterDataProvider);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Administration',
            subtitle: 'Users, roles, sites and master data',
            help: 'Changes made here apply for this demo session only.',
          ),
          const SizedBox(height: 12),
          SegmentTabs(
            tabs: [
              SegmentTab('Users', count: people.length),
              SegmentTab('Roles', count: permissionMatrix.length),
              SegmentTab('Sites', count: locationTree.length),
              SegmentTab(
                'Master Data',
                count: master.categories.length + master.types.length + master.manufacturers.length,
              ),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          switch (_tab) {
            0 => LoadingGate(
              key: const ValueKey('users'),
              rows: 6,
              child: _Users(people: people),
            ),
            1 => const _Roles(),
            2 => const LoadingGate(key: ValueKey('sites'), rows: 3, child: _Sites()),
            _ => const _MasterData(),
          },
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- users

class _Users extends StatelessWidget {
  const _Users({required this.people});

  final List<Person> people;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) {
      return const EmptyState(icon: Icons.group_off_outlined, title: 'No users', message: 'No users are set up yet.');
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, p) in people.indexed) ...[
            if (i > 0) const Divider(indent: 64),
            ListTile(
              leading: _Avatar(p),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(p.role, tone: ChipTone.purple),
                    Text(p.department ?? '—', style: AppText.caption),
                  ],
                ),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              onTap: () => context.push(Routes.adminUser(p.id)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.person, {this.radius = 20});

  final Person person;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: AppColors.primarySoft,
    child: Text(
      person.initials,
      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: radius * .7),
    ),
  );
}

/// User detail with a working role dropdown.
class AdminUserScreen extends ConsumerWidget {
  const AdminUserScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(personByIdProvider(personId));
    if (p == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'User not found',
          actionLabel: 'All users',
          onAction: () => context.go(Routes.admin),
        ),
      );
    }
    final custodyOf = ref.watch(assetsProvider).where((a) => a.custodian.startsWith(p.name)).length;
    final wos = ref.watch(workOrdersProvider).mine(p.id).length;
    final isMe = ref.watch(currentUserProvider).id == p.id;
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          AppCard(
            child: Column(
              children: [
                _Avatar(p, radius: 34),
                const SizedBox(height: 10),
                Text(
                  p.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.role} · ${p.department ?? '—'}',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.secondary,
                ),
                if (isMe) ...[const SizedBox(height: 6), const StatusChip('Signed in', tone: ChipTone.green)],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Details',
            child: Column(
              children: [
                InfoRow(label: 'User ID', value: p.id),
                InfoRow(label: 'Phone', value: p.phone ?? '—'),
                InfoRow(label: 'Department', value: p.department ?? '—'),
                InfoRow(label: 'Assets in custody', value: '$custodyOf'),
                InfoRow(label: 'Active work orders', value: '$wos'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Role',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(p.role),
                  initialValue: p.role,
                  isExpanded: true,
                  items: [
                    for (final r in {...appRoles, p.role})
                      DropdownMenuItem(
                        value: r,
                        child: Text(r, style: AppText.body),
                      ),
                  ],
                  onChanged: (r) {
                    if (r == null || r == p.role) return;
                    ref.read(peopleProvider.notifier).update(p.copyWith(role: r));
                    context.showSnack('${p.name} is now $r');
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  permissionMatrix.containsKey(p.role)
                      ? 'Permissions follow the "${p.role}" row of Roles & Permissions.'
                      : 'No permission profile for "${p.role}" – it has view access by default.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- roles

class _Roles extends StatelessWidget {
  const _Roles();

  @override
  Widget build(BuildContext context) {
    ChipTone tone(String level) => switch (level) {
      Perm.full => ChipTone.green,
      Perm.edit => ChipTone.blue,
      Perm.view => ChipTone.grey,
      _ => ChipTone.red,
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Text('Roles & Permissions (view only)', style: AppText.bodyStrong),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              horizontalMargin: 14,
              columnSpacing: 10,
              headingTextStyle: AppText.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
              columns: [
                const DataColumn(label: Text('Role')),
                for (final m in permissionModules) DataColumn(label: Text(m)),
              ],
              rows: [
                for (final e in permissionMatrix.entries)
                  DataRow(
                    cells: [
                      DataCell(Text(e.key, style: AppText.bodyStrong.copyWith(fontSize: 12.5))),
                      for (final level in e.value)
                        DataCell(
                          level == Perm.none ? Text('—', style: AppText.caption) : StatusChip(level, tone: tone(level)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- sites

class _Sites extends ConsumerWidget {
  const _Sites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(assetsProvider);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final site in locationTree.entries)
            ExpansionTile(
              leading: Icon(Icons.apartment_rounded, color: AppColors.primary),
              title: Text(site.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
              subtitle: Text(
                '${site.value.length} buildings · ${assets.where((a) => a.site == site.key).length} assets',
                style: AppText.caption,
              ),
              shape: const Border(),
              children: [
                for (final building in site.value.entries)
                  ExpansionTile(
                    tilePadding: const EdgeInsets.only(left: 40, right: 16),
                    leading: Icon(Icons.business_rounded, size: 20, color: AppColors.textSecondary),
                    title: Text(building.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body),
                    shape: const Border(),
                    children: [
                      for (final floor in building.value.entries)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(72, 4, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(floor.key, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [for (final z in floor.value) TagLabel(z, icon: Icons.place_outlined)],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- master data

class _MasterData extends ConsumerWidget {
  const _MasterData();

  Future<void> _add(BuildContext context, WidgetRef ref, String what) async {
    final master = ref.read(masterDataProvider);
    final result = await showDialog<(String, String?)>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _AddDialog(what: what, categories: what == 'Asset Type' ? master.categories : null),
    );
    if (result == null || !context.mounted) return;
    final (name, category) = result;
    final n = ref.read(masterDataProvider.notifier);
    final ok = switch (what) {
      'Category' => n.addCategory(name),
      'Asset Type' => n.addType(name, category!),
      _ => n.addManufacturer(name),
    };
    context.showSnack(ok ? '$what "$name" added' : '$what "$name" already exists');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(masterDataProvider);
    Widget card(String title, String what, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: title,
        actionLabel: '+ Add',
        actionIcon: null,
        onAction: () => _add(context, ref, what),
        child: Wrap(spacing: 6, runSpacing: 6, children: chips),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card('Categories (${m.categories.length})', 'Category', [for (final c in m.categories) TagLabel(c)]),
        card('Asset Types (${m.types.length})', 'Asset Type', [
          for (final e in (m.types.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
            TagLabel('${e.key} · ${e.value}'),
        ]),
        card('Manufacturers (${m.manufacturers.length})', 'Manufacturer', [
          for (final x in m.manufacturers) TagLabel(x),
        ]),
      ],
    );
  }
}

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.what, this.categories});

  final String what;

  /// Shown as a dropdown when adding an asset type.
  final List<String>? categories;

  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _name = TextEditingController();
  late String? _category = widget.categories?.firstOrNull;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final v = _name.text.trim();
    if (v.length < 2) {
      setState(() => _error = 'Enter a name');
      return;
    }
    Navigator.pop(context, (v, _category));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.what}'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
            onSubmitted: (_) => _save(),
          ),
          if (widget.categories != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [for (final c in widget.categories!) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
