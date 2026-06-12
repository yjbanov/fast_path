// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// All factory results agree with vector_math to this absolute tolerance.
/// The arithmetic is identical (both use dart:math), so the gap is just
/// floating-point reassociation; 1e-12 is comfortably loose.
const double _tol = 1e-12;

/// Asserts [actual]'s 16 entries match [expected]'s within [_tol]. `mRC` is
/// row R, column C on our side; vector_math exposes the same via `entry(R, C)`.
void expectMatches(Matrix actual, vm.Matrix4 expected) {
  final actualRows = <double>[
    actual.m00, actual.m01, actual.m02, actual.m03, //
    actual.m10, actual.m11, actual.m12, actual.m13, //
    actual.m20, actual.m21, actual.m22, actual.m23, //
    actual.m30, actual.m31, actual.m32, actual.m33, //
  ];
  for (var i = 0; i < 16; i++) {
    final r = i ~/ 4;
    final c = i % 4;
    expect(actualRows[i], closeTo(expected.entry(r, c), _tol),
        reason: 'entry m$r$c');
  }
}

void main() {
  group('factory canonicalization & shape', () {
    test('rotationZ(0), scale(1), skew(0,0), rotationX(0) lower to identity', () {
      expect(identical(Matrix.rotationZ(0), Matrix.identity), isTrue);
      expect(identical(Matrix.scale(1), Matrix.identity), isTrue);
      expect(identical(Matrix.skew(0, 0), Matrix.identity), isTrue);
      expect(identical(Matrix.rotationX(0), Matrix.identity), isTrue);
    });

    test('scale shapes', () {
      final s = Matrix.scale(2, 3);
      expect(s.scaleX, 2.0);
      expect(s.scaleY, 3.0);
      expect(s.isSimple2d, isTrue);
      expect(s.isTranslation2d, isFalse);
      // Single-argument form is uniform.
      expect(Matrix.scale(4).scaleY, 4.0);
    });

    test('rotationZ / skew are general 2D affine', () {
      final r = Matrix.rotationZ(0.5);
      expect(r.isSimple2d, isFalse);
      expect(r.isAffine2d, isTrue);
      final k = Matrix.skew(0.3, 0.4);
      expect(k.isSimple2d, isFalse);
      expect(k.isAffine2d, isTrue);
    });

    test('rotationX / orthographic are affine but not simple', () {
      expect(Matrix.rotationX(0.5).isSimple2d, isFalse);
      expect(Matrix.rotationX(0.5).isAffine2d, isTrue);
      final o = Matrix.orthographic(-1, 1, -1, 1, 1, 100);
      expect(o.isSimple2d, isFalse);
      expect(o.isAffine2d, isTrue);
    });

    test('perspective is not affine', () {
      final p = Matrix.perspective(1.0, 1.5, 0.1, 100);
      expect(p.isAffine2d, isFalse);
    });
  });

  group('parity with vector_math', () {
    test('rotationX', () {
      expectMatches(Matrix.rotationX(0.7), vm.Matrix4.rotationX(0.7));
    });
    test('rotationY', () {
      expectMatches(Matrix.rotationY(0.7), vm.Matrix4.rotationY(0.7));
    });
    test('rotationZ', () {
      expectMatches(Matrix.rotationZ(0.7), vm.Matrix4.rotationZ(0.7));
    });
    test('skew', () {
      expectMatches(Matrix.skew(0.3, 0.4), vm.Matrix4.skew(0.3, 0.4));
    });
    test('scale', () {
      expectMatches(Matrix.scale(2, 3), vm.Matrix4.diagonal3Values(2, 3, 1));
    });
    test('orthographic', () {
      expectMatches(
        Matrix.orthographic(-2, 2, -1.5, 1.5, 0.5, 50),
        vm.makeOrthographicMatrix(-2, 2, -1.5, 1.5, 0.5, 50),
      );
    });
    test('perspective', () {
      expectMatches(
        Matrix.perspective(1.0, 1.5, 0.1, 100),
        vm.makePerspectiveMatrix(1.0, 1.5, 0.1, 100),
      );
    });
  });
}
