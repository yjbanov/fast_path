// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

double _len(Path p) {
  final m = p.computeMetrics().toList();
  return m.isEmpty ? 0.0 : m.single.length;
}

void main() {
  group('PathMetric.extractPath', () {
    test('full range reproduces the contour length', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0))
          .build();
      final m = path.computeMetrics().single;
      final extracted = m.extractPath(0, m.length);
      expect(_len(extracted), closeTo(100, 1e-6));
    });

    test('middle segment of a line has the right endpoints and length', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0))
          .build();
      final m = path.computeMetrics().single;
      final mid = m.extractPath(25, 75);
      expect(_len(mid), closeTo(50, 1e-6));
      expect(mid.getBounds(),
          equals(const Rect.fromLTRB(25, 0, 75, 0)));
    });

    test('start >= end yields an empty path', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0))
          .build();
      final m = path.computeMetrics().single;
      expect(m.extractPath(60, 40).getBounds(), equals(Rect.zero));
      expect(m.extractPath(50, 50).getBounds(), equals(Rect.zero));
    });

    test('distances clamp to [0, length]', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0))
          .build();
      final m = path.computeMetrics().single;
      // -10..200 clamps to 0..100 → the whole line.
      expect(_len(m.extractPath(-10, 200)), closeTo(100, 1e-6));
    });

    test('spanning a corner keeps both legs', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(40, 0)
            ..lineTo(40, 40))
          .build();
      final m = path.computeMetrics().single; // length 80
      // 20..60 spans the corner: 20 along the top + 20 down.
      final seg = m.extractPath(20, 60);
      expect(_len(seg), closeTo(40, 1e-6));
      expect(seg.getBounds(), equals(const Rect.fromLTRB(20, 0, 40, 20)));
    });

    test('extracted arc length matches the requested span', () {
      final circle =
          (PathBuilder()..addOval(const Rect.fromLTRB(0, 0, 100, 100)))
              .build();
      final m = circle.computeMetrics().single;
      final span = m.length * 0.3;
      final arc = m.extractPath(m.length * 0.2, m.length * 0.5);
      expect(_len(arc), closeTo(span, 0.1));
    });

    test('startWithMoveTo controls the leading verb', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0))
          .build();
      final m = path.computeMetrics().single;
      // true: starts with moveTo(25,0) → bounds begin at x=25.
      expect(m.extractPath(25, 75).getBounds(),
          equals(const Rect.fromLTRB(25, 0, 75, 0)));
      // false: leading lineTo on an empty builder injects an implicit
      // moveTo(0,0), so the extracted path runs (0,0)→(25,0)→(75,0) and
      // its bounds include the origin — matching dart:ui, where a path
      // beginning with a lineTo starts from (0,0).
      expect(m.extractPath(25, 75, startWithMoveTo: false).getBounds(),
          equals(const Rect.fromLTRB(0, 0, 75, 0)));
    });

    test('empty / degenerate contour extracts nothing', () {
      final empty = PathBuilder().build();
      // No metrics at all; nothing to extract from.
      expect(empty.computeMetrics(), isEmpty);
    });

    test('quarter-arc extract is within the circle band', () {
      // Sanity: extracting from a circle yields points at radius ~50.
      final circle =
          (PathBuilder()..addOval(const Rect.fromLTRB(-50, -50, 50, 50)))
              .build();
      final m = circle.computeMetrics().single;
      final arc = m.extractPath(0, m.length * 0.25);
      final am = arc.computeMetrics().single;
      for (final f in const [0.0, 0.5, 1.0]) {
        final p = am.getTangentForOffset(am.length * f)!.position;
        final r = math.sqrt(p.dx * p.dx + p.dy * p.dy);
        expect(r, closeTo(50, 0.5));
      }
    });
  });
}
