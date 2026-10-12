import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/client_demo.dart';

export 'package:asset360_mobile/app/client_demo.dart' show DemoAction, demoCanDo, demoCanOpen;

/// Keeps a control visible but inert when the client demo does not allow it
/// (lib/app/client_demo.dart): no navigation, no ripple, no SnackBar, no visual
/// change. With the demo off, or the screen / action allowed, it changes nothing.
///
/// Wrap a control with `DemoGuard(route: …)` or `DemoGuard(action: …)` (buttons keep
/// their look), or build its callback with [DemoGuard.push] / [DemoGuard.go] /
/// [DemoGuard.open] / [DemoGuard.tap], which return null (no ripple) when blocked.
class DemoGuard extends StatelessWidget {
  const DemoGuard({super.key, this.route, this.action, this.allowed, required this.child})
    : assert(route != null || action != null || allowed != null);

  /// The location the control opens.
  final String? route;

  /// Or the in-screen action it performs.
  final DemoAction? action;

  /// Or an explicit decision (e.g. a row that may or may not lead somewhere allowed).
  final bool? allowed;
  final Widget child;

  static bool allows({String? route, DemoAction? action}) =>
      (route == null || demoCanOpen(route)) && (action == null || demoCanDo(action));

  /// [onTap] when [action] is allowed, null otherwise.
  static VoidCallback? tap(DemoAction action, VoidCallback? onTap) => demoCanDo(action) ? onTap : null;

  /// [onTap] when the screen at [route] is allowed, null otherwise.
  static VoidCallback? open(String route, VoidCallback? onTap) => demoCanOpen(route) ? onTap : null;

  /// A callback that pushes [route], or null when the screen is not allowed.
  static VoidCallback? push(BuildContext context, String route) =>
      demoCanOpen(route) ? () => context.push(route) : null;

  /// A callback that goes to [route], or null when the screen is not allowed.
  static VoidCallback? go(BuildContext context, String route) => demoCanOpen(route) ? () => context.go(route) : null;

  @override
  Widget build(BuildContext context) =>
      (allowed ?? true) && allows(route: route, action: action) ? child : IgnorePointer(child: child);
}
