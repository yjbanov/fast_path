// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

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

/// An immutable 2D floating-point offset.
///
/// Mirrors `dart:ui.Offset`. Field names (`dx`, `dy`) match the engine so
/// porting code from Flutter is mechanical.
final class Offset {
  /// Creates an offset with the given horizontal (`dx`) and vertical (`dy`)
  /// components.
  const Offset(this.dx, this.dy);

  /// An offset with zero in both components.
  static const Offset zero = Offset(0.0, 0.0);

  /// An offset with infinity in both components.
  static const Offset infinite = Offset(double.infinity, double.infinity);

  /// The horizontal component.
  final double dx;

  /// The vertical component.
  final double dy;

  @override
  bool operator ==(Object other) =>
      other is Offset && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset(${dx.toStringAsFixed(1)}, ${dy.toStringAsFixed(1)})';
}

/// An immutable 2D floating-point size (width × height).
///
/// Mirrors `dart:ui.Size`.
final class Size {
  /// Creates a size with the given [width] and [height].
  const Size(this.width, this.height);

  /// A size with zero width and height.
  static const Size zero = Size(0.0, 0.0);

  /// The horizontal extent.
  final double width;

  /// The vertical extent.
  final double height;

  @override
  bool operator ==(Object other) =>
      other is Size && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() =>
      'Size(${width.toStringAsFixed(1)}, ${height.toStringAsFixed(1)})';
}

/// An immutable, axis-aligned rectangle defined by its left, top, right, and
/// bottom edges.
///
/// Mirrors `dart:ui.Rect`. The convention is that `left <= right` and
/// `top <= bottom` for a non-empty rectangle, but this is not enforced at
/// construction time — both empty and inverted rectangles are representable.
final class Rect {
  const Rect._(this.left, this.top, this.right, this.bottom);

  /// Creates a rectangle from its left, top, right, and bottom edges.
  const Rect.fromLTRB(double left, double top, double right, double bottom)
      : this._(left, top, right, bottom);

  /// Creates a rectangle from its left and top edges, plus its width and
  /// height.
  const Rect.fromLTWH(double left, double top, double width, double height)
      : this._(left, top, left + width, top + height);

  /// Creates a rectangle that bounds the given two corner points.
  factory Rect.fromPoints(Offset a, Offset b) => Rect.fromLTRB(
        math.min(a.dx, b.dx),
        math.min(a.dy, b.dy),
        math.max(a.dx, b.dx),
        math.max(a.dy, b.dy),
      );

  /// Creates a rectangle of the given [width] and [height] centered at
  /// [center].
  factory Rect.fromCenter({
    required Offset center,
    required double width,
    required double height,
  }) {
    final halfW = width / 2.0;
    final halfH = height / 2.0;
    return Rect.fromLTRB(
      center.dx - halfW,
      center.dy - halfH,
      center.dx + halfW,
      center.dy + halfH,
    );
  }

  /// Creates a square rectangle of side `2 * radius` centered at [center].
  factory Rect.fromCircle({required Offset center, required double radius}) =>
      Rect.fromCenter(center: center, width: radius * 2, height: radius * 2);

  /// A rectangle with all four edges at zero.
  static const Rect zero = Rect._(0.0, 0.0, 0.0, 0.0);

  /// The left edge.
  final double left;

  /// The top edge.
  final double top;

  /// The right edge.
  final double right;

  /// The bottom edge.
  final double bottom;

  /// The distance between [left] and [right].
  double get width => right - left;

  /// The distance between [top] and [bottom].
  double get height => bottom - top;

  /// The size of this rectangle.
  Size get size => Size(width, height);

  /// Whether this rectangle has zero area.
  bool get isEmpty => left >= right || top >= bottom;

  @override
  bool operator ==(Object other) =>
      other is Rect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'Rect.fromLTRB('
      '${left.toStringAsFixed(1)}, '
      '${top.toStringAsFixed(1)}, '
      '${right.toStringAsFixed(1)}, '
      '${bottom.toStringAsFixed(1)})';
}

/// A radius for either circular or elliptical corners on an [RRect].
///
/// Mirrors `dart:ui.Radius`.
final class Radius {
  const Radius._(this.x, this.y);

  /// Creates a circular radius — both axes equal to [radius].
  const Radius.circular(double radius) : this._(radius, radius);

  /// Creates an elliptical radius with horizontal axis [x] and vertical
  /// axis [y].
  const Radius.elliptical(double x, double y) : this._(x, y);

  /// A radius with both axes set to zero.
  static const Radius zero = Radius._(0.0, 0.0);

  /// The horizontal axis.
  final double x;

  /// The vertical axis.
  final double y;

  @override
  bool operator ==(Object other) =>
      other is Radius && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => x == y
      ? 'Radius.circular(${x.toStringAsFixed(1)})'
      : 'Radius.elliptical(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// An immutable rounded rectangle: an axis-aligned rectangle with a
/// per-corner [Radius].
///
/// Mirrors `dart:ui.RRect`. For the M0 milestone this carries the data only;
/// path-construction helpers that consume it (e.g. `addRRect`) arrive in M2.
final class RRect {
  const RRect._({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.tlRadiusX,
    required this.tlRadiusY,
    required this.trRadiusX,
    required this.trRadiusY,
    required this.brRadiusX,
    required this.brRadiusY,
    required this.blRadiusX,
    required this.blRadiusY,
  });

  /// Creates a rounded rectangle from a [Rect] and a uniform corner [Radius].
  factory RRect.fromRectAndRadius(Rect rect, Radius radius) => RRect._(
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
        tlRadiusX: radius.x,
        tlRadiusY: radius.y,
        trRadiusX: radius.x,
        trRadiusY: radius.y,
        brRadiusX: radius.x,
        brRadiusY: radius.y,
        blRadiusX: radius.x,
        blRadiusY: radius.y,
      );

  /// Creates a rounded rectangle from a [Rect] and per-corner radii.
  factory RRect.fromRectAndCorners(
    Rect rect, {
    Radius topLeft = Radius.zero,
    Radius topRight = Radius.zero,
    Radius bottomRight = Radius.zero,
    Radius bottomLeft = Radius.zero,
  }) =>
      RRect._(
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom,
        tlRadiusX: topLeft.x,
        tlRadiusY: topLeft.y,
        trRadiusX: topRight.x,
        trRadiusY: topRight.y,
        brRadiusX: bottomRight.x,
        brRadiusY: bottomRight.y,
        blRadiusX: bottomLeft.x,
        blRadiusY: bottomLeft.y,
      );

  /// The left edge.
  final double left;

  /// The top edge.
  final double top;

  /// The right edge.
  final double right;

  /// The bottom edge.
  final double bottom;

  /// Horizontal radius of the top-left corner.
  final double tlRadiusX;

  /// Vertical radius of the top-left corner.
  final double tlRadiusY;

  /// Horizontal radius of the top-right corner.
  final double trRadiusX;

  /// Vertical radius of the top-right corner.
  final double trRadiusY;

  /// Horizontal radius of the bottom-right corner.
  final double brRadiusX;

  /// Vertical radius of the bottom-right corner.
  final double brRadiusY;

  /// Horizontal radius of the bottom-left corner.
  final double blRadiusX;

  /// Vertical radius of the bottom-left corner.
  final double blRadiusY;

  /// The bounding rectangle.
  Rect get outerRect => Rect.fromLTRB(left, top, right, bottom);

  /// The top-left corner radius.
  Radius get tlRadius => Radius.elliptical(tlRadiusX, tlRadiusY);

  /// The top-right corner radius.
  Radius get trRadius => Radius.elliptical(trRadiusX, trRadiusY);

  /// The bottom-right corner radius.
  Radius get brRadius => Radius.elliptical(brRadiusX, brRadiusY);

  /// The bottom-left corner radius.
  Radius get blRadius => Radius.elliptical(blRadiusX, blRadiusY);

  @override
  bool operator ==(Object other) =>
      other is RRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.tlRadiusX == tlRadiusX &&
      other.tlRadiusY == tlRadiusY &&
      other.trRadiusX == trRadiusX &&
      other.trRadiusY == trRadiusY &&
      other.brRadiusX == brRadiusX &&
      other.brRadiusY == brRadiusY &&
      other.blRadiusX == blRadiusX &&
      other.blRadiusY == blRadiusY;

  @override
  int get hashCode => Object.hashAll([
        left,
        top,
        right,
        bottom,
        tlRadiusX,
        tlRadiusY,
        trRadiusX,
        trRadiusY,
        brRadiusX,
        brRadiusY,
        blRadiusX,
        blRadiusY,
      ]);
}
