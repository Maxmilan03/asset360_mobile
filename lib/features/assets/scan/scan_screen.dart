import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/mock/demo_ids.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/scans_repository.dart';
import 'package:asset360_mobile/data/repositories/settings_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';
import 'package:asset360_mobile/features/more/tracking/tracking_widgets.dart';
import 'package:asset360_mobile/features/assets/scan/scan_flow.dart';
import 'package:asset360_mobile/features/assets/scan/scan_widgets.dart';

enum ScanMode {
  qr('QR / Barcode', Icons.qr_code_scanner_rounded),
  nfc('NFC', Icons.nfc_rounded),
  rfid('RFID', Icons.sensors_rounded),
  ble('BLE', Icons.bluetooth_rounded);

  const ScanMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// NFC (real) / RFID (simulated) read: hold → read → (opened) idle.
enum _TagRead { reading, read, idle }

/// Scan & Identify (left screen of design/05_scan_identify.jpg): QR / Barcode with the live
/// camera, real NFC reads (nfc_manager), simulated RFID reads and BLE beacon search. Manual Entry
/// and Multi Scan work in every mode. Camera, NFC, Manual Entry and HHT reads go through
/// ScanService (saved in Local Data); while visible the screen is the scan target for the HHT.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  /// How long the simulated RFID read takes.
  static const tagReadTime = Duration(seconds: 2);

  /// How long the simulated BLE search takes to list every nearby beacon.
  static const bleSearchTime = Duration(seconds: 3);

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.all]);
  final _random = Random();
  ScanMode _mode = ScanMode.qr;

  // Camera runs only while this screen is visible, the app is in front and nothing covers it.
  bool _visible = true;
  bool _resumed = true;
  bool _busy = false;
  Future<void> _cameraOp = Future.value();

  /// Last code the camera saw (Tap to Scan uses it) and the code just handled (not re-opened at once).
  (String, DateTime)? _lastSeen;
  BarcodeFormat _lastFormat = BarcodeFormat.qrCode;
  (String, DateTime)? _cooldown;
  bool _seeking = false;
  Timer? _seekTimer;

  // NFC / RFID
  _TagRead _tagRead = _TagRead.idle;
  String? _tagCode;
  String? _tagUid;
  int _tagRecords = 0;
  NfcState? _nfcState;
  Timer? _tagTimer;
  late final NfcReader _nfc;
  late final _target = ScanTarget(accepts: ScanTarget.all, onScan: _onResult, debugLabel: 'Scan screen');

  // BLE
  int _bleFound = 0;
  Timer? _bleTimer;

  // Multi Scan
  bool _multi = false;
  final List<String> _batch = [];

  bool get _cameraWanted => _mode == ScanMode.qr && _visible && _resumed && !_busy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nfc = ref.read(nfcReaderProvider);
    // Settings → Scanning → Default scan mode.
    final start = ScanMode.values.byName(ref.read(appSettingsProvider).scanMode.name);
    if (start != ScanMode.qr) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _setMode(start) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another route covers this one or another tab is showing.
    final visible = TickerMode.of(context);
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) _stopSimulations();
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSimulations();
    _seekTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Starts or stops the camera to match [_cameraWanted]; calls run one after another.
  void _syncCamera() {
    _cameraOp = _cameraOp.then((_) async {
      if (!mounted) return;
      try {
        if (_cameraWanted) {
          await _controller.start();
        } else {
          await _controller.stop();
        }
      } catch (_) {
        // Shown by the scanner's errorBuilder (permission denied, no camera …).
      }
    });
  }

  void _stopSimulations() {
    _tagTimer?.cancel();
    _bleTimer?.cancel();
    if (_mode == ScanMode.nfc && _tagRead == _TagRead.reading) _nfc.cancel();
    if (_tagRead != _TagRead.idle) _tagRead = _TagRead.idle;
  }

  // ---------------------------------------------------------------- Mode switching

  void _setMode(ScanMode mode) {
    if (mode == _mode) return;
    _stopSimulations();
    _endSeek();
    setState(() => _mode = mode);
    switch (mode) {
      case ScanMode.qr:
        break; // The MobileScanner widget starts the camera when it is built.
      case ScanMode.nfc:
        _checkNfc();
      case ScanMode.rfid:
        // API mode: the reader is asked for on Tap to Read (no mock tags to simulate).
        if (!apiMode) _startTagRead();
      case ScanMode.ble:
        _startBleSearch();
    }
  }

  // ---------------------------------------------------------------- Handling a code

  /// Saves [e] through ScanService and opens (or, in Multi Scan, collects) the result.
  Future<void> _handle(ScanEvent e) async {
    if (_busy || e.value.trim().isEmpty) return;
    _endSeek();
    final r = await ref.read(scanServiceProvider).submit(e);
    if (r == null || !mounted) return;
    scanFeedback(ref, recognised: r.isKnown);
    await _onResult(r);
  }

  /// RFID / BLE are simulated: matched like any code, but not saved in Local Data.
  Future<void> _handleSimulated(String code, String method) async {
    if (_busy || code.trim().isEmpty) return;
    final r = await ref
        .read(scanServiceProvider)
        .resolve(ScanEvent(value: code.trim(), format: method.toLowerCase(), source: ScanSource.manual));
    if (!mounted) return;
    scanFeedback(ref, recognised: r.isKnown);
    await _onResult(r, method: method);
  }

  /// A result from this screen or from the HHT trigger while this screen is showing.
  Future<void> _onResult(ScanResult r, {String? method}) async {
    if (_busy || !mounted) return;
    _endSeek();
    if (_multi) return _collect(r, method ?? ScanMethod.of(r.event));
    setState(() => _busy = true);
    _syncCamera();
    await openScanFromScanScreen(context, ref, r, method: method);
    if (!mounted) return;
    _cooldown = (r.event.value, DateTime.now());
    setState(() {
      _busy = false;
      if (_tagRead == _TagRead.read) _tagRead = _TagRead.idle;
    });
    _syncCamera();
  }

  /// Multi Scan: each asset is added once to the counter list (and to Scan History).
  void _collect(ScanResult r, String method) {
    if (!r.isKnown) {
      context.showSnack('"${r.event.value}" is not registered – skipped');
      return;
    }
    if (r.matchType != MatchType.asset) {
      context.showSnack('${r.matchLabel} is not an asset – Multi Scan collects assets only');
      return;
    }
    final id = r.matchId!;
    if (_batch.contains(id)) return;
    ref.read(scanHistoryProvider.notifier).add(ScanKind.asset, id, method: method, label: r.matchLabel);
    HapticFeedback.lightImpact();
    setState(() => _batch.add(id));
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue?.trim();
    if (barcode == null || code == null || code.isEmpty) return;
    final now = DateTime.now();
    _lastSeen = (code, now);
    _lastFormat = barcode.format;
    // The code that was just opened stays in view when the user comes back: ignore it for a few
    // seconds (Tap to Scan opens it again straight away).
    final cool = _cooldown;
    if (!_seeking && cool != null && cool.$1 == code && now.difference(cool.$2) < const Duration(seconds: 4)) return;
    if (_multi && _batch.isNotEmpty && ref.read(scanHistoryProvider.notifier).resolve(code)?.refId == _batch.last) {
      return;
    }
    _handle(_cameraEvent(code, barcode.format));
  }

  ScanEvent _cameraEvent(String code, BarcodeFormat f) =>
      ScanEvent(value: code, format: barcodeFormatName(f), source: ScanSource.camera);

  /// Tap to Scan: opens the code in view now, or waits up to 3 s for one.
  void _tapToScan() {
    final seen = _lastSeen;
    if (seen != null && DateTime.now().difference(seen.$2) < const Duration(milliseconds: 1500)) {
      _cooldown = null;
      _handle(_cameraEvent(seen.$1, _lastFormat));
      return;
    }
    if (!_controller.value.isRunning) {
      context.showSnack('Camera is not running. Use Manual Entry or allow camera access.');
      return;
    }
    setState(() => _seeking = true);
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_seeking) return;
      _endSeek();
      context.showSnack('No code found. Hold the tag steady inside the frame.');
    });
  }

  void _endSeek() {
    _seekTimer?.cancel();
    if (_seeking && mounted) setState(() => _seeking = false);
  }

  Future<void> _scanFromGallery() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (mounted) context.showSnack('Gallery is not available. Allow photo access in Settings.');
      return;
    }
    if (file == null || !mounted) return;
    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(file.path);
    } catch (_) {
      capture = null;
    }
    if (!mounted) return;
    final barcode = capture?.barcodes.firstOrNull;
    final code = barcode?.rawValue?.trim();
    if (barcode == null || code == null || code.isEmpty) {
      context.showSnack('No QR code or barcode found in that image');
      return;
    }
    _cooldown = null;
    await _handle(_cameraEvent(code, barcode.format));
  }

  // ---------------------------------------------------------------- NFC

  Future<void> _checkNfc() async {
    final st = await _nfc.availability();
    if (mounted) setState(() => _nfcState = st);
  }

  /// Tap to Read: one real NFC session; any tag (blank tags give their UID).
  Future<void> _startNfcRead() async {
    final st = await _nfc.availability();
    if (!mounted || _mode != ScanMode.nfc) return;
    setState(() => _nfcState = st);
    if (st == NfcState.unsupported) {
      context.showSnack('This device has no NFC reader. Use the camera or Manual Entry.');
      return;
    }
    if (st == NfcState.disabled) {
      await showNfcOffDialog(context);
      return;
    }
    setState(() {
      _tagRead = _TagRead.reading;
      _tagCode = _tagUid = null;
    });
    try {
      final e = await _nfc.readOnce();
      if (!mounted || _mode != ScanMode.nfc) return;
      HapticFeedback.selectionClick();
      setState(() {
        _tagRead = _TagRead.read;
        _tagCode = e.value;
        _tagUid = e.nfcUid;
        _tagRecords = e.nfcRecords?.length ?? 0;
      });
      await _handle(e);
      if (mounted && _tagRead == _TagRead.read) setState(() => _tagRead = _TagRead.idle);
      // Multi Scan keeps reading tags until Done.
      if (mounted && _multi && _mode == ScanMode.nfc && _visible) _startNfcRead();
    } on NfcReadException catch (x) {
      if (!mounted) return;
      setState(() => _tagRead = _TagRead.idle);
      switch (x.failure) {
        case NfcFailure.timeout:
          context.showSnack('No NFC tag found. Tap to Read and hold the phone on the tag.');
        case NfcFailure.disabled:
          await showNfcOffDialog(context);
        case NfcFailure.unsupported:
          context.showSnack('This device has no NFC reader.');
        case NfcFailure.error:
          context.showSnack('Could not read the tag. Try again.');
        case NfcFailure.cancelled:
          break;
      }
    }
  }

  // ---------------------------------------------------------------- RFID (simulated)

  void _startTagRead() {
    if (apiMode) {
      _readRfidLive();
      return;
    }
    final assets = ref.read(assetsProvider);
    final tagged = assets.where((a) => a.tagId != null).toList();
    final pool = tagged.isEmpty ? assets : tagged;
    if (pool.isEmpty) return;
    final asset = pool[_random.nextInt(pool.length)];
    _tagTimer?.cancel();
    setState(() {
      _tagRead = _TagRead.reading;
      _tagCode = asset.tagId ?? asset.id;
    });
    _tagTimer = Timer(ScanScreen.tagReadTime, () {
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _tagRead = _TagRead.read);
      _tagTimer = Timer(const Duration(milliseconds: 700), () async {
        if (!mounted) return;
        await _handleSimulated(_tagCode!, ScanMethod.rfid);
        // Multi Scan keeps reading tags until Done.
        if (mounted && _multi && _mode == ScanMode.rfid && _visible) _startTagRead();
      });
    });
  }

  /// API mode: the RFID reader's tag ID (typed or from a keyboard-wedge reader) is looked up as
  /// rfidTagId (GET …/lookup?type=rfid).
  Future<void> _readRfidLive() async {
    final code = await showManualEntrySheet(context, rfid: true);
    if (code == null || !mounted) return;
    await _handleSimulated(code, ScanMethod.rfid);
    if (mounted && _multi && _mode == ScanMode.rfid && _visible) _startTagRead();
  }

  // ---------------------------------------------------------------- BLE

  void _startBleSearch() {
    if (apiMode) {
      showNotAvailableYet(context, 'BLE beacon search');
      return;
    }
    final total = ref.read(nearbyBeaconsProvider).length;
    _bleTimer?.cancel();
    setState(() => _bleFound = 0);
    if (total == 0) return;
    final step = ScanScreen.bleSearchTime ~/ total;
    _bleTimer = Timer.periodic(step, (t) {
      if (!mounted) return t.cancel();
      setState(() => _bleFound++);
      if (_bleFound >= total) t.cancel();
    });
  }

  // ---------------------------------------------------------------- Bottom buttons

  Future<void> _manualEntry() async {
    final code = await showManualEntrySheet(context);
    if (code != null && mounted) {
      await _handle(ScanEvent(value: code, format: 'manual', source: ScanSource.manual));
    }
  }

  void _toggleMulti() {
    if (_multi) {
      _finishMulti();
      return;
    }
    setState(() => _multi = true);
    if (_mode == ScanMode.nfc && _tagRead == _TagRead.idle) _startNfcRead();
    if (_mode == ScanMode.rfid && _tagRead == _TagRead.idle) _startTagRead();
  }

  Future<void> _finishMulti() async {
    if (_batch.isEmpty) {
      setState(() => _multi = false);
      context.showSnack('Multi Scan off');
      return;
    }
    _stopSimulations();
    setState(() => _busy = true);
    _syncCamera();
    final done = await showMultiScanSummary(context, ref, List.of(_batch));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (done) {
        _batch.clear();
        _multi = false;
      }
    });
    _syncCamera();
  }

  void _onShutter() {
    switch (_mode) {
      case ScanMode.qr:
        _tapToScan();
      case ScanMode.nfc:
        if (_tagRead == _TagRead.idle) _startNfcRead();
      case ScanMode.rfid:
        if (_tagRead == _TagRead.idle) _startTagRead();
      case ScanMode.ble:
        _startBleSearch();
    }
  }

  String get _shutterLabel => switch (_mode) {
    ScanMode.qr => _seeking ? 'Scanning…' : 'Tap to Scan',
    ScanMode.nfc || ScanMode.rfid => _tagRead == _TagRead.idle ? 'Tap to Read' : 'Reading…',
    ScanMode.ble => 'Rescan',
  };

  // ---------------------------------------------------------------- Build

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(scanHistoryProvider);
    return AppScaffold(
      backgroundColor: Colors.white,
      body: ScanTargetScope(
        target: _target,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: PageTitle(
                title: 'Scan & Identify',
                subtitle: 'Scan asset tag to instantly view details',
                trailing: DemoGuard(
                  route: Routes.scanHistoryFrom(Routes.home),
                  child: IconButton(
                    tooltip: 'Scan History (${history.length})',
                    onPressed: () => context.push(Routes.scanHistoryFrom(GoRouterState.of(context).uri.path)),
                    icon: Badge(
                      isLabelVisible: history.isNotEmpty,
                      backgroundColor: AppColors.primary,
                      label: Text('${history.length}'),
                      child: Icon(Icons.history_rounded, color: AppColors.text),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 8), child: LocalDataBadge()),
            _ModeTabs(selected: _mode, onChanged: _setMode),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  switch (_mode) {
                    ScanMode.qr => _cameraView(),
                    ScanMode.nfc || ScanMode.rfid => _TagReadPane(
                      mode: _mode,
                      state: _tagRead,
                      code: _tagCode,
                      uid: _tagUid,
                      records: _tagRecords,
                      nfcState: _nfcState,
                    ),
                    ScanMode.ble => _BlePane(found: _bleFound, onTap: (a) => _handleSimulated(a.id, ScanMethod.ble)),
                  },
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: context.bottomInset + 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_multi) ...[
                          _MultiScanStrip(
                            ids: _batch,
                            onRemove: (id) => setState(() => _batch.remove(id)),
                            onDone: _finishMulti,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: DemoGuard(
                                action: DemoAction.scanManualEntry,
                                child: ScanSideButton(
                                  icon: Icons.keyboard_alt_outlined,
                                  label: 'Manual Entry',
                                  onTap: _manualEntry,
                                ),
                              ),
                            ),
                            Flexible(
                              child: DemoGuard(
                                action: DemoAction.scanTap,
                                child: ScanShutterButton(
                                  label: _shutterLabel,
                                  icon: _mode.icon,
                                  busy: _seeking,
                                  onTap: _onShutter,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 22),
                              child: DemoGuard(
                                action: DemoAction.scanMultiScan,
                                child: ScanSideButton(
                                  icon: _multi ? Icons.done_all_rounded : Icons.library_add_check_outlined,
                                  label: _multi ? 'Done' : 'Multi Scan',
                                  active: _multi,
                                  onTap: _toggleMulti,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(
              error: error,
              onRetry: () {
                _syncCamera();
                setState(() {});
              },
              onManualEntry: _manualEntry,
            ),
          ),
        ),
        Align(
          alignment: const Alignment(0, -.35),
          child: ScanCornerFrame(size: _seeking ? 236 : 250),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              DemoGuard(
                action: DemoAction.scanFlash,
                child: TorchButton(controller: _controller),
              ),
              const SizedBox(height: 14),
              DemoGuard(
                action: DemoAction.scanGallery,
                child: ScanRoundButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Scan from gallery',
                  onPressed: _scanFromGallery,
                ),
              ),
            ],
          ),
        ),
        // API mode: no mock asset to pretend-scan.
        if (kDebugMode && !apiMode)
          Positioned(
            top: 16,
            left: 16,
            child: ActionChip(
              avatar: Icon(Icons.bug_report_outlined, size: 16, color: AppColors.primary),
              label: const Text('Simulate scan'),
              tooltip: 'Pretend ${DemoIds.scannedAsset} was scanned (debug builds only)',
              onPressed: () {
                _cooldown = null;
                _handle(const ScanEvent(value: DemoIds.scannedAsset, format: 'qr', source: ScanSource.camera));
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Tabs

/// QR / Barcode | NFC | RFID | BLE: icon over label, violet underline on the active tab.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.selected, required this.onChanged});

  final ScanMode selected;
  final ValueChanged<ScanMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in ScanMode.values)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(m),
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: m == selected ? AppColors.primary : Colors.transparent, width: 2.5),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(m.icon, size: 22, color: m == selected ? AppColors.primary : AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: m == selected ? FontWeight.w600 : FontWeight.w500,
                        color: m == selected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    // RFID and BLE are simulated.
                    Text(
                      m == ScanMode.rfid || m == ScanMode.ble ? 'Demo' : '',
                      style: TextStyle(fontSize: 10, height: 1.2, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Camera error

/// Friendly camera error: permission denied → Open Settings; other errors → Manual Entry.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry, required this.onManualEntry});

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 56, 28, 180 + context.bottomInset),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(
                denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              denied ? 'Camera access is off' : 'Camera is not available',
              textAlign: TextAlign.center,
              style: AppText.sectionTitle.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              denied
                  ? 'Asset360 needs the camera to read QR codes and barcodes on asset tags. '
                        'Allow camera access in Settings, then come back here.'
                  : 'The camera could not start (${error.errorCode.name}). '
                        'You can still type the asset ID with Manual Entry.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onDarkMuted, height: 1.5),
            ),
            const SizedBox(height: 22),
            if (denied)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                onPressed: () async {
                  final ok = await AppLauncher.openAppSettings();
                  if (!ok && context.mounted) {
                    context.showSnack('Open Settings → Apps → Asset360 → Permissions and allow Camera');
                  }
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Settings'),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Enter ID manually'),
              ),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- NFC / RFID

class _TagReadPane extends StatelessWidget {
  const _TagReadPane({
    required this.mode,
    required this.state,
    required this.code,
    this.uid,
    this.records = 0,
    this.nfcState,
  });

  final ScanMode mode;
  final _TagRead state;
  final String? code;
  final String? uid;
  final int records;
  final NfcState? nfcState;

  @override
  Widget build(BuildContext context) {
    final nfc = mode == ScanMode.nfc;
    final (title, message) = switch (state) {
      _TagRead.reading => (
        'Hold your phone near the tag',
        nfc
            ? 'Keep the back of the phone within 4 cm of the NFC tag'
            : 'Point the phone at the RFID tag, up to 1 m away',
      ),
      _TagRead.read => (
        'Tag read',
        [
          code ?? '',
          if (uid != null) 'UID $uid',
          if (uid != null) records == 0 ? 'No NDEF records' : '$records NDEF record${records == 1 ? '' : 's'}',
        ].join('\n'),
      ),
      _TagRead.idle when nfc && nfcState == NfcState.unsupported => (
        'NFC not available',
        'This device has no NFC reader. Use the camera or Manual Entry.',
      ),
      _TagRead.idle when nfc && nfcState == NfcState.disabled => (
        'NFC is turned off',
        'Tap to Read to turn on NFC in the system settings',
      ),
      _TagRead.idle => ('Ready to read', 'Tap to Read, then hold your phone near the ${nfc ? 'NFC' : 'RFID'} tag'),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      // Small phones: the rings shrink so the text clears the buttons below.
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: const Alignment(0, -.45),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: (box.maxHeight * .4).clamp(96, 180).toDouble(),
                  child: state == _TagRead.read
                      ? Icon(Icons.check_circle_rounded, size: 96, color: AppColors.greenBg)
                      : PulseRings(
                          icon: mode.icon,
                          size: (box.maxHeight * .4).clamp(96, 180).toDouble(),
                          active: state == _TagRead.reading,
                          color: AppColors.illustration,
                        ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppText.sectionTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: state == _TagRead.read ? Colors.white : AppColors.onDarkMuted,
                    fontWeight: state == _TagRead.read ? FontWeight.w600 : FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- BLE

class _BlePane extends ConsumerWidget {
  const _BlePane({required this.found, required this.onTap});

  final int found;
  final ValueChanged<Asset> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (apiMode) {
      return DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 150 + context.bottomInset),
          children: const [
            AppCard(
              child: NotAvailableYet(feature: 'BLE beacon search', icon: Icons.bluetooth_disabled_rounded),
            ),
          ],
        ),
      );
    }
    final beacons = ref.watch(nearbyBeaconsProvider);
    final shown = beacons.take(found).toList();
    final searching = found < beacons.length;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 150 + context.bottomInset),
        children: [
          Row(
            children: [
              if (searching)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else
                const Icon(Icons.bluetooth_searching_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  searching
                      ? 'Searching nearby beacons…'
                      : '${beacons.length} beacon${beacons.length == 1 ? '' : 's'} found nearby',
                  style: AppText.bodyStrong.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Strongest signal first. Tap an asset to identify it.',
            style: TextStyle(color: AppColors.onDarkMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (!searching && beacons.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.bluetooth_disabled_rounded,
                title: 'No beacons nearby',
                message: 'Move closer to the assets and tap Rescan.',
              ),
            ),
          for (final (a, b) in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => onTap(a),
                child: Row(
                  children: [
                    AssetThumb(imagePath: a.imagePath, fallbackIcon: assetIcon(a), size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle.copyWith(fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SignalBars(rssi: b.rssi, height: 14),
                        const SizedBox(height: 4),
                        Text(
                          '${b.rssi} dBm · ~${b.distanceM.toStringAsFixed(1)} m',
                          style: AppText.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Multi Scan strip

/// White card above the buttons in Multi Scan: the counter, the scanned IDs and Done.
class _MultiScanStrip extends StatelessWidget {
  const _MultiScanStrip({required this.ids, required this.onRemove, required this.onDone});

  final List<String> ids;
  final ValueChanged<String> onRemove;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Text(
                '${ids.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ids.isEmpty
                  ? Text('Multi Scan: scan tags one after another', style: AppText.secondary)
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        children: [
                          for (final id in ids)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InputChip(
                                label: Text(id, style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                                onDeleted: () => onRemove(id),
                                deleteButtonTooltipMessage: 'Remove $id',
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            TextButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
