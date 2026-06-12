// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Determines the strategy for filling the interior of a path.
///
/// Mirrors `dart:ui`'s `PathFillType`.
enum PathFillType {
  /// A point is inside the path if a ray cast from it crosses the path's
  /// edges an odd number of times overall, *or* if the signed sum of
  /// crossings is non-zero — either rule labels it inside.
  ///
  /// This is the default fill type and matches `dart:ui.PathFillType.nonZero`.
  nonZero,

  /// A point is inside the path if a ray cast from it crosses the path's
  /// edges an odd number of times.
  ///
  /// Matches `dart:ui.PathFillType.evenOdd`.
  evenOdd,
}
