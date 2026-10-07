import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/settings_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';

/// App version for About (package_info_plus; "1.0.0 (1)" when the platform cannot tell).
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '1.0.0 (1)';
  }
});

/// Settings (not in the designs; built in the style of the module screens).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final s = ref.read(appSettingsProvider.notifier);
    final notif = ref.watch(notificationSettingsProvider);
    final net = ref.watch(networkProvider);
    final sync = ref.watch(syncProvider);
    final version = ref.watch(appVersionProvider).value ?? '…';
    final here = GoRouterState.of(context).uri.path;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(title.toUpperCase(), style: AppText.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: .6)),
    );
    Widget nav(IconData icon, TileTone tone, String title, String subtitle, VoidCallback onTap) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: IconSquare(icon: icon, tone: tone, size: 40),
      title: Text(title, style: AppText.bodyStrong),
      subtitle: Text(subtitle, style: AppText.caption),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
    Widget toggle(IconData icon, TileTone tone, String title, String subtitle, bool value, ValueChanged<bool> on) =>
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          secondary: IconSquare(icon: icon, tone: tone, size: 40),
          title: Text(title, style: AppText.bodyStrong),
          subtitle: Text(subtitle, style: AppText.caption),
          value: value,
          onChanged: on,
        );

    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Settings',
            subtitle: 'Appearance, notifications and preferences',
            help:
                'Preferences apply at once and last until the app is closed (demo). The Developer section appears '
                'only in debug builds.',
          ),
          section('Appearance'),
          AppCard(
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.settings_suggest_outlined),
                    label: Text('System'),
                  ),
                ],
                selected: {settings.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
            ),
          ),
          section('Notifications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (key, label, desc) in notificationSettingCategories)
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    title: Text(label, style: AppText.bodyStrong),
                    subtitle: Text(desc, style: AppText.caption),
                    value: notif.isOn(key),
                    onChanged: (v) => ref.read(notificationSettingsProvider.notifier).setCategory(key, v),
                  ),
                nav(
                  Icons.bedtime_outlined,
                  TileTone.lavender,
                  'Quiet hours',
                  notif.quietHours ? 'On' : 'Off',
                  () => context.push(Routes.notificationSettingsFrom(here)),
                ),
              ],
            ),
          ),
          section('Scanning'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: IconSquare(icon: Icons.qr_code_scanner_rounded, tone: TileTone.sky, size: 40),
                  title: Text('Default scan mode', style: AppText.bodyStrong),
                  subtitle: Text('Tab the Scan screen opens on', style: AppText.caption),
                  trailing: DropdownButton<DefaultScanMode>(
                    value: settings.scanMode,
                    underline: const SizedBox.shrink(),
                    items: [for (final m in DefaultScanMode.values) DropdownMenuItem(value: m, child: Text(m.label))],
                    onChanged: (v) => v == null ? null : s.setScanMode(v),
                  ),
                ),
                toggle(
                  Icons.volume_up_outlined,
                  TileTone.peach,
                  'Beep on scan',
                  'Play a sound when a tag is read',
                  settings.beep,
                  s.setBeep,
                ),
                toggle(
                  Icons.vibration_rounded,
                  TileTone.mint,
                  'Vibrate on scan',
                  'Short vibration when a tag is read',
                  settings.vibrate,
                  s.setVibrate,
                ),
              ],
            ),
          ),
          section('Offline & Sync'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                nav(
                  Icons.cloud_sync_outlined,
                  TileTone.cyan,
                  'Offline Sync',
                  '${net.online ? 'Online' : 'Offline'} · ${sync.pending.length} pending · '
                      'Automatic sync ${sync.autoSync ? 'on' : 'off'}',
                  () => context.push(Routes.offlineSync),
                ),
                nav(
                  Icons.pending_actions_outlined,
                  TileTone.peach,
                  'Pending Sync',
                  'Changes waiting to be uploaded',
                  () => context.push(Routes.pendingSync),
                ),
              ],
            ),
          ),
          section('Language'),
          AppCard(
            padding: EdgeInsets.zero,
            child: RadioGroup<String>(
              groupValue: settings.language,
              onChanged: (v) {
                if (v == 'العربية') context.showSnack('Arabic (العربية) is coming soon');
              },
              child: const Column(
                children: [
                  RadioListTile(value: 'English', title: Text('English')),
                  RadioListTile(value: 'العربية', title: Text('العربية'), subtitle: Text('Coming soon')),
                ],
              ),
            ),
          ),
          if (kDebugMode) ...[
            section('Developer'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  nav(
                    Icons.fact_check_outlined,
                    TileTone.mint,
                    'Data check',
                    'Every count and total in the mock data',
                    () => context.push(Routes.dataCheck),
                  ),
                  nav(
                    Icons.qr_code_2_rounded,
                    TileTone.lavender,
                    'Print demo tags',
                    'QR codes for the demo assets, to scan from a second phone',
                    () => context.push(Routes.demoTags),
                  ),
                  toggle(
                    Icons.cloud_off_rounded,
                    TileTone.peach,
                    'Simulate offline',
                    'Changes are queued for Offline Sync; switching back starts auto-sync',
                    net.simulatedOffline,
                    ref.read(networkProvider.notifier).setSimulatedOffline,
                  ),
                  toggle(
                    Icons.sync_problem_rounded,
                    TileTone.pink,
                    'Simulate sync failures',
                    'Each item has a 10% chance to fail while syncing',
                    sync.simulateFailures,
                    ref.read(syncProvider.notifier).setSimulateFailures,
                  ),
                  nav(
                    Icons.restart_alt_rounded,
                    TileTone.grey,
                    'Reset demo data',
                    'Reload every seed record',
                    () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Reset demo data?',
                        message:
                            'Every change made in this session (work orders, scans, sync queue …) is discarded and '
                            'the seed data is loaded again. You stay signed in.',
                        confirmLabel: 'Reset',
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;
                      resetDemoData(ref);
                      context.showSnack('Demo data reset');
                    },
                  ),
                ],
              ),
            ),
          ],
          section('About'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: IconSquare(icon: Icons.info_outline_rounded, tone: TileTone.lavender, size: 40),
                  title: Text('Asset360', style: AppText.bodyStrong),
                  subtitle: Text('Version $version · Purple IQ', style: AppText.caption),
                ),
                nav(
                  Icons.description_outlined,
                  TileTone.grey,
                  'Open-source licenses',
                  'Packages used by this app',
                  () => showLicensePage(
                    context: context,
                    applicationName: 'Asset360',
                    applicationVersion: version,
                    useRootNavigator: false,
                  ),
                ),
                nav(
                  Icons.help_outline_rounded,
                  TileTone.sky,
                  'Help & Support',
                  'FAQs, contact support, report a bug',
                  () => context.push(Routes.help),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
