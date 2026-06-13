// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math';

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'matrix_vm_match.dart';

void main() {
  // A fixed seed keeps this reproducible (no CI flake) while still sweeping a
  // wide variety of fully-general 4x4 matrices. Random 16-value matrices are
  // essentially never affine and never near-singular, so this exercises the
  // general path richly; the affine fast paths and deliberate singular cases
  // are covered by the targeted tests.
  test('property-based round-trip fuzzing against vector_math', () {
    final rand = Random(42);

    for (var i = 0; i < 100; i++) {
      final v = List<double>.generate(16, (_) => (rand.nextDouble() - 0.5) * 200);

      final m = Matrix.transform(
        m00: v[0], m10: v[1], m20: v[2], m30: v[3],
        m01: v[4], m11: v[5], m21: v[6], m31: v[7],
        m02: v[8], m12: v[9], m22: v[10], m32: v[11],
        m03: v[12], m13: v[13], m23: v[14], m33: v[15],
      );
      final m4 = vm.Matrix4(
        v[0], v[1], v[2], v[3], //
        v[4], v[5], v[6], v[7], //
        v[8], v[9], v[10], v[11], //
        v[12], v[13], v[14], v[15], //
      );

      // Determinant: a *relative* tolerance. |det| here ranges over many orders
      // of magnitude (up to ~1e8), so an absolute tolerance would either be
      // meaningless or coincidental.
      final d4 = m4.determinant();
      expect(m.determinant(), closeTo(d4, 1e-9 * d4.abs() + 1e-12),
          reason: 'determinant[$i]');

      // These matrices are well-conditioned, so invert and the multiply
      // round-trip hold to tight tolerances (the previous 1e-5/1e-6 absolute
      // tolerances had ~170x slack that masked nothing but also proved little).
      final inv = m.invert();
      expect(inv, isNotNull, reason: 'invert[$i]');
      expectMatches(inv!, vm.Matrix4.inverted(m4), tol: 1e-9);
      expectMatches(m * inv, vm.Matrix4.identity(), tol: 1e-9);

      // transformPoint parity, with a relative tolerance. Skip points whose
      // perspective w is near zero: the divide blows up there and a comparison
      // against any fixed tolerance is meaningless.
      final pt = Offset(v[0], v[1]);
      final w = m.m30 * pt.dx + m.m31 * pt.dy + m.m33;
      if (w.abs() > 1e-3) {
        final v4 = m4.perspectiveTransform(vm.Vector3(pt.dx, pt.dy, 0));
        final mapped = m.transformPoint(pt);
        expect(mapped.dx, closeTo(v4.x, 1e-6 * v4.x.abs() + 1e-9),
            reason: 'transformPoint.dx[$i]');
        expect(mapped.dy, closeTo(v4.y, 1e-6 * v4.y.abs() + 1e-9),
            reason: 'transformPoint.dy[$i]');
      }
    }
  });
}
