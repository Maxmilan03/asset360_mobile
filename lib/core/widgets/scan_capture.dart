import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';

/// Full-screen camera scanner that returns the first code it reads (QR or
/// barcode), or a code typed in by hand. [suggestions] are demo codes shown
/// as chips so the flow also works without a printed tag.
Future<String?> showScanCapture(
  BuildContext context, {
  String title = 'Scan Asset Tag',
  List<String> suggestions = const [],
}) async => (await captureScan(context, title: title, suggestions: suggestions))?.code;

/// A code from [captureScan] and its format (qr, code128, ean13 … or manual).
typedef CapturedCode = ({String code, String format});

/// Like [showScanCapture], with the symbology the camera reported.
Future<CapturedCode?> captureScan(
  BuildContext context, {
  String title = 'Scan Asset Tag',
  List<String> suggestions = const [],
}) {
  // Current tab's navigator: the bottom bar stays visible over the scanner.
  return Navigator.of(context).push<CapturedCode>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ScanCapturePage(title: title, suggestions: suggestions),
    ),
  );
}

/// mobile_scanner format → the ScanLog format name (qr, code128, ean13, datamatrix …).
String barcodeFormatName(BarcodeFormat f) => switch (f) {
  BarcodeFormat.qrCode => 'qr',
  BarcodeFormat.dataMatrix => 'datamatrix',
  BarcodeFormat.unknown || BarcodeFormat.all => 'barcode',
  _ => f.name.toLowerCase(),
};

class _ScanCapturePage extends StatefulWidget {
  const _ScanCapturePage({required this.title, required this.suggestions});

  final String title;
  final List<String> suggestions;

  @override
  State<_ScanCapturePage> createState() => _ScanCapturePageState();
}

class _ScanCapturePageState extends State<_ScanCapturePage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String code, String format) {
    if (_done || code.trim().isEmpty) return;
    _done = true;
    Navigator.pop<CapturedCode>(context, (code: code.trim(), format: format));
  }

  Future<void> _enterManually() async {
    final code = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => const _CodeDialog(),
    );
    if (code != null) _finish(code, 'manual');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: _torch ? 'Torch off' : 'Torch on',
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final b = capture.barcodes.firstOrNull;
                    if (b?.rawValue case final value?) _finish(value, barcodeFormatName(b!.format));
                  },
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Camera is not available (${error.errorCode.name}).\nEnter the code manually below.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, height: 1.5),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.illustration, width: 3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Text(
                    'Point the camera at the QR code or barcode on the asset tag',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.suggestions.isNotEmpty) ...[
                  Text('Demo tags', style: AppText.bodyStrong),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in widget.suggestions)
                        ActionChip(
                          avatar: Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.primary),
                          label: Text(s),
                          onPressed: () => _finish(s, 'qr'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _enterManually,
                    icon: const Icon(Icons.keyboard_alt_outlined),
                    label: const Text('Enter code manually'),
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

/// "Enter code" dialog; owns its controller so it is disposed after the exit animation.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enter code'),
    content: TextField(
      controller: _text,
      autofocus: true,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(hintText: 'Asset ID, serial, tag or barcode'),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(context, _text.text), child: const Text('Find')),
    ],
  );
}
