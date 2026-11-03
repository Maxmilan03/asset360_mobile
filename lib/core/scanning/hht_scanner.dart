import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a handheld terminal's built-in scanner reaches the app.
enum HhtMode {
  auto('Auto', 'Broadcast intents and keyboard input'),
  broadcast('Broadcast', 'Intents sent by the scanner service'),
  keyboard('Keyboard', 'The scanner types the code and presses Enter');

  const HhtMode(this.label, this.description);
  final String label;
  final String description;
}

/// A scanner make with its broadcast intent action and data extra.
class HhtPreset {
  const HhtPreset(this.id, this.label, this.action, this.extraKey, {this.claimHoneywell = false, this.note});

  final String id;
  final String label;
  final String action;
  final String extraKey;

  /// Honeywell: the app claims the scanner (ACTION_CLAIM_SCANNER) and asks it to send data intents to [action].
  final bool claimHoneywell;
  final String? note;

  static const zebra = HhtPreset(
    'zebra',
    'Zebra DataWedge',
    'com.purpleiq.asset360.SCAN',
    'com.symbol.datawedge.data_string',
    note: 'DataWedge profile: Intent output on, action com.purpleiq.asset360.SCAN, delivery Broadcast intent',
  );
  static const honeywell = HhtPreset(
    'honeywell',
    'Honeywell',
    'com.purpleiq.asset360.HONEYWELL_SCAN',
    'data',
    claimHoneywell: true,
    note: 'Claims the scanner with com.honeywell.aidc.action.ACTION_CLAIM_SCANNER (data intent on)',
  );
  static const urovo = HhtPreset('urovo', 'Urovo', 'android.intent.ACTION_DECODE_DATA', 'barcode_string');
  static const custom = HhtPreset('custom', 'Custom', '', '');

  static const all = [zebra, honeywell, urovo, custom];

  static HhtPreset byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => zebra);
}

class ScannerSettings {
  const ScannerSettings({
    this.mode = HhtMode.auto,
    this.presetId = 'zebra',
    this.customAction = '',
    this.customExtra = '',
  });

  final HhtMode mode;
  final String presetId;
  final String customAction;
  final String customExtra;

  HhtPreset get preset => HhtPreset.byId(presetId);
  bool get isCustom => presetId == HhtPreset.custom.id;
  String get action => isCustom ? customAction.trim() : preset.action;
  String get extraKey => isCustom ? customExtra.trim() : preset.extraKey;
  bool get broadcast => mode != HhtMode.keyboard && action.isNotEmpty && extraKey.isNotEmpty;
  bool get keyboard => mode != HhtMode.broadcast;

  ScannerSettings copyWith({HhtMode? mode, String? presetId, String? customAction, String? customExtra}) =>
      ScannerSettings(
        mode: mode ?? this.mode,
        presetId: presetId ?? this.presetId,
        customAction: customAction ?? this.customAction,
        customExtra: customExtra ?? this.customExtra,
      );
}

/// Settings → Scanner, saved in shared_preferences.
class ScannerSettingsNotifier extends Notifier<ScannerSettings> {
  static const _mode = 'hht.mode', _preset = 'hht.preset', _action = 'hht.action', _extra = 'hht.extra';

  @override
  ScannerSettings build() {
    _load();
    return const ScannerSettings();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = ScannerSettings(
        mode: HhtMode.values.asNameMap()[p.getString(_mode)] ?? HhtMode.auto,
        presetId: p.getString(_preset) ?? 'zebra',
        customAction: p.getString(_action) ?? '',
        customExtra: p.getString(_extra) ?? '',
      );
    } catch (_) {
      // No storage (tests): defaults.
    }
  }

  Future<void> update(ScannerSettings s) async {
    state = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_mode, s.mode.name);
      await p.setString(_preset, s.presetId);
      await p.setString(_action, s.customAction);
      await p.setString(_extra, s.customExtra);
    } catch (_) {
      // Kept in memory only.
    }
  }
}

final scannerSettingsProvider = NotifierProvider<ScannerSettingsNotifier, ScannerSettings>(ScannerSettingsNotifier.new);

/// The last value the hardware scanner sent (Settings → Scanner → Test scanner).
typedef HardwareRead = ({String value, String via, DateTime at});

class LastHardwareReadNotifier extends Notifier<HardwareRead?> {
  @override
  HardwareRead? build() => null;

  void set(String value, String via) => state = (value: value, via: via, at: DateTime.now());
}

final lastHardwareReadProvider = NotifierProvider<LastHardwareReadNotifier, HardwareRead?>(
  LastHardwareReadNotifier.new,
);

// ---------------------------------------------------------------- Broadcast mode

/// One broadcast read: the data string and, when the scanner says, the symbology.
typedef BroadcastScan = ({String data, String? labelType});

/// MainActivity.kt registers a BroadcastReceiver for the configured action and streams the extra.
abstract final class HhtBroadcast {
  static const _config = MethodChannel('com.purpleiq.asset360/hht');
  static const _scans = EventChannel('com.purpleiq.asset360/hht/scans');

  /// Only Android terminals send scanner intents.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Sets the intent action / extra the receiver listens for (and claims a Honeywell scanner).
  static Future<void> configure(ScannerSettings s) async {
    if (!supported) return;
    try {
      await _config.invokeMethod('configure', {
        'action': s.action,
        'extra': s.extraKey,
        'claimHoneywell': s.preset.claimHoneywell && !s.isCustom,
      });
    } on PlatformException {
      // Ignored: the receiver keeps its previous configuration.
    } on MissingPluginException {
      // Not on a device.
    }
  }

  static Stream<BroadcastScan> scans() {
    if (!supported) return const Stream.empty();
    return _scans.receiveBroadcastStream().map((e) {
      final m = (e as Map).cast<String, Object?>();
      return (data: (m['data'] as String? ?? '').trim(), labelType: m['labelType'] as String?);
    });
  }
}

/// "LABEL-TYPE-QRCODE" / "QR Code" / "EAN13" → qr / ean13 …
String formatFromLabelType(String? labelType) {
  final t = (labelType ?? '').toLowerCase().replaceAll(RegExp(r'^label-type-'), '').replaceAll(RegExp('[^a-z0-9]'), '');
  if (t.isEmpty) return 'barcode';
  if (t.contains('qr')) return 'qr';
  if (t.contains('datamatrix')) return 'datamatrix';
  if (t.contains('128')) return 'code128';
  if (t.contains('39')) return 'code39';
  if (t.contains('ean13')) return 'ean13';
  if (t.contains('ean8')) return 'ean8';
  if (t.contains('upca')) return 'upca';
  if (t.contains('pdf417')) return 'pdf417';
  return t;
}

// ---------------------------------------------------------------- Keyboard mode

/// Tells a keyboard-wedge scanner from typing: characters less than [gap] apart, ending with
/// Enter, at least [minLength] long, form one scan.
class KeyboardWedgeDetector {
  KeyboardWedgeDetector({this.gap = const Duration(milliseconds: 50), this.minLength = 3});

  final Duration gap;
  final int minLength;
  final _buffer = StringBuffer();
  DateTime? _last;

  /// A printable character arrived at [at].
  void addChar(String char, DateTime at) {
    final last = _last;
    if (last == null || at.difference(last) >= gap) _buffer.clear();
    _buffer.write(char);
    _last = at;
  }

  /// Enter arrived at [at]. Returns the scanned code, or null when it was normal typing.
  String? enter(DateTime at) {
    final last = _last;
    final code = _buffer.toString();
    reset();
    if (last == null || at.difference(last) >= gap) return null;
    return code.trim().length >= minLength ? code.trim() : null;
  }

  void reset() {
    _buffer.clear();
    _last = null;
  }
}
