// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:typed_data';

import 'package:fast_path/src/martinez.dart';
import 'package:test/test.dart';

/// A clockwise square ring (no duplicated closing vertex).
Float64List _sq(double l, double t, double r, double b) =>
    Float64List.fromList([l, t, r, t, r, b, l, b]);

/// Even-odd point membership across a set of result rings — the rule the
/// boolean output is emitted under. Sample points are kept off the edges.
bool _inside(List<Float64List> rings, double x, double y) {
  var crossings = 0;
  for (final ring in rings) {
    final n = ring.length ~/ 2;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final x0 = ring[i * 2], y0 = ring[i * 2 + 1];
      final x1 = ring[j * 2], y1 = ring[j * 2 + 1];
      if ((y0 > y) != (y1 > y)) {
        final xc = x0 + (y - y0) / (y1 - y0) * (x1 - x0);
        if (xc > x) crossings++;
      }
    }
  }
  return crossings.isOdd;
}

void main() {
  group('martinezBooleanOp — overlapping squares', () {
    final a = [_sq(0, 0, 20, 20)];
    final b = [_sq(10, 10, 30, 30)];

    test('union covers either', () {
      final r = martinezBooleanOp(a, b, BoolOp.union);
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 15, 15), isTrue);
      expect(_inside(r, 25, 25), isTrue);
      expect(_inside(r, 50, 50), isFalse);
    });

    test('intersection covers both', () {
      final r = martinezBooleanOp(a, b, BoolOp.intersection);
      expect(_inside(r, 15, 15), isTrue);
      expect(_inside(r, 5, 5), isFalse);
      expect(_inside(r, 25, 25), isFalse);
    });

    test('difference is a minus the overlap', () {
      final r = martinezBooleanOp(a, b, BoolOp.difference);
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 15, 15), isFalse);
      expect(_inside(r, 25, 25), isFalse);
    });

    test('xor excludes the overlap', () {
      final r = martinezBooleanOp(a, b, BoolOp.xor);
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 25, 25), isTrue);
      expect(_inside(r, 15, 15), isFalse);
    });
  });

  group('martinezBooleanOp — disjoint squares', () {
    final a = [_sq(0, 0, 10, 10)];
    final b = [_sq(20, 20, 30, 30)];

    test('union keeps both', () {
      final r = martinezBooleanOp(a, b, BoolOp.union);
      expect(r, hasLength(2));
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 25, 25), isTrue);
      expect(_inside(r, 15, 15), isFalse);
    });

    test('intersection is empty', () {
      expect(martinezBooleanOp(a, b, BoolOp.intersection), isEmpty);
    });

    test('difference keeps only a', () {
      final r = martinezBooleanOp(a, b, BoolOp.difference);
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 25, 25), isFalse);
    });
  });

  group('martinezBooleanOp — nested squares (hole)', () {
    final big = [_sq(0, 0, 30, 30)];
    final small = [_sq(10, 10, 20, 20)];

    test('difference punches a hole', () {
      final r = martinezBooleanOp(big, small, BoolOp.difference);
      expect(r, hasLength(2), reason: 'outer boundary + inner hole');
      expect(_inside(r, 15, 15), isFalse, reason: 'center is the hole');
      expect(_inside(r, 5, 5), isTrue, reason: 'corner is solid');
    });

    test('intersection is the inner square', () {
      final r = martinezBooleanOp(big, small, BoolOp.intersection);
      expect(_inside(r, 15, 15), isTrue);
      expect(_inside(r, 5, 5), isFalse);
    });

    test('union is the outer square', () {
      final r = martinezBooleanOp(big, small, BoolOp.union);
      expect(_inside(r, 15, 15), isTrue);
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 35, 35), isFalse);
    });

    test('reverse difference (small − big) is empty', () {
      // small is entirely inside big.
      final r = martinezBooleanOp(small, big, BoolOp.difference);
      expect(r, isEmpty);
    });
  });

  group('martinezBooleanOp — general position (diagonal edges)', () {
    // Right triangle below the line x + y = 30, overlapping a square. The
    // hypotenuse cuts the square's corner — exercises the single-point
    // intersection of two non-axis-aligned edges.
    final tri = [Float64List.fromList([0, 0, 30, 0, 0, 30])];
    final sq = [_sq(10, 10, 40, 40)];

    test('intersection clipped by the hypotenuse', () {
      final r = martinezBooleanOp(tri, sq, BoolOp.intersection);
      expect(_inside(r, 11, 11), isTrue); // x+y=22 < 30, inside square
      expect(_inside(r, 18, 18), isFalse); // x+y=36 > 30, past hypotenuse
      expect(_inside(r, 5, 5), isFalse); // outside square
    });

    test('difference removes the square part of the triangle', () {
      final r = martinezBooleanOp(tri, sq, BoolOp.difference);
      expect(_inside(r, 5, 5), isTrue); // triangle, outside square
      expect(_inside(r, 11, 11), isFalse); // triangle ∩ square → removed
    });
  });

  group('martinezBooleanOp — edge cases', () {
    test('coincident shared edge dissolves on union', () {
      final r = martinezBooleanOp(
          [_sq(0, 0, 10, 10)], [_sq(10, 0, 20, 10)], BoolOp.union);
      expect(_inside(r, 5, 5), isTrue);
      expect(_inside(r, 15, 5), isTrue);
      expect(_inside(r, 9, 5), isTrue); // straddles former seam
    });

    test('empty operands', () {
      final a = [_sq(0, 0, 10, 10)];
      expect(martinezBooleanOp([], [], BoolOp.union), isEmpty);
      expect(martinezBooleanOp(a, [], BoolOp.union), hasLength(1));
      expect(martinezBooleanOp([], a, BoolOp.union), hasLength(1));
      expect(martinezBooleanOp(a, [], BoolOp.intersection), isEmpty);
      expect(martinezBooleanOp(a, [], BoolOp.difference), hasLength(1));
      expect(martinezBooleanOp([], a, BoolOp.difference), isEmpty);
    });

    test('identical squares: union ≈ self, difference empty', () {
      final a = [_sq(0, 0, 10, 10)];
      final b = [_sq(0, 0, 10, 10)];
      expect(_inside(martinezBooleanOp(a, b, BoolOp.union), 5, 5), isTrue);
      expect(martinezBooleanOp(a, b, BoolOp.difference), isEmpty);
      expect(_inside(martinezBooleanOp(a, b, BoolOp.intersection), 5, 5),
          isTrue);
      expect(martinezBooleanOp(a, b, BoolOp.xor), isEmpty);
    });
  });
}
