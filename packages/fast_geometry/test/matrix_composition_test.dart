// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'matrix_vm_match.dart';

void main() {
  group('composition order (this * T, T applied first)', () {
    test('scale then translate scales the translation', () {
      // scale(2).translated(3, 4) == scale * T. Applied to a point p:
      // scale*(T*p) = 2*(p + (3,4)) = 2p + (6,8). So dx/dy are scaled.
      final m = Matrix.scale(2).translated(3, 4);
      expect(m.scaleX, 2.0);
      expect(m.scaleY, 2.0);
      expect(m.dx, 6.0);
      expect(m.dy, 8.0);
    });

    test('identity composition returns the factory transform', () {
      expect(Matrix.identity.translated(5, 6),
          equals(Matrix.translation2d(dx: 5, dy: 6)));
      expect(Matrix.identity.rotatedZ(0.4), equals(Matrix.rotationZ(0.4)));
    });
  });

  group('composition canonicalization', () {
    test('no-op composition preserves the receiver', () {
      final base = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 1, dy: 2);
      expect(base.translated(0, 0), equals(base));
      expect(base.scaled(1), equals(base));
      expect(base.rotatedZ(0), equals(base));
      expect(base.skewed(0, 0), equals(base));
    });

    test('identity.scaled(1) lowers to the identity constant', () {
      expect(identical(Matrix.identity.scaled(1), Matrix.identity), isTrue);
    });
  });

  group('parity with vector_math (post-multiplication)', () {
    final base = Matrix.rotationZ(0.5);
    final base4 = vm.Matrix4.rotationZ(0.5);

    test('translated', () {
      expectMatches(base.translated(1, 2),
          base4.multiplied(vm.Matrix4.translationValues(1, 2, 0)));
    });
    test('scaled', () {
      expectMatches(base.scaled(2, 3),
          base4.multiplied(vm.Matrix4.diagonal3Values(2, 3, 1)));
    });
    test('rotatedZ', () {
      expectMatches(
          base.rotatedZ(0.3), base4.multiplied(vm.Matrix4.rotationZ(0.3)));
    });
    test('skewed', () {
      expectMatches(
          base.skewed(0.2, 0.1), base4.multiplied(vm.Matrix4.skew(0.2, 0.1)));
    });
  });
}
