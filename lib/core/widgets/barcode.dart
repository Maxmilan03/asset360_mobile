import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Code 39 barcode drawn with CustomPaint, readable by the phone scanner.
/// Supports A–Z, 0–9 and - . space $ / + % (other characters are skipped).
class Code39Barcode extends StatelessWidget {
  const Code39Barcode({super.key, required this.data, this.height = 34, this.showLabel = true});

  final String data;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _Code39Painter(data.toUpperCase())),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            data,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              letterSpacing: .6,
            ),
          ),
        ],
      ],
    );
  }
}

class _Code39Painter extends CustomPainter {
  _Code39Painter(this.data);

  final String data;

  // 9 elements per character (bar, space, bar …); '1' = wide.
  static const _patterns = {
    '0': '000110100', '1': '100100001', '2': '001100001', '3': '101100000', '4': '000110001', //
    '5': '100110000', '6': '001110000', '7': '000100101', '8': '100100100', '9': '001100100',
    'A': '100001001', 'B': '001001001', 'C': '101001000', 'D': '000011001', 'E': '100011000',
    'F': '001011000', 'G': '000001101', 'H': '100001100', 'I': '001001100', 'J': '000011100',
    'K': '100000011', 'L': '001000011', 'M': '101000010', 'N': '000010011', 'O': '100010010',
    'P': '001010010', 'Q': '000000111', 'R': '100000110', 'S': '001000110', 'T': '000010110',
    'U': '110000001', 'V': '011000001', 'W': '111000000', 'X': '010010001', 'Y': '110010000',
    'Z': '011010000', '-': '010000101', '.': '110000100', ' ': '011000100', '*': '010010100',
    r'$': '010101000', '/': '010100010', '+': '010001010', '%': '000101010',
  };
  static const _wide = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final chars = ['*', ...data.split('').where((c) => c != '*' && _patterns.containsKey(c)), '*'];
    final elements = <(bool bar, double w)>[];
    for (var i = 0; i < chars.length; i++) {
      final p = _patterns[chars[i]]!;
      for (var j = 0; j < 9; j++) {
        elements.add((j.isEven, p[j] == '1' ? _wide : 1));
      }
      if (i < chars.length - 1) elements.add((false, 1)); // gap between characters
    }
    final units = elements.fold<double>(0, (s, e) => s + e.$2);
    final unit = size.width / units;
    final paint = Paint()..color = AppColors.text;
    var x = 0.0;
    for (final (bar, w) in elements) {
      if (bar) canvas.drawRect(Rect.fromLTWH(x, 0, w * unit, size.height), paint);
      x += w * unit;
    }
  }

  @override
  bool shouldRepaint(_Code39Painter old) => old.data != data;
}
