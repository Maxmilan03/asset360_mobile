import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';

/// Finger-drawn signature. Strokes are reported as 0–1 fractions of the pad.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged, this.height = 150});

  final ValueChanged<List<List<(double, double)>>> onChanged;
  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _strokes = <List<Offset>>[];
  Size _size = Size.zero;

  void _emit() => widget.onChanged([
    for (final s in _strokes) [for (final p in s) (p.dx / _size.width, p.dy / _size.height)],
  ]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            _size = Size(c.maxWidth, widget.height);
            // Claims the drag at once, so drawing never scrolls the sheet / page around it.
            return RawGestureDetector(
              key: const ValueKey('signature-pad'),
              gestures: {
                _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(_EagerPan.new, (r) {
                  r.onStart = (d) => setState(() => _strokes.add([d.localPosition]));
                  r.onUpdate = (d) => setState(() => _strokes.last.add(d.localPosition));
                  r.onEnd = (_) => _emit();
                }),
              },
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(
                    painter: SignaturePainter(_strokes),
                    child: _strokes.isEmpty
                        ? Center(child: Text('Sign here with your finger', style: AppText.caption))
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _strokes.isEmpty
                ? null
                : () {
                    setState(_strokes.clear);
                    _emit();
                  },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Clear signature'),
          ),
        ),
      ],
    );
  }
}

/// Paints strokes given in pixels, or in 0–1 fractions when [normalized].
class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes, {this.normalized = false});

  /// Builds a painter from saved fractional strokes.
  factory SignaturePainter.saved(List<List<(double, double)>> strokes) => SignaturePainter([
    for (final s in strokes) [for (final (x, y) in s) Offset(x, y)],
  ], normalized: true);

  final List<List<Offset>> strokes;
  final bool normalized;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      Offset at(Offset p) => normalized ? Offset(p.dx * size.width, p.dy * size.height) : p;
      final path = Path()..moveTo(at(s.first).dx, at(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      if (s.length == 1) path.lineTo(at(s.first).dx + .5, at(s.first).dy + .5);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) => true;
}

/// Pan recognizer that wins the gesture arena on touch-down (beats an enclosing scroll view).
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
