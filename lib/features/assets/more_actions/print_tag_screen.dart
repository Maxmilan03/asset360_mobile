import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/features/assets/more_actions/more_action_widgets.dart';

/// Tag type, live preview, printer and copies → a PDF label in the system print dialog
/// (or a simulated Zebra label printer).
class PrintTagScreen extends ConsumerStatefulWidget {
  const PrintTagScreen({super.key, required this.assetId});

  final String? assetId;

  /// Tests replace the system print dialog (bytes = the generated PDF). Returns true when printed.
  @visibleForTesting
  static Future<bool> Function(Uint8List pdf, String name)? debugLayoutPdf;

  @override
  ConsumerState<PrintTagScreen> createState() => _PrintTagScreenState();
}

class _PrintTagScreenState extends ConsumerState<PrintTagScreen> {
  String _type = tagTypes.first;
  String _printer = labelPrinters.first;
  int _copies = 1;
  bool _busy = false;

  Future<void> _print(Asset a) async {
    final labels = '$_copies label${_copies == 1 ? '' : 's'}';
    if (_printer == zebraPrinter) {
      ref.read(assetsProvider.notifier).addEvent(a.id, 'Asset tag printed', note: '$labels · $_type · $_printer');
      finishAction(context, 'Sent $labels to $_printer');
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await buildTagPdf(a, type: _type, copies: _copies);
      final name = 'Asset_Tag_${a.id}';
      final printed = PrintTagScreen.debugLayoutPdf != null
          ? await PrintTagScreen.debugLayoutPdf!(bytes, name)
          : await Printing.layoutPdf(name: name, format: tagPageFormat(_type), onLayout: (_) async => bytes);
      if (!mounted) return;
      if (printed) {
        ref.read(assetsProvider.notifier).addEvent(a.id, 'Asset tag printed', note: '$labels · $_type · $_printer');
        finishAction(context, 'Printed $labels for ${a.id}');
      } else {
        context.showSnack('Printing cancelled');
      }
    } catch (_) {
      if (mounted) context.showSnack('Printing is not available on this device');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MoreActionPage(
      action: MoreAction.printTag,
      assetId: widget.assetId,
      button: (a) => FilledButton.icon(
        onPressed: _busy ? null : () => _print(a),
        icon: _busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.print_rounded),
        label: const Text('Print'),
      ),
      builder: (context, a) => [
        formField(
          'Tag Type',
          SelectField(value: _type, options: tagTypes, onChanged: (v) => setState(() => _type = v)),
        ),
        SectionCard(
          title: 'Live Preview',
          child: Center(child: TagPreview(asset: a, type: _type)),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Print Options',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              formField(
                'Printer',
                SelectField(value: _printer, options: labelPrinters, onChanged: (v) => setState(() => _printer = v)),
              ),
              Row(
                children: [
                  Expanded(child: Text('Copies', style: AppText.bodyStrong)),
                  IconButton(
                    tooltip: 'Fewer copies',
                    onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('$_copies', textAlign: TextAlign.center, style: AppText.bodyStrong),
                  ),
                  IconButton(
                    tooltip: 'More copies',
                    onPressed: _copies < maxTagCopies ? () => setState(() => _copies++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// On-screen label preview; matches [buildTagPdf] for each tag type.
class TagPreview extends StatelessWidget {
  const TagPreview({super.key, required this.asset, required this.type});

  final Asset asset;
  final String type;

  @override
  Widget build(BuildContext context) {
    final a = asset;
    final code = a.barcode ?? a.id;
    final box = BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    );
    const ink = TextStyle(color: Colors.black);
    return switch (type) {
      'Small Label' => Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        decoration: box,
        child: Row(
          children: [
            QrCode(data: a.id, size: 64),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.id, style: ink.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Code39Barcode(data: code, height: 26),
                ],
              ),
            ),
          ],
        ),
      ),
      'QR Only' => Container(
        padding: const EdgeInsets.all(10),
        decoration: box,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrCode(data: a.id, size: 110),
            const SizedBox(height: 4),
            Text(a.id, style: ink.copyWith(fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
      _ => Container(
        padding: const EdgeInsets.all(10),
        decoration: box,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/logo_on_light.webp', height: 22),
                  const SizedBox(height: 6),
                  Text(a.id, style: ink.copyWith(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ink.copyWith(fontSize: 11)),
                  Text(
                    a.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink.copyWith(fontSize: 10, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Code39Barcode(data: code, height: 30),
                ],
              ),
            ),
            const SizedBox(width: 10),
            QrCode(data: a.id, size: 84),
          ],
        ),
      ),
    };
  }
}

/// Label size for a tag type.
PdfPageFormat tagPageFormat(String type) => switch (type) {
  'Small Label' => const PdfPageFormat(50 * PdfPageFormat.mm, 25 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm),
  'QR Only' => const PdfPageFormat(40 * PdfPageFormat.mm, 40 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
  _ => const PdfPageFormat(100 * PdfPageFormat.mm, 50 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
};

/// One page per copy, laid out like [TagPreview].
Future<Uint8List> buildTagPdf(Asset a, {required String type, int copies = 1}) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final logo = await _logoPng();
  final doc = pw.Document(title: 'Asset Tag ${a.id}', author: 'Purple IQ Asset360');
  final code = a.barcode ?? a.id;
  final format = tagPageFormat(type);
  pw.TextStyle t(double size, {bool strong = false}) =>
      pw.TextStyle(font: strong ? bold : regular, fontSize: size, color: PdfColors.black);
  pw.Widget qr(double size) =>
      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: a.id, width: size, height: size, drawText: false);
  pw.Widget bar(double h) =>
      pw.BarcodeWidget(barcode: pw.Barcode.code39(), data: code.toUpperCase(), height: h, drawText: false);
  const mm = PdfPageFormat.mm;

  for (var i = 0; i < copies; i++) {
    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => switch (type) {
          'Small Label' => pw.Row(
            children: [
              qr(19 * mm),
              pw.SizedBox(width: 2 * mm),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [pw.Text(a.id, style: t(9, strong: true)), pw.SizedBox(height: 1 * mm), bar(8 * mm)],
                ),
              ),
            ],
          ),
          'QR Only' => pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [qr(27 * mm), pw.SizedBox(height: 1 * mm), pw.Text(a.id, style: t(8, strong: true))],
          ),
          _ => pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logo != null)
                      pw.Image(pw.MemoryImage(logo), height: 7 * mm)
                    else
                      pw.Text('Purple IQ Asset360', style: t(8, strong: true)),
                    pw.Text(a.id, style: t(13, strong: true)),
                    pw.Text(a.name, style: t(7), maxLines: 1),
                    pw.Text(a.location, style: t(6), maxLines: 1),
                    bar(9 * mm),
                  ],
                ),
              ),
              pw.SizedBox(width: 3 * mm),
              qr(32 * mm),
            ],
          ),
        },
      ),
    );
  }
  return doc.save();
}

/// The bundled logo is WebP, which PDF cannot embed: decode it and re-encode as PNG.
Future<Uint8List?> _logoPng() async {
  try {
    final data = await rootBundle.load('assets/images/logo_on_light.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return png?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
