import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/scan/scan_widgets.dart';

/// Client demo Scan & Identify (left screen of design/05_scan_identify.jpg, QR / barcode only):
/// live camera inside a violet corner frame and a flash toggle. A detected code opens a
/// result sheet: the matching asset from the mock data, or "Tag not registered".
class DemoScanScreen extends ConsumerStatefulWidget {
  const DemoScanScreen({super.key});

  @override
  ConsumerState<DemoScanScreen> createState() => _DemoScanScreenState();
}

class _DemoScanScreenState extends ConsumerState<DemoScanScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _showingResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (_showingResult || code == null || code.isEmpty) return;
    _showingResult = true;
    await _controller.stop();
    if (!mounted) return;
    final asset = ref.read(assetsProvider.notifier).ownerOf(code);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ScanResultSheet(code: code, asset: asset),
    );
    // Any way the sheet closes (Scan Again, swipe, tap outside, back) resumes scanning.
    _showingResult = false;
    if (mounted) await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: PageTitle(title: 'Scan & Identify', subtitle: 'Scan asset tag to instantly view details'),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Camera is not available (${error.errorCode.name}).',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, height: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
                const Center(child: ScanCornerFrame()),
                Positioned(top: 16, right: 16, child: TorchButton(controller: _controller)),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: context.bottomInset + 16,
                  child: const Text(
                    'Point the camera at the QR code or barcode on the asset tag',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13, shadows: [Shadow(blurRadius: 6)]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of one scan: the identified asset, or "Tag not registered".
class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({required this.code, required this.asset});

  final String code;
  final Asset? asset;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a != null) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 26),
                  const SizedBox(width: 10),
                  Text('Asset Identified', style: AppText.sectionTitle),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AssetThumb(imagePath: a.imagePath, size: 84),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.cardTitle.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 3),
                        Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body),
                        const SizedBox(height: 6),
                        IconLine(icon: Icons.location_on_outlined, text: a.location),
                        const SizedBox(height: 8),
                        StatusChip(a.status),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Icon(Icons.qr_code_2_rounded, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 10),
              Text('Tag not registered', textAlign: TextAlign.center, style: AppText.sectionTitle),
              const SizedBox(height: 6),
              Text('No asset in Asset360 matches "$code".', textAlign: TextAlign.center, style: AppText.secondary),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}
