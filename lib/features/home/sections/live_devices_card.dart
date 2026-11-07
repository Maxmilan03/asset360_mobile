import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/repositories/dashboard_repository.dart';
import 'package:asset360_mobile/features/home/dash_ui.dart';

/// API mode Home card: devices online / offline. Starts from GET /network-status, then the
/// WebSocket (/network-status/live) pushes new counts. The socket runs only while Home is on screen
/// (not covered by another route, its tab selected: [TickerMode]) and the app is in the foreground.
class LiveDevicesCard extends ConsumerStatefulWidget {
  const LiveDevicesCard({super.key});

  @override
  ConsumerState<LiveDevicesCard> createState() => _LiveDevicesCardState();
}

class _LiveDevicesCardState extends ConsumerState<LiveDevicesCard> {
  late final LiveDevicesNotifier _live = ref.read(liveDevicesProvider.notifier);
  late final AppLifecycleListener _lifecycle;
  ValueListenable<bool>? _ticker;
  bool _foreground = true;
  bool? _active;

  @override
  void initState() {
    super.initState();
    final s = WidgetsBinding.instance.lifecycleState;
    _foreground = s == null || s == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        _foreground = s == AppLifecycleState.resumed;
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = TickerMode.getNotifier(context);
    if (!identical(t, _ticker)) {
      _ticker?.removeListener(_sync);
      _ticker = t..addListener(_sync);
    }
    _sync();
  }

  /// Opens / closes the socket when visibility or the app state changes (after the frame:
  /// providers must not change while widgets build).
  void _sync() {
    final active = mounted && (_ticker?.value ?? true) && _foreground;
    if (active == _active) return;
    _active = active;
    scheduleMicrotask(() => _live.setActive(active));
  }

  @override
  void dispose() {
    _ticker?.removeListener(_sync);
    _lifecycle.dispose();
    final live = _live;
    scheduleMicrotask(() => live.setActive(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveDevicesProvider);
    final open = DemoGuard.push(context, Routes.devices);
    return SectionCard(
      title: 'Live Devices',
      actionLabel: 'View Devices',
      onAction: open,
      child: DashSection<NetworkStatusCounts>(
        provider: networkStatusProvider,
        onRetry: (ref) => ref.invalidate(networkStatusProvider),
        isEmpty: (rest) => (live.counts ?? rest).total == 0,
        emptyIcon: Icons.sensors_off_rounded,
        emptyTitle: 'No devices reporting yet',
        emptyMessage: 'IoT tags appear here once they send data.',
        builder: (rest) {
          final c = live.counts ?? rest;
          return InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: LiveDot(connection: live.connection),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: CountCard(
                        icon: Icons.wifi_rounded,
                        value: dashNumber.format(c.totalOnline),
                        label: 'Online',
                        color: AppColors.green,
                        onTap: open,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CountCard(
                        icon: Icons.wifi_off_rounded,
                        value: dashNumber.format(c.totalOffline),
                        label: 'Offline',
                        color: AppColors.red,
                        onTap: open,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "● Live" while the WebSocket is connected; "Reconnecting…" / "Connecting…" / "Paused" otherwise.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, required this.connection});

  final LiveConnection connection;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (connection) {
      LiveConnection.connected => ('Live', AppColors.green),
      LiveConnection.connecting => ('Connecting…', AppColors.amber),
      LiveConnection.waiting => ('Reconnecting…', AppColors.amber),
      LiveConnection.stopped => ('Paused', AppColors.textMuted),
    };
    return Semantics(
      label: 'Live updates: $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppText.caption.copyWith(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
