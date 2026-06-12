// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

const double _tol = 1e-12;

void expectOffset(Offset actual, double dx, double dy) {
  expect(actual.dx, closeTo(dx, _tol), reason: 'dx');
  expect(actual.dy, closeTo(dy, _tol), reason: 'dy');
}

/// Bounding box of [rect]'s four corners transformed by [m4] (with perspective
/// divide), the reference for [Matrix.transformRect].
Rect _cornerBounds(vm.Matrix4 m4, Rect rect) {
  final corners = <vm.Vector3>[
    m4.perspectiveTransform(vm.Vector3(rect.left, rect.top, 0)),
    m4.perspectiveTransform(vm.Vector3(rect.right, rect.top, 0)),
    m4.perspectiveTransform(vm.Vector3(rect.right, rect.bottom, 0)),
    m4.perspectiveTransform(vm.Vector3(rect.left, rect.bottom, 0)),
  ];
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final c in corners) {
    minX = c.x < minX ? c.x : minX;
    minY = c.y < minY ? c.y : minY;
    maxX = c.x > maxX ? c.x : maxX;
    maxY = c.y > maxY ? c.y : maxY;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

void main() {
  group('transformPoint fast paths', () {
    test('translation', () {
      expectOffset(
          Matrix.translation2d(dx: 5, dy: 6).transformPoint(const Offset(1, 1)),
          6,
          7);
    });
    test('scale', () {
      expectOffset(
          Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 0, dy: 0)
              .transformPoint(const Offset(1, 1)),
          2,
          3);
    });
  });

  group('transformVector', () {
    test('ignores translation', () {
      expectOffset(
          Matrix.translation2d(dx: 5, dy: 6).transformVector(const Offset(1, 1)),
          1,
          1);
    });
    test('applies scale and shear', () {
      expectOffset(
          Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 9, dy: 9)
              .transformVector(const Offset(1, 1)),
          2,
          3);
    });
  });

  group('transformRect fast path', () {
    test('translation', () {
      final r = Matrix.translation2d(dx: 5, dy: 6)
          .transformRect(const Rect.fromLTRB(0, 0, 2, 2));
      expect(r, equals(const Rect.fromLTRB(5, 6, 7, 8)));
    });
    test('negative scale reorders corners', () {
      final r = Matrix.simple2d(scaleX: -1, scaleY: 1, dx: 0, dy: 0)
          .transformRect(const Rect.fromLTRB(1, 0, 3, 2));
      expect(r.left, -3.0);
      expect(r.right, -1.0);
      expect(r.top, 0.0);
      expect(r.bottom, 2.0);
    });
  });

  group('parity with vector_math', () {
    final base = Matrix.rotationZ(0.5);
    final base4 = vm.Matrix4.rotationZ(0.5);
    const points = <Offset>[Offset(1, 2), Offset(-3, 4), Offset(0, 0)];

    test('transformPoint (affine)', () {
      for (final p in points) {
        final v = base4.perspectiveTransform(vm.Vector3(p.dx, p.dy, 0));
        expectOffset(base.transformPoint(p), v.x, v.y);
      }
    });

    test('transformPoint (perspective divide)', () {
      // A non-affine matrix whose w varies with x and y (m30, m31 != 0), so the
      // divide is exercised with finite, non-zero w — unlike a pure GL
      // perspective matrix, which yields w == 0 for the z == 0 inputs
      // transformPoint always uses.
      final pm = Matrix.transform(
        m00: 2, m01: 0.5, m02: 0, m03: 1,
        m10: 0.3, m11: 3, m12: 0, m13: 2,
        m20: 0, m21: 0, m22: 1, m23: 0,
        m30: 0.1, m31: 0.2, m32: 0, m33: 1,
      );
      final pm4 = vm.Matrix4(
        2, 0.3, 0, 0.1, // col 0
        0.5, 3, 0, 0.2, // col 1
        0, 0, 1, 0, // col 2
        1, 2, 0, 1, // col 3
      );
      expect(pm.isAffine2d, isFalse);
      for (final p in <Offset>[const Offset(0.3, 0.4), const Offset(-0.6, 0.2)]) {
        final v = pm4.perspectiveTransform(vm.Vector3(p.dx, p.dy, 0));
        expectOffset(pm.transformPoint(p), v.x, v.y);
      }
    });

    test('transformVector', () {
      for (final p in points) {
        final v = base4.transformed(vm.Vector4(p.dx, p.dy, 0, 0));
        expectOffset(base.transformVector(p), v.x, v.y);
      }
    });

    test('transformRect (rotated bounding box)', () {
      const rect = Rect.fromLTRB(1, 2, 5, 8);
      final expected = _cornerBounds(base4, rect);
      final actual = base.transformRect(rect);
      expect(actual.left, closeTo(expected.left, _tol));
      expect(actual.top, closeTo(expected.top, _tol));
      expect(actual.right, closeTo(expected.right, _tol));
      expect(actual.bottom, closeTo(expected.bottom, _tol));
    });
  });
}
