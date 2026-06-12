// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

// Shared test helper: assert a fast_geometry Matrix matches a vector_math
// Matrix4 entry-for-entry. Not a *_test.dart file, so the runner does not pick
// it up directly.

import 'package:fast_geometry/fast_geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Default tolerance for matrices built from the same arithmetic on both sides
/// (the gap is only floating-point reassociation).
const double matrixTolerance = 1e-12;

/// Asserts [actual]'s 16 entries match [expected]'s within [tol]. `mRC` is
/// row R, column C on our side; vector_math exposes the same via `entry(R, C)`.
void expectMatches(
  Matrix actual,
  vm.Matrix4 expected, {
  double tol = matrixTolerance,
}) {
  final actualRows = <double>[
    actual.m00, actual.m01, actual.m02, actual.m03, //
    actual.m10, actual.m11, actual.m12, actual.m13, //
    actual.m20, actual.m21, actual.m22, actual.m23, //
    actual.m30, actual.m31, actual.m32, actual.m33, //
  ];
  for (var i = 0; i < 16; i++) {
    final r = i ~/ 4;
    final c = i % 4;
    expect(actualRows[i], closeTo(expected.entry(r, c), tol),
        reason: 'entry m$r$c');
  }
}
