// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

Path _shape() => (PathBuilder()
      ..moveTo(0, 0)
      ..lineTo(10, 0)
      ..quadraticBezierTo(15, 5, 10, 10)
      ..conicTo(5, 12, 0, 10, 0.8)
      ..close())
    .build();

void main() {
  group('Path.shift', () {
    test('translates the bounds', () {
      final shifted = _shape().shift(const Offset(100, 50));
      final base = _shape().getBounds();
      final b = shifted.getBounds();
      expect(b.left, closeTo(base.left + 100, 1e-4));
      expect(b.top, closeTo(base.top + 50, 1e-4));
      expect(b.right, closeTo(base.right + 100, 1e-4));
      expect(b.bottom, closeTo(base.bottom + 50, 1e-4));
    });

    test('translates containment', () {
      final base = (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 50, 50)))
          .build();
      final shifted = base.shift(const Offset(100, 0));
      expect(base.contains(const Offset(25, 25)), isTrue);
      expect(shifted.contains(const Offset(25, 25)), isFalse);
      expect(shifted.contains(const Offset(125, 25)), isTrue);
    });

    test('zero offset equals the original', () {
      final base = _shape();
      expect(base.shift(Offset.zero), equals(base));
    });

    test('equals the same shape built pre-translated', () {
      final shifted = _shape().shift(const Offset(7, 3));
      final preTranslated = (PathBuilder()
            ..moveTo(7, 3)
            ..lineTo(17, 3)
            ..quadraticBezierTo(22, 8, 17, 13)
            ..conicTo(12, 15, 7, 13, 0.8)
            ..close())
          .build();
      expect(shifted, equals(preTranslated));
    });

    test('does not mutate the original', () {
      final base = _shape();
      final beforeBounds = base.getBounds();
      base.shift(const Offset(100, 100));
      expect(base.getBounds(), equals(beforeBounds));
    });

    test('composes additively', () {
      final once = _shape().shift(const Offset(10, 20)).shift(
            const Offset(5, -5),
          );
      final combined = _shape().shift(const Offset(15, 15));
      expect(once, equals(combined));
    });

    test('empty path shifts to an empty path', () {
      final empty = PathBuilder().build();
      final shifted = empty.shift(const Offset(10, 10));
      expect(shifted.getBounds(), equals(Rect.zero));
    });
  });
}
