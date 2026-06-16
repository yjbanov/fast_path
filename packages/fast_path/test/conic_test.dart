// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.conicTo', () {
    test('control point contributes to (loose) bounds', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, 0.5))
          .build();
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 100); // control point at y=100 is in the bbox
    });

    test('quarter circle (w = sqrt(2)/2) contains points by radius', () {
      // Quarter circle of radius 100 centered at the origin: from
      // (100, 0) to (0, 100) with control (100, 100). Closing back to
      // the origin via lines makes a pie quadrant. Points on the
      // 45° diagonal are inside iff their distance from the origin is
      // less than 100.
      final w = math.sqrt(2) / 2;
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0)
            ..conicTo(100, 100, 0, 100, w)
            ..close())
          .build();
      // (60, 60): r ≈ 84.9 < 100 → inside the pie.
      expect(path.contains(const Offset(60, 60)), isTrue);
      // (75, 75): r ≈ 106.1 > 100 → outside the arc, though inside the
      // control hull. A chord-flattened arc would get this wrong.
      expect(path.contains(const Offset(75, 75)), isFalse);
      // Inside near the corner.
      expect(path.contains(const Offset(10, 10)), isTrue);
      // Outside the quadrant entirely.
      expect(path.contains(const Offset(-10, 50)), isFalse);
    });

    test('w == 1 is stored as a quadratic Bézier', () {
      final viaConic = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, 1.0))
          .build();
      final viaQuad = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(50, 100, 100, 0))
          .build();
      expect(viaConic, equals(viaQuad));
    });

    test('degenerate weights: w<=0 and NaN are quads, +infinity is a corner',
        () {
      // Matches the 2026-06 dart:ui (Impeller): w <= 0 normalizes to a plain
      // quadratic through the control point (classic Skia docs say w <= 0
      // becomes a line — current Flutter does not). w == +infinity collapses to
      // the infinite-weight corner: two line segments through the control
      // point. NaN is fast_path's documented divergence — dart:ui treats a NaN
      // weight like +infinity (a corner), but we keep it a safe quadratic.
      final viaQuad = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(50, 100, 100, 0))
          .build();
      for (final w in [0.0, -2.0, double.nan]) {
        final viaConic = (PathBuilder()
              ..moveTo(0, 0)
              ..conicTo(50, 100, 100, 0, w))
            .build();
        expect(viaConic, equals(viaQuad), reason: 'w=$w should be a quad');
      }

      // +infinity becomes the two-segment corner through the control point.
      final viaCorner = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(50, 100)
            ..lineTo(100, 0))
          .build();
      final viaInfinity = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, double.infinity))
          .build();
      expect(viaInfinity, equals(viaCorner));

      // The corner fills up to the control point (y=100), so a point above the
      // quad apex (y=50) is inside the corner but outside the equivalent quad.
      final cornerClosed = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, double.infinity)
            ..close())
          .build();
      final quadClosed = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(50, 100, 100, 0)
            ..close())
          .build();
      expect(cornerClosed.contains(const Offset(50, 70)), isTrue);
      expect(quadClosed.contains(const Offset(50, 70)), isFalse);
    });

    test('relativeConicTo accumulates from current point', () {
      final relPath = (PathBuilder()
            ..moveTo(10, 10)
            ..relativeConicTo(40, 90, 90, 0, 0.7))
          .build();
      final absPath = (PathBuilder()
            ..moveTo(10, 10)
            ..conicTo(50, 100, 100, 10, 0.7))
          .build();
      expect(relPath, equals(absPath));
    });

    test('conicTo without prior moveTo implicitly starts at origin', () {
      final path = (PathBuilder()..conicTo(50, 100, 100, 0, 0.5)).build();
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 100);
    });

    test('PathBuilder.from reseeds a path that contains a conic', () {
      final original = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, 0.5)
            ..close())
          .build();
      final reseeded = PathBuilder.from(original).build();
      expect(reseeded, equals(original));
      // Weight survived the round trip: contains agrees on a point that
      // discriminates by weight (low w pulls the curve toward the chord).
      expect(
        reseeded.contains(const Offset(50, 30)),
        equals(original.contains(const Offset(50, 30))),
      );
    });

    test('different weights produce different paths', () {
      final low = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, 0.3)
            ..close())
          .build();
      final high = (PathBuilder()
            ..moveTo(0, 0)
            ..conicTo(50, 100, 100, 0, 0.9)
            ..close())
          .build();
      expect(low, isNot(equals(high)));
      // High weight pulls the curve toward the control point. The apex
      // of this conic is y = 100w/(1+w): ≈47.4 for w=0.9, ≈23.1 for
      // w=0.3. A point at y=35 discriminates.
      expect(high.contains(const Offset(50, 35)), isTrue);
      expect(low.contains(const Offset(50, 35)), isFalse);
    });
  });
}
