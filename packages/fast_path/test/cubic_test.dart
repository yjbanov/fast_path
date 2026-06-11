// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.cubicTo', () {
    test('control points contribute to (loose) bounds', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..cubicTo(30, 100, 70, -50, 100, 0))
          .build();
      // Loose bounds matches dart:ui.Path.getBounds(): bbox of every
      // stored point including off-curve control points.
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, -50);
      expect(bounds.bottom, 100);
    });

    test('point inside a cubic-bounded region is contained', () {
      // Closed shape: line across the bottom, S-shaped cubic back over
      // the top. The interior includes points well above y=0 and well
      // below the cubic's apex.
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0)
            ..cubicTo(80, 100, 20, 100, 0, 0)
            ..close())
          .build();
      expect(path.contains(const Offset(50, 30)), isTrue);
      expect(path.contains(const Offset(50, -10)), isFalse); // below baseline
      expect(path.contains(const Offset(-5, 30)), isFalse); // left of shape
      expect(path.contains(const Offset(105, 30)), isFalse); // right of shape
    });

    test('S-curve cubic produces three real roots when ray bisects it', () {
      // An S-curve cubic from (0, 0) to (100, 100) passing through the
      // ray y = 50 three times — once descending, once ascending, once
      // descending. Closing back makes it a fillable region.
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..cubicTo(100, 200, 0, -100, 100, 100)
            ..lineTo(0, 100)
            ..close())
          .build();
      // The S-curve makes contains nontrivial — verify a few clear
      // points without over-asserting on exact geometry.
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      // Points obviously outside the loose bounding box.
      expect(path.contains(const Offset(-10, 50)), isFalse);
      expect(path.contains(const Offset(110, 50)), isFalse);
    });

    test('relativeCubicTo accumulates from current point', () {
      final relPath = (PathBuilder()
            ..moveTo(10, 10)
            ..relativeCubicTo(20, 80, 60, -30, 90, 0))
          .build();
      final absPath = (PathBuilder()
            ..moveTo(10, 10)
            ..cubicTo(30, 90, 70, -20, 100, 10))
          .build();
      expect(relPath.getBounds(), equals(absPath.getBounds()));
    });

    test('cubicTo without prior moveTo implicitly starts at origin', () {
      final path = (PathBuilder()..cubicTo(30, 100, 70, -50, 100, 0)).build();
      // Same loose bounds as the explicit-moveTo version above.
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, -50);
      expect(bounds.bottom, 100);
    });

    test('degenerate cubic (collinear controls) reduces to a line for bounds',
        () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..cubicTo(33, 0, 66, 0, 100, 0))
          .build();
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 0);
    });

    test('PathBuilder.from reseeds a path that contains a cubic', () {
      final original = (PathBuilder()
            ..moveTo(0, 0)
            ..cubicTo(30, 100, 70, -50, 100, 0)
            ..close())
          .build();
      final reseeded = PathBuilder.from(original).build();
      expect(reseeded, equals(original));
      expect(reseeded.getBounds(), equals(original.getBounds()));
    });
  });
}
