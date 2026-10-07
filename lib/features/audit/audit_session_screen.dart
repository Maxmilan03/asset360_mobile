import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/mock/demo_ids.dart';
import '../../data/models/asset.dart';
import '../../data/models/audit.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/audits_repository.dart';
import '../assets/asset_ui.dart';
import '../common/location_picker.dart';
import '../registration/registration_widgets.dart';
import '../scan/scan_widgets.dart';
import 'audit_widgets.dart';

enum AuditMode { scan, search, manual }

/// Audit session (middle screen of design/15_asset_audit.jpg).
class AuditSessionScreen extends ConsumerStatefulWidget {
  const AuditSessionScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<AuditSessionScreen> createState() => _AuditSessionScreenState();
}

class _AuditSessionScreenState extends ConsumerState<AuditSessionScreen> with WidgetsBindingObserver {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.all]);
  final _manual = TextEditingController();
  AuditMode _mode = AuditMode.scan;
  String _search = '';

  bool _visible = true;
  bool _resumed = true;
  bool _busy = false;
  bool _cameraOn = false;
  Future<void> _cameraOp = Future.value();

  /// Last code the camera saw (the capture button uses it) and the code just handled.
  (String, String)? _lastSeen;
  (String, DateTime)? _cooldown;

  Audit? get _audit => ref.read(auditByIdProvider(widget.id));
  bool get _canScan => _audit?.status == AuditStatus.inProgress;
  bool get _cameraWanted => _mode == AuditMode.scan && _visible && _resumed && !_busy && _canScan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another route covers this one or another tab is showing.
    final visible = TickerMode.of(context);
    if (visible == _visible) return;
    _visible = visible;
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
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _syncCamera() {
    _cameraOp = _cameraOp.then((_) async {
      if (!mounted) return;
      final want = _cameraWanted;
      if (want == _cameraOn) return;
      _cameraOn = want;
      try {
        if (want) {
          await _controller.start();
        } else {
          await _controller.stop();
        }
      } catch (_) {
        // Shown by the scanner's errorBuilder.
      }
    });
  }

  String _methodOf(BarcodeFormat f) => f == BarcodeFormat.qrCode ? AuditMethod.qr : AuditMethod.barcode;

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue?.trim();
    if (barcode == null || code == null || code.isEmpty) return;
    _lastSeen = (code, _methodOf(barcode.format));
    final cool = _cooldown;
    if (cool != null && cool.$1 == code && DateTime.now().difference(cool.$2) < const Duration(seconds: 4)) return;
    _handle(code, _methodOf(barcode.format));
  }

  void _capture() {
    final seen = _lastSeen;
    if (seen == null) {
      context.showSnack('Point the camera at an asset tag, then tap capture');
      return;
    }
    _cooldown = null;
    _handle(seen.$1, seen.$2);
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
    await _handle(code, _methodOf(barcode.format));
  }

  /// A scanned / typed code: known asset → Asset Found, unknown → "Unregistered asset found".
  Future<void> _handle(String code, String method) async {
    if (_busy) return;
    final audit = _audit;
    if (audit == null) return;
    if (!_canScan) {
      context.showSnack(switch (audit.status) {
        AuditStatus.pending => 'Start the audit first',
        AuditStatus.paused => 'The audit is paused. Resume it to scan.',
        _ => 'This audit is completed',
      });
      return;
    }
    setState(() => _busy = true);
    _syncCamera();
    try {
      final asset = ref.read(assetsProvider).byCode(code);
      if (asset == null) {
        await _unregistered(code, method);
      } else {
        await _openAsset(asset, method);
      }
    } finally {
      _cooldown = (code, DateTime.now());
      if (mounted) {
        setState(() => _busy = false);
        _syncCamera();
      }
    }
  }

  Future<void> _openAsset(Asset asset, String method) async {
    final audit = _audit!;
    if (asset.site != audit.site) {
      final ok = await showConfirmDialog(
        context,
        title: 'Outside this audit',
        message: '${asset.id} is registered at ${asset.site}, not ${audit.site}. Audit it here anyway?',
        confirmLabel: 'Audit anyway',
      );
      if (!ok || !mounted) return;
    }
    final prev = audit.entryFor(asset.id);
    if (prev != null) {
      final ok = await showConfirmDialog(
        context,
        title: 'Already ${prev.result.toLowerCase()} at ${auditTime(prev.at)} – re-audit?',
        message: 'Saving again replaces the earlier result for ${asset.id}.',
        confirmLabel: 'Re-audit',
      );
      if (!ok || !mounted) return;
    }
    final saved = await context.push<String>(Routes.auditAsset(audit.id, asset.id, method: method));
    if (saved != null && mounted) context.showSnack('${asset.id} saved as $saved – scan the next asset');
  }

  Future<void> _unregistered(String code, String method) async {
    final audit = _audit!;
    final tag = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UnregisteredSheet(audit: audit, code: code, method: method),
    );
    if (tag == null || !mounted) return;
    final register = await showSuccessSheet(
      context,
      title: 'Unregistered asset recorded',
      message: '$tag was added to ${audit.name} as Unregistered. Register it now so it can be tracked.',
      primaryLabel: 'Register now',
      secondaryLabel: 'Continue Scanning',
    );
    if (!register || !mounted) return;
    final photo = audit.entryFor(tag)?.photos.firstOrNull;
    final rfid = method == AuditMethod.rfid;
    await context.push(
      Routes.newRegistration,
      extra: RegistrationPrefill(
        photo: photo,
        tagId: rfid ? code : null,
        barcode: rfid || code.startsWith('UNREG-') ? null : code.toUpperCase(),
      ),
    );
  }

  Future<void> _complete(Audit a) async {
    final unscanned = unscannedAssets(a, ref.read(assetsProvider));
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Audit?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanned ${formatCount(a.done)} of ${formatCount(a.totalAssets)} assets.', style: AppText.body),
            const SizedBox(height: 8),
            Text(
              a.remaining == 0
                  ? 'Every asset has a result.'
                  : '${formatCount(a.remaining)} unscanned assets will be marked Not Found '
                        '(Not Found ${formatCount(a.notFound)} → ${formatCount(a.notFound + a.remaining)}).',
              style: AppText.body.copyWith(color: a.remaining == 0 ? AppColors.green : AppColors.red),
            ),
            if (a.remaining > 0 && unscanned.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Including ${unscanned.take(5).map((x) => x.id).join(', ')}'
                '${a.remaining > 5 ? ' and ${formatCount(a.remaining - unscanned.take(5).length)} more' : ''}.',
                style: AppText.caption,
              ),
            ],
            const SizedBox(height: 8),
            Text('Results are final once the audit is completed.', style: AppText.caption),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete Audit')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(auditsProvider.notifier).complete(a.id);
    _syncCamera();
    context.showSnack('${a.name} completed');
    context.push(Routes.auditReport(a.id));
  }

  void _start(Audit a) {
    ref.read(auditsProvider.notifier).start(a.id);
    context.showSnack('${a.name} is In Progress – start scanning');
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCamera());
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.watch(auditByIdProvider(widget.id));
    if (a == null) {
      return AppScaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Audit not found',
          message: widget.id,
          actionLabel: 'Back to Asset Audit',
          onAction: () => context.go(Routes.audit),
        ),
      );
    }
    final pct = (a.progress * 100).round();
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            leading: Icon(Icons.photo_camera_outlined, color: AppColors.text, size: 26),
            title: a.name,
            subtitle: '${a.site}  |  ${auditDateRange(a)}',
            trailing: PopupMenuButton<String>(
              tooltip: 'Audit actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) => switch (v) {
                'complete' => _complete(a),
                'report' => context.push(Routes.auditReport(a.id)),
                'pause' => () {
                  ref.read(auditsProvider.notifier).pause(a.id);
                  _syncCamera();
                  context.showSnack('${a.name} paused');
                }(),
                _ => _start(a),
              },
              itemBuilder: (_) => [
                if (a.status != AuditStatus.completed)
                  const PopupMenuItem(value: 'complete', child: Text('Complete Audit')),
                const PopupMenuItem(value: 'report', child: Text('Export Report')),
                if (a.status == AuditStatus.inProgress)
                  const PopupMenuItem(value: 'pause', child: Text('Pause Audit'))
                else if (a.status != AuditStatus.completed)
                  PopupMenuItem(
                    value: 'start',
                    child: Text(a.status == AuditStatus.paused ? 'Resume Audit' : 'Start Audit'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Progress', style: AppText.bodyStrong)),
                    Text(
                      '${formatCount(a.done)} / ${formatCount(a.totalAssets)}',
                      style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(value: a.progress, minHeight: 8, backgroundColor: AppColors.divider),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('$pct%', style: AppText.caption),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, r) in AuditResult.all.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _ResultTile(audit: a, result: r),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (a.status != AuditStatus.inProgress) ...[
            _StatusBanner(audit: a, onStart: () => _start(a)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              for (final (m, icon, label) in [
                (AuditMode.scan, Icons.qr_code_scanner_rounded, 'Scan'),
                (AuditMode.search, Icons.search_rounded, 'Search'),
                (AuditMode.manual, Icons.edit_outlined, 'Manual Entry'),
              ]) ...[
                if (m != AuditMode.scan) const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    icon: icon,
                    label: label,
                    selected: _mode == m,
                    onTap: () {
                      setState(() => _mode = m);
                      _syncCamera();
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          switch (_mode) {
            AuditMode.scan => _scanPane(a),
            AuditMode.search => _searchPane(a),
            AuditMode.manual => _manualPane(),
          },
        ],
      ),
    );
  }

  Widget _scanPane(Audit a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: _canScan
                      ? MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder: (context, error) => _CameraUnavailable(
                            denied: error.errorCode == MobileScannerErrorCode.permissionDenied,
                            onSearch: () => setState(() => _mode = AuditMode.search),
                            onManual: () => setState(() => _mode = AuditMode.manual),
                          ),
                        )
                      : const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 48)),
                ),
                const Align(alignment: Alignment(0, -.3), child: ScanCornerFrame(size: 190)),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TorchButton(controller: _controller),
                      Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 4)),
                        child: IconButton(
                          tooltip: 'Capture',
                          iconSize: 30,
                          padding: const EdgeInsets.all(14),
                          onPressed: _canScan ? _capture : () => _handle('', AuditMethod.qr),
                          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                        ),
                      ),
                      ScanRoundButton(
                        icon: Icons.image_outlined,
                        tooltip: 'Scan from gallery',
                        onPressed: _scanFromGallery,
                      ),
                    ],
                  ),
                ),
                if (kDebugMode)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: ActionChip(
                      avatar: Icon(Icons.bug_report_outlined, size: 16, color: AppColors.primary),
                      label: const Text('Simulate scan'),
                      tooltip: 'Pretend ${DemoIds.auditedAsset} was scanned (debug builds only)',
                      onPressed: () {
                        _cooldown = null;
                        _handle(DemoIds.auditedAsset, AuditMethod.qr);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.blueBg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: AppColors.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Position the QR / Barcode within the frame', style: AppText.bodyStrong),
                    Text('Scan to verify asset and update status', style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchPane(Audit a) {
    final q = _search.trim().toLowerCase();
    final scope = auditScope(a, ref.watch(assetsProvider));
    final rows = scope
        .where(
          (x) =>
              q.isEmpty ||
              x.id.toLowerCase().contains(q) ||
              x.name.toLowerCase().contains(q) ||
              x.location.toLowerCase().contains(q),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search assets in this audit by ID, name or location',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 10),
        LoadingGate(
          rows: 3,
          child: AppCard(
            padding: EdgeInsets.zero,
            child: rows.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No assets match',
                    message: 'Not in the register? Record it with Manual Entry.',
                    actionLabel: 'Manual Entry',
                    onAction: () => setState(() {
                      _manual.text = _search.trim();
                      _mode = AuditMode.manual;
                    }),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
                        _ScopeRow(
                          asset: rows[i],
                          entry: a.entryFor(rows[i].id),
                          onTap: () => _handle(rows[i].id, AuditMethod.search),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Showing ${rows.length} of ${formatCount(a.totalAssets)} (sample records)',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _manualPane() {
    void find() {
      final code = _manual.text.trim();
      if (code.isEmpty) {
        context.showSnack('Enter an asset ID, tag, barcode or serial number');
        return;
      }
      FocusScope.of(context).unfocus();
      _handle(code, AuditMethod.manual);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Asset ID, tag, barcode or serial number'),
          TextField(
            controller: _manual,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'e.g. GEN-00045'),
            onSubmitted: (_) => find(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: find, icon: const Icon(Icons.search_rounded), label: const Text('Find Asset')),
          const SizedBox(height: 6),
          Text(
            'An ID that is not in the register is recorded as an Unregistered asset.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.audit, required this.result});

  final Audit audit;
  final String result;

  @override
  Widget build(BuildContext context) {
    final look = auditResultLook(result);
    return Material(
      color: look.tone.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(Routes.auditResults(audit.id, result)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(look.icon, color: look.color, size: 24),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCount(audit.count(result)),
                  style: AppText.kpiNumber.copyWith(fontSize: 17, color: look.color),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(result, maxLines: 1, style: AppText.caption.copyWith(color: AppColors.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tileLavender : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.text),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppText.bodyStrong.copyWith(
                      fontSize: 13,
                      color: selected ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.audit, required this.onStart});

  final Audit audit;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final a = audit;
    final completed = a.status == AuditStatus.completed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? AppColors.greenBg : AppColors.amberBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.verified_rounded : Icons.pause_circle_rounded,
            color: completed ? AppColors.green : AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(switch (a.status) {
              AuditStatus.pending => 'This audit has not started. Start it to scan assets.',
              AuditStatus.paused => 'This audit is paused. Resume it to continue scanning.',
              _ => 'Completed${a.completedAt == null ? '' : ' on ${auditTime(a.completedAt!)}'}. Results are final.',
            }, style: AppText.body),
          ),
          const SizedBox(width: 8),
          if (completed)
            OutlinedButton(onPressed: () => context.push(Routes.auditReport(a.id)), child: const Text('View Report'))
          else
            FilledButton(
              onPressed: onStart,
              child: Text(a.status == AuditStatus.paused ? 'Resume Audit' : 'Start Audit'),
            ),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.asset, required this.entry, required this.onTap});

  final Asset asset;
  final AuditEntry? entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: AssetThumb(imagePath: asset.imagePath, fallbackIcon: assetIcon(asset), size: 44),
      title: Text(asset.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
      subtitle: Text(
        '${asset.name}\n${asset.location}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption,
      ),
      isThreeLine: true,
      trailing: entry == null
          ? Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary)
          : StatusChip(entry!.result),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.denied, required this.onSearch, required this.onManual});

  final bool denied;
  final VoidCallback onSearch;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(denied ? Icons.no_photography_outlined : Icons.videocam_off_outlined, color: Colors.white70, size: 36),
            const SizedBox(height: 8),
            Text(
              denied ? 'Camera access is off. Allow it in Settings.' : 'The camera is not available.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onSearch,
                  child: const Text('Search'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: onManual,
                  child: const Text('Manual Entry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Unregistered asset found": photo, description, location. Pops the temporary tag when saved.
class _UnregisteredSheet extends ConsumerStatefulWidget {
  const _UnregisteredSheet({required this.audit, required this.code, required this.method});

  final Audit audit;
  final String code;
  final String method;

  @override
  ConsumerState<_UnregisteredSheet> createState() => _UnregisteredSheetState();
}

class _UnregisteredSheetState extends ConsumerState<_UnregisteredSheet> {
  final _description = TextEditingController();
  final _photos = <String>[];
  String? _location;
  bool _submitted = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _submitted = true);
    if (_description.text.trim().isEmpty || _location == null) return;
    final tag = ref
        .read(auditsProvider.notifier)
        .recordUnregistered(
          widget.audit.id,
          code: widget.code.toUpperCase(),
          description: _description.text.trim(),
          location: _location,
          photos: List.of(_photos),
          method: widget.method,
        );
    Navigator.pop(context, tag);
  }

  @override
  Widget build(BuildContext context) {
    return sheetFrame(context, [
      SheetTitle(
        'Unregistered asset found',
        subtitle: widget.code.isEmpty
            ? 'No tag – it will get a temporary audit tag'
            : '${widget.code} is not in the asset register',
      ),
      PhotoStrip(
        photos: _photos,
        addLabel: 'Capture Photo',
        onAdd: (p) => setState(() => _photos.add(p)),
        onRemove: (i) => setState(() => _photos.removeAt(i)),
      ),
      const SizedBox(height: 12),
      const FieldLabel('Description', required: true),
      TextField(
        controller: _description,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'What is it? e.g. Portable welding set',
          errorText: _submitted && _description.text.trim().isEmpty ? 'Describe the asset' : null,
        ),
      ),
      const SizedBox(height: 12),
      const FieldLabel('Location', required: true),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final l = await showLocationPicker(context, site: widget.audit.site, selected: _location);
          if (l != null) setState(() => _location = l);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            suffixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
            errorText: _submitted && _location == null ? 'Select where it was found' : null,
          ),
          child: Text(_location ?? 'Select location', style: _location == null ? hintStyle : AppText.body),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(onPressed: _save, child: const Text('Save as Unregistered')),
          ),
        ],
      ),
    ]);
  }
}
