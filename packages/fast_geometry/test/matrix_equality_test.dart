// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';

void main() {
  group('Matrix ==', () {
    test('equal-but-distinct matrices compare equal across shapes', () {
      // Translation.
      expect(Matrix.translation2d(dx: 5, dy: 6),
          equals(Matrix.translation2d(dx: 5, dy: 6)));
      // Simple 2D.
      expect(Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6),
          equals(Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6)));
      // General 2D (has a _rest extension).
      expect(
        Matrix.transform2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6),
        equals(Matrix.transform2d(
            scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6)),
      );
    });

    test('differing matrices compare unequal', () {
      final base = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6);
      expect(base, isNot(equals(Matrix.simple2d(scaleX: 9, scaleY: 3, dx: 5, dy: 6))));
      expect(base, isNot(equals(Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 9))));
      // Differ only in an extension field.
      final g1 =
          Matrix.transform2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6);
      final g2 =
          Matrix.transform2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.7);
      expect(g1, isNot(equals(g2)));
    });

    test('uses the canonical-lowering invariant: a lowered general matrix '
        'equals the simple one', () {
      // transform2d with zero shear lowers to simple2d (_rest == null), so it
      // must compare equal to the directly-built simple matrix.
      final lowered =
          Matrix.transform2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0, k2: 0);
      final simple = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6);
      expect(lowered.isSimple2d, isTrue);
      expect(lowered, equals(simple));
      expect(lowered.hashCode, equals(simple.hashCode));
    });

    test('identical instance is equal even with NaN entries', () {
      final m = Matrix.simple2d(scaleX: double.nan, scaleY: 1, dx: 0, dy: 0);
      expect(m == m, isTrue);
    });

    test('NaN entries make distinct instances unequal (IEEE-754)', () {
      final a = Matrix.simple2d(scaleX: double.nan, scaleY: 1, dx: 0, dy: 0);
      final b = Matrix.simple2d(scaleX: double.nan, scaleY: 1, dx: 0, dy: 0);
      expect(a == b, isFalse);
    });

    test('+0.0 and -0.0 entries compare equal', () {
      final pos = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 0.0, dy: 0.0);
      final neg = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: -0.0, dy: -0.0);
      expect(pos, equals(neg));
    });

    test('not equal to a non-Matrix', () {
      // ignore: unrelated_type_equality_checks
      expect(Matrix.identity == 'not a matrix', isFalse);
    });
  });

  group('Matrix hashCode', () {
    test('equal matrices hash equally across shapes', () {
      expect(Matrix.translation2d(dx: 5, dy: 6).hashCode,
          equals(Matrix.translation2d(dx: 5, dy: 6).hashCode));
      expect(Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6).hashCode,
          equals(Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6).hashCode));
      final h1 = Matrix.transform2d(
              scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6)
          .hashCode;
      final h2 = Matrix.transform2d(
              scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6)
          .hashCode;
      expect(h1, equals(h2));
    });

    test('+0.0 and -0.0 hash equally (consistent with ==)', () {
      final pos = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 0.0, dy: 0.0);
      final neg = Matrix.simple2d(scaleX: 2, scaleY: 3, dx: -0.0, dy: -0.0);
      expect(pos.hashCode, equals(neg.hashCode));
    });

    test('usable as a Map/Set key', () {
      final set = <Matrix>{
        Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6),
        Matrix.simple2d(scaleX: 2, scaleY: 3, dx: 5, dy: 6),
      };
      expect(set, hasLength(1));
    });
  });

  group('Matrix toString', () {
    test('renders a 4x4 grid', () {
      final s = Matrix.identity.toString();
      expect(s, contains('Matrix('));
      expect(s, contains('[1.0, 0.0, 0.0, 0.0]'));
      expect(s, contains('[0.0, 0.0, 0.0, 1.0]'));
    });

    test('includes extension entries for a general matrix', () {
      final s = Matrix.transform2d(
              scaleX: 2, scaleY: 3, dx: 5, dy: 6, k1: 0.5, k2: 0.6)
          .toString();
      expect(s, contains('[2.0, 0.5, 0.0, 5.0]'));
      expect(s, contains('[0.6, 3.0, 0.0, 6.0]'));
    });
  });
}
