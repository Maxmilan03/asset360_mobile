import 'package:flutter_test/flutter_test.dart';
import 'package:asset360_mobile/core/widgets/qr_code.dart';

int mul(int x, int y) {
  var z = 0;
  for (var i = 7; i >= 0; i--) {
    z = (z << 1) ^ ((z >> 7) * 0x11D);
    z ^= ((y >> i) & 1) * x;
  }
  return z & 0xff;
}

void main() {
  test('QR: format bits, Reed–Solomon syndromes and payload round-trip', () {
    // format string for L/mask0 must be 111011111000100
    final data = 1 << 3 | 0;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = (data << 10 | rem) ^ 0x5412;
    expect(bits.toRadixString(2).padLeft(15, '0'), '111011111000100');
    final m = encodeQr('https://asset360.purpleiq.ae/assets/MTR-00124');
    expect(m.length, 29); // v3
    // Read back data by inverse placement: rebuild function map like the encoder.
    final size = m.length;
    // read format bits from top-left copy to get mask
    bool g(int x, int y) => m[y][x];
    var f = 0;
    for (var i = 0; i <= 5; i++) {
      if (g(8, i)) f |= 1 << i;
    }
    if (g(8, 7)) f |= 1 << 6;
    if (g(8, 8)) f |= 1 << 7;
    if (g(7, 8)) f |= 1 << 8;
    for (var i = 9; i < 15; i++) {
      if (g(14 - i, 8)) f |= 1 << i;
    }
    final fmt = f ^ 0x5412;
    final mask = (fmt >> 10) & 7;
    expect((fmt >> 13) & 3, 1);
    final fn = List.generate(size, (_) => List.filled(size, false));
    for (var i = 0; i < size; i++) {
      fn[i][6] = true;
      fn[6][i] = true;
    }
    for (final (cx, cy) in [(3, 3), (size - 4, 3), (3, size - 4)]) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          final x = cx + dx, y = cy + dy;
          if (x >= 0 && y >= 0 && x < size && y < size) fn[y][x] = true;
        }
      }
    }
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        fn[22 + dy][22 + dx] = true;
      }
    }
    for (var i = 0; i < 9; i++) {
      fn[8][i] = true;
      fn[i][8] = true;
    }
    for (var i = 0; i < 8; i++) {
      fn[8][size - 1 - i] = true;
      fn[size - 1 - i][8] = true;
    }
    bool masked(int x, int y) => switch (mask) {
      0 => (x + y) % 2 == 0,
      1 => y % 2 == 0,
      2 => x % 3 == 0,
      3 => (x + y) % 3 == 0,
      4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
      5 => x * y % 2 + x * y % 3 == 0,
      6 => (x * y % 2 + x * y % 3) % 2 == 0,
      _ => ((x + y) % 2 + x * y % 3) % 2 == 0,
    };
    final out = <int>[];
    var cur = 0, n = 0;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          final up = ((right + 1) & 2) == 0;
          final y = up ? size - 1 - vert : vert;
          if (!fn[y][x]) {
            final b = m[y][x] ^ masked(x, y);
            cur = cur << 1 | (b ? 1 : 0);
            n++;
            if (n == 8) {
              out.add(cur);
              cur = 0;
              n = 0;
            }
          }
        }
      }
    }
    final cw = out.sublist(0, 70);
    // syndromes
    var a = 1;
    for (var i = 0; i < 15; i++) {
      var s = 0;
      for (final c in cw) {
        s = mul(s, a) ^ c;
      }
      expect(s, 0, reason: 'syndrome $i');
      a = mul(a, 2);
    }
    // decode payload
    expect(cw[0] >> 4, 4);
    final len = ((cw[0] & 15) << 4) | (cw[1] >> 4);
    final bytes = [for (var i = 0; i < len; i++) ((cw[1 + i] & 15) << 4) | (cw[2 + i] >> 4)];
    expect(String.fromCharCodes(bytes), 'https://asset360.purpleiq.ae/assets/MTR-00124');
  });
}
