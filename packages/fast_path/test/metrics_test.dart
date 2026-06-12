// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('Path.computeMetrics — length', () {
    test('empty path yields no metrics', () {
      expect(PathBuilder().build().computeMetrics(), isEmpty);
    });

    test('straight line length', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(30, 40)) // 3-4-5 → length 50
          .build();
      final metrics = path.computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(metrics.single.length, closeTo(50, 1e-6));
      expect(metrics.single.isClosed, isFalse);
      expect(metrics.single.contourIndex, 0);
    });

    test('polyline perimeter sums segments', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(10, 10)
            ..close()) // closing segment (10,10)->(0,0): sqrt(200)
          .build();
      final m = path.computeMetrics().single;
      expect(m.length, closeTo(20 + math.sqrt(200), 1e-6));
      expect(m.isClosed, isTrue);
    });

    test('forceClosed adds the closing segment to an open contour', () {
      final open = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(10, 10))
          .build();
      expect(open.computeMetrics().single.length, closeTo(20, 1e-6));
      final forced = open.computeMetrics(forceClosed: true).single;
      // Plus the diagonal (10,10)->(0,0).
      expect(forced.length, closeTo(20 + math.sqrt(200), 1e-6));
      expect(forced.isClosed, isTrue);
    });

    test('circle circumference (oval) ≈ 2πr', () {
      final circle =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 100, 100)))
              .build();
      final m = circle.computeMetrics().single;
      expect(m.length, closeTo(2 * math.pi * 50, 0.05));
    });

    test('quarter-circle arc length ≈ πr/2', () {
      // Quarter circle radius 100 from (100,0) to (0,100).
      final w = math.sqrt(2) / 2;
      final arc = (PathBuilder()
            ..moveTo(100, 0)
            ..conicTo(100, 100, 0, 100, w))
          .build();
      final m = arc.computeMetrics().single;
      expect(m.length, closeTo(math.pi * 100 / 2, 0.05));
    });

    test('multiple contours yield multiple metrics', () {
      final path = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 10, 10))
            ..addRect(const Rect.fromLTRB(20, 20, 25, 25)))
          .build();
      final metrics = path.computeMetrics().toList();
      expect(metrics, hasLength(2));
      expect(metrics[0].length, closeTo(40, 1e-6));
      expect(metrics[1].length, closeTo(20, 1e-6));
      expect(metrics[0].contourIndex, 0);
      expect(metrics[1].contourIndex, 1);
    });

    test('re-iterable (unlike dart:ui one-shot)', () {
      final path =
          (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 10, 10))).build();
      final metrics = path.computeMetrics();
      expect(metrics.length, 1);
      expect(metrics.length, 1); // second iteration still works
    });
  });

  group('PathMetric.getTangentForOffset', () {
    test('position and tangent along a straight line', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0))
          .build();
      final m = path.computeMetrics().single;
      final t = m.getTangentForOffset(25)!;
      expect(t.position.dx, closeTo(25, 1e-6));
      expect(t.position.dy, closeTo(0, 1e-6));
      // Tangent points along +x.
      expect(t.vector.dx, closeTo(1, 1e-6));
      expect(t.vector.dy, closeTo(0, 1e-6));
    });

    test('vertical line tangent', () {
      final path = (PathBuilder()
            ..moveTo(5, 0)
            ..lineTo(5, 50))
          .build();
      final t = path.computeMetrics().single.getTangentForOffset(10)!;
      expect(t.position.dx, closeTo(5, 1e-6));
      expect(t.position.dy, closeTo(10, 1e-6));
      expect(t.vector.dx, closeTo(0, 1e-6));
      expect(t.vector.dy, closeTo(1, 1e-6));
    });

    test('distance clamps to [0, length]', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0))
          .build();
      final m = path.computeMetrics().single;
      expect(m.getTangentForOffset(-5)!.position.dx, closeTo(0, 1e-6));
      expect(m.getTangentForOffset(999)!.position.dx, closeTo(10, 1e-6));
    });

    test('tangent direction on a circle is perpendicular to the radius', () {
      final circle =
          (PathBuilder()..addOval(const Rect.fromLTRB(-50, -50, 50, 50)))
              .build();
      final m = circle.computeMetrics().single;
      // At distance 0 the point is the rightmost (50, 0); for a CW oval
      // the tangent there points roughly +y (downward in screen space).
      final t0 = m.getTangentForOffset(0)!;
      expect(t0.position.dx, closeTo(50, 0.5));
      expect(t0.position.dy, closeTo(0, 0.5));
      // Tangent ⟂ radius: radius is +x, so tangent has near-zero x.
      expect(t0.vector.dx.abs(), lessThan(0.05));
      expect(t0.vector.dy.abs(), closeTo(1, 0.05));
    });

    test('null for a zero-length contour', () {
      final dot = (PathBuilder()
            ..moveTo(5, 5)
            ..lineTo(5, 5))
          .build();
      final metrics = dot.computeMetrics().toList();
      // A degenerate move+line to the same point flattens to <2 distinct
      // points or zero length → no usable tangent.
      if (metrics.isNotEmpty) {
        expect(metrics.single.getTangentForOffset(0), isNull);
      }
    });
  });

  group('Tangent', () {
    test('angle negates atan2', () {
      const t = Tangent(Offset(0, 0), Offset(1, 0));
      expect(t.angle, closeTo(0, 1e-9));
      const up = Tangent(Offset(0, 0), Offset(0, 1));
      // vector (0,1): -atan2(1,0) = -π/2.
      expect(up.angle, closeTo(-math.pi / 2, 1e-9));
    });

    test('fromAngle round-trips through vector', () {
      final t = Tangent.fromAngle(const Offset(3, 4), math.pi / 3);
      expect(t.vector.dx, closeTo(math.cos(math.pi / 3), 1e-9));
      expect(t.vector.dy, closeTo(math.sin(math.pi / 3), 1e-9));
      expect(t.position, const Offset(3, 4));
    });
  });
}
