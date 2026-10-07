import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../data/repositories/alerts_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../session_actions.dart';
import 'demo_gate.dart';
import 'feedback.dart';

/// Purple top bar: back arrow, logo + "Purple IQ | Asset360", bell and "RK" avatar.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.showBack, this.onBack});

  /// Defaults to "can this route pop?".
  final bool? showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = showBack ?? GoRouter.of(context).canPop();
    return _HeaderBar(
      children: [
        if (canPop)
          IconButton(
            tooltip: 'Back',
            onPressed: onBack ?? () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          )
        else
          const SizedBox(width: 12),
        const Expanded(child: _Brand(showProduct: true)),
        const DemoGate(child: NotificationBell()),
        const SizedBox(width: 6),
        const DemoGate(child: _InitialsAvatar()),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// Home variant: avatar photo, "Rex Kumar / DCS" and a chevron menu.
/// [bottom] is placed under the bar on the same purple background (the Home hero).
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, this.showProduct = false, this.bottom});

  final bool showProduct;
  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return _HeaderBar(
      bottom: bottom,
      children: [
        const SizedBox(width: 16),
        Expanded(child: _Brand(showProduct: showProduct)),
        const DemoGate(child: NotificationBell()),
        const SizedBox(width: 4),
        DemoGate(
          child: PopupMenuButton<_UserMenu>(
            tooltip: 'Account menu',
            offset: const Offset(0, 48),
            onSelected: (item) => switch (item) {
              _UserMenu.profile => context.push(Routes.profileFrom(GoRouterState.of(context).uri.path)),
              _UserMenu.settings => context.go(Routes.settings),
              _UserMenu.site => showSwitchSiteSheet(context, ref),
              _UserMenu.logout => confirmLogout(context, ref),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: _UserMenu.profile, child: _MenuRow(Icons.person_outline_rounded, 'Profile')),
              const PopupMenuItem(value: _UserMenu.settings, child: _MenuRow(Icons.settings_outlined, 'Settings')),
              const PopupMenuItem(value: _UserMenu.site, child: _MenuRow(Icons.apartment_rounded, 'Switch Site')),
              const PopupMenuItem(
                value: _UserMenu.logout,
                child: _MenuRow(Icons.logout_rounded, 'Logout', color: AppColors.red),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _PhotoAvatar(),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(user.role, style: const TextStyle(color: AppColors.onDarkMuted, fontSize: 11)),
                    ],
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

enum _UserMenu { profile, settings, site, logout }

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {this.color});
  final IconData icon;
  final String label;
  final Color? color;
  Color get _color => color ?? AppColors.text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: _color),
      const SizedBox(width: 12),
      Text(
        label,
        style: TextStyle(color: _color, fontWeight: FontWeight.w500),
      ),
    ],
  );
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.children, this.bottom});
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.headerOverlay,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 60, child: Row(children: children)),
            ?bottom,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.showProduct});
  final bool showProduct;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo_on_dark.png', width: 32, height: 32, filterQuality: FilterQuality.medium),
            const SizedBox(width: 8),
            const Text(
              'Purple IQ',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -.2),
            ),
            if (showProduct) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.white24,
              ),
              const Text(
                'Asset360',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bell with the unread count; opens Notifications inside the current tab.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () {
        final path = GoRouterState.of(context).uri.path;
        if (path.endsWith('/${Routes.notificationsSegment}')) {
          context.showSnack('You are already viewing Notifications');
          return;
        }
        context.push(Routes.notificationsFrom(path));
      },
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.badge,
        label: Text(count > 99 ? '99+' : '$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        offset: const Offset(6, -6),
        child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _InitialsAvatar extends ConsumerWidget {
  const _InitialsAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Tooltip(
      message: 'Profile',
      child: InkResponse(
        radius: 24,
        onTap: () {
          final path = GoRouterState.of(context).uri.path;
          if (path.endsWith('/${Routes.profileSegment}')) {
            context.showSnack('You are already viewing your Profile');
            return;
          }
          context.push(Routes.profileFrom(path));
        },
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: Text(
            user.initials,
            style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Photo placeholder for the Home header (no real photo in the demo data).
class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        gradient: const LinearGradient(colors: [Color(0xFFB9A6F3), Color(0xFF7B55E8)]),
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
    );
  }
}
