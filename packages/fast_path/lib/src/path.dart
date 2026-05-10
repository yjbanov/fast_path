// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:typed_data';

import 'geometry.dart';
import 'verbs.dart';

/// Mutable, write-optimized builder for [Path].
///
/// All construction primitives (`moveTo`, `lineTo`, `close`, …) live here.
/// The builder appends to internal verb and point buffers in place; it does
/// not maintain query caches. To run a query, call [build] to produce an
/// immutable [Path] and query that.
///
/// Method behavior matches the identically-named methods on `dart:ui.Path`,
/// even though `dart:ui` hosts construction and query on a single class. See
/// the package README for the rationale behind the builder/path split.
final class PathBuilder {
  /// Creates an empty builder. Buffers are not pre-allocated; the first
  /// append triggers an initial allocation. Use [reserve] when the eventual
  /// size is known up front.
  PathBuilder()
      : _verbs = _emptyVerbs,
        _points = _emptyPoints,
        _conicWeights = _emptyWeights;

  /// Creates a builder seeded with the contents of [path].
  ///
  /// Buffers are deep-copied so subsequent mutations on the builder do not
  /// affect [path].
  factory PathBuilder.from(Path path) {
    final builder = PathBuilder()
      .._verbs = _growU8(_emptyVerbs, path._verbs.length)
      .._points = _growF32(_emptyPoints, path._points.length)
      .._conicWeights = _growF32(_emptyWeights, path._conicWeights.length)
      .._verbsLen = path._verbs.length
      .._pointsLen = path._points.length
      .._conicWeightsLen = path._conicWeights.length
      ..fillType = path.fillType;
    builder._verbs.setRange(0, path._verbs.length, path._verbs);
    builder._points.setRange(0, path._points.length, path._points);
    builder._conicWeights
        .setRange(0, path._conicWeights.length, path._conicWeights);
    builder._lastMoveToIndex = _findLastMoveToIndex(
      builder._verbs,
      builder._verbsLen,
      builder._points,
    );
    return builder;
  }

  /// Creates a builder that is a clone of [other].
  factory PathBuilder.fromBuilder(PathBuilder other) {
    final builder = PathBuilder()
      .._verbs = _growU8(_emptyVerbs, other._verbsLen)
      .._points = _growF32(_emptyPoints, other._pointsLen)
      .._conicWeights = _growF32(_emptyWeights, other._conicWeightsLen)
      .._verbsLen = other._verbsLen
      .._pointsLen = other._pointsLen
      .._conicWeightsLen = other._conicWeightsLen
      .._lastMoveToIndex = other._lastMoveToIndex
      ..fillType = other.fillType;
    builder._verbs.setRange(0, other._verbsLen, other._verbs);
    builder._points.setRange(0, other._pointsLen, other._points);
    builder._conicWeights
        .setRange(0, other._conicWeightsLen, other._conicWeights);
    return builder;
  }

  static final Uint8List _emptyVerbs = Uint8List(0);
  static final Float32List _emptyPoints = Float32List(0);
  static final Float32List _emptyWeights = Float32List(0);

  Uint8List _verbs;
  Float32List _points;
  Float32List _conicWeights;
  int _verbsLen = 0;
  int _pointsLen = 0; // Counts doubles. Number of (x,y) pairs is _pointsLen/2.
  int _conicWeightsLen = 0;

  /// Index into [_points] of the x-coordinate of the most recent `moveTo`,
  /// or -1 if no contour has been started yet. Used by [close] to find the
  /// point to connect back to.
  int _lastMoveToIndex = -1;

  /// The fill type the produced [Path] will use.
  ///
  /// Behaves identically to `Path.fillType` in `dart:ui`, except that the
  /// setter lives on [PathBuilder] rather than `Path` (the produced [Path]
  /// is immutable; see the package README on the builder/path split).
  /// Defaults to [PathFillType.nonZero].
  PathFillType fillType = PathFillType.nonZero;

  /// Starts a new contour at `(x, y)`.
  ///
  /// Behaves identically to `Path.moveTo` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void moveTo(double x, double y) {
    _lastMoveToIndex = _pointsLen;
    _appendVerb(verbMove);
    _appendPoint(x, y);
  }

  /// Adds a straight line segment from the current point to `(x, y)`.
  ///
  /// If no contour has been started, an implicit `moveTo(0, 0)` is injected
  /// first, matching `dart:ui.Path`'s behavior.
  ///
  /// Behaves identically to `Path.lineTo` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void lineTo(double x, double y) {
    _injectMoveToIfNeeded();
    _appendVerb(verbLine);
    _appendPoint(x, y);
  }

  /// Closes the current contour by connecting the current point back to the
  /// most recent `moveTo`.
  ///
  /// If there is no open contour to close, this is a no-op (matching
  /// `dart:ui.Path.close`).
  ///
  /// Behaves identically to `Path.close` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void close() {
    if (_lastMoveToIndex < 0) {
      return;
    }
    _appendVerb(verbClose);
  }

  /// Removes all contours and resets to an empty path. Backing buffer
  /// capacity is preserved so the builder can be reused across frames
  /// without reallocating.
  ///
  /// Mirrors the intent of `dart:ui.Path.reset` (which also clears state).
  void reset() {
    _verbsLen = 0;
    _pointsLen = 0;
    _conicWeightsLen = 0;
    _lastMoveToIndex = -1;
    fillType = PathFillType.nonZero;
  }

  /// Reserves capacity for at least [verbCount] verbs and [pointCount]
  /// `(x, y)` point pairs.
  ///
  /// This is a fast_path-specific extension that has no `dart:ui` analogue.
  /// Calling it is never required for correctness; it lets size-aware
  /// callers avoid intermediate buffer growth on hot paths.
  void reserve(int verbCount, int pointCount) {
    _verbs = _growU8(_verbs, verbCount);
    _points = _growF32(_points, pointCount * 2);
  }

  /// Snapshots the builder's current state into an immutable [Path].
  ///
  /// The returned path receives a tightly-sized copy of the builder's
  /// buffers. The builder remains usable; subsequent mutations do not
  /// affect the snapshot.
  Path build() {
    final verbs = _verbsLen == 0
        ? _emptyVerbs
        : Uint8List.sublistView(_verbs, 0, _verbsLen).sublist(0);
    final points = _pointsLen == 0
        ? _emptyPoints
        : Float32List.sublistView(_points, 0, _pointsLen).sublist(0);
    final weights = _conicWeightsLen == 0
        ? _emptyWeights
        : Float32List.sublistView(_conicWeights, 0, _conicWeightsLen)
            .sublist(0);
    return Path._(verbs, points, weights, fillType);
  }

  void _injectMoveToIfNeeded() {
    if (_lastMoveToIndex < 0) {
      moveTo(0.0, 0.0);
    }
  }

  void _appendVerb(int verb) {
    if (_verbsLen == _verbs.length) {
      _verbs = _growU8(_verbs, _verbsLen + 1);
    }
    _verbs[_verbsLen++] = verb;
  }

  void _appendPoint(double x, double y) {
    if (_pointsLen + 2 > _points.length) {
      _points = _growF32(_points, _pointsLen + 2);
    }
    _points[_pointsLen++] = x;
    _points[_pointsLen++] = y;
  }

  static Uint8List _growU8(Uint8List old, int needed) {
    if (old.length >= needed) {
      return old;
    }
    var cap = old.isEmpty ? 8 : old.length;
    while (cap < needed) {
      cap *= 2;
    }
    final next = Uint8List(cap);
    if (old.isNotEmpty) {
      next.setRange(0, old.length, old);
    }
    return next;
  }

  static Float32List _growF32(Float32List old, int needed) {
    if (old.length >= needed) {
      return old;
    }
    var cap = old.isEmpty ? 16 : old.length;
    while (cap < needed) {
      cap *= 2;
    }
    final next = Float32List(cap);
    if (old.isNotEmpty) {
      next.setRange(0, old.length, old);
    }
    return next;
  }

  /// Walks the verb stream of an inherited buffer to find where the most
  /// recent `moveTo`'s coordinates start. Used by [PathBuilder.from] when
  /// reconstructing builder state from a [Path].
  static int _findLastMoveToIndex(
    Uint8List verbs,
    int verbsLen,
    Float32List points,
  ) {
    var pointIdx = 0;
    var lastMoveToIndex = -1;
    for (var i = 0; i < verbsLen; i++) {
      final verb = verbs[i];
      if (verb == verbMove) {
        lastMoveToIndex = pointIdx;
      }
      pointIdx += verbPointCount[verb] * 2;
    }
    return lastMoveToIndex;
  }
}

/// Immutable, query-optimized 2D path.
///
/// Construct via [PathBuilder.build]. The class is `final` and exposes only
/// observation methods plus pure functions that return new [Path] instances
/// (e.g. transforms, [combine]).
///
/// Method behavior matches the identically-named methods on `dart:ui.Path`.
/// The split from `dart:ui` is structural: mutating methods live on
/// [PathBuilder]; this class is read-only and safe to share across isolates,
/// hash, and use as a map key.
final class Path {
  Path._(this._verbs, this._points, this._conicWeights, this.fillType);

  final Uint8List _verbs;
  final Float32List _points;
  // ignore: unused_field — populated for future curve verbs (M1+).
  final Float32List _conicWeights;

  /// The fill type used when interpreting this path's interior.
  ///
  /// Behaves identically to `Path.fillType` (getter) in `dart:ui`. The
  /// setter lives on [PathBuilder].
  final PathFillType fillType;

  Rect? _cachedBounds;
  int? _cachedHashCode;

  /// Computes the axis-aligned bounding rectangle of this path.
  ///
  /// Returns [Rect.zero] for an empty path. The result is cached on first
  /// call; the path is immutable, so no invalidation is needed.
  ///
  /// Behaves identically to `Path.getBounds` in `dart:ui`.
  Rect getBounds() {
    final cached = _cachedBounds;
    if (cached != null) {
      return cached;
    }
    final result = _computeBounds();
    _cachedBounds = result;
    return result;
  }

  Rect _computeBounds() {
    if (_points.isEmpty) {
      return Rect.zero;
    }
    var minX = _points[0];
    var maxX = _points[0];
    var minY = _points[1];
    var maxY = _points[1];
    final n = _points.length;
    for (var i = 2; i < n; i += 2) {
      final x = _points[i];
      final y = _points[i + 1];
      if (x < minX) {
        minX = x;
      } else if (x > maxX) {
        maxX = x;
      }
      if (y < minY) {
        minY = y;
      } else if (y > maxY) {
        maxY = y;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Returns whether the given [point] is inside this path, considering the
  /// active [fillType].
  ///
  /// Empty paths and paths with no closed area contain no points.
  ///
  /// Behaves identically to `Path.contains` in `dart:ui`.
  bool contains(Offset point) {
    if (_verbs.isEmpty) {
      return false;
    }
    final px = point.dx;
    final py = point.dy;

    var crossings = 0;
    var winding = 0;
    var pointIdx = 0;
    var startX = 0.0;
    var startY = 0.0;
    var curX = 0.0;
    var curY = 0.0;
    var contourOpen = false;

    for (var i = 0; i < _verbs.length; i++) {
      final verb = _verbs[i];
      switch (verb) {
        case verbMove:
          if (contourOpen) {
            // Implicitly close the previous contour for fill-containment.
            final delta =
                _edgeWindingDelta(curX, curY, startX, startY, px, py);
            winding += delta;
            if (delta != 0) {
              crossings++;
            }
          }
          startX = _points[pointIdx];
          startY = _points[pointIdx + 1];
          curX = startX;
          curY = startY;
          pointIdx += 2;
          contourOpen = true;
        case verbLine:
          final nx = _points[pointIdx];
          final ny = _points[pointIdx + 1];
          final delta = _edgeWindingDelta(curX, curY, nx, ny, px, py);
          winding += delta;
          if (delta != 0) {
            crossings++;
          }
          curX = nx;
          curY = ny;
          pointIdx += 2;
        case verbClose:
          final delta =
              _edgeWindingDelta(curX, curY, startX, startY, px, py);
          winding += delta;
          if (delta != 0) {
            crossings++;
          }
          curX = startX;
          curY = startY;
          contourOpen = false;
        default:
          // M0 has no curves yet. M1 will add quad/conic/cubic handling.
          assert(false, 'Unsupported verb in M0: $verb');
      }
    }

    if (contourOpen) {
      // Close the final contour for fill-containment.
      final delta = _edgeWindingDelta(curX, curY, startX, startY, px, py);
      winding += delta;
      if (delta != 0) {
        crossings++;
      }
    }

    if (fillType == PathFillType.evenOdd) {
      return (crossings & 1) != 0;
    }
    return winding != 0;
  }

  /// Returns the signed winding contribution of the directed edge
  /// `(x0, y0) -> (x1, y1)` for a horizontal ray cast from `(px, py)` to
  /// `+x` infinity.
  ///
  /// `+1` if the edge crosses the ray going downward (`y0 < py < y1`),
  /// `-1` if going upward (`y0 > py > y1`), or `0` if it does not cross.
  /// The standard ray-casting tie-breaker is applied so each crossing is
  /// counted exactly once when a vertex sits on the ray.
  static int _edgeWindingDelta(
    double x0,
    double y0,
    double x1,
    double y1,
    double px,
    double py,
  ) {
    // Tie-break: use half-open intervals on y so vertices on the ray are
    // counted by exactly one of the two incident edges.
    final crossesDown = y0 <= py && y1 > py;
    final crossesUp = y1 <= py && y0 > py;
    if (!crossesDown && !crossesUp) {
      return 0;
    }
    final t = (py - y0) / (y1 - y0);
    final xIntersect = x0 + t * (x1 - x0);
    if (xIntersect <= px) {
      return 0;
    }
    return crossesDown ? 1 : -1;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Path) {
      return false;
    }
    if (other.fillType != fillType) {
      return false;
    }
    if (other._verbs.length != _verbs.length ||
        other._points.length != _points.length ||
        other._conicWeights.length != _conicWeights.length) {
      return false;
    }
    for (var i = 0; i < _verbs.length; i++) {
      if (other._verbs[i] != _verbs[i]) {
        return false;
      }
    }
    for (var i = 0; i < _points.length; i++) {
      if (other._points[i] != _points[i]) {
        return false;
      }
    }
    for (var i = 0; i < _conicWeights.length; i++) {
      if (other._conicWeights[i] != _conicWeights[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    final cached = _cachedHashCode;
    if (cached != null) {
      return cached;
    }
    var h = fillType.hashCode;
    for (var i = 0; i < _verbs.length; i++) {
      h = Object.hash(h, _verbs[i]);
    }
    for (var i = 0; i < _points.length; i++) {
      h = Object.hash(h, _points[i]);
    }
    for (var i = 0; i < _conicWeights.length; i++) {
      h = Object.hash(h, _conicWeights[i]);
    }
    _cachedHashCode = h;
    return h;
  }
}
