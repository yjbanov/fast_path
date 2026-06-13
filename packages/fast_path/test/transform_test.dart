// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

/// Column-major 4x4 builders for the common 2D cases.
Float64List _translate(double dx, double dy) => Float64List.fromList([
      1, 0, 0, 0, //
      0, 1, 0, 0, //
      0, 0, 1, 0, //
      dx, dy, 0, 1,
    ]);

Float64List _scale(double sx, double sy) => Float64List.fromList([
      sx, 0, 0, 0, //
      0, sy, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1,
    ]);

Float64List _rotateZ(double radians) {
  final c = math.cos(radians);
  final s = math.sin(radians);
  return Float64List.fromList([
    c, s, 0, 0, //
    -s, c, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1,
  ]);
}

final Float64List _identity = Float64List.fromList([
  1, 0, 0, 0, //
  0, 1, 0, 0, //
  0, 0, 1, 0, //
  0, 0, 0, 1,
]);

Path _unitSquare() =>
    (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 10, 10))).build();

void main() {
  group('Path.transform', () {
    test('identity is a no-op (equal path)', () {
      final p = _unitSquare();
      expect(p.transform(_identity), equals(p));
    });

    test('translate matches shift', () {
      final p = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(5, 10, 10, 0)
            ..close())
          .build();
      expect(
        p.transform(_translate(100, 50)),
        equals(p.shift(const Offset(100, 50))),
      );
    });

    test('scale expands bounds about the origin', () {
      final scaled = _unitSquare().transform(_scale(3, 2));
      expect(
        scaled.getBounds(),
        equals(const Rect.fromLTRB(0, 0, 30, 20)),
      );
    });

    test('scale moves containment', () {
      final scaled = _unitSquare().transform(_scale(10, 10));
      // (50, 50) is outside the 10x10 square but inside the 100x100 one.
      expect(_unitSquare().contains(const Offset(50, 50)), isFalse);
      expect(scaled.contains(const Offset(50, 50)), isTrue);
    });

    test('90-degree rotation maps bounds predictably', () {
      // Rect (0,0,20,10) rotated 90° CCW (about origin): x' = -y,
      // y' = x → x' ∈ [-10, 0], y' ∈ [0, 20].
      final rect =
          (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 20, 10))).build();
      final rotated = rect.transform(_rotateZ(math.pi / 2));
      final b = rotated.getBounds();
      expect(b.left, closeTo(-10, 1e-4));
      expect(b.top, closeTo(0, 1e-4));
      expect(b.right, closeTo(0, 1e-4));
      expect(b.bottom, closeTo(20, 1e-4));
    });

    test('preserves conic weights (circle stays a circle)', () {
      final circle =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 100, 100)))
              .build();
      final scaled = circle.transform(_scale(2, 2));
      // Now a circle radius 100 centred (100, 100).
      expect(scaled.contains(const Offset(100, 100)), isTrue);
      expect(scaled.contains(const Offset(170, 170)), isTrue); // r≈99 < 100
      expect(scaled.contains(const Offset(180, 180)), isFalse); // r≈113 > 100
    });

    test('composition: scale then translate', () {
      final p = _unitSquare();
      final st = p.transform(_scale(2, 2)).transform(_translate(5, 5));
      expect(st.getBounds(), equals(const Rect.fromLTRB(5, 5, 25, 25)));
    });

    test('does not mutate the original', () {
      final p = _unitSquare();
      final before = p.getBounds();
      p.transform(_scale(5, 5));
      expect(p.getBounds(), equals(before));
    });

    test('perspective matrix applies the homogeneous divide', () {
      final m = Float64List.fromList([
        1, 0, 0, 0.01, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]);
      // Point (10, 0): w = 0.01*10 + 1 = 1.1 → (10/1.1, 0) ≈ (9.09, 0).
      final p = (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 10, 10)))
          .build()
          .transform(m);
      final b = p.getBounds();
      // Right edge x=10 has w=1.1 → 9.09; the far corner shrinks.
      expect(b.right, closeTo(10 / 1.1, 1e-3));
      expect(b.left, 0);
    });

    test('empty path transforms to an empty path', () {
      final empty = PathBuilder().build();
      expect(empty.transform(_scale(3, 3)).getBounds(), equals(Rect.zero));
    });
  });

  // Characterization tests: these pin the exact current behavior of the
  // matrix-handling code (which entries are read, the perspective trigger, the
  // column-major index mapping) so a refactor of how the matrix is consumed
  // is provably behavior-preserving. They are deliberately precise, not just
  // bounds/contains assertions.
  group('Path.transform — representation characterization', () {
    test('the z-column entries are ignored (points are treated as z=0)', () {
      // 2D identity, with arbitrary junk in the seven entries the 2D point map
      // never reads: m20(2) m21(6) m02(8) m12(9) m22(10) m32(11) m23(14).
      final junk = Float64List.fromList([
        1, 0, 7, 0, // 0=m00 1=m10 2=m20(junk) 3=m30
        0, 1, 9, 0, // 4=m01 5=m11 6=m21(junk) 7=m31
        3, 4, 5, 6, // 8=m02 9=m12 10=m22 11=m32  (all junk)
        0, 0, 8, 1, // 12=m03 13=m13 14=m23(junk) 15=m33
      ]);
      final p = _unitSquare();
      // Identical to an identity transform — the junk must not leak in.
      expect(p.transform(junk), equals(p));
    });

    test('off-diagonal shear reads m01 (col-major index 4), applied to y', () {
      // x-shear: x' = x + 2y, y' = y. A migration that swapped m01/m10 would
      // map (0,5) to (0,5) instead of (10,5).
      final shear = Float64List.fromList([
        1, 0, 0, 0, // col0: m00=1, m10=0
        2, 1, 0, 0, // col1: m01=2, m11=1
        0, 0, 1, 0,
        0, 0, 0, 1,
      ]);
      final src = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(0, 5)
            ..close())
          .build();
      final expected = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(10, 5) // (0,5) -> (0 + 2*5, 5)
            ..close())
          .build();
      expect(src.transform(shear), equals(expected));
    });

    test('perspective triggered by m33 != 1 alone applies the divide', () {
      // No m30/m31, but m33 = 2 -> w = 2 everywhere -> uniform half scale.
      // A trigger that only checked m30/m31 would skip the divide.
      final m = Float64List.fromList([
        1, 0, 0, 0, //
        0, 1, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 2, // index 15 = m33 = 2
      ]);
      final rect =
          (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 10, 20))).build();
      expect(rect.transform(m).getBounds(),
          equals(const Rect.fromLTRB(0, 0, 5, 10)));
    });

    test('every contour is transformed', () {
      final two = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 10, 10))
            ..addRect(const Rect.fromLTRB(20, 0, 30, 10)))
          .build();
      final scaled = two.transform(_scale(2, 2));
      expect(scaled.getBounds(), equals(const Rect.fromLTRB(0, 0, 60, 20)));
      expect(scaled.contains(const Offset(10, 10)), isTrue); // first rect 0..20
      expect(scaled.contains(const Offset(50, 10)), isTrue); // second 40..60
      expect(scaled.contains(const Offset(30, 10)), isFalse); // gap
    });

    test('negative scale reflects across the axis', () {
      final rect =
          (PathBuilder()..addRect(const Rect.fromLTRB(2, 0, 8, 4))).build();
      expect(rect.transform(_scale(-1, 1)).getBounds(),
          equals(const Rect.fromLTRB(-8, 0, -2, 4)));
    });
  });
}
