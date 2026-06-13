// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

Path _triangle() => (PathBuilder()
      ..moveTo(0, 0)
      ..lineTo(10, 0)
      ..lineTo(5, 10)
      ..close())
    .build();

void main() {
  group('PathBuilder.addPath', () {
    test('appends with offset', () {
      final path = (PathBuilder()
            ..addPath(_triangle(), const Offset(100, 50)))
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(100, 50, 110, 60)),
      );
      expect(path.contains(const Offset(105, 53)), isTrue);
    });

    test('zero offset reproduces the source exactly', () {
      final src = _triangle();
      final path = (PathBuilder()..addPath(src, Offset.zero)).build();
      expect(path, equals(src));
    });

    test('appends after existing contours without joining', () {
      final path = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 10, 10))
            ..addPath(_triangle(), const Offset(50, 0)))
          .build();
      expect(path.contains(const Offset(5, 5)), isTrue); // rect
      expect(path.contains(const Offset(55, 3)), isTrue); // triangle
      expect(path.contains(const Offset(30, 5)), isFalse); // gap between
    });

    test('curved source survives the copy (conic weights preserved)', () {
      final src =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 100, 100)))
              .build();
      final moved = (PathBuilder()..addPath(src, const Offset(10, 0))).build();
      // Circle now centered (60, 50) radius 50.
      expect(moved.contains(const Offset(60, 50)), isTrue);
      // (95, 85) is inside (r ≈ 49.5 < 50) — only a true conic agrees
      // there; a chord approximation would cut it off.
      expect(moved.contains(const Offset(95, 85)), isTrue);
      // (100, 88): dx=40, dy=38 → r ≈ 55.2 > 50 — outside, though
      // still inside the bounding box corner band.
      expect(moved.contains(const Offset(100, 88)), isFalse);
    });

    test('affine matrix4 applies before offset', () {
      // 90° clockwise rotation (column-major): x' = -y, y' = x.
      final rot = Float64List.fromList([
        math.cos(math.pi / 2), math.sin(math.pi / 2), 0, 0, //
        -math.sin(math.pi / 2), math.cos(math.pi / 2), 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]);
      final src = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 20, 10)))
          .build();
      final path = (PathBuilder()
            ..addPath(src, const Offset(100, 0), matrix4: rot))
          .build();
      // Rect (0,0,20,10) rotated 90° CW → x' ∈ [-10, 0], y' ∈ [0, 20];
      // then offset (100, 0) → (90, 0, 100, 20).
      final b = path.getBounds();
      expect(b.left, closeTo(90, 1e-6));
      expect(b.top, closeTo(0, 1e-6));
      expect(b.right, closeTo(100, 1e-6));
      expect(b.bottom, closeTo(20, 1e-6));
    });

    test('perspective matrix applies the homogeneous divide', () {
      // Same result as Path.transform with the same perspective matrix.
      final perspective = Float64List.fromList([
        1, 0, 0, 0.004, //
        0, 1, 0, 0.002, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]);
      final src = (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 40, 30)))
          .build();
      final viaAddPath =
          (PathBuilder()..addPath(src, Offset.zero, matrix4: perspective))
              .build();
      final viaTransform = src.transform(perspective);
      expect(viaAddPath, equals(viaTransform));
    });
  });

  group('PathBuilder.extendWithPath', () {
    test('joins the first contour with a line', () {
      final extended = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..extendWithPath(_triangle(), const Offset(50, 0)))
          .build();
      final explicit = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..lineTo(50, 0) // join line: source first moveTo became lineTo
            ..lineTo(60, 0)
            ..lineTo(55, 10)
            ..close())
          .build();
      expect(extended, equals(explicit));
    });

    test('on an empty builder behaves like addPath', () {
      final viaExtend =
          (PathBuilder()..extendWithPath(_triangle(), Offset.zero)).build();
      final viaAdd =
          (PathBuilder()..addPath(_triangle(), Offset.zero)).build();
      expect(viaExtend, equals(viaAdd));
    });

    test('only the first contour joins; later contours stay separate', () {
      final twoContours = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(10, 0)
            ..close()
            ..moveTo(20, 0)
            ..lineTo(30, 0)
            ..close())
          .build();
      final extended = (PathBuilder()
            ..moveTo(100, 100)
            ..extendWithPath(twoContours, Offset.zero))
          .build();
      final explicit = (PathBuilder()
            ..moveTo(100, 100)
            ..lineTo(0, 0) // first moveTo joined
            ..lineTo(10, 0)
            ..close()
            ..moveTo(20, 0) // second contour starts fresh
            ..lineTo(30, 0)
            ..close())
          .build();
      expect(extended, equals(explicit));
    });
  });

  // Characterization tests pinning the exact matrix behavior of the shared
  // append machinery before a refactor of how the matrix is consumed.
  group('matrix4 behavior — characterization', () {
    final junk = Float64List.fromList([
      1, 0, 7, 0, // 2=m20(junk)
      0, 1, 9, 0, // 6=m21(junk)
      3, 4, 5, 6, // 8,9,10,11 = m02,m12,m22,m32 (junk)
      0, 0, 8, 1, // 14=m23(junk)
    ]);

    test('addPath ignores the z-column entries', () {
      final src = _triangle();
      final out =
          (PathBuilder()..addPath(src, Offset.zero, matrix4: junk)).build();
      expect(out, equals(src)); // junk in z entries must not leak in
    });

    test('addPath perspective + non-zero offset == transform then translate', () {
      // Pins the documented "transform by matrix4, then translate by offset"
      // model: the offset is applied after the homogeneous divide. (This is
      // the corner that diverges from dart:ui, so it is a unit test, not a
      // parity test.)
      final persp = Float64List.fromList([
        1, 0, 0, 0.004, //
        0, 1, 0, 0.002, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]);
      final src =
          (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 40, 30))).build();
      final viaAddPath =
          (PathBuilder()..addPath(src, const Offset(100, 50), matrix4: persp))
              .build();
      final viaCompose = src.transform(persp).shift(const Offset(100, 50));
      expect(viaAddPath, equals(viaCompose));
    });

    test('extendWithPath transforms the joined first point and the rest', () {
      // src points (5,0),(5,5); scale x2 -> (10,0),(10,10); + offset (1,1) ->
      // (11,1),(11,11). The opening moveTo(5,0) becomes the join lineTo.
      final scale2 = Float64List.fromList([
        2, 0, 0, 0, //
        0, 2, 0, 0, //
        0, 0, 1, 0, //
        0, 0, 0, 1,
      ]);
      final src = (PathBuilder()
            ..moveTo(5, 0)
            ..lineTo(5, 5)
            ..close())
          .build();
      final extended = (PathBuilder()
            ..moveTo(0, 0)
            ..extendWithPath(src, const Offset(1, 1), matrix4: scale2))
          .build();
      final explicit = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(11, 1) // joined first point, transformed
            ..lineTo(11, 11) // remaining point, transformed
            ..close())
          .build();
      expect(extended, equals(explicit));
    });
  });
}
