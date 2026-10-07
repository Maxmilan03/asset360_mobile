import 'package:flutter/widgets.dart';

import '../../app/feature_flags.dart';

/// Keeps a control visible but inert in client demo mode ([kClientDemo]):
/// no navigation, no ripple, no SnackBar. In the full app it changes nothing.
///
/// Wrap a control with `DemoGate(child: …)`, or pass its callback through
/// [DemoGate.tap] when the control has an InkWell that goes quiet without one.
class DemoGate extends StatelessWidget {
  const DemoGate({super.key, required this.child, this.onTap});

  final Widget child;

  /// Optional tap handler for a plain (non-button) [child]; dropped in demo mode.
  final VoidCallback? onTap;

  /// True in the full app; false when gated controls must do nothing.
  static const bool live = !kClientDemo;

  /// [onTap] in the full app, null (= disabled, no ripple) in demo mode.
  static VoidCallback? tap(VoidCallback? onTap) => live ? onTap : null;

  @override
  Widget build(BuildContext context) {
    if (!live) return IgnorePointer(child: child);
    if (onTap == null) return child;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child);
  }
}
