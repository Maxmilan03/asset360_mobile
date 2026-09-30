import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Scannable QR code (byte mode, error correction L, versions 1–5 = up to 106 bytes),
/// drawn with CustomPaint so no package is needed.
class QrCode extends StatelessWidget {
  const QrCode({super.key, required this.data, this.size = 160, this.color = AppColors.text});

  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final modules = encodeQr(data);
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: CustomPaint(painter: _QrPainter(modules, color)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.modules, this.color);

  final List<List<bool>> modules;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const quiet = 2; // quiet-zone modules on each side (the white box adds the rest)
    final n = modules.length;
    final cell = size.width / (n + quiet * 2);
    final paint = Paint()..color = color;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (modules[y][x]) {
          // Slight overlap avoids hairline gaps between cells.
          canvas.drawRect(Rect.fromLTWH((x + quiet) * cell, (y + quiet) * cell, cell + .3, cell + .3), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.modules != modules || old.color != color;
}

// ECC level L: (total codewords, EC codewords per block) for versions 1–5, all single block.
const _versions = [(26, 7), (44, 10), (70, 15), (100, 20), (134, 26)];
const _alignment = [0, 18, 22, 26, 30]; // second alignment coordinate (v2+; the first is 6)

/// QR modules (true = dark), row by row.
List<List<bool>> encodeQr(String text) {
  final bytes = utf8.encode(text);
  var version = 0;
  while (version < _versions.length && bytes.length > _versions[version].$1 - _versions[version].$2 - 2) {
    version++;
  }
  if (version == _versions.length) throw ArgumentError('Text too long for the QR code (max 106 bytes)');
  final (total, ecLen) = _versions[version];
  final dataLen = total - ecLen;

  // Bit stream: mode 0100 (byte), 8-bit length, data, terminator, pad bytes.
  final bits = <int>[];
  void put(int value, int len) {
    for (var i = len - 1; i >= 0; i--) {
      bits.add((value >> i) & 1);
    }
  }

  put(4, 4);
  put(bytes.length, 8);
  for (final b in bytes) {
    put(b, 8);
  }
  put(0, (dataLen * 8 - bits.length).clamp(0, 4));
  while (bits.length % 8 != 0) {
    bits.add(0);
  }
  final data = <int>[for (var i = 0; i < bits.length; i += 8) int.parse(bits.sublist(i, i + 8).join(), radix: 2)];
  for (var pad = 0xEC; data.length < dataLen; pad ^= 0xEC ^ 0x11) {
    data.add(pad);
  }
  final codewords = [...data, ..._reedSolomon(data, ecLen)];

  final size = 21 + version * 4;
  final m = List.generate(size, (_) => List.filled(size, false));
  final fn = List.generate(size, (_) => List.filled(size, false));
  void set(int x, int y, bool dark) {
    m[y][x] = dark;
    fn[y][x] = true;
  }

  // Timing patterns, finders (with separators), alignment, format area, dark module.
  for (var i = 0; i < size; i++) {
    set(6, i, i.isEven);
    set(i, 6, i.isEven);
  }
  for (final (cx, cy) in [(3, 3), (size - 4, 3), (3, size - 4)]) {
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        final x = cx + dx, y = cy + dy;
        if (x < 0 || y < 0 || x >= size || y >= size) continue;
        final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        set(x, y, d != 2 && d != 4);
      }
    }
  }
  if (version > 0) {
    final c = _alignment[version];
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final d = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
        set(c + dx, c + dy, d != 1);
      }
    }
  }
  _drawFormat(set, size, 0);

  // Data in the zig-zag order, skipping function modules.
  var i = 0;
  for (var right = size - 1; right >= 1; right -= 2) {
    if (right == 6) right = 5;
    for (var vert = 0; vert < size; vert++) {
      for (var j = 0; j < 2; j++) {
        final x = right - j;
        final upward = ((right + 1) & 2) == 0;
        final y = upward ? size - 1 - vert : vert;
        if (!fn[y][x] && i < codewords.length * 8) {
          m[y][x] = ((codewords[i >> 3] >> (7 - (i & 7))) & 1) == 1;
          i++;
        }
      }
    }
  }

  // Try every mask and keep the one with the lowest penalty.
  List<List<bool>>? best;
  var bestScore = 1 << 30;
  for (var mask = 0; mask < 8; mask++) {
    final c = [
      for (final row in m) [...row],
    ];
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (!fn[y][x] && _masked(mask, x, y)) c[y][x] = !c[y][x];
      }
    }
    _drawFormat((x, y, d) => c[y][x] = d, size, mask);
    final score = _penalty(c);
    if (score < bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return best!;
}

bool _masked(int mask, int x, int y) => switch (mask) {
  0 => (x + y) % 2 == 0,
  1 => y % 2 == 0,
  2 => x % 3 == 0,
  3 => (x + y) % 3 == 0,
  4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
  5 => x * y % 2 + x * y % 3 == 0,
  6 => (x * y % 2 + x * y % 3) % 2 == 0,
  _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
};

void _drawFormat(void Function(int x, int y, bool dark) set, int size, int mask) {
  final data = 1 << 3 | mask; // ECC L = 01
  var rem = data;
  for (var i = 0; i < 10; i++) {
    rem = (rem << 1) ^ ((rem >> 9) * 0x537);
  }
  final bits = (data << 10 | rem) ^ 0x5412;
  bool bit(int i) => ((bits >> i) & 1) == 1;
  for (var i = 0; i <= 5; i++) {
    set(8, i, bit(i));
  }
  set(8, 7, bit(6));
  set(8, 8, bit(7));
  set(7, 8, bit(8));
  for (var i = 9; i < 15; i++) {
    set(14 - i, 8, bit(i));
  }
  for (var i = 0; i < 8; i++) {
    set(size - 1 - i, 8, bit(i));
  }
  for (var i = 8; i < 15; i++) {
    set(8, size - 15 + i, bit(i));
  }
  set(8, size - 8, true);
}

/// Penalty rules 1 (runs), 2 (2×2 blocks) and 4 (dark balance).
int _penalty(List<List<bool>> c) {
  final n = c.length;
  var score = 0;
  for (var pass = 0; pass < 2; pass++) {
    for (var a = 0; a < n; a++) {
      var run = 1;
      for (var b = 1; b < n; b++) {
        final cur = pass == 0 ? c[a][b] : c[b][a];
        final prev = pass == 0 ? c[a][b - 1] : c[b - 1][a];
        if (cur == prev) {
          run++;
          if (run == 5) score += 3;
          if (run > 5) score++;
        } else {
          run = 1;
        }
      }
    }
  }
  var dark = 0;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      if (c[y][x]) dark++;
      if (x < n - 1 && y < n - 1 && c[y][x] == c[y][x + 1] && c[y][x] == c[y + 1][x] && c[y][x] == c[y + 1][x + 1]) {
        score += 3;
      }
    }
  }
  score += ((dark * 20 - n * n * 10).abs() ~/ (n * n)) * 10;
  return score;
}

int _gfMul(int x, int y) {
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >> 7) * 0x11D);
    z ^= ((y >> i) & 1) * x;
  }
  return z & 0xFF;
}

List<int> _reedSolomon(List<int> data, int degree) {
  final divisor = List.filled(degree, 0)..[degree - 1] = 1;
  var root = 1;
  for (var i = 0; i < degree; i++) {
    for (var j = 0; j < degree; j++) {
      divisor[j] = _gfMul(divisor[j], root);
      if (j + 1 < degree) divisor[j] ^= divisor[j + 1];
    }
    root = _gfMul(root, 2);
  }
  final result = List.filled(degree, 0, growable: true);
  for (final b in data) {
    final factor = b ^ result.removeAt(0);
    result.add(0);
    for (var i = 0; i < degree; i++) {
      result[i] ^= _gfMul(divisor[i], factor);
    }
  }
  return result;
}
