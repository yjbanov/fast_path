// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Internal verb byte constants stored in the path's `Uint8List _verbs`.
///
/// Values mirror Skia's `SkPath::Verb` ordering so that ports from upstream
/// algorithms can use the same numeric comparisons. New verbs append; do not
/// reorder.
library;

/// `moveTo` — starts a new contour. Consumes 1 point from `_points`.
const int verbMove = 0;

/// `lineTo` — straight segment from the current point to a new point.
/// Consumes 1 point.
const int verbLine = 1;

/// `quadraticBezierTo` — quadratic Bézier with one control point.
/// Consumes 2 points.
const int verbQuad = 2;

/// `conicTo` — rational quadratic Bézier with one control point and one
/// weight. Consumes 2 points and 1 entry from `_conicWeights`.
const int verbConic = 3;

/// `cubicTo` — cubic Bézier with two control points. Consumes 3 points.
const int verbCubic = 4;

/// `close` — closes the current contour by connecting back to the most
/// recent `moveTo`. Consumes 0 points.
const int verbClose = 5;

/// Number of `(x, y)` point pairs each verb consumes from `_points`.
///
/// Indexed by verb byte value. Used by both `PathBuilder` and `Path` when
/// walking the verb stream.
const List<int> verbPointCount = <int>[
  1, // verbMove
  1, // verbLine
  2, // verbQuad
  2, // verbConic
  3, // verbCubic
  0, // verbClose
];
