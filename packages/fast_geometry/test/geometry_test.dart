// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';

void main() {
  group('Offset', () {
    test('constructs and exposes components', () {
      const o = Offset(3.0, 4.0);
      expect(o.dx, 3.0);
      expect(o.dy, 4.0);
    });

    test('zero and infinite constants', () {
      expect(Offset.zero.dx, 0.0);
      expect(Offset.zero.dy, 0.0);
      expect(Offset.infinite.dx, double.infinity);
      expect(Offset.infinite.dy, double.infinity);
    });

    test('equality and hashCode are structural', () {
      const a = Offset(1.0, 2.0);
      const b = Offset(1.0, 2.0);
      const c = Offset(1.0, 3.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('Size', () {
    test('constructs and exposes width/height', () {
      const s = Size(10.0, 20.0);
      expect(s.width, 10.0);
      expect(s.height, 20.0);
    });

    test('zero constant', () {
      expect(Size.zero, equals(const Size(0.0, 0.0)));
    });
  });

  group('Rect', () {
    test('fromLTRB exposes edges', () {
      const r = Rect.fromLTRB(1.0, 2.0, 3.0, 4.0);
      expect(r.left, 1.0);
      expect(r.top, 2.0);
      expect(r.right, 3.0);
      expect(r.bottom, 4.0);
    });

    test('fromLTWH derives right and bottom', () {
      const r = Rect.fromLTWH(1.0, 2.0, 10.0, 20.0);
      expect(r.right, 11.0);
      expect(r.bottom, 22.0);
      expect(r.width, 10.0);
      expect(r.height, 20.0);
    });

    test('fromPoints orders corners', () {
      final r = Rect.fromPoints(const Offset(5.0, 5.0), const Offset(1.0, 8.0));
      expect(r.left, 1.0);
      expect(r.top, 5.0);
      expect(r.right, 5.0);
      expect(r.bottom, 8.0);
    });

    test('fromCenter centers correctly', () {
      final r = Rect.fromCenter(
        center: const Offset(10.0, 20.0),
        width: 4.0,
        height: 6.0,
      );
      expect(r.left, 8.0);
      expect(r.top, 17.0);
      expect(r.right, 12.0);
      expect(r.bottom, 23.0);
    });

    test('fromCircle yields a square', () {
      final r = Rect.fromCircle(center: Offset.zero, radius: 5.0);
      expect(r.width, 10.0);
      expect(r.height, 10.0);
    });

    test('isEmpty when degenerate or inverted', () {
      expect(Rect.zero.isEmpty, isTrue);
      expect(const Rect.fromLTRB(5.0, 5.0, 5.0, 10.0).isEmpty, isTrue);
      expect(const Rect.fromLTRB(10.0, 5.0, 5.0, 10.0).isEmpty, isTrue);
      expect(const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0).isEmpty, isFalse);
    });

    test('equality is structural', () {
      const a = Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
      const b = Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
      const c = Rect.fromLTRB(0.0, 0.0, 2.0, 1.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('Radius', () {
    test('circular sets both axes', () {
      const r = Radius.circular(5.0);
      expect(r.x, 5.0);
      expect(r.y, 5.0);
    });

    test('elliptical sets axes independently', () {
      const r = Radius.elliptical(2.0, 3.0);
      expect(r.x, 2.0);
      expect(r.y, 3.0);
    });

    test('zero constant', () {
      expect(Radius.zero, equals(const Radius.circular(0.0)));
    });
  });

  group('RRect', () {
    test('fromRectAndRadius applies uniform corners', () {
      final r = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        const Radius.circular(2.0),
      );
      expect(r.tlRadiusX, 2.0);
      expect(r.brRadiusY, 2.0);
      expect(r.outerRect, equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)));
    });

    test('fromRectAndCorners applies per-corner radii', () {
      final r = RRect.fromRectAndCorners(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        topLeft: const Radius.circular(1.0),
        topRight: const Radius.elliptical(2.0, 3.0),
        bottomRight: const Radius.circular(4.0),
      );
      expect(r.tlRadius, equals(const Radius.circular(1.0)));
      expect(r.trRadius, equals(const Radius.elliptical(2.0, 3.0)));
      expect(r.brRadius, equals(const Radius.circular(4.0)));
      expect(r.blRadius, equals(Radius.zero));
    });

    test('equality is structural across all 12 fields', () {
      final a = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        const Radius.circular(2.0),
      );
      final b = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        const Radius.circular(2.0),
      );
      final c = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        const Radius.circular(3.0),
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('PathFillType', () {
    test('exposes both fill rules', () {
      expect(PathFillType.values, hasLength(2));
      expect(PathFillType.values, contains(PathFillType.nonZero));
      expect(PathFillType.values, contains(PathFillType.evenOdd));
    });
  });
}
