import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/scanning/hht_scanner.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';

export 'package:asset360_mobile/core/scanning/hht_scanner.dart';

/// Marks a text field that accepts scanner input (e.g. Manual Entry): a keyboard-wedge scan
/// while it has focus goes to [onScan] instead of being ignored.
class ScanFieldScope extends StatelessWidget {
  const ScanFieldScope({super.key, required this.onScan, required this.child});

  final ValueChanged<String> onScan;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Listens to the HHT scanner on every signed-in screen (it wraps the shell): broadcast intents
/// (Android) and keyboard-wedge input, per Settings → Scanner. Each read goes through ScanService
/// and is delivered on the current tab's navigator ([navigatorContext]).
class HardwareScanListener extends ConsumerStatefulWidget {
  const HardwareScanListener({super.key, required this.navigatorContext, required this.child});

  final BuildContext? Function() navigatorContext;
  final Widget child;

  @override
  ConsumerState<HardwareScanListener> createState() => _HardwareScanListenerState();
}

class _HardwareScanListenerState extends ConsumerState<HardwareScanListener> {
  final _wedge = KeyboardWedgeDetector();
  StreamSubscription<BroadcastScan>? _broadcast;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _apply(ref.read(scannerSettingsProvider));
    ref.listenManual(scannerSettingsProvider, (_, s) => _apply(s));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _broadcast?.cancel();
    super.dispose();
  }

  void _apply(ScannerSettings s) {
    if (s.broadcast && HhtBroadcast.supported) {
      HhtBroadcast.configure(s);
      _broadcast ??= HhtBroadcast.scans().listen(
        (b) => _deliver(b.data, formatFromLabelType(b.labelType), 'Broadcast'),
        onError: (_) {},
      );
    } else {
      _broadcast?.cancel();
      _broadcast = null;
    }
  }

  bool _onKey(KeyEvent e) {
    if (!ref.read(scannerSettingsProvider).keyboard || e is! KeyDownEvent) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    final scanField = focus?.findAncestorWidgetOfExactType<ScanFieldScope>();
    final typing =
        focus != null && (focus.widget is EditableText || focus.findAncestorWidgetOfExactType<EditableText>() != null);
    if (typing && scanField == null) {
      _wedge.reset();
      return false;
    }
    final at = DateTime.fromMicrosecondsSinceEpoch(e.timeStamp.inMicroseconds);
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _wedge.enter(at);
      if (code == null) return false;
      if (scanField != null) {
        ref.read(lastHardwareReadProvider.notifier).set(code, 'Keyboard');
        scanField.onScan(code);
      } else {
        _deliver(code, 'barcode', 'Keyboard');
      }
      return false;
    }
    final c = e.character;
    if (c != null && c.length == 1 && c.codeUnitAt(0) >= 0x20) _wedge.addChar(c, at);
    return false;
  }

  void _deliver(String value, String format, String via) {
    if (value.trim().isEmpty) return;
    ref.read(lastHardwareReadProvider.notifier).set(value.trim(), via);
    final ctx = widget.navigatorContext();
    if (ctx == null || !ctx.mounted) return;
    handleScanEvent(ctx, ref, ScanEvent(value: value.trim(), format: format, source: ScanSource.hht));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
