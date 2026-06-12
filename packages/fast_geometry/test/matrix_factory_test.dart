// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'matrix_vm_match.dart';

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
