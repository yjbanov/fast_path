// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';

/// Per-field inequality matrix: asserts [base] is unequal to each variant —
/// where each variant differs from [base] in exactly *one* field — and that the
/// hashCodes distinguish them too. This is what catches an `==` or `hashCode`
/// that silently drops a field (the classic "all instances share one
/// coordinate so inequality on the others is never exercised" gap).
void _distinctByField(Object base, Map<String, Object> variants) {
  for (final entry in variants.entries) {
    final field = entry.key;
    final variant = entry.value;
    expect(base == variant, isFalse, reason: 'operator== ignores "$field"');
    expect(base.hashCode == variant.hashCode, isFalse,
        reason: 'hashCode ignores "$field"');
  }
}

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

    test('equal offsets are equal and share a hashCode', () {
      const a = Offset(1.0, 2.0);
      const b = Offset(1.0, 2.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, equals(a));
    });

    test('inequality is exercised on every field', () {
      _distinctByField(const Offset(1.0, 2.0), {
        'dx': const Offset(9.0, 2.0),
        'dy': const Offset(1.0, 9.0),
      });
    });

    test('is never equal to a non-Offset', () {
      expect(const Offset(1.0, 2.0), isNot(equals(const Size(1.0, 2.0))));
      expect(const Offset(1.0, 2.0) == Object(), isFalse);
    });

    test('NaN components are never equal (IEEE semantics, matching dart:ui)',
        () {
      expect(const Offset(double.nan, 0.0) == const Offset(double.nan, 0.0),
          isFalse);
    });

    test('-0.0 and 0.0 compare equal and hash equal (contract holds)', () {
      const a = Offset(0.0, 0.0);
      const b = Offset(-0.0, -0.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString uses one-decimal formatting', () {
      expect(const Offset(3.0, 4.5).toString(), 'Offset(3.0, 4.5)');
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

    test('equal sizes are equal and share a hashCode', () {
      const a = Size(10.0, 20.0);
      const b = Size(10.0, 20.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality is exercised on every field', () {
      _distinctByField(const Size(10.0, 20.0), {
        'width': const Size(99.0, 20.0),
        'height': const Size(10.0, 99.0),
      });
    });

    test('is never equal to a non-Size', () {
      expect(const Size(1.0, 2.0), isNot(equals(const Offset(1.0, 2.0))));
      expect(const Size(1.0, 2.0) == Object(), isFalse);
    });

    test('toString uses one-decimal formatting', () {
      expect(const Size(10.0, 20.0).toString(), 'Size(10.0, 20.0)');
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

    test('width, height, and size derive from the edges', () {
      const r = Rect.fromLTRB(1.0, 2.0, 4.0, 8.0);
      expect(r.width, 3.0);
      expect(r.height, 6.0);
      expect(r.size, equals(const Size(3.0, 6.0)));
    });

    test('zero constant has zero edges and area', () {
      expect(Rect.zero, equals(const Rect.fromLTRB(0.0, 0.0, 0.0, 0.0)));
      expect(Rect.zero.isEmpty, isTrue);
    });

    test('isEmpty when degenerate or inverted', () {
      expect(Rect.zero.isEmpty, isTrue);
      expect(const Rect.fromLTRB(5.0, 5.0, 5.0, 10.0).isEmpty, isTrue); // 0 width
      expect(const Rect.fromLTRB(0.0, 5.0, 10.0, 5.0).isEmpty, isTrue); // 0 height
      expect(const Rect.fromLTRB(10.0, 5.0, 5.0, 10.0).isEmpty, isTrue); // l > r
      expect(const Rect.fromLTRB(0.0, 10.0, 10.0, 5.0).isEmpty, isTrue); // t > b
      expect(const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0).isEmpty, isFalse);
    });

    test('equal rects are equal and share a hashCode', () {
      const a = Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
      const b = Rect.fromLTRB(0.0, 0.0, 1.0, 1.0);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality is exercised on every edge', () {
      _distinctByField(const Rect.fromLTRB(1.0, 2.0, 3.0, 4.0), {
        'left': const Rect.fromLTRB(9.0, 2.0, 3.0, 4.0),
        'top': const Rect.fromLTRB(1.0, 9.0, 3.0, 4.0),
        'right': const Rect.fromLTRB(1.0, 2.0, 9.0, 4.0),
        'bottom': const Rect.fromLTRB(1.0, 2.0, 3.0, 9.0),
      });
    });

    test('is never equal to a non-Rect', () {
      expect(const Rect.fromLTRB(1.0, 2.0, 3.0, 4.0) == Object(), isFalse);
    });

    test('toString uses one-decimal formatting', () {
      expect(const Rect.fromLTRB(1.0, 2.0, 3.0, 4.0).toString(),
          'Rect.fromLTRB(1.0, 2.0, 3.0, 4.0)');
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

    test('circular equals the equivalent elliptical', () {
      expect(const Radius.circular(5.0), equals(const Radius.elliptical(5.0, 5.0)));
      expect(const Radius.circular(5.0).hashCode,
          equals(const Radius.elliptical(5.0, 5.0).hashCode));
    });

    test('inequality is exercised on every axis', () {
      _distinctByField(const Radius.elliptical(2.0, 3.0), {
        'x': const Radius.elliptical(9.0, 3.0),
        'y': const Radius.elliptical(2.0, 9.0),
      });
    });

    test('is never equal to a non-Radius', () {
      expect(const Radius.circular(1.0) == Object(), isFalse);
    });

    test('toString distinguishes circular from elliptical', () {
      expect(const Radius.circular(5.0).toString(), 'Radius.circular(5.0)');
      expect(const Radius.elliptical(2.0, 3.0).toString(),
          'Radius.elliptical(2.0, 3.0)');
    });
  });

  group('RRect', () {
    test('fromRectAndRadius applies uniform corners', () {
      final r = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        const Radius.circular(2.0),
      );
      expect(r.tlRadiusX, 2.0);
      expect(r.tlRadiusY, 2.0);
      expect(r.brRadiusY, 2.0);
      expect(r.tlRadius, equals(const Radius.circular(2.0)));
      expect(r.trRadius, equals(const Radius.circular(2.0)));
      expect(r.brRadius, equals(const Radius.circular(2.0)));
      expect(r.blRadius, equals(const Radius.circular(2.0)));
      expect(r.outerRect, equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)));
    });

    test('fromRectAndCorners applies per-corner radii; omitted are zero', () {
      final r = RRect.fromRectAndCorners(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        topLeft: const Radius.circular(1.0),
        topRight: const Radius.elliptical(2.0, 3.0),
        bottomRight: const Radius.circular(4.0),
      );
      expect(r.tlRadius, equals(const Radius.circular(1.0)));
      expect(r.trRadius, equals(const Radius.elliptical(2.0, 3.0)));
      expect(r.brRadius, equals(const Radius.circular(4.0)));
      expect(r.blRadius, equals(Radius.zero)); // defaulted
    });

    test('equal rrects are equal and share a hashCode', () {
      expect(_rrect(), equals(_rrect()));
      expect(_rrect().hashCode, equals(_rrect().hashCode));
    });

    test('inequality is exercised on all twelve fields', () {
      _distinctByField(_rrect(), {
        'left': _rrect(l: 99),
        'top': _rrect(t: 99),
        'right': _rrect(r: 99),
        'bottom': _rrect(b: 99),
        'tlRadiusX': _rrect(tlX: 99),
        'tlRadiusY': _rrect(tlY: 99),
        'trRadiusX': _rrect(trX: 99),
        'trRadiusY': _rrect(trY: 99),
        'brRadiusX': _rrect(brX: 99),
        'brRadiusY': _rrect(brY: 99),
        'blRadiusX': _rrect(blX: 99),
        'blRadiusY': _rrect(blY: 99),
      });
    });

    test('is never equal to a non-RRect', () {
      expect(_rrect() == Object(), isFalse);
    });

    test('toString shows edges and per-corner radii', () {
      expect(
        _rrect().toString(),
        'RRect.fromLTRB(1.0, 2.0, 3.0, 4.0, '
        'Radius.elliptical(5.0, 6.0), Radius.elliptical(7.0, 8.0), '
        'Radius.elliptical(9.0, 10.0), Radius.elliptical(11.0, 12.0))',
      );
      // Uniform circular corners render via the circular branch of Radius.
      final uniform = RRect.fromRectAndRadius(
        const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0),
        const Radius.circular(2.0),
      );
      expect(
        uniform.toString(),
        'RRect.fromLTRB(0.0, 0.0, 10.0, 10.0, '
        'Radius.circular(2.0), Radius.circular(2.0), '
        'Radius.circular(2.0), Radius.circular(2.0))',
      );
    });
  });

  group('Tangent', () {
    test('constructs from a position and vector', () {
      const t = Tangent(Offset(1.0, 2.0), Offset(0.0, 1.0));
      expect(t.position, equals(const Offset(1.0, 2.0)));
      expect(t.vector, equals(const Offset(0.0, 1.0)));
    });

    test('fromAngle builds the unit vector for the direction', () {
      final t = Tangent.fromAngle(const Offset(5.0, 6.0), 0.0);
      expect(t.position, equals(const Offset(5.0, 6.0)));
      expect(t.vector.dx, closeTo(1.0, 1e-12));
      expect(t.vector.dy, closeTo(0.0, 1e-12));
    });

    test('angle negates atan2 (CCW-positive despite y-down), matching dart:ui',
        () {
      // +x axis -> 0; +y (downward) -> -pi/2; -y (upward) -> +pi/2.
      expect(const Tangent(Offset.zero, Offset(1.0, 0.0)).angle,
          closeTo(0.0, 1e-12));
      expect(const Tangent(Offset.zero, Offset(0.0, 1.0)).angle,
          closeTo(-math.pi / 2, 1e-12));
      expect(const Tangent(Offset.zero, Offset(0.0, -1.0)).angle,
          closeTo(math.pi / 2, 1e-12));
    });

    test('fromAngle and angle are sign-inverses of each other', () {
      for (final a in [-1.2, -0.3, 0.0, 0.7, 1.5]) {
        expect(Tangent.fromAngle(Offset.zero, a).angle, closeTo(-a, 1e-12));
      }
    });

    test('toString nests the position and vector', () {
      expect(const Tangent(Offset(1.0, 2.0), Offset(0.0, 1.0)).toString(),
          'Tangent(Offset(1.0, 2.0), Offset(0.0, 1.0))');
    });
  });
}

/// Builds an [RRect] whose twelve fields all hold distinct values, so a single
/// overridden parameter changes exactly one field.
RRect _rrect({
  double l = 1.0,
  double t = 2.0,
  double r = 3.0,
  double b = 4.0,
  double tlX = 5.0,
  double tlY = 6.0,
  double trX = 7.0,
  double trY = 8.0,
  double brX = 9.0,
  double brY = 10.0,
  double blX = 11.0,
  double blY = 12.0,
}) =>
    RRect.fromRectAndCorners(
      Rect.fromLTRB(l, t, r, b),
      topLeft: Radius.elliptical(tlX, tlY),
      topRight: Radius.elliptical(trX, trY),
      bottomRight: Radius.elliptical(brX, brY),
      bottomLeft: Radius.elliptical(blX, blY),
    );
