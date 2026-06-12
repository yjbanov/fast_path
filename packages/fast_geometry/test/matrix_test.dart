import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:fast_geometry/fast_geometry.dart';

void main() {
  group('Matrix tests', () {
    test('Matrix.identity', () {
      const m = Matrix.identity;
      expect(m.scaleX, 1.0);
      expect(m.scaleY, 1.0);
      expect(m.dx, 0.0);
      expect(m.dy, 0.0);
      expect(m.isTranslation2d, true);
      expect(m.isSimple2d, true);
      expect(m.isAffine2d, true);
      
      expect(m.m00, 1.0);
      expect(m.m01, 0.0);
      expect(m.m02, 0.0);
      expect(m.m03, 0.0);
      expect(m.m10, 0.0);
      expect(m.m11, 1.0);
      expect(m.m22, 1.0);
      expect(m.m33, 1.0);
    });

    test('translation2d constructor and predicates', () {
      final t = Matrix.translation2d(dx: 10, dy: 20);
      expect(t.scaleX, 1.0);
      expect(t.scaleY, 1.0);
      expect(t.dx, 10.0);
      expect(t.dy, 20.0);
      expect(t.isTranslation2d, true);
      expect(t.isSimple2d, true);
      expect(t.isAffine2d, true);

      // (0,0) translation lowers to identity constant
      final t0 = Matrix.translation2d(dx: 0, dy: 0);
      expect(identical(t0, Matrix.identity), true);
    });

    test('simple2d constructor', () {
      final s = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6);
      expect(s.scaleX, 2.0);
      expect(s.scaleY, 3.0);
      expect(s.dx, 5.0);
      expect(s.dy, 6.0);
      expect(s.isTranslation2d, false);
      expect(s.isSimple2d, true);
      expect(s.isAffine2d, true);

      // (1,1) scaling lowers to translation
      final s1 = Matrix.simple2d(scaleX: 1, scaleY: 1, dx: 4, dy: 4);
      expect(s1.isTranslation2d, true);
    });

    test('transform2d constructor', () {
      final t2d = Matrix.transform2d(
        scaleX: 2.0,
        scaleY: 3.0,
        dx: 4.0,
        dy: 5.0,
        k1: 0.5,
        k2: 0.6,
      );
      expect(t2d.scaleX, 2.0);
      expect(t2d.scaleY, 3.0);
      expect(t2d.m01, 0.5);
      expect(t2d.m10, 0.6);
      expect(t2d.dx, 4.0);
      expect(t2d.dy, 5.0);
      expect(t2d.isTranslation2d, false);
      expect(t2d.isSimple2d, false);
      expect(t2d.isAffine2d, true);
    });

    test('transform constructor (3D/Perspective)', () {
      final m = Matrix.transform(
        m00: 1.0, m01: 2.0, m02: 3.0, m03: 4.0,
        m10: 5.0, m11: 6.0, m12: 7.0, m13: 8.0,
        m20: 9.0, m21: 10.0, m22: 11.0, m23: 12.0,
        m30: 0.1, m31: 0.2, m32: 0.3, m33: 1.0,
      );
      expect(m.scaleX, 1.0);
      expect(m.m01, 2.0);
      expect(m.m02, 3.0);
      expect(m.dx, 4.0);
      expect(m.m10, 5.0);
      expect(m.scaleY, 6.0);
      expect(m.m12, 7.0);
      expect(m.dy, 8.0);
      expect(m.m20, 9.0);
      expect(m.m21, 10.0);
      expect(m.m22, 11.0);
      expect(m.m23, 12.0);
      expect(m.m30, 0.1);
      expect(m.m31, 0.2);
      expect(m.m32, 0.3);
      expect(m.m33, 1.0);

      expect(m.isTranslation2d, false);
      expect(m.isSimple2d, false);
      expect(m.isAffine2d, false); // because m30 and m31 are non-zero
    });

    test('Float64List conversion extension', () {
      final list = Float64List.fromList([
        1, 5, 9, 13,
        2, 6, 10, 14,
        3, 7, 11, 15,
        4, 8, 12, 16,
      ]);
      final m = list.toMatrix();
      expect(m.m00, 1.0);
      expect(m.m10, 5.0);
      expect(m.m20, 9.0);
      expect(m.m30, 13.0);
      expect(m.m01, 2.0);
      expect(m.m11, 6.0);
      expect(m.m21, 10.0);
      expect(m.m31, 14.0);
      expect(m.m02, 3.0);
      expect(m.m12, 7.0);
      expect(m.m22, 11.0);
      expect(m.m32, 15.0);
      expect(m.m03, 4.0);
      expect(m.m13, 8.0);
      expect(m.m23, 12.0);
      expect(m.m33, 16.0);
    });

    test('Matrix operations - multiply, invert, determinant', () {
      // Identity multiplication
      expect(Matrix.identity * Matrix.identity, equals(Matrix.identity));
      
      final t = Matrix.translation2d(dx: 10, dy: 20);
      expect(t * Matrix.identity, equals(t));
      expect(Matrix.identity * t, equals(t));

      final scale = Matrix.simple2d(scaleX: 2.0, scaleY: 3.0, dx: 0, dy: 0);
      final combined = scale * t; // scale then translate? Wait, operator * is this * other.
      // this * other represents applying other, then applying this? Or this then other?
      // In matrix algebra: (this) * (other).
      // If we multiply scaling by translation:
      // [2 0 0 0]   [1 0 0 10]   [2 0 0 20]
      // [0 3 0 0] * [0 1 0 20] = [0 3 0 60]
      // [0 0 1 0]   [0 0 1  0]   [0 0 1  0]
      // [0 0 0 1]   [0 0 0  1]   [0 0 0  1]
      expect(combined.scaleX, 2.0);
      expect(combined.scaleY, 3.0);
      expect(combined.dx, 20.0);
      expect(combined.dy, 60.0);

      // Determinant
      expect(scale.determinant(), 6.0);
      expect(t.determinant(), 1.0);

      // Invert
      final invScale = scale.invert();
      expect(invScale, isNotNull);
      expect(invScale!.scaleX, 0.5);
      expect(invScale.scaleY, 1.0 / 3.0);
      expect(invScale.dx, 0.0);
      expect(invScale.dy, 0.0);

      final invCombined = combined.invert();
      expect(invCombined, isNotNull);
      final identityProduct = combined * invCombined!;
      expect(identityProduct.scaleX, closeTo(1.0, 1e-9));
      expect(identityProduct.scaleY, closeTo(1.0, 1e-9));
      expect(identityProduct.dx, closeTo(0.0, 1e-9));
      expect(identityProduct.dy, closeTo(0.0, 1e-9));
    });
  });
}
