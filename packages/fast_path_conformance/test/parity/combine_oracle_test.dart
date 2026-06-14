// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

// Oracle characterization of `dart:ui.Path.combine` (M4a step 0).
//
// These tests assert the *engine's* observed boolean-op behavior — the contract
// fast_path's `Path.combine` must match. They were distilled from an
// exploratory probe (see design_docs/boolean_ops.md §7.0) into pinned
// assertions so that:
//   1. The behavior M4a targets is documented executably, not just in prose.
//   2. A Flutter upgrade that changes engine behavior trips a red test here
//      before it silently diverges our parity suite.
//
// fast_path's own combine parity tests (replaying the same op on both sides)
// land separately once M4a is implemented.

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

ui.Path _rect(double l, double t, double r, double b,
    {ui.PathFillType fill = ui.PathFillType.nonZero}) {
  return ui.Path()
    ..fillType = fill
    ..addRect(ui.Rect.fromLTRB(l, t, r, b));
}

int _contourCount(ui.Path p) => p.computeMetrics().length;

void main() {
  const allOps = ui.PathOperation.values;

  group('dart:ui.Path.combine oracle', () {
    test('result fill type is always evenOdd, for every op', () {
      final a = _rect(0, 0, 20, 20);
      final b = _rect(10, 10, 30, 30);
      for (final op in allOps) {
        final out = ui.Path.combine(op, a, b);
        expect(out.fillType, ui.PathFillType.evenOdd,
            reason: '$op result should be evenOdd');
      }
    });

    test('each input is resolved under its OWN fillType before the op', () {
      // A path covering [0,0,20,20] twice in one path.
      ui.Path doubled(ui.PathFillType fill) => ui.Path()
        ..fillType = fill
        ..addRect(const ui.Rect.fromLTRB(0, 0, 20, 20))
        ..addRect(const ui.Rect.fromLTRB(0, 0, 20, 20));

      // nonZero: the doubled region is still inside -> union covers it.
      final nz = ui.Path.combine(
          ui.PathOperation.union, doubled(ui.PathFillType.nonZero), ui.Path());
      expect(nz.contains(const ui.Offset(10, 10)), isTrue);
      expect(_contourCount(nz), 1);

      // evenOdd: the doubled region cancels -> union is empty.
      final eo = ui.Path.combine(
          ui.PathOperation.union, doubled(ui.PathFillType.evenOdd), ui.Path());
      expect(eo.contains(const ui.Offset(10, 10)), isFalse);
      expect(_contourCount(eo), 0);
    });

    test('difference of a fully-nested rect punches a hole (2 contours)', () {
      final big = _rect(0, 0, 30, 30);
      final small = _rect(10, 10, 20, 20);
      final out = ui.Path.combine(ui.PathOperation.difference, big, small);
      expect(_contourCount(out), 2, reason: 'outer boundary + inner hole');
      expect(out.contains(const ui.Offset(15, 15)), isFalse,
          reason: 'center is the hole');
      expect(out.contains(const ui.Offset(5, 5)), isTrue,
          reason: 'corner is still solid');
    });

    test('intersect of disjoint paths is empty', () {
      final out = ui.Path.combine(
          ui.PathOperation.intersect, _rect(0, 0, 10, 10), _rect(20, 20, 30, 30));
      expect(_contourCount(out), 0);
      expect(out.getBounds(), ui.Rect.zero);
    });

    test('coincident shared edge dissolves on union', () {
      final out = ui.Path.combine(
          ui.PathOperation.union, _rect(0, 0, 10, 10), _rect(10, 0, 20, 10));
      expect(_contourCount(out), 1, reason: 'seam at x=10 dissolves');
      expect(out.getBounds(), const ui.Rect.fromLTRB(0, 0, 20, 10));
      expect(out.contains(const ui.Offset(10, 5)), isTrue);
    });

    test('union with empty returns the non-empty operand (either order)', () {
      final r = _rect(0, 0, 10, 10);
      for (final out in [
        ui.Path.combine(ui.PathOperation.union, ui.Path(), r),
        ui.Path.combine(ui.PathOperation.union, r, ui.Path()),
      ]) {
        expect(out.getBounds(), const ui.Rect.fromLTRB(0, 0, 10, 10));
        expect(out.contains(const ui.Offset(5, 5)), isTrue);
      }
    });

    test('reverseDifference(a in b) equals difference(b, a)', () {
      final big = _rect(0, 0, 30, 30);
      final small = _rect(10, 10, 20, 20);
      // big - small = donut; small - big = empty.
      final rev =
          ui.Path.combine(ui.PathOperation.reverseDifference, big, small);
      expect(_contourCount(rev), 0, reason: 'small minus big is empty');
    });

    test('xor of overlapping rects excludes the overlap', () {
      final out = ui.Path.combine(
          ui.PathOperation.xor, _rect(0, 0, 20, 20), _rect(10, 10, 30, 30));
      expect(out.contains(const ui.Offset(15, 15)), isFalse,
          reason: 'overlap is excluded');
      expect(out.contains(const ui.Offset(5, 5)), isTrue);
      expect(out.contains(const ui.Offset(25, 25)), isTrue);
    });
  });
}
