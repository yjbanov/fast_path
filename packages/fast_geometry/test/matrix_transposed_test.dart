// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'matrix_vm_match.dart';

void main() {
  group('transposed shape', () {
    test('diagonal matrices are symmetric (returns the receiver)', () {
      expect(identical(Matrix.identity.transposed(), Matrix.identity), isTrue);
      final s = Matrix.scale(2, 3);
      expect(identical(s.transposed(), s), isTrue);
    });

    test('translation moves into the bottom row and becomes general', () {
      final t = Matrix.translation2d(dx: 5, dy: 6).transposed();
      expect(t.m30, 5.0);
      expect(t.m31, 6.0);
      expect(t.m03, 0.0);
      expect(t.m13, 0.0);
      expect(t.isSimple2d, isFalse);
    });
  });

  group('transposed identities', () {
    test('is an involution (transposing twice restores the original)', () {
      final m = Matrix.transform2d(
          scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6);
      expect(m.transposed().transposed(), equals(m));
    });
  });

  group('parity with vector_math', () {
    test('general 2D affine', () {
      expectMatches(
          Matrix.rotationZ(0.5).transposed(), vm.Matrix4.rotationZ(0.5).transposed());
    });

    test('translation', () {
      expectMatches(
        Matrix.translation2d(dx: 5, dy: 6).transposed(),
        (vm.Matrix4.identity()..setTranslationRaw(5, 6, 0)).transposed(),
      );
    });
  });
}
