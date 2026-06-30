import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse/features/receive/services/camera_light_source.dart';

Uint8List _frame(int w, int h, int fill) =>
    Uint8List(w * h)..fillRange(0, w * h, fill);

void _block(Uint8List y, int w, int x0, int y0, int bw, int bh, int val) {
  for (var r = y0; r < y0 + bh; r++) {
    for (var c = x0; c < x0 + bw; c++) {
      y[r * w + c] = val;
    }
  }
}

void main() {
  const w = 40, h = 40;

  test('uniform dark frame → low luminance', () {
    final y = _frame(w, h, 12);
    expect(brightRegionLuminance(y, w, h, w, stride: 2), lessThan(20));
  });

  test('small central bright blob → high luminance (distant flash)', () {
    final y = _frame(w, h, 12);
    _block(y, w, 16, 16, 8, 8, 255); // ~4% of frame, centred
    final lum = brightRegionLuminance(y, w, h, w, stride: 2);
    expect(lum, greaterThan(60),
        reason: 'bright tail must reflect the blob, not the dark background');
  });

  test('bright-region metric beats whole-frame mean for a small blob', () {
    final y = _frame(w, h, 12);
    _block(y, w, 17, 17, 6, 6, 255); // ~2% of frame
    final region = brightRegionLuminance(y, w, h, w, stride: 1);

    var sum = 0;
    for (final v in y) {
      sum += v;
    }
    final wholeFrameMean = sum / y.length;

    expect(region, greaterThan(wholeFrameMean * 3));
  });

  test('peripheral blob is ignored (center crop) → stays low', () {
    final y = _frame(w, h, 12);
    _block(y, w, 0, 0, 8, 8, 255); // corner, outside the central 50%
    final lum = brightRegionLuminance(y, w, h, w,
        centerFraction: 0.5, stride: 1);
    expect(lum, lessThan(20),
        reason: 'background/peripheral lights must not register');
  });

  test('empty plane → 0, never throws', () {
    expect(brightRegionLuminance(Uint8List(0), 0, 0, 0), 0);
  });

  group('brightCentroid', () {
    test('locates a central blob near the centre', () {
      final y = _frame(w, h, 12);
      _block(y, w, 16, 16, 8, 8, 255);
      final c = brightCentroid(y, w, h, w, stride: 1)!;
      expect(c.x, closeTo(0.5, 0.08));
      expect(c.y, closeTo(0.5, 0.08));
    });

    test('locates an off-centre blob', () {
      final y = _frame(w, h, 12);
      _block(y, w, 30, 8, 6, 6, 255); // upper-right
      final c = brightCentroid(y, w, h, w, stride: 1)!;
      expect(c.x, closeTo(0.82, 0.1));
      expect(c.y, closeTo(0.27, 0.1));
    });

    test('returns null on a dark/uniform frame (no spot)', () {
      expect(brightCentroid(_frame(w, h, 14), w, h, w, stride: 1), isNull);
    });
  });

  test('windowed sampling follows the blob off-centre (tracking benefit)', () {
    final y = _frame(w, h, 12);
    _block(y, w, 30, 8, 6, 6, 255); // upper-right blob

    // Window centred on the tracked blob captures it.
    final tracked = brightRegionLuminance(y, w, h, w,
        stride: 1, centerX: 0.82, centerY: 0.27);
    // Fixed centre window misses it.
    final fixedCentre = brightRegionLuminance(y, w, h, w, stride: 1);

    expect(tracked, greaterThan(60));
    expect(fixedCentre, lessThan(25));
  });
}
