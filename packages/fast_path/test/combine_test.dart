// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

Path _rect(double l, double t, double r, double b) =>
    (PathBuilder()..addRect(Rect.fromLTRB(l, t, r, b))).build();

Path _oval(double l, double t, double r, double b) =>
    (PathBuilder()..addOval(Rect.fromLTRB(l, t, r, b))).build();

final Path _empty = PathBuilder().build();

// Sample grid whose coordinates avoid the integer edges (0,10,20,30,40) of the
// shapes under test, so containment comparisons never land on a boundary tie.
const _coords = [-5.0, 3.0, 7.0, 13.0, 17.0, 23.0, 27.0, 33.0, 37.0, 43.0];

Iterable<Offset> get _grid sync* {
  for (final x in _coords) {
    for (final y in _coords) {
      yield Offset(x, y);
    }
  }
}

/// Asserts two paths cover the same region (by `contains` over the grid).
void _sameRegion(Path got, Path want) {
  for (final p in _grid) {
    expect(got.contains(p), want.contains(p), reason: 'disagree at $p');
  }
}

/// Asserts a path covers no area (no grid point is inside).
void _emptyRegion(Path p) {
  for (final o in _grid) {
    expect(p.contains(o), isFalse, reason: 'unexpectedly inside at $o');
  }
}

void main() {
  final a = _rect(0, 0, 20, 20);
  final b = _rect(10, 10, 30, 30);

  group('Path.combine — algebraic identities', () {
    test('union(a, a) covers a', () {
      _sameRegion(Path.combine(PathOperation.union, a, a), a);
    });

    test('intersect(a, a) covers a', () {
      _sameRegion(Path.combine(PathOperation.intersect, a, a), a);
    });

    test('xor(a, a) is empty', () {
      _emptyRegion(Path.combine(PathOperation.xor, a, a));
    });

    test('difference(a, a) is empty', () {
      _emptyRegion(Path.combine(PathOperation.difference, a, a));
    });

    test('union(a, empty) covers a', () {
      _sameRegion(Path.combine(PathOperation.union, a, _empty), a);
    });

    test('intersect(a, empty) is empty', () {
      _emptyRegion(Path.combine(PathOperation.intersect, a, _empty));
    });

    test('difference(a, empty) covers a', () {
      _sameRegion(Path.combine(PathOperation.difference, a, _empty), a);
    });

    test('difference(a, b) equals reverseDifference(b, a)', () {
      _sameRegion(
        Path.combine(PathOperation.difference, a, b),
        Path.combine(PathOperation.reverseDifference, b, a),
      );
    });

    test('combine of two empties is empty', () {
      _emptyRegion(Path.combine(PathOperation.union, _empty, _empty));
      _emptyRegion(Path.combine(PathOperation.xor, _empty, _empty));
    });
  });

  group('Path.combine — geometry', () {
    test('result fill type is always evenOdd', () {
      for (final op in PathOperation.values) {
        expect(Path.combine(op, a, b).fillType, PathFillType.evenOdd,
            reason: '$op');
      }
    });

    test('union of overlapping rects covers either', () {
      final r = Path.combine(PathOperation.union, a, b);
      expect(r.contains(const Offset(5, 5)), isTrue);
      expect(r.contains(const Offset(15, 15)), isTrue);
      expect(r.contains(const Offset(25, 25)), isTrue);
      expect(r.contains(const Offset(45, 45)), isFalse);
    });

    test('intersect of overlapping rects covers both', () {
      final r = Path.combine(PathOperation.intersect, a, b);
      expect(r.contains(const Offset(15, 15)), isTrue);
      expect(r.contains(const Offset(5, 5)), isFalse);
      expect(r.contains(const Offset(25, 25)), isFalse);
    });

    test('xor of overlapping rects excludes the overlap', () {
      final r = Path.combine(PathOperation.xor, a, b);
      expect(r.contains(const Offset(5, 5)), isTrue);
      expect(r.contains(const Offset(25, 25)), isTrue);
      expect(r.contains(const Offset(15, 15)), isFalse);
    });

    test('disjoint union keeps both islands', () {
      final r = Path.combine(
          PathOperation.union, _rect(0, 0, 10, 10), _rect(20, 20, 30, 30));
      expect(r.contains(const Offset(5, 5)), isTrue);
      expect(r.contains(const Offset(25, 25)), isTrue);
      expect(r.contains(const Offset(15, 15)), isFalse);
    });

    test('difference of a nested rect punches a hole', () {
      final r = Path.combine(
          PathOperation.difference, _rect(0, 0, 30, 30), _rect(10, 10, 20, 20));
      expect(r.contains(const Offset(15, 15)), isFalse); // hole
      expect(r.contains(const Offset(5, 5)), isTrue); // solid
    });
  });

  group('Path.combine — curved operands (polygonal output)', () {
    test('intersect of two overlapping circles', () {
      // Circles of radius 50 centered (50,50) and (90,50): lens overlap around
      // x in [40,60]. The lens center (~70,50) is in both; the far sides are
      // not.
      final c1 = _oval(0, 0, 100, 100);
      final c2 = _oval(40, 0, 140, 100);
      final lens = Path.combine(PathOperation.intersect, c1, c2);
      expect(lens.contains(const Offset(70, 50)), isTrue); // shared middle
      expect(lens.contains(const Offset(10, 50)), isFalse); // only c1
      expect(lens.contains(const Offset(130, 50)), isFalse); // only c2
      // Output is polygonal: no conic verbs survive a combine.
      expect(lens.fillType, PathFillType.evenOdd);
    });

    test('union of two circles covers each center', () {
      final u = Path.combine(
          PathOperation.union, _oval(0, 0, 100, 100), _oval(40, 0, 140, 100));
      expect(u.contains(const Offset(20, 50)), isTrue);
      expect(u.contains(const Offset(120, 50)), isTrue);
    });
  });
}
