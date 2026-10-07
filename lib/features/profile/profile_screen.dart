import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/session_actions.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/audits_repository.dart';
import '../../data/repositories/inspections_repository.dart';
import '../../data/repositories/maintenance_repository.dart';
import '../../data/repositories/session_repository.dart';

/// Profile (not in the designs; built in the style of the module screens).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final path = await pickPhoto(context);
    if (path == null || !context.mounted) return;
    ref.read(sessionProvider.notifier).setPhoto(path);
    context.showSnack('Profile photo updated');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final session = ref.watch(sessionProvider);
    final me = user.id;
    final openWos = ref.watch(workOrdersProvider).mine(me).length;
    final now = DemoClock.now;
    final insThisMonth = ref
        .watch(inspectionsProvider)
        .where((i) => i.inspectorId == me && i.dueAt.year == now.year && i.dueAt.month == now.month)
        .length;
    final audits = ref.watch(auditsProvider).mine(me).length;

    Widget stat(String value, String label, IconData icon, TileTone tone, VoidCallback onTap) => Expanded(
      child: KpiTile(icon: icon, value: value, label: label, tone: tone, onTap: onTap),
    );

    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(title: 'Profile', subtitle: 'Your details, role and password'),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                Stack(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Change photo',
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _changePhoto(context, ref),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.tileLavender,
                          backgroundImage: user.photoPath == null ? null : photoProvider(user.photoPath!),
                          child: user.photoPath == null
                              ? Text(
                                  user.initials,
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: AppColors.primary,
                        shape: CircleBorder(side: BorderSide(color: AppColors.surface, width: 2)),
                        child: IconButton(
                          tooltip: 'Change photo',
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          onPressed: () => _changePhoto(context, ref),
                          icon: const Icon(Icons.photo_camera_rounded, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  user.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageTitle.copyWith(fontSize: 20),
                ),
                Text(user.role, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                InfoRow(label: 'Email', value: user.email),
                InfoRow(label: 'Phone', value: user.person.phone ?? '—'),
                InfoRow(label: 'Department', value: user.person.department ?? '—'),
                InfoRow(label: 'Site', value: session.site),
                InfoRow(label: 'Username', value: user.username),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat(
                '$openWos',
                'Open WOs',
                Icons.build_rounded,
                TileTone.peach,
                () => context.push(Routes.maintenanceTab('mine')),
              ),
              const SizedBox(width: 8),
              stat(
                '$insThisMonth',
                'Inspections (month)',
                Icons.fact_check_rounded,
                TileTone.sky,
                () => context.push(Routes.inspectionTab('mine')),
              ),
              const SizedBox(width: 8),
              stat('$audits', 'Audits', Icons.view_in_ar_rounded, TileTone.mint, () => context.push(Routes.audit)),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _Row(
                  icon: Icons.edit_outlined,
                  tone: TileTone.lavender,
                  title: 'Edit Profile',
                  subtitle: 'Name, phone and photo',
                  onTap: () => showEditProfileSheet(context, ref),
                ),
                _Row(
                  icon: Icons.lock_outline_rounded,
                  tone: TileTone.peach,
                  title: 'Change Password',
                  subtitle: 'Use at least 8 characters with a mix of types',
                  onTap: () => showChangePasswordSheet(context, ref),
                ),
                _Row(
                  icon: Icons.location_city_rounded,
                  tone: TileTone.cyan,
                  title: 'Switch Site',
                  subtitle: session.site,
                  onTap: () => showSwitchSiteSheet(context, ref),
                ),
                _Row(
                  icon: Icons.settings_outlined,
                  tone: TileTone.grey,
                  title: 'Settings',
                  subtitle: 'Appearance, notifications, scanning',
                  onTap: () => context.push(Routes.settings),
                ),
                _Row(
                  icon: Icons.help_outline_rounded,
                  tone: TileTone.sky,
                  title: 'Help & Support',
                  subtitle: 'FAQs, contact support, report a bug',
                  onTap: () => context.push(Routes.help),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
            ),
            onPressed: () => confirmLogout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final TileTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: IconSquare(icon: icon, tone: tone, size: 40),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
    onTap: onTap,
  );
}

/// Edit Profile: name, phone and photo.
Future<void> showEditProfileSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _EditProfileSheet(),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(currentUserProvider).name);
  late final _phone = TextEditingController(text: ref.read(currentUserProvider).person.phone ?? '');
  late String? _photo = ref.read(currentUserProvider).photoPath;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final s = ref.read(sessionProvider.notifier);
    s.updateProfile(name: _name.text.trim(), phone: _phone.text.trim());
    if (_photo != null && _photo != ref.read(currentUserProvider).photoPath) s.setPhoto(_photo!);
    Navigator.pop(context);
    context.showSnack('Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: sheetFrame(context, [
        const SheetTitle('Edit Profile', subtitle: 'Name, phone and photo'),
        Center(
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              final p = await pickPhoto(context);
              if (p != null) setState(() => _photo = p);
            },
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.tileLavender,
              backgroundImage: _photo == null ? null : photoProvider(_photo!),
              child: _photo == null ? Icon(Icons.add_a_photo_outlined, color: AppColors.primary) : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text('Tap to change photo', style: AppText.caption)),
        const SizedBox(height: 12),
        const FieldLabel('Full Name', required: true),
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v ?? '').trim().length < 3 ? 'Enter your full name' : null,
        ),
        const SizedBox(height: 12),
        const FieldLabel('Phone', required: true),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          validator: (v) =>
              RegExp(r'^\+?[0-9 ]{8,16}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid phone number',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ]),
    );
  }
}

/// Password rules (Change Password).
List<(String, bool)> passwordRules(String p) => [
  ('At least 8 characters', p.length >= 8),
  ('An uppercase letter', p.contains(RegExp('[A-Z]'))),
  ('A lowercase letter', p.contains(RegExp('[a-z]'))),
  ('A number', p.contains(RegExp('[0-9]'))),
  ('A symbol (e.g. @ # !)', p.contains(RegExp(r'[^A-Za-z0-9]'))),
];

Future<void> showChangePasswordSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _new.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(sessionProvider.notifier).changePassword(_new.text);
    Navigator.pop(context);
    context.showSnack('Password changed. Use the new password next time you sign in.');
  }

  @override
  Widget build(BuildContext context) {
    final rules = passwordRules(_new.text);
    final met = rules.where((r) => r.$2).length;
    final strength = switch (met) {
      <= 2 => ('Weak', AppColors.red),
      3 || 4 => ('Medium', AppColors.amber),
      _ => ('Strong', AppColors.green),
    };
    InputDecoration deco(String hint) => InputDecoration(
      hintText: hint,
      suffixIcon: IconButton(
        tooltip: _show ? 'Hide passwords' : 'Show passwords',
        onPressed: () => setState(() => _show = !_show),
        icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      ),
    );
    return Form(
      key: _formKey,
      child: sheetFrame(context, [
        const SheetTitle('Change Password', subtitle: 'Enter your current password, then the new one twice'),
        const FieldLabel('Current Password', required: true),
        TextFormField(
          controller: _current,
          obscureText: !_show,
          decoration: deco('Current password'),
          validator: (v) => (v ?? '').isEmpty
              ? 'Enter your current password'
              : v != ref.read(sessionProvider).password
              ? 'The current password is not correct'
              : null,
        ),
        const SizedBox(height: 12),
        const FieldLabel('New Password', required: true),
        TextFormField(
          controller: _new,
          obscureText: !_show,
          decoration: deco('New password'),
          validator: (v) {
            final p = v ?? '';
            if (passwordRules(p).any((r) => !r.$2)) return 'The password does not meet every rule';
            if (p == _current.text) return 'Choose a password different from the current one';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _new.text.isEmpty ? 0 : met / rules.length,
                  minHeight: 6,
                  color: strength.$2,
                  backgroundColor: AppColors.divider,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _new.text.isEmpty ? 'Strength' : strength.$1,
              style: AppText.caption.copyWith(color: _new.text.isEmpty ? null : strength.$2),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final (label, ok) in rules)
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: ok ? AppColors.green : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: AppText.caption.copyWith(color: ok ? AppColors.green : null)),
              ),
            ],
          ),
        const SizedBox(height: 12),
        const FieldLabel('Confirm New Password', required: true),
        TextFormField(
          controller: _confirm,
          obscureText: !_show,
          decoration: deco('Repeat the new password'),
          validator: (v) => v != _new.text ? 'The passwords do not match' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: _save, child: const Text('Update Password')),
            ),
          ],
        ),
      ]),
    );
  }
}
