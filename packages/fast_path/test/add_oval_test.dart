// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.addOval', () {
    test('bounds equal the oval rect (conic controls at corners)', () {
      final path =
          (PathBuilder()..addOval(const Rect.fromLTRB(10, 20, 110, 80)))
              .build();
      expect(path.getBounds(), equals(const Rect.fromLTRB(10, 20, 110, 80)));
    });

    test('circle contains points by radius', () {
      // Circle of radius 50 centered at (50, 50).
      final path =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 100, 100)))
              .build();
      expect(path.contains(const Offset(50, 50)), isTrue); // center
      // (80, 80): distance from center ≈ 42.4 < 50 → inside.
      expect(path.contains(const Offset(80, 80)), isTrue);
      // (88, 88): distance ≈ 53.7 > 50 → outside the circle, but inside
      // the bounding square. A polygonal approximation would misjudge
      // points in this band.
      expect(path.contains(const Offset(88, 88)), isFalse);
      // Cardinal extremes, just inside.
      expect(path.contains(const Offset(97, 50)), isTrue);
      expect(path.contains(const Offset(50, 3)), isTrue);
      // Corners of the bounding box — far outside the circle.
      expect(path.contains(const Offset(5, 5)), isFalse);
      expect(path.contains(const Offset(95, 95)), isFalse);
    });

    test('ellipse honors distinct radii', () {
      // rx = 100, ry = 25, centered (100, 25).
      final path =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 200, 50)))
              .build();
      expect(path.contains(const Offset(100, 25)), isTrue);
      expect(path.contains(const Offset(190, 25)), isTrue); // near +x apex
      expect(path.contains(const Offset(100, 45)), isTrue); // near +y apex
      // Inside bbox, outside ellipse: (170, 42) → (x/rx)² + (y/ry)² =
      // 0.7² + 0.68² ≈ 0.95... that's inside. Use (180, 40): 0.8² + 0.6²
      // = 1.0 — on the boundary. Use (185, 40): 0.7225 + 0.36 ≈ 1.08 —
      // outside.
      expect(path.contains(const Offset(185, 40)), isFalse);
    });

    test('two nested ovals under evenOdd form an annulus', () {
      final path = (PathBuilder()
            ..fillType = PathFillType.evenOdd
            ..addOval(const Rect.fromLTRB(0, 0, 100, 100))
            ..addOval(const Rect.fromLTRB(25, 25, 75, 75)))
          .build();
      expect(path.contains(const Offset(50, 50)), isFalse); // hole
      expect(path.contains(const Offset(50, 10)), isTrue); // ring
    });

    test('subsequent segments start fresh after addOval close', () {
      final path = (PathBuilder()
            ..addOval(const Rect.fromLTRB(0, 0, 10, 10))
            ..lineTo(20, 5))
          .build();
      // The implicit moveTo lands at the oval's start (10, 5); the new
      // segment extends bounds to x=20.
      expect(path.getBounds(), equals(const Rect.fromLTRB(0, 0, 20, 10)));
    });
  });
}
