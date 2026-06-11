// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.addArc / arcTo', () {
    test('half-circle arc closed into a semicircular pie', () {
      // Bottom half of the circle r=50 centered (50,50): start angle 0,
      // sweep pi (clockwise through the bottom in screen coords).
      final path = (PathBuilder()
            ..addArc(const Rect.fromLTRB(0, 0, 100, 100), 0, math.pi)
            ..close())
          .build();
      // Inside the bottom half-disk.
      expect(path.contains(const Offset(50, 75)), isTrue);
      expect(path.contains(const Offset(20, 60)), isTrue);
      // The top half is not part of the shape.
      expect(path.contains(const Offset(50, 25)), isFalse);
      // Below the circle.
      expect(path.contains(const Offset(50, 105)), isFalse);
    });

    test('quarter arc matches the conic quarter-circle construction', () {
      // arcTo from 0 to pi/2 on circle r=100 centered origin-ish rect
      // produces the same geometry as the manual quarter-circle conic.
      final viaArc = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0)
            ..arcTo(const Rect.fromLTRB(-100, -100, 100, 100), 0,
                math.pi / 2, false)
            ..close())
          .build();
      // Same pie as the conic_test quarter circle: contains by radius.
      expect(viaArc.contains(const Offset(60, 60)), isTrue); // r≈85
      expect(viaArc.contains(const Offset(75, 75)), isFalse); // r≈106
    });

    test('arcTo with forceMoveTo=false draws a connecting line', () {
      final path = (PathBuilder()
            ..moveTo(0, 50)
            // Line from (0,50) to arc start (100+50=150? no — rect
            // (100,0,200,100): center (150,50), rx=ry=50, start angle 0
            // → start point (200, 50).
            ..arcTo(const Rect.fromLTRB(100, 0, 200, 100), 0, math.pi, false)
            ..close())
          .build();
      final bounds = path.getBounds();
      // The connecting line from (0,50) to (200,50) extends bounds to
      // the left edge.
      expect(bounds.left, 0);
      expect(bounds.right, closeTo(200, 1e-6));
    });

    test('arcTo with forceMoveTo=true starts a new contour', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..arcTo(const Rect.fromLTRB(100, 0, 200, 100), 0, math.pi, true))
          .build();
      // Two contours: the stub line and the open arc. The arc contour's
      // implicit closing chord spans (200,50)→(100,50); the region
      // under the arc (bottom half-disk) is filled.
      expect(path.contains(const Offset(150, 75)), isTrue);
      expect(path.contains(const Offset(150, 25)), isFalse);
    });

    test('full-circle sweep equals addOval geometry', () {
      final viaArc = (PathBuilder()
            ..addArc(const Rect.fromLTRB(0, 0, 100, 100), 0, 2 * math.pi)
            ..close())
          .build();
      // Same containment as a circle (not structurally equal to
      // addOval — segment count differs — but geometrically identical).
      expect(viaArc.contains(const Offset(50, 50)), isTrue);
      expect(viaArc.contains(const Offset(80, 80)), isTrue); // r≈42<50
      expect(viaArc.contains(const Offset(88, 88)), isFalse); // r≈54>50
    });

    test('sweep beyond 2π is clamped', () {
      final clamped = (PathBuilder()
            ..addArc(const Rect.fromLTRB(0, 0, 100, 100), 0, 3 * math.pi)
            ..close())
          .build();
      final full = (PathBuilder()
            ..addArc(const Rect.fromLTRB(0, 0, 100, 100), 0, 2 * math.pi)
            ..close())
          .build();
      expect(clamped, equals(full));
    });

    test('negative sweep goes counterclockwise', () {
      // Start angle 0, sweep -pi: the top half of the circle.
      final path = (PathBuilder()
            ..addArc(const Rect.fromLTRB(0, 0, 100, 100), 0, -math.pi)
            ..close())
          .build();
      expect(path.contains(const Offset(50, 25)), isTrue);
      expect(path.contains(const Offset(50, 75)), isFalse);
    });

    test('zero sweep adds only the start point', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..arcTo(const Rect.fromLTRB(0, 0, 100, 100), 0, 0, false))
          .build();
      // Line from origin to arc start (100, 50); no curve. Bounds stop
      // at the start point.
      expect(path.getBounds(), equals(const Rect.fromLTRB(0, 0, 100, 50)));
    });
  });
}
