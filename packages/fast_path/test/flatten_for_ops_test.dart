// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

/// Reads a packed ring `[x0,y0,x1,y1,…]` into `(x, y)` vertex records.
List<(double, double)> _vertices(Float64List ring) {
  return [
    for (var i = 0; i < ring.length; i += 2) (ring[i], ring[i + 1]),
  ];
}

void main() {
  group('Path flatten-for-ops', () {
    test('empty path flattens to no contours', () {
      final contours = PathBuilder().build().debugFlattenForOps();
      expect(contours, isEmpty);
    });

    test('a rect is one 4-vertex ring, no duplicated closing vertex', () {
      final rect =
          (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 10, 10))).build();
      final contours = rect.debugFlattenForOps();
      expect(contours, hasLength(1));
      final verts = _vertices(contours.single);
      expect(verts, hasLength(4), reason: 'closing vertex must not be repeated');
      expect(
        verts.toSet(),
        {(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)},
      );
    });

    test('an explicitly closed triangle keeps three vertices', () {
      final tri = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(5, 10)
            ..close())
          .build();
      final verts = _vertices(tri.debugFlattenForOps().single);
      expect(verts, hasLength(3));
      expect(verts.toSet(), {(0.0, 0.0), (10.0, 0.0), (5.0, 10.0)});
    });

    test('an open contour is implicitly closed for ops', () {
      // No close() — still a fillable region, so flattening yields the ring.
      final open = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(10, 10))
          .build();
      final verts = _vertices(open.debugFlattenForOps().single);
      expect(verts, hasLength(3));
      expect(verts.toSet(), {(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)});
    });

    test('two subpaths flatten to two rings', () {
      final two = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 10, 10))
            ..addRect(const Rect.fromLTRB(20, 0, 30, 10)))
          .build();
      expect(two.debugFlattenForOps(), hasLength(2));
    });

    test('a zero-area contour (single segment) is dropped', () {
      final line = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0))
          .build();
      expect(line.debugFlattenForOps(), isEmpty);
      // A lone moveTo is likewise arealess.
      final dot = (PathBuilder()..moveTo(5, 5)).build();
      expect(dot.debugFlattenForOps(), isEmpty);
    });

    test('a circle flattens to a fine ring within tolerance of the radius', () {
      const cx = 50.0, cy = 50.0, r = 50.0;
      final circle =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 100, 100)))
              .build();
      final verts = _vertices(circle.debugFlattenForOps().single);
      // A circle of radius 50 subdivides into many segments at tolerance 0.02.
      expect(verts.length, greaterThan(16));
      for (final (x, y) in verts) {
        final dist = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        // Flattened vertices sit on the curve, so within a hair of the radius.
        expect(dist, closeTo(r, 0.5));
      }
    });

    test('curve endpoints are preserved exactly', () {
      // A quad from (0,0) to (20,0); the ring must contain both endpoints.
      final quad = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(10, 20, 20, 0)
            ..lineTo(10, -5)
            ..close())
          .build();
      final verts = _vertices(quad.debugFlattenForOps().single);
      expect(verts.first, (0.0, 0.0));
      expect(verts.contains((20.0, 0.0)), isTrue);
      expect(verts.contains((10.0, -5.0)), isTrue);
    });
  });
}
