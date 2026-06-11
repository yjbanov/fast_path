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
  void quadraticBezierTo(double x1, double y1, double x2, double y2);
  void relativeQuadraticBezierTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
  );
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  );
  void relativeCubicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx3,
    double dy3,
  );
  void conicTo(double x1, double y1, double x2, double y2, double w);
  void relativeConicTo(double dx1, double dy1, double dx2, double dy2, double w);
  void addPolygon(List<(double, double)> points, bool close);
  void addRect(double l, double t, double r, double b);
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
  void quadraticBezierTo(double x1, double y1, double x2, double y2) =>
      _b.quadraticBezierTo(x1, y1, x2, y2);

  @override
  void relativeQuadraticBezierTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
  ) =>
      _b.relativeQuadraticBezierTo(dx1, dy1, dx2, dy2);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) =>
      _b.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void relativeCubicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx3,
    double dy3,
  ) =>
      _b.relativeCubicTo(dx1, dy1, dx2, dy2, dx3, dy3);

  @override
  void conicTo(double x1, double y1, double x2, double y2, double w) =>
      _b.conicTo(x1, y1, x2, y2, w);

  @override
  void relativeConicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double w,
  ) =>
      _b.relativeConicTo(dx1, dy1, dx2, dy2, w);

  @override
  void addPolygon(List<(double, double)> points, bool close) =>
      _b.addPolygon(
        points.map((p) => fp.Offset(p.$1, p.$2)).toList(growable: false),
        close,
      );

  @override
  void addRect(double l, double t, double r, double b) =>
      _b.addRect(fp.Rect.fromLTRB(l, t, r, b));

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
  void quadraticBezierTo(double x1, double y1, double x2, double y2) =>
      _p.quadraticBezierTo(x1, y1, x2, y2);

  @override
  void relativeQuadraticBezierTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
  ) =>
      _p.relativeQuadraticBezierTo(dx1, dy1, dx2, dy2);

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) =>
      _p.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void relativeCubicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx3,
    double dy3,
  ) =>
      _p.relativeCubicTo(dx1, dy1, dx2, dy2, dx3, dy3);

  @override
  void conicTo(double x1, double y1, double x2, double y2, double w) =>
      _p.conicTo(x1, y1, x2, y2, w);

  @override
  void relativeConicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double w,
  ) =>
      _p.relativeConicTo(dx1, dy1, dx2, dy2, w);

  @override
  void addPolygon(List<(double, double)> points, bool close) =>
      _p.addPolygon(
        points.map((p) => ui.Offset(p.$1, p.$2)).toList(growable: false),
        close,
      );

  @override
  void addRect(double l, double t, double r, double b) =>
      _p.addRect(ui.Rect.fromLTRB(l, t, r, b));

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

  // M1 — Curves.

  _Case(
    'single quad arc — control above the chord',
    (t) {
      t
        ..moveTo(0, 0)
        ..quadraticBezierTo(50, 100, 100, 0)
        ..close();
    },
    const [
      // Comfortably inside the arc.
      fp.Offset(50, 20),
      fp.Offset(30, 10),
      fp.Offset(70, 10),
      // Outside.
      fp.Offset(50, -5),
      fp.Offset(50, 60), // above the apex (apex y is 50)
      fp.Offset(-5, 0),
      fp.Offset(105, 0),
      ..._gridFar,
    ],
  ),

  _Case(
    'two-quad leaf shape',
    (t) {
      t
        ..moveTo(0, 0)
        ..quadraticBezierTo(50, 80, 100, 0)
        ..quadraticBezierTo(50, -80, 0, 0)
        ..close();
    },
    const [
      fp.Offset(50, 10),
      fp.Offset(50, -10),
      fp.Offset(20, 0),
      fp.Offset(80, 0),
      fp.Offset(50, 50), // outside top lobe (apex y ~40)
      fp.Offset(50, -50),
      ..._gridFar,
    ],
  ),

  _Case(
    'mixed line + quad — rounded triangle',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..quadraticBezierTo(120, 50, 50, 100)
        ..lineTo(0, 0)
        ..close();
    },
    const [
      fp.Offset(50, 30),
      fp.Offset(70, 20),
      fp.Offset(80, 60),
      fp.Offset(50, -5),
      fp.Offset(105, 60),
      ..._gridFar,
    ],
  ),

  _Case(
    'quad with control on the chord (degenerate, line-like)',
    // Triangle (0,0), (0,50), (100,0). The quad's chord goes (0,50) →
    // (100,0); control at (50,25) is the chord midpoint so the curve
    // collapses to a straight line. Samples below stay well clear of
    // that diagonal — chord eqn is y = 50 - x/2.
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(0, 50)
        ..quadraticBezierTo(50, 25, 100, 0)
        ..close();
    },
    const [
      fp.Offset(10, 5), // clearly inside
      fp.Offset(30, 5), // clearly inside
      fp.Offset(70, 30), // clearly outside (above diagonal)
      fp.Offset(20, 45), // clearly outside (above diagonal)
      ..._gridFar,
    ],
  ),

  _Case(
    'relativeQuadraticBezierTo accumulates from current point',
    (t) {
      t
        ..moveTo(10, 10)
        ..relativeQuadraticBezierTo(40, 100, 90, 0)
        ..close();
    },
    const [
      fp.Offset(60, 30),
      fp.Offset(60, 5),
      fp.Offset(60, 70),
      ..._gridFar,
    ],
  ),

  _Case(
    'quad without prior moveTo starts at the origin',
    (t) => t
      ..quadraticBezierTo(50, 100, 100, 0)
      ..close(),
    const [
      fp.Offset(50, 20),
      fp.Offset(50, -5),
      ..._gridFar,
    ],
  ),

  _Case(
    'evenOdd fill on a self-overlapping quad path',
    (t) {
      t
        ..evenOdd = true
        ..moveTo(0, 0)
        ..quadraticBezierTo(50, 100, 100, 0)
        ..quadraticBezierTo(50, 50, 0, 0)
        ..close();
    },
    const [
      // Region between the two arcs — sample a few points.
      fp.Offset(50, 40),
      fp.Offset(50, 15),
      fp.Offset(50, 5),
      fp.Offset(50, 30),
      ..._gridFar,
    ],
  ),

  // M1 — Cubics.

  _Case(
    'single cubic arc with both controls above the chord',
    (t) {
      t
        ..moveTo(0, 0)
        ..cubicTo(30, 100, 70, 100, 100, 0)
        ..close();
    },
    const [
      fp.Offset(50, 30),
      fp.Offset(30, 20),
      fp.Offset(70, 20),
      fp.Offset(50, -5),
      fp.Offset(50, 80), // above apex (apex y ≈ 75)
      ..._gridFar,
    ],
  ),

  _Case(
    'S-curve cubic (controls on opposite sides of the chord)',
    (t) {
      t
        ..moveTo(0, 0)
        ..cubicTo(40, 80, 60, -80, 100, 0)
        ..lineTo(100, 50)
        ..lineTo(0, 50)
        ..close();
    },
    const [
      // Clearly above the cubic (in the closed rectangle).
      fp.Offset(20, 40),
      fp.Offset(80, 40),
      // Outside the bounding box.
      fp.Offset(-5, 25),
      fp.Offset(105, 25),
      ..._gridFar,
    ],
  ),

  _Case(
    'mixed line + cubic — rounded triangle',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..cubicTo(130, 30, 90, 80, 50, 100)
        ..lineTo(0, 0)
        ..close();
    },
    const [
      fp.Offset(50, 20),
      fp.Offset(70, 40),
      fp.Offset(50, -5),
      fp.Offset(110, 70),
      ..._gridFar,
    ],
  ),

  _Case(
    'cubic with collinear controls (degenerate, line-like)',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(0, 50)
        ..cubicTo(33, 33, 66, 16, 100, 0)
        ..close();
    },
    const [
      fp.Offset(10, 5),
      fp.Offset(30, 5),
      fp.Offset(70, 30), // above the cubic
      fp.Offset(20, 45),
      ..._gridFar,
    ],
  ),

  _Case(
    'relativeCubicTo accumulates from current point',
    (t) {
      t
        ..moveTo(10, 10)
        ..relativeCubicTo(20, 90, 60, 90, 90, 0)
        ..close();
    },
    const [
      fp.Offset(60, 40),
      fp.Offset(60, 5),
      fp.Offset(60, 90),
      ..._gridFar,
    ],
  ),

  _Case(
    'cubic without prior moveTo starts at the origin',
    (t) => t
      ..cubicTo(30, 100, 70, 100, 100, 0)
      ..close(),
    const [
      fp.Offset(50, 30),
      fp.Offset(50, -5),
      fp.Offset(50, 80),
      ..._gridFar,
    ],
  ),

  _Case(
    'evenOdd fill on a self-overlapping cubic path',
    (t) {
      t
        ..evenOdd = true
        ..moveTo(0, 0)
        ..cubicTo(40, 100, 60, 100, 100, 0)
        ..cubicTo(60, 50, 40, 50, 0, 0)
        ..close();
    },
    const [
      fp.Offset(50, 60),
      fp.Offset(50, 20),
      fp.Offset(50, 5),
      ..._gridFar,
    ],
  ),

  // M1 — Conics.

  _Case(
    'quarter-circle pie via conic (w = sqrt(2)/2)',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        // 0.70710678 ≈ sqrt(2)/2: exact quarter circle of radius 100.
        ..conicTo(100, 100, 0, 100, 0.7071067811865476)
        ..close();
    },
    const [
      fp.Offset(60, 60), // r ≈ 84.9 — inside the arc
      fp.Offset(74, 74), // r ≈ 104.7 — outside the arc, inside the hull
      fp.Offset(10, 10),
      fp.Offset(-10, 50),
      ..._gridFar,
    ],
  ),

  _Case(
    'low-weight conic hugs the chord',
    (t) {
      t
        ..moveTo(0, 0)
        ..conicTo(50, 100, 100, 0, 0.25)
        ..close();
    },
    const [
      fp.Offset(50, 10), // inside (apex y = 100·0.25/1.25 = 20)
      fp.Offset(50, 30), // outside
      ..._gridFar,
    ],
  ),

  _Case(
    'high-weight conic approaches the control polyline',
    (t) {
      t
        ..moveTo(0, 0)
        ..conicTo(50, 100, 100, 0, 4.0)
        ..close();
    },
    const [
      fp.Offset(50, 60), // inside (apex y = 100·4/5 = 80)
      fp.Offset(50, 90), // outside
      fp.Offset(10, 30),
      ..._gridFar,
    ],
  ),

  _Case(
    'conic with w == 1 behaves as a quadratic',
    (t) {
      t
        ..moveTo(0, 0)
        ..conicTo(50, 100, 100, 0, 1.0)
        ..close();
    },
    const [
      fp.Offset(50, 30),
      fp.Offset(50, 60), // above apex (apex y = 50)
      ..._gridFar,
    ],
  ),

  _Case(
    // Verified empirically: current dart:ui (Impeller) normalizes
    // invalid conic weights to w == 1 (a plain quadratic), NOT to a
    // line as classic Skia documentation suggests.
    'conic with invalid weights (0, negative, NaN, infinity) acts as quad',
    (t) {
      t
        ..moveTo(0, 0)
        ..conicTo(50, 100, 100, 0, 0.0)
        ..close()
        ..moveTo(120, 0)
        ..conicTo(170, 100, 220, 0, -3.0)
        ..close()
        ..moveTo(240, 0)
        ..conicTo(290, 100, 340, 0, double.nan)
        ..close()
        ..moveTo(360, 0)
        ..conicTo(410, 100, 460, 0, double.infinity)
        ..close();
    },
    const [
      // Quad apex is y = 50 for each lobe; probe just inside and out.
      fp.Offset(50, 45),
      fp.Offset(50, 55),
      fp.Offset(170, 45),
      fp.Offset(170, 55),
      fp.Offset(290, 45),
      fp.Offset(290, 55),
      fp.Offset(410, 45),
      fp.Offset(410, 55),
      ..._gridFar,
    ],
  ),

  _Case(
    'relativeConicTo accumulates from current point',
    (t) {
      t
        ..moveTo(10, 10)
        ..relativeConicTo(40, 90, 90, 0, 0.7)
        ..close();
    },
    const [
      fp.Offset(55, 30),
      fp.Offset(55, 70),
      ..._gridFar,
    ],
  ),

  _Case(
    'mixed line + conic + cubic contour',
    (t) {
      t
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..conicTo(120, 40, 100, 80, 0.8)
        ..cubicTo(70, 110, 30, 110, 0, 80)
        ..close();
    },
    const [
      fp.Offset(50, 40),
      fp.Offset(50, 95),
      fp.Offset(115, 40),
      fp.Offset(-5, 40),
      ..._gridFar,
    ],
  ),

  // M2 — Convenience builders.

  _Case(
    'addRect simple',
    (t) => t.addRect(10, 20, 110, 70),
    const [
      fp.Offset(60, 45),
      fp.Offset(5, 45),
      fp.Offset(115, 45),
      fp.Offset(60, 15),
      fp.Offset(60, 75),
      ..._gridFar,
    ],
  ),

  _Case(
    // Catches a winding-direction mismatch: with evenOdd two nested
    // rects form a frame regardless of direction, but with nonZero the
    // result differs if directions differ. Test both fill types.
    'addRect nested, nonZero (both filled if same direction)',
    (t) => t
      ..addRect(0, 0, 90, 90)
      ..addRect(25, 25, 75, 75),
    const [
      fp.Offset(50, 50),
      fp.Offset(10, 10),
      fp.Offset(95, 50),
      ..._gridFar,
    ],
  ),

  _Case(
    'addRect nested, evenOdd (frame with hole)',
    (t) {
      t
        ..evenOdd = true
        ..addRect(0, 0, 90, 90)
        ..addRect(25, 25, 75, 75);
    },
    const [
      fp.Offset(50, 50), // hole
      fp.Offset(10, 10), // frame
      ..._gridFar,
    ],
  ),

  _Case(
    'addRect then lineTo opens a fresh contour at the rect start',
    (t) => t
      ..addRect(0, 0, 10, 10)
      ..lineTo(5, 20),
    const [
      fp.Offset(5, 5),
      fp.Offset(2, 15),
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
