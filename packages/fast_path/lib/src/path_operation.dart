// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Set operation that [Path.combine] applies to a pair of paths.
///
/// Mirrors `dart:ui`'s `PathOperation`, including the value order. Each
/// operation interprets its two operands as filled regions (each under its
/// own [PathFillType]) and produces a new region.
enum PathOperation {
  /// Subtracts the second path from the first: the region inside the first
  /// operand but outside the second.
  ///
  /// Matches `dart:ui.PathOperation.difference`.
  difference,

  /// Intersection: the region inside both operands.
  ///
  /// Matches `dart:ui.PathOperation.intersect`.
  intersect,

  /// Union (inclusive-or): the region inside either operand.
  ///
  /// Matches `dart:ui.PathOperation.union`.
  union,

  /// Exclusive-or: the region inside exactly one operand (union minus the
  /// intersection).
  ///
  /// Matches `dart:ui.PathOperation.xor`.
  xor,

  /// Subtracts the first path from the second: the region inside the second
  /// operand but outside the first. The mirror of [difference].
  ///
  /// Matches `dart:ui.PathOperation.reverseDifference`.
  reverseDifference,
}
