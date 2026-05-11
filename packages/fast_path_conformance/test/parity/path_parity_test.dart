// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:ui' as ui;

import 'package:fast_path/fast_path.dart' as fp;
import 'package:flutter_test/flutter_test.dart';

/// Tolerances for `getBounds` parity, per DESIGN.md §8.2.
const double _boundsAbsTol = 1e-4;
const double _boundsRelTol = 1e-6;

/// A program that drives a path target with calls common to both
/// `fast_path.PathBuilder` and `dart:ui.Path`. Replaying the same program
/// on each side is the basis of every parity test.
typedef PathProgram = void Function(PathTarget target);

/// Common surface across `fast_path.PathBuilder` and `dart:ui.Path` so a
/// single [PathProgram] can drive either. The methods here are the M0
/// surface — extend as new milestones land.
abstract class PathTarget {
  void moveTo(double x, double y);
  void relativeMoveTo(double dx, double dy);
  void lineTo(double x, double y);
  void relativeLineTo(double dx, double dy);
  void addPolygon(List<(double, double)> points, bool close);
  void close();
  set evenOdd(bool value);
}

class _FpTarget implements PathTarget {
  _FpTarget(this._b);
  final fp.PathBuilder _b;

  @override
  void moveTo(double x, double y) => _b.moveTo(x, y);

  @override
  void relativeMoveTo(double dx, double dy) => _b.relativeMoveTo(dx, dy);

  @override
  void lineTo(double x, double y) => _b.lineTo(x, y);

  @override
  void relativeLineTo(double dx, double dy) => _b.relativeLineTo(dx, dy);

  @override
  void addPolygon(List<(double, double)> points, bool close) =>
      _b.addPolygon(
        points.map((p) => fp.Offset(p.$1, p.$2)).toList(growable: false),
        close,
      );

  @override
  void close() => _b.close();

  @override
  set evenOdd(bool value) => _b.fillType =
      value ? fp.PathFillType.evenOdd : fp.PathFillType.nonZero;
}

class _UiTarget implements PathTarget {
  _UiTarget(this._p);
  final ui.Path _p;

  @override
  void moveTo(double x, double y) => _p.moveTo(x, y);

  @override
  void relativeMoveTo(double dx, double dy) => _p.relativeMoveTo(dx, dy);

  @override
  void lineTo(double x, double y) => _p.lineTo(x, y);

  @override
  void relativeLineTo(double dx, double dy) => _p.relativeLineTo(dx, dy);

  @override
  void addPolygon(List<(double, double)> points, bool close) =>
      _p.addPolygon(
        points.map((p) => ui.Offset(p.$1, p.$2)).toList(growable: false),
        close,
      );

  @override
  void close() => _p.close();

  @override
  set evenOdd(bool value) => _p.fillType =
      value ? ui.PathFillType.evenOdd : ui.PathFillType.nonZero;
}

fp.Path _buildFp(PathProgram program) {
  final builder = fp.PathBuilder();
  program(_FpTarget(builder));
  return builder.build();
}

ui.Path _buildUi(PathProgram program) {
  final path = ui.Path();
  program(_UiTarget(path));
  return path;
}

void _expectBoundsParity(fp.Rect a, ui.Rect b) {
  void expectClose(double x, double y, String field) {
    final diff = (x - y).abs();
    if (diff <= _boundsAbsTol) {
      return;
    }
    final mag = x.abs() > y.abs() ? x.abs() : y.abs();
    if (mag > 0 && diff / mag <= _boundsRelTol) {
      return;
    }
    fail('$field disagrees: fast_path=$x, dart:ui=$y (diff=$diff)');
  }

  expectClose(a.left, b.left, 'left');
  expectClose(a.top, b.top, 'top');
  expectClose(a.right, b.right, 'right');
  expectClose(a.bottom, b.bottom, 'bottom');
}

void _expectContainsParity(
  fp.Path fpPath,
  ui.Path uiPath,
  List<fp.Offset> samples,
) {
  for (final p in samples) {
    final fpResult = fpPath.contains(p);
    final uiResult = uiPath.contains(ui.Offset(p.dx, p.dy));
    expect(
      fpResult,
      equals(uiResult),
      reason: 'contains($p): fast_path=$fpResult, dart:ui=$uiResult',
    );
  }
}

/// One parity case: a path-building program plus the sample points to
/// query for `contains` parity. Sample points are chosen well clear of
/// any edge so that ray-casting tie-breakers don't cause spurious
/// disagreement.
class _Case {
  const _Case(this.name, this.program, this.samples);
  final String name;
  final PathProgram program;
  final List<fp.Offset> samples;
}

const _gridFar = <fp.Offset>[
  fp.Offset(-100, -100),
  fp.Offset(100, -100),
  fp.Offset(-100, 100),
  fp.Offset(100, 100),
];

final List<_Case> _cases = <_Case>[
  _Case('empty path', (_) {}, _gridFar),

  _Case(
    'single moveTo',
    (t) => t.moveTo(5, 5),
    const [..._gridFar, fp.Offset(5.5, 5.5), fp.Offset(0, 0)],
  ),

  _Case(
    'single line, no close',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0);
    },
    // A degenerate two-point "polygon" has zero area; nothing is inside.
    const [..._gridFar, fp.Offset(5, 0.001), fp.Offset(5, -0.001)],
  ),

  _Case(
    'closed triangle',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(5, 10)
        ..close();
    },
    const [
      // Inside.
      fp.Offset(5, 2),
      fp.Offset(5, 4),
      fp.Offset(3, 1),
      fp.Offset(7, 1),
      // Outside.
      fp.Offset(-1, 5),
      fp.Offset(11, 5),
      fp.Offset(5, -1),
      fp.Offset(0, 9),
      fp.Offset(10, 9),
      ..._gridFar,
    ],
  ),

  _Case(
    'closed square',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();
    },
    const [
      fp.Offset(5, 5),
      fp.Offset(2.5, 7.5),
      fp.Offset(-1, 5),
      fp.Offset(11, 5),
      fp.Offset(5, -1),
      fp.Offset(5, 11),
      ..._gridFar,
    ],
  ),

  _Case(
    'pentagon',
    (t) {
      // Roughly regular pentagon centered at (50, 50), radius 40.
      t
        ..moveTo(50.0, 10.0)
        ..lineTo(88.04, 37.64)
        ..lineTo(73.51, 82.36)
        ..lineTo(26.49, 82.36)
        ..lineTo(11.96, 37.64)
        ..close();
    },
    const [
      fp.Offset(50, 50),
      fp.Offset(50, 30),
      fp.Offset(30, 60),
      fp.Offset(70, 60),
      fp.Offset(0, 0),
      fp.Offset(100, 100),
      fp.Offset(50, 5),
      ..._gridFar,
    ],
  ),

  _Case(
    'implicit moveTo (lineTo before any moveTo)',
    (t) => t.lineTo(10, 10),
    // dart:ui injects an implicit moveTo at (0, 0), so this is a
    // degenerate single segment from (0,0) to (10,10). Zero area.
    const [..._gridFar, fp.Offset(5, 5.001), fp.Offset(5, 4.999)],
  ),

  _Case(
    'two nested squares, same winding (nonZero fills both)',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close()
        ..moveTo(3, 3)
        ..lineTo(7, 3)
        ..lineTo(7, 7)
        ..lineTo(3, 7)
        ..close();
    },
    const [
      fp.Offset(1, 1), // outer ring
      fp.Offset(5, 5), // inner — under nonZero, still inside
      fp.Offset(8.5, 5), // outer ring
      ..._gridFar,
    ],
  ),

  _Case(
    'two nested squares, evenOdd (frame with hole)',
    (t) {
      t.evenOdd = true;
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close()
        ..moveTo(3, 3)
        ..lineTo(7, 3)
        ..lineTo(7, 7)
        ..lineTo(3, 7)
        ..close();
    },
    const [
      fp.Offset(1, 1), // outer ring — inside
      fp.Offset(5, 5), // inner hole — outside
      fp.Offset(8.5, 5), // outer ring — inside
      ..._gridFar,
    ],
  ),

  _Case(
    'two disjoint squares',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(5, 0)
        ..lineTo(5, 5)
        ..lineTo(0, 5)
        ..close()
        ..moveTo(20, 20)
        ..lineTo(25, 20)
        ..lineTo(25, 25)
        ..lineTo(20, 25)
        ..close();
    },
    const [
      fp.Offset(2.5, 2.5), // inside first
      fp.Offset(22.5, 22.5), // inside second
      fp.Offset(10, 10), // gap between them
      ..._gridFar,
    ],
  ),

  _Case(
    'self-intersecting bowtie (nonZero)',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(10, 10)
        ..lineTo(10, 0)
        ..lineTo(0, 10)
        ..close();
    },
    const [
      // Sample well inside each lobe.
      fp.Offset(2, 5),
      fp.Offset(8, 5),
      // Far outside.
      ..._gridFar,
    ],
  ),

  _Case(
    'fill type set to evenOdd without other state',
    (t) {
      t.evenOdd = true;
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..lineTo(0, 10)
        ..close();
    },
    const [
      fp.Offset(5, 5),
      fp.Offset(-1, -1),
      ..._gridFar,
    ],
  ),

  _Case(
    'relativeLineTo before any moveTo (origin is implicit)',
    (t) {
      t
        ..relativeLineTo(10, 0)
        ..relativeLineTo(0, 10)
        ..relativeLineTo(-10, 0)
        ..close();
    },
    const [
      fp.Offset(5, 5), // inside the resulting square
      fp.Offset(11, 5),
      ..._gridFar,
    ],
  ),

  _Case(
    'relativeMoveTo + relativeLineTo build a square',
    (t) {
      t
        ..relativeMoveTo(2, 3)
        ..relativeLineTo(10, 0)
        ..relativeLineTo(0, 10)
        ..relativeLineTo(-10, 0)
        ..close();
    },
    const [
      fp.Offset(7, 8), // inside (square is at (2,3)-(12,13))
      fp.Offset(0, 0),
      fp.Offset(15, 15),
      ..._gridFar,
    ],
  ),

  _Case(
    'addPolygon (closed=true) builds a triangle',
    (t) => t.addPolygon(
      const [(0.0, 0.0), (10.0, 0.0), (5.0, 10.0)],
      true,
    ),
    const [
      fp.Offset(5, 2),
      fp.Offset(5, 4),
      fp.Offset(0, 9),
      fp.Offset(10, 9),
      ..._gridFar,
    ],
  ),

  _Case(
    'addPolygon (closed=false) leaves the contour open',
    (t) => t.addPolygon(
      const [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)],
      false,
    ),
    const [
      fp.Offset(5, 5), // implicit close still fills the interior
      fp.Offset(-1, 5),
      fp.Offset(11, 5),
      ..._gridFar,
    ],
  ),

  _Case(
    'addPolygon empty list is a no-op',
    (t) => t.addPolygon(const <(double, double)>[], true),
    _gridFar,
  ),

  _Case(
    'lineTo after close opens a fresh contour at the closed start',
    // Catches the post-close implicit moveTo: without it, the second
    // line would extend the just-closed contour and produce a different
    // shape than dart:ui.
    (t) {
      t
        ..moveTo(5, 5)
        ..lineTo(15, 5)
        ..close()
        ..lineTo(7, 8) // expected: implicit moveTo(5, 5), then lineTo(7, 8)
        ..close();
    },
    const [
      fp.Offset(8, 6), // near the second segment, well off any edge
      fp.Offset(10, 4), // near first segment but above its degenerate band
      ..._gridFar,
    ],
  ),

  _Case(
    'multiple close() calls in a row are idempotent',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(10, 0)
        ..lineTo(10, 10)
        ..close()
        ..close()
        ..close();
    },
    const [
      fp.Offset(7, 5),
      fp.Offset(11, 5),
      ..._gridFar,
    ],
  ),
];

void main() {
  group('M0 parity vs dart:ui.Path', () {
    for (final c in _cases) {
      group(c.name, () {
        late fp.Path fpPath;
        late ui.Path uiPath;

        setUpAll(() {
          fpPath = _buildFp(c.program);
          uiPath = _buildUi(c.program);
        });

        test('getBounds matches', () {
          _expectBoundsParity(fpPath.getBounds(), uiPath.getBounds());
        });

        test('contains agrees on sample points', () {
          _expectContainsParity(fpPath, uiPath, c.samples);
        });
      });
    }
  });

  group('fillType round-trips through PathBuilder.build', () {
    test('nonZero is the default and matches dart:ui', () {
      expect(fp.PathBuilder().build().fillType, fp.PathFillType.nonZero);
      expect(ui.Path().fillType, ui.PathFillType.nonZero);
    });

    test('evenOdd survives the snapshot', () {
      final fpBuilder = fp.PathBuilder()..fillType = fp.PathFillType.evenOdd;
      expect(fpBuilder.build().fillType, fp.PathFillType.evenOdd);

      final uiPath = ui.Path()..fillType = ui.PathFillType.evenOdd;
      expect(uiPath.fillType, ui.PathFillType.evenOdd);
    });
  });
}
