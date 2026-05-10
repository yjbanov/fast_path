// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

Path _square(double size, {Offset origin = Offset.zero}) {
  return (PathBuilder()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(origin.dx + size, origin.dy)
        ..lineTo(origin.dx + size, origin.dy + size)
        ..lineTo(origin.dx, origin.dy + size)
        ..close())
      .build();
}

void main() {
  group('Path.getBounds', () {
    test('empty path returns Rect.zero', () {
      expect(PathBuilder().build().getBounds(), equals(Rect.zero));
    });

    test('returns the tight bounding box of all points', () {
      final path = (PathBuilder()
            ..moveTo(-5.0, 2.0)
            ..lineTo(10.0, -3.0)
            ..lineTo(0.0, 8.0)
            ..close())
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(-5.0, -3.0, 10.0, 8.0)),
      );
    });

    test('cached on first call (returns identical Rect)', () {
      final path = _square(10.0);
      final first = path.getBounds();
      final second = path.getBounds();
      expect(identical(first, second), isTrue);
    });
  });

  group('Path.contains (nonZero)', () {
    test('empty path contains nothing', () {
      final empty = PathBuilder().build();
      expect(empty.contains(Offset.zero), isFalse);
    });

    test('point clearly inside a unit square is contained', () {
      final square = _square(10.0);
      expect(square.contains(const Offset(5.0, 5.0)), isTrue);
    });

    test('point clearly outside the square is not contained', () {
      final square = _square(10.0);
      expect(square.contains(const Offset(-1.0, 5.0)), isFalse);
      expect(square.contains(const Offset(11.0, 5.0)), isFalse);
      expect(square.contains(const Offset(5.0, -1.0)), isFalse);
      expect(square.contains(const Offset(5.0, 11.0)), isFalse);
    });

    test('open contour is implicitly closed for fill containment', () {
      // Triangle without an explicit close should still contain its
      // interior.
      final triangle = (PathBuilder()
            ..moveTo(0.0, 0.0)
            ..lineTo(10.0, 0.0)
            ..lineTo(5.0, 10.0))
          .build();
      expect(triangle.contains(const Offset(5.0, 3.0)), isTrue);
      expect(triangle.contains(const Offset(0.0, 9.0)), isFalse);
    });

    test('two nested squares with same winding fill the whole region', () {
      // Both contours wind clockwise. Under nonZero, the inner region's
      // winding sums to 2, which is non-zero — so it counts as inside.
      final builder = PathBuilder()
        ..moveTo(0.0, 0.0)
        ..lineTo(10.0, 0.0)
        ..lineTo(10.0, 10.0)
        ..lineTo(0.0, 10.0)
        ..close()
        ..moveTo(3.0, 3.0)
        ..lineTo(7.0, 3.0)
        ..lineTo(7.0, 7.0)
        ..lineTo(3.0, 7.0)
        ..close();
      final path = builder.build();
      expect(path.contains(const Offset(5.0, 5.0)), isTrue);
      expect(path.contains(const Offset(1.0, 1.0)), isTrue);
    });
  });

  group('Path.contains (evenOdd)', () {
    test('two nested squares form a frame (hole in the middle)', () {
      final builder = PathBuilder()
        ..fillType = PathFillType.evenOdd
        ..moveTo(0.0, 0.0)
        ..lineTo(10.0, 0.0)
        ..lineTo(10.0, 10.0)
        ..lineTo(0.0, 10.0)
        ..close()
        ..moveTo(3.0, 3.0)
        ..lineTo(7.0, 3.0)
        ..lineTo(7.0, 7.0)
        ..lineTo(3.0, 7.0)
        ..close();
      final path = builder.build();
      // Outer ring is inside.
      expect(path.contains(const Offset(1.0, 1.0)), isTrue);
      // Inner hole is outside.
      expect(path.contains(const Offset(5.0, 5.0)), isFalse);
    });
  });

  group('Path.fillType', () {
    test('is the value set on the builder at build time', () {
      final builder = PathBuilder()..fillType = PathFillType.evenOdd;
      expect(builder.build().fillType, equals(PathFillType.evenOdd));
      builder.fillType = PathFillType.nonZero;
      expect(builder.build().fillType, equals(PathFillType.nonZero));
    });
  });

  group('Path equality and hashCode', () {
    test('paths built from the same call sequence compare equal', () {
      expect(_square(10.0), equals(_square(10.0)));
      expect(_square(10.0).hashCode, equals(_square(10.0).hashCode));
    });

    test('different point coordinates are not equal', () {
      expect(_square(10.0), isNot(equals(_square(20.0))));
    });

    test('different fillType makes paths unequal', () {
      final a = _square(10.0);
      final b = (PathBuilder()
            ..fillType = PathFillType.evenOdd
            ..moveTo(0.0, 0.0)
            ..lineTo(10.0, 0.0)
            ..lineTo(10.0, 10.0)
            ..lineTo(0.0, 10.0)
            ..close())
          .build();
      expect(a, isNot(equals(b)));
    });

    test('hashCode is cached (same value across calls)', () {
      final path = _square(10.0);
      expect(path.hashCode, equals(path.hashCode));
    });

    test('usable as a Map key', () {
      final cache = <Path, String>{
        _square(10.0): 'small',
        _square(20.0): 'big',
      };
      expect(cache[_square(10.0)], equals('small'));
      expect(cache[_square(20.0)], equals('big'));
    });
  });
}
