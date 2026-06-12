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
  });

  group('invert parity', () {
    test('general', () {
      final inv = _general().invert();
      expect(inv, isNotNull);
      expectMatches(inv!, vm.Matrix4.inverted(_general4()), tol: 1e-9);
    });

    test('singular returns null', () {
      // Zero X-scale -> determinant 0.
      expect(Matrix.simple2d(scaleX: 0, scaleY: 3, dx: 1, dy: 1).invert(), isNull);
    });
  });
}
