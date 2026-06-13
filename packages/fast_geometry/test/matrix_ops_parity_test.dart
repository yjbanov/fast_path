// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

// Parity tests for the core arithmetic ops (multiply, determinant, invert)
// against vector_math. These predate — and guard — the representation
// optimization (the 4->6 inline-core widening): they pin the observable
// behavior of the general path so the rewrite can't silently change it.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'matrix_vm_match.dart';

/// A general, invertible 3D-affine matrix (has a non-trivial extension tail in
/// either representation).
Matrix _general() => Matrix.transform(
      m00: 2, m01: 0.3, m02: 0.1, m03: 1,
      m10: 0.2, m11: 3, m12: 0.4, m13: 2,
      m20: 0.5, m21: 0.6, m22: 1.5, m23: 0.7,
      m30: 0, m31: 0, m32: 0, m33: 1,
    );

/// The same matrix as a vector_math Matrix4 (column-major constructor args).
vm.Matrix4 _general4() => vm.Matrix4(
      2, 0.2, 0.5, 0, // col 0
      0.3, 3, 0.6, 0, // col 1
      0.1, 0.4, 1.5, 0, // col 2
      1, 2, 0.7, 1, // col 3
    );

void main() {
  group('multiply parity', () {
    test('affine x general', () {
      final a = Matrix.rotationZ(0.5);
      final a4 = vm.Matrix4.rotationZ(0.5);
      expectMatches(a * _general(), a4.multiplied(_general4()), tol: 1e-12);
    });

    test('general x affine (other order)', () {
      final a = Matrix.rotationZ(0.5);
      final a4 = vm.Matrix4.rotationZ(0.5);
      expectMatches(_general() * a, _general4().multiplied(a4), tol: 1e-12);
    });

    test('general x general', () {
      expectMatches(
          _general() * _general(), _general4().multiplied(_general4()),
          tol: 1e-12);
    });
  });

  group('determinant parity', () {
    test('general', () {
      expect(_general().determinant(), closeTo(_general4().determinant(), 1e-12));
    });
    test('simple', () {
      final s = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 4, dy: 5);
      final s4 = vm.Matrix4.diagonal3Values(2, 3, 1)
        ..setEntry(0, 3, 4)
        ..setEntry(1, 3, 5);
      expect(s.determinant(), closeTo(s4.determinant(), 1e-12));
    });
    test('affine with shear', () {
      final a = Matrix.rotationZ(0.5);
      final a4 = vm.Matrix4.rotationZ(0.5);
      expect(a.determinant(), closeTo(a4.determinant(), 1e-12));
    });
  });

  group('invert parity', () {
    test('general', () {
      final inv = _general().invert();
      expect(inv, isNotNull);
      expectMatches(inv!, vm.Matrix4.inverted(_general4()), tol: 1e-9);
    });

    test('singular returns null', () {
      // Zero X-scale -> determinant 0 (affine fast path).
      expect(Matrix.simple2d(scaleX: 0, scaleY: 3, dx: 1, dy: 1).invert(), isNull);
    });

    test('general (3D) singular returns null', () {
      // A zero row makes the determinant exactly 0.0, exercising the null
      // return in the *general* inverse path (not just the affine fast path).
      // Note: invert() uses an exact `det == 0` test, so this needs a
      // structurally-singular matrix, not merely a near-singular one.
      final singular = Matrix.transform(
        m00: 0, m01: 0, m02: 0, m03: 0, // zero row
        m10: 1, m11: 2, m12: 3, m13: 4,
        m20: 5, m21: 6, m22: 7, m23: 8,
        m30: 9, m31: 1, m32: 2, m33: 3,
      );
      expect(singular.isSimple2d, isFalse); // confirm the general path
      expect(singular.determinant(), 0.0);
      expect(singular.invert(), isNull);
    });

    test('affine with shear', () {
      final a = Matrix.rotationZ(0.5);
      final a4 = vm.Matrix4.rotationZ(0.5);
      expectMatches(a.invert()!, vm.Matrix4.inverted(a4), tol: 1e-12);
    });

    test('invert of NaN matrix yields a NaN matrix (not null)', () {
      final nanMatrix = Matrix.simple2d(scaleX: double.nan, scaleY: 1, dx: 0, dy: 0);
      final inv = nanMatrix.invert();
      expect(inv, isNotNull);
      expect(inv!.m00.isNaN, isTrue);
    });
  });

  group('add / negate parity (element-wise, matches Matrix4)', () {
    test('identity + identity doubles the full diagonal', () {
      final sum = Matrix.identity + Matrix.identity;
      expect(sum.m00, 2.0);
      expect(sum.m11, 2.0);
      expect(sum.m22, 2.0); // the tail is summed too, not left at 1
      expect(sum.m33, 2.0);
    });

    test('affine + affine', () {
      final a = Matrix.rotationZ(0.5);
      final a4 = vm.Matrix4.rotationZ(0.5);
      expectMatches(a + a, a4 + a4, tol: 1e-12);
    });

    test('general + general', () {
      expectMatches(_general() + _general(), _general4() + _general4(),
          tol: 1e-12);
    });

    test('negate: general', () {
      expectMatches(-_general(), _general4()..negate(), tol: 1e-12);
    });
  });
}
