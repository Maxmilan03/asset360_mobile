import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/alert.dart';
import '../../data/repositories/alerts_repository.dart';

/// Icon and colour per notification kind (design 11, right screen).
(IconData, ChipTone) notificationLook(AppNotification n) => switch (n.kind) {
  'lowBattery' => (Icons.warning_rounded, ChipTone.red),
  'woAssigned' || 'woCreated' || 'woStarted' => (Icons.build_rounded, ChipTone.orange),
  'woOverdue' => (Icons.alarm_rounded, ChipTone.red),
  'maintenanceDue' => (Icons.notifications_rounded, ChipTone.amber),
  'temperature' => (Icons.device_thermostat_rounded, ChipTone.red),
  'assetMoved' => (Icons.location_on_rounded, ChipTone.green),
  'woCompleted' => (Icons.published_with_changes_rounded, ChipTone.blue),
  'vibration' => (Icons.warning_amber_rounded, ChipTone.amber),
  'stockLow' => (Icons.inventory_2_rounded, ChipTone.purple),
  'approval' => (Icons.approval_rounded, ChipTone.blue),
  'issue' => (Icons.report_rounded, ChipTone.red),
  'inspection' => (Icons.fact_check_rounded, ChipTone.purple),
  'sync' => (Icons.cloud_sync_rounded, ChipTone.blue),
  'alert' => (Icons.notifications_active_rounded, ChipTone.red),
  _ => (Icons.notifications_rounded, ChipTone.grey),
};

/// Where tapping a notification goes. Asset-moved alerts open Tracking for the asset.
String? notificationRoute(AppNotification n, WidgetRef ref) {
  final id = n.refId;
  if (n.kind == 'assetMoved') {
    final asset = id == null ? null : ref.read(alertByIdProvider(id))?.assetId;
    return asset == null ? Routes.tracking : Routes.trackAsset(asset);
  }
  if (id == null) return n.refType == 'sync' ? Routes.offlineSync : null;
  return switch (n.refType) {
    'alert' => Routes.alertDetail(id),
    'workOrder' => Routes.workOrder(id),
    'part' => Routes.partDetail(id),
    'asset' => Routes.assetDetail(id),
    'movement' => Routes.movementRequest(id),
    'issue' => Routes.issueDetail(id),
    'inspection' => Routes.inspectionDetail(id),
    'audit' => Routes.auditSession(id),
    'document' => Routes.documentDetail(id),
    'sync' => Routes.offlineSync,
    _ => null,
  };
}

/// Notifications (right screen of design/11_alerts_notifications.jpg). The header bell opens it.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0;

  void _open(AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);
    final route = notificationRoute(n, ref);
    if (route == null) {
      context.showSnack(n.message);
    } else {
      context.push(route);
    }
  }

  void _delete(AppNotification n) {
    final notifier = ref.read(notificationsProvider.notifier);
    final index = ref.read(notificationsProvider).indexOf(n);
    notifier.remove(n.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          margin: context.snackMargin,
          content: const Text('Notification deleted'),
          action: SnackBarAction(label: 'Undo', onPressed: () => notifier.restore(n, index)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(clockTickProvider);
    final all = ref.watch(notificationsProvider);
    final tabs = [
      all,
      all.unread,
      all.inCategory(NotificationCategory.system),
      all.inCategory(NotificationCategory.workOrders),
    ];
    final rows = tabs[_tab];
    final here = GoRouterState.of(context).uri.path;
    return AppScaffold(
      body: LazyListPage(
        header: [
          PageTitle(
            title: 'Notifications',
            subtitle: 'All your recent asset related notifications',
            trailing: PopupMenuButton<String>(
              tooltip: 'More options',
              icon: Icon(Icons.more_vert_rounded, color: AppColors.text),
              onSelected: (v) {
                if (v == 'read') {
                  final n = all.unread.length;
                  ref.read(notificationsProvider.notifier).markAllRead();
                  context.showSnack(n == 0 ? 'Everything is already read' : '$n marked as read');
                } else {
                  context.push(Routes.notificationSettingsFrom(here));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'read', child: Text('Mark all as read')),
                PopupMenuItem(value: 'settings', child: Text('Notification settings')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SegmentTabs(
            tabs: [
              const SegmentTab('All'),
              SegmentTab('Unread', count: tabs[1].length),
              SegmentTab('System', count: tabs[2].length),
              SegmentTab('Work Orders', count: tabs[3].length),
            ],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
        ],
        list: SliverLoadingGate(
          rows: 6,
          sliver: rows.isEmpty
              ? SliverToBoxAdapter(
                  child: AppCard(
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: _tab == 1 ? 'All caught up' : 'No notifications',
                      message: _tab == 1 ? 'You have read everything.' : 'New notifications will appear here.',
                    ),
                  ),
                )
              : SliverCardList(
                  itemCount: rows.length,
                  indent: 68,
                  itemBuilder: (_, i) => Dismissible(
                    key: ValueKey('n-${rows[i].id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) => _delete(rows[i]),
                    child: _NotificationRow(notification: rows[i], onTap: () => _open(rows[i])),
                  ),
                ),
        ),
        footer: [
          const SizedBox(height: 8),
          if (rows.isNotEmpty) Text('Swipe left to delete', textAlign: TextAlign.center, style: AppText.caption),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icon, tone) = notificationLook(n);
    return Material(
      color: n.read ? AppColors.surface : AppColors.primarySoft.withValues(alpha: .35),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: tone.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong.copyWith(
                              fontSize: 13.5,
                              fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(DemoClock.timeAgo(n.at), style: AppText.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.secondary),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Semantics(
                  label: n.read ? 'Read' : 'Unread',
                  child: Icon(Icons.circle, size: 8, color: n.read ? AppColors.border : AppColors.red),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// ⋮ → Notification settings: categories and quiet hours.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _pick(BuildContext context, ({int h, int m}) initial, ValueChanged<({int h, int m})> onPicked) async {
    final t = await showTimePicker(
      context: context,
      useRootNavigator: false,
      initialTime: TimeOfDay(hour: initial.h, minute: initial.m),
    );
    if (t != null) onPicked((h: t.hour, m: t.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(notificationSettingsProvider);
    final n = ref.read(notificationSettingsProvider.notifier);
    String fmt(({int h, int m}) t) => TimeOfDay(hour: t.h, minute: t.m).format(context);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(title: 'Notification Settings', subtitle: 'Choose what you are notified about'),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (key, label, desc) in notificationSettingCategories)
                  SwitchListTile(
                    title: Text(label, style: AppText.bodyStrong),
                    subtitle: Text(desc, style: AppText.caption),
                    value: s.isOn(key),
                    onChanged: (v) {
                      n.setCategory(key, v);
                      context.showSnack('$label notifications ${v ? 'on' : 'off'}');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.bedtime_outlined, color: AppColors.primary),
                  title: Text('Quiet hours', style: AppText.bodyStrong),
                  subtitle: Text('Only critical alerts make a sound', style: AppText.caption),
                  value: s.quietHours,
                  onChanged: n.setQuietHours,
                ),
                ListTile(
                  enabled: s.quietHours,
                  title: const Text('From'),
                  trailing: Text(fmt(s.quietFrom), style: AppText.bodyStrong),
                  onTap: () => _pick(context, s.quietFrom, n.setQuietFrom),
                ),
                ListTile(
                  enabled: s.quietHours,
                  title: const Text('To'),
                  trailing: Text(fmt(s.quietTo), style: AppText.bodyStrong),
                  onTap: () => _pick(context, s.quietTo, n.setQuietTo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
