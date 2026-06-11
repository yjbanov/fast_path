// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
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
    final (lastMove, closed) =
        _scanBuilderState(builder._verbs, builder._verbsLen);
    builder._lastMoveToIndex = lastMove;
    builder._contourClosed = closed;
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
      .._contourClosed = other._contourClosed
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

  /// True after a successful [close] until the next [moveTo] (explicit or
  /// implicitly injected). When set, the next mutation that would extend a
  /// contour first injects an implicit `moveTo` at the just-closed contour's
  /// start, mirroring `dart:ui.Path` (and Skia) behavior.
  bool _contourClosed = false;

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
    _contourClosed = false;
  }

  /// Starts a new contour at the current point plus `(dx, dy)`.
  ///
  /// If no contour has been started, the current point is taken to be the
  /// origin, matching `dart:ui.Path`'s behavior.
  ///
  /// Behaves identically to `Path.relativeMoveTo` in `dart:ui`, except that
  /// this method lives on [PathBuilder] rather than `Path`.
  void relativeMoveTo(double dx, double dy) {
    final (cx, cy) = _currentPoint();
    moveTo(cx + dx, cy + dy);
  }

  /// Adds a straight line segment from the current point to `(x, y)`.
  ///
  /// If no contour has been started, an implicit `moveTo(0, 0)` is injected
  /// first. If the previous operation was [close], an implicit `moveTo` is
  /// injected at the just-closed contour's start so the new segment opens a
  /// fresh contour. Both behaviors mirror `dart:ui.Path`.
  ///
  /// Behaves identically to `Path.lineTo` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void lineTo(double x, double y) {
    _injectMoveToIfNeeded();
    _appendVerb(verbLine);
    _appendPoint(x, y);
  }

  /// Adds a straight line segment from the current point to the current
  /// point plus `(dx, dy)`.
  ///
  /// Behaves identically to `Path.relativeLineTo` in `dart:ui`, except that
  /// this method lives on [PathBuilder] rather than `Path`. See [lineTo] for
  /// implicit-moveTo behavior.
  void relativeLineTo(double dx, double dy) {
    final (cx, cy) = _currentPoint();
    lineTo(cx + dx, cy + dy);
  }

  /// Adds a quadratic Bézier segment from the current point with control
  /// point `(x1, y1)` ending at `(x2, y2)`.
  ///
  /// Implicit-moveTo rules from [lineTo] apply.
  ///
  /// Behaves identically to `Path.quadraticBezierTo` in `dart:ui`, except
  /// that this method lives on [PathBuilder] rather than `Path`.
  void quadraticBezierTo(double x1, double y1, double x2, double y2) {
    _injectMoveToIfNeeded();
    _appendVerb(verbQuad);
    _appendPoint(x1, y1);
    _appendPoint(x2, y2);
  }

  /// Quadratic Bézier from the current point with control point
  /// current + `(dx1, dy1)` ending at current + `(dx2, dy2)`.
  ///
  /// Behaves identically to `Path.relativeQuadraticBezierTo` in `dart:ui`,
  /// except that this method lives on [PathBuilder] rather than `Path`.
  void relativeQuadraticBezierTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
  ) {
    final (cx, cy) = _currentPoint();
    quadraticBezierTo(cx + dx1, cy + dy1, cx + dx2, cy + dy2);
  }

  /// Adds a cubic Bézier segment from the current point with control
  /// points `(x1, y1)` and `(x2, y2)` ending at `(x3, y3)`.
  ///
  /// Implicit-moveTo rules from [lineTo] apply.
  ///
  /// Behaves identically to `Path.cubicTo` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    _injectMoveToIfNeeded();
    _appendVerb(verbCubic);
    _appendPoint(x1, y1);
    _appendPoint(x2, y2);
    _appendPoint(x3, y3);
  }

  /// Cubic Bézier from the current point with control points
  /// current + `(dx1, dy1)` and current + `(dx2, dy2)` ending at current +
  /// `(dx3, dy3)`.
  ///
  /// Behaves identically to `Path.relativeCubicTo` in `dart:ui`, except
  /// that this method lives on [PathBuilder] rather than `Path`.
  void relativeCubicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double dx3,
    double dy3,
  ) {
    final (cx, cy) = _currentPoint();
    cubicTo(
      cx + dx1, cy + dy1,
      cx + dx2, cy + dy2,
      cx + dx3, cy + dy3,
    );
  }

  /// Adds a conic (rational quadratic Bézier) segment from the current
  /// point with control point `(x1, y1)` ending at `(x2, y2)`, weighted
  /// by [w].
  ///
  /// Invalid weights — `w <= 0`, NaN, or infinite — are normalized to
  /// `w == 1`, i.e. the segment becomes a plain quadratic Bézier through
  /// the same control point. This matches the behavior observed in
  /// current `dart:ui.Path.conicTo` (Impeller-backed; verified
  /// empirically — note this differs from classic Skia documentation,
  /// which converts `w <= 0` to a straight line). A weight of exactly 1
  /// is also stored as a quadratic, since the two are geometrically
  /// identical.
  ///
  /// Implicit-moveTo rules from [lineTo] apply.
  ///
  /// Behaves identically to `Path.conicTo` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void conicTo(double x1, double y1, double x2, double y2, double w) {
    if (!w.isFinite || w <= 0 || w == 1.0) {
      // NaN, ±infinity, non-positive, and exactly-1 weights all behave
      // as a plain quadratic in current dart:ui.
      quadraticBezierTo(x1, y1, x2, y2);
      return;
    }
    _injectMoveToIfNeeded();
    _appendVerb(verbConic);
    _appendPoint(x1, y1);
    _appendPoint(x2, y2);
    _appendConicWeight(w);
  }

  /// Conic segment from the current point with control point
  /// current + `(dx1, dy1)` ending at current + `(dx2, dy2)`, weighted
  /// by [w]. See [conicTo] for weight normalization.
  ///
  /// Behaves identically to `Path.relativeConicTo` in `dart:ui`, except
  /// that this method lives on [PathBuilder] rather than `Path`.
  void relativeConicTo(
    double dx1,
    double dy1,
    double dx2,
    double dy2,
    double w,
  ) {
    final (cx, cy) = _currentPoint();
    conicTo(cx + dx1, cy + dy1, cx + dx2, cy + dy2, w);
  }

  /// Adds a contour consisting of straight line segments connecting [points]
  /// in order. If [close] is true, the contour is closed back to
  /// `points.first`.
  ///
  /// An empty [points] list is a no-op, matching `dart:ui.Path.addPolygon`.
  ///
  /// Behaves identically to `Path.addPolygon` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void addPolygon(List<Offset> points, bool close) {
    if (points.isEmpty) {
      return;
    }
    moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      lineTo(points[i].dx, points[i].dy);
    }
    if (close) {
      this.close();
    }
  }

  /// Adds a closed rectangular contour: clockwise from the top-left
  /// corner of [rect].
  ///
  /// Behaves identically to `Path.addRect` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void addRect(Rect rect) {
    moveTo(rect.left, rect.top);
    lineTo(rect.right, rect.top);
    lineTo(rect.right, rect.bottom);
    lineTo(rect.left, rect.bottom);
    close();
  }

  /// The conic weight that turns a quarter ellipse into an exact conic
  /// section: cos(45°) = √2/2.
  static const double _quarterArcWeight = 0.707106781186547524;

  /// Adds a closed oval contour inscribed in [oval]: four quarter-ellipse
  /// conics (weight √2/2) wound clockwise from the right edge's midpoint,
  /// with control points at the corners of [oval]. The control points
  /// land in the loose `getBounds`, so the bounds of an oval path equal
  /// [oval] itself — matching Skia's representation.
  ///
  /// Behaves identically to `Path.addOval` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void addOval(Rect oval) {
    final l = oval.left;
    final t = oval.top;
    final r = oval.right;
    final b = oval.bottom;
    final cx = (l + r) / 2;
    final cy = (t + b) / 2;
    const w = _quarterArcWeight;
    moveTo(r, cy);
    conicTo(r, b, cx, b, w);
    conicTo(l, b, l, cy, w);
    conicTo(l, t, cx, t, w);
    conicTo(r, t, r, cy, w);
    close();
  }

  /// Adds a closed rounded-rectangle contour: straight edges joined by
  /// quarter-ellipse conic corners (weight √2/2), wound clockwise.
  ///
  /// Radii are normalized the way Skia's `SkRRect::scaleRadii` does
  /// (and therefore the way `dart:ui` behaves): negative radii clamp to
  /// zero, and if the radii of two adjacent corners overflow the edge
  /// between them, *all* radii are scaled down uniformly by the largest
  /// factor that makes every edge fit.
  ///
  /// Behaves identically to `Path.addRRect` in `dart:ui`, except that
  /// this method lives on [PathBuilder] rather than `Path`.
  void addRRect(RRect rrect) {
    final l = rrect.left;
    final t = rrect.top;
    final r = rrect.right;
    final b = rrect.bottom;
    final width = r - l;
    final height = b - t;

    var tlX = rrect.tlRadiusX < 0 ? 0.0 : rrect.tlRadiusX;
    var tlY = rrect.tlRadiusY < 0 ? 0.0 : rrect.tlRadiusY;
    var trX = rrect.trRadiusX < 0 ? 0.0 : rrect.trRadiusX;
    var trY = rrect.trRadiusY < 0 ? 0.0 : rrect.trRadiusY;
    var brX = rrect.brRadiusX < 0 ? 0.0 : rrect.brRadiusX;
    var brY = rrect.brRadiusY < 0 ? 0.0 : rrect.brRadiusY;
    var blX = rrect.blRadiusX < 0 ? 0.0 : rrect.blRadiusX;
    var blY = rrect.blRadiusY < 0 ? 0.0 : rrect.blRadiusY;

    // Skia's scaleRadii: find the largest uniform scale that makes the
    // radii of every edge's two corners fit within that edge.
    var scale = 1.0;
    void limit(double edge, double r1, double r2) {
      final sum = r1 + r2;
      if (sum > edge && sum > 0) {
        final s = edge / sum;
        if (s < scale) {
          scale = s;
        }
      }
    }

    limit(width, tlX, trX); // top
    limit(height, trY, brY); // right
    limit(width, blX, brX); // bottom
    limit(height, tlY, blY); // left
    if (scale < 1.0) {
      tlX *= scale;
      tlY *= scale;
      trX *= scale;
      trY *= scale;
      brX *= scale;
      brY *= scale;
      blX *= scale;
      blY *= scale;
    }

    const w = _quarterArcWeight;
    moveTo(l + tlX, t);
    lineTo(r - trX, t);
    if (trX > 0 && trY > 0) {
      conicTo(r, t, r, t + trY, w);
    }
    lineTo(r, b - brY);
    if (brX > 0 && brY > 0) {
      conicTo(r, b, r - brX, b, w);
    }
    lineTo(l + blX, b);
    if (blX > 0 && blY > 0) {
      conicTo(l, b, l, b - blY, w);
    }
    lineTo(l, t + tlY);
    if (tlX > 0 && tlY > 0) {
      conicTo(l, t, l + tlX, t, w);
    }
    close();
  }

  /// Adds an arc segment along the ellipse inscribed in [rect], starting
  /// at [startAngle] radians (0 = +x axis, positive = clockwise on
  /// screen) and sweeping [sweepAngle] radians.
  ///
  /// If [forceMoveTo] is true the arc starts a new contour; otherwise a
  /// straight line connects the current point to the arc's start (with
  /// the usual implicit `moveTo(0, 0)` when the path is empty). Sweeps
  /// beyond a full circle are clamped to ±2π.
  ///
  /// Behaves identically to `Path.arcTo` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void arcTo(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool forceMoveTo,
  ) {
    final cx = (rect.left + rect.right) / 2;
    final cy = (rect.top + rect.bottom) / 2;
    final rx = (rect.right - rect.left) / 2;
    final ry = (rect.bottom - rect.top) / 2;

    final sx = cx + rx * math.cos(startAngle);
    final sy = cy + ry * math.sin(startAngle);
    if (forceMoveTo) {
      moveTo(sx, sy);
    } else {
      lineTo(sx, sy);
    }

    var sweep = sweepAngle;
    const twoPi = 2 * math.pi;
    if (sweep > twoPi) {
      sweep = twoPi;
    } else if (sweep < -twoPi) {
      sweep = -twoPi;
    }
    if (sweep == 0) {
      return;
    }

    // Chop into segments of at most 90° so each is representable as a
    // single conic with weight cos(halfSweep). Control point on the
    // unit circle sits at the mid-angle, pushed out to 1/cos(halfSweep)
    // (the intersection of the endpoint tangents).
    final n = (sweep.abs() / (math.pi / 2)).ceil();
    final delta = sweep / n;
    final half = delta / 2;
    final w = math.cos(half.abs());
    final controlScale = 1 / w;

    var a0 = startAngle;
    for (var i = 0; i < n; i++) {
      final a1 = a0 + delta;
      final mid = a0 + half;
      conicTo(
        cx + rx * math.cos(mid) * controlScale,
        cy + ry * math.sin(mid) * controlScale,
        cx + rx * math.cos(a1),
        cy + ry * math.sin(a1),
        w,
      );
      a0 = a1;
    }
  }

  /// Adds an arc along the ellipse inscribed in [oval], always starting
  /// a new contour at the arc's start point. Equivalent to
  /// `arcTo(oval, startAngle, sweepAngle, true)`.
  ///
  /// Behaves identically to `Path.addArc` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void addArc(Rect oval, double startAngle, double sweepAngle) {
    arcTo(oval, startAngle, sweepAngle, true);
  }

  /// Closes the current contour by connecting the current point back to the
  /// most recent `moveTo`.
  ///
  /// If there is no open contour to close (no prior `moveTo`, or the most
  /// recent contour is already closed), this is a no-op. Both behaviors
  /// match `dart:ui.Path.close`.
  ///
  /// Behaves identically to `Path.close` in `dart:ui`, except that this
  /// method lives on [PathBuilder] rather than `Path`.
  void close() {
    if (_lastMoveToIndex < 0 || _contourClosed) {
      return;
    }
    _appendVerb(verbClose);
    _contourClosed = true;
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
    _contourClosed = false;
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
    } else if (_contourClosed) {
      // The previous contour was closed; reopen at its start so the next
      // segment begins a fresh contour rather than silently extending the
      // closed one. Matches Skia's `injectMoveToIfNeeded`.
      moveTo(_points[_lastMoveToIndex], _points[_lastMoveToIndex + 1]);
    }
  }

  /// Returns the current point — the implicit "from" position used by the
  /// next mutation. After [close], this is the start of the just-closed
  /// contour. Before any mutation, it is the origin.
  (double, double) _currentPoint() {
    if (_verbsLen == 0) {
      return (0.0, 0.0);
    }
    final lastVerb = _verbs[_verbsLen - 1];
    if (lastVerb == verbClose) {
      return (_points[_lastMoveToIndex], _points[_lastMoveToIndex + 1]);
    }
    return (_points[_pointsLen - 2], _points[_pointsLen - 1]);
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

  void _appendConicWeight(double w) {
    if (_conicWeightsLen + 1 > _conicWeights.length) {
      _conicWeights = _growF32(_conicWeights, _conicWeightsLen + 1);
    }
    _conicWeights[_conicWeightsLen++] = w;
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

  /// Walks the verb stream of an inherited buffer to recover the builder
  /// state that isn't represented directly in the verb/point arrays:
  /// the `_lastMoveToIndex` cursor, and whether the trailing contour was
  /// closed. Used by [PathBuilder.from] when reseeding from a [Path].
  static (int lastMoveToIndex, bool contourClosed) _scanBuilderState(
    Uint8List verbs,
    int verbsLen,
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
    final contourClosed = verbsLen > 0 && verbs[verbsLen - 1] == verbClose;
    return (lastMoveToIndex, contourClosed);
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
    // Loose bounds: the bbox of every point in the path, including control
    // points of any curves. Matches `dart:ui.Path.getBounds()` (and Skia's
    // `SkPath::getBounds()`), which is documented as "may be larger than
    // the actual area" precisely because it includes off-curve control
    // points without solving for true curve extrema. A separate
    // `computeTightBounds`-style method could be added later if a caller
    // genuinely needs the tight value; for now matching dart:ui wins.
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
    var weightIdx = 0;
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
        case verbQuad:
          final cx = _points[pointIdx];
          final cy = _points[pointIdx + 1];
          final ex = _points[pointIdx + 2];
          final ey = _points[pointIdx + 3];
          // Quick reject on the control hull: the curve lies inside the
          // convex hull of its control points, so if the ray's y is
          // strictly outside the hull's y-range there is no root, and if
          // px is at or beyond the hull's max x no root can satisfy
          // x(t) > px. Strict y comparisons keep endpoint ties flowing
          // to the solver, which owns the tie-break rules.
          var yMin = curY < cy ? curY : cy;
          if (ey < yMin) yMin = ey;
          var yMax = curY > cy ? curY : cy;
          if (ey > yMax) yMax = ey;
          if (py >= yMin && py <= yMax) {
            var xMax = curX > cx ? curX : cx;
            if (ex > xMax) xMax = ex;
            if (px < xMax) {
              final (qWinding, qCrossings) = _quadCrossingsForRay(
                curX, curY, cx, cy, ex, ey, px, py,
              );
              winding += qWinding;
              crossings += qCrossings;
            }
          }
          curX = ex;
          curY = ey;
          pointIdx += 4;
        case verbConic:
          final cx = _points[pointIdx];
          final cy = _points[pointIdx + 1];
          final ex = _points[pointIdx + 2];
          final ey = _points[pointIdx + 3];
          final w = _conicWeights[weightIdx++];
          // Same hull reject as the quad case: a conic with w > 0 is a
          // convex combination of its control points, so the hull bound
          // holds.
          var yMin = curY < cy ? curY : cy;
          if (ey < yMin) yMin = ey;
          var yMax = curY > cy ? curY : cy;
          if (ey > yMax) yMax = ey;
          if (py >= yMin && py <= yMax) {
            var xMax = curX > cx ? curX : cx;
            if (ex > xMax) xMax = ex;
            if (px < xMax) {
              final (kWinding, kCrossings) = _conicCrossingsForRay(
                curX, curY, cx, cy, ex, ey, w, px, py,
              );
              winding += kWinding;
              crossings += kCrossings;
            }
          }
          curX = ex;
          curY = ey;
          pointIdx += 4;
        case verbCubic:
          final c1x = _points[pointIdx];
          final c1y = _points[pointIdx + 1];
          final c2x = _points[pointIdx + 2];
          final c2y = _points[pointIdx + 3];
          final ex = _points[pointIdx + 4];
          final ey = _points[pointIdx + 5];
          // Hull reject before the (comparatively expensive) Cardano /
          // trig solver.
          var yMin = curY < c1y ? curY : c1y;
          if (c2y < yMin) yMin = c2y;
          if (ey < yMin) yMin = ey;
          var yMax = curY > c1y ? curY : c1y;
          if (c2y > yMax) yMax = c2y;
          if (ey > yMax) yMax = ey;
          if (py >= yMin && py <= yMax) {
            var xMax = curX > c1x ? curX : c1x;
            if (c2x > xMax) xMax = c2x;
            if (ex > xMax) xMax = ex;
            if (px < xMax) {
              final (cWinding, cCrossings) = _cubicCrossingsForRay(
                curX, curY, c1x, c1y, c2x, c2y, ex, ey, px, py,
              );
              winding += cWinding;
              crossings += cCrossings;
            }
          }
          curX = ex;
          curY = ey;
          pointIdx += 6;
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
          assert(false, 'Unknown verb: $verb');
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

  /// Analytic crossings of a single quadratic Bézier against a horizontal
  /// ray cast from `(px, py)` to `+x`. Returns
  /// `(windingDelta, crossingCount)` — the signed sum for the nonZero
  /// fill rule, and the unsigned count for evenOdd.
  ///
  /// The curve is `B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2`. Setting
  /// `y(t) = py` yields a quadratic in `t`:
  ///
  ///     a·t² + b·t + c = 0
  ///     a = y0 - 2y1 + y2
  ///     b = 2(y1 - y0)
  ///     c = y0 - py
  ///
  /// For each real root in `[0, 1]`, we compute `x(t)` and the sign of
  /// `y'(t) = b + 2at` to determine the crossing direction. Tie-breaking
  /// at endpoints matches the line-segment convention used by
  /// [_edgeWindingDelta]: a vertex on the ray is counted by the segment
  /// that LEAVES the vertex going downward (positive `y'` at `t = 0`) or
  /// the segment that ARRIVES at the vertex going upward (negative `y'`
  /// at `t = 1`). Tangent crossings (`y' = 0`) contribute nothing.
  ///
  /// Handles two boundary cases explicitly:
  ///
  /// - `a = 0` (curve is linear in `t`): single root at `-c/b`. Skip if
  ///   `b = 0` (degenerate constant).
  /// - `discriminant < 0`: the curve never reaches `py`. No crossings.
  /// - `discriminant = 0`: double root, curve grazes `py` tangentially.
  ///   Processed once; `y'(t)` at that root is `0` so the tangent guard
  ///   suppresses it.
  static (int, int) _quadCrossingsForRay(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double px,
    double py,
  ) {
    final a = y0 - 2 * y1 + y2;
    final b = 2 * (y1 - y0);
    final c = y0 - py;

    if (a == 0) {
      // Linear in t: b·t + c = 0.
      if (b == 0) {
        return (0, 0);
      }
      final t = -c / b;
      if (t < 0 || t > 1) {
        return (0, 0);
      }
      return _quadRootContribution(t, a, b, x0, x1, x2, px);
    }

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
      return (0, 0);
    }
    final sqrtD = math.sqrt(discriminant);
    final twoA = 2 * a;
    final t1 = (-b - sqrtD) / twoA;
    final t2 = (-b + sqrtD) / twoA;

    var winding = 0;
    var crossings = 0;

    if (t1 >= 0 && t1 <= 1) {
      final (w, c) = _quadRootContribution(t1, a, b, x0, x1, x2, px);
      winding += w;
      crossings += c;
    }
    // When discriminant == 0 the two roots coincide (a single double
    // root). Process only once to avoid double-counting; the tangent
    // guard inside `_quadRootContribution` will zero it out anyway.
    if (discriminant > 0 && t2 >= 0 && t2 <= 1) {
      final (w, c) = _quadRootContribution(t2, a, b, x0, x1, x2, px);
      winding += w;
      crossings += c;
    }

    return (winding, crossings);
  }

  /// Contribution of a single root `t` of `y(t) = py` to the ray-crossing
  /// count. Encapsulates the half-open endpoint tie-break and the
  /// `x(t) > px` filter.
  static (int, int) _quadRootContribution(
    double t,
    double a,
    double b,
    double x0,
    double x1,
    double x2,
    double px,
  ) {
    final yPrime = b + 2 * a * t;
    if (yPrime == 0) {
      // Tangent crossing: the curve touches the ray without traversing
      // it. No winding contribution either way.
      return (0, 0);
    }
    // Endpoint half-open convention: vertex on the ray is counted by the
    // segment that LEAVES going downward or ARRIVES going upward.
    if (t == 0 && yPrime < 0) {
      return (0, 0);
    }
    if (t == 1 && yPrime > 0) {
      return (0, 0);
    }

    final omt = 1 - t;
    final x = omt * omt * x0 + 2 * omt * t * x1 + t * t * x2;
    if (x <= px) {
      return (0, 0);
    }

    return yPrime > 0 ? (1, 1) : (-1, 1);
  }

  /// Analytic crossings of a single conic (rational quadratic Bézier)
  /// against the horizontal ray from `(px, py)` to `+x`. Returns
  /// `(windingDelta, crossingCount)`.
  ///
  /// The conic is `B(t) = N(t) / D(t)` with
  ///
  ///     N(t) = (1-t)²·P0 + 2w·(1-t)t·P1 + t²·P2
  ///     D(t) = (1-t)²    + 2w·(1-t)t    + t²
  ///
  /// Setting `y(t) = py` and multiplying through by `D(t)` (strictly
  /// positive for `w > 0` on `t ∈ [0, 1]`) gives a plain quadratic:
  ///
  ///     f(t) = (1-t)²·c0 + 2(1-t)t·c1 + t²·c2 = 0
  ///     c0 = y0 - py,  c1 = w·(y1 - py),  c2 = y2 - py
  ///
  /// i.e. `a·t² + b·t + c` with `a = c0 - 2c1 + c2`, `b = 2(c1 - c0)`,
  /// `c = c0`. Because `y - py = f / D` and `D > 0`, the crossing
  /// direction at a root is `sign(f'(t)) = sign(2at + b)` — identical in
  /// shape to the quad case. Only the `x(t)` evaluation differs (it's
  /// rational).
  ///
  /// Callers guarantee `0 < w < ∞` and `w != 1`: [PathBuilder.conicTo]
  /// normalizes degenerate weights to lines / quads before they ever
  /// reach the verb buffer.
  static (int, int) _conicCrossingsForRay(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double w,
    double px,
    double py,
  ) {
    final c0 = y0 - py;
    final c1 = w * (y1 - py);
    final c2 = y2 - py;
    final a = c0 - 2 * c1 + c2;
    final b = 2 * (c1 - c0);

    if (a == 0) {
      if (b == 0) {
        return (0, 0);
      }
      final t = -c0 / b;
      if (t < 0 || t > 1) {
        return (0, 0);
      }
      return _conicRootContribution(t, a, b, x0, x1, x2, w, px);
    }

    final discriminant = b * b - 4 * a * c0;
    if (discriminant < 0) {
      return (0, 0);
    }
    final sqrtD = math.sqrt(discriminant);
    final twoA = 2 * a;
    final t1 = (-b - sqrtD) / twoA;
    final t2 = (-b + sqrtD) / twoA;

    var winding = 0;
    var crossings = 0;

    if (t1 >= 0 && t1 <= 1) {
      final (rw, rc) = _conicRootContribution(t1, a, b, x0, x1, x2, w, px);
      winding += rw;
      crossings += rc;
    }
    if (discriminant > 0 && t2 >= 0 && t2 <= 1) {
      final (rw, rc) = _conicRootContribution(t2, a, b, x0, x1, x2, w, px);
      winding += rw;
      crossings += rc;
    }

    return (winding, crossings);
  }

  /// Contribution of a single root `t` of the conic's `y(t) = py` to the
  /// ray-crossing count. Same tie-break rules as [_quadRootContribution];
  /// `x(t)` is the rational conic evaluation.
  static (int, int) _conicRootContribution(
    double t,
    double a,
    double b,
    double x0,
    double x1,
    double x2,
    double w,
    double px,
  ) {
    final yPrime = b + 2 * a * t;
    if (yPrime == 0) {
      return (0, 0); // tangent crossing
    }
    if (t == 0 && yPrime < 0) {
      return (0, 0);
    }
    if (t == 1 && yPrime > 0) {
      return (0, 0);
    }

    final omt = 1 - t;
    final basis0 = omt * omt;
    final basis1 = 2 * w * omt * t;
    final basis2 = t * t;
    final denom = basis0 + basis1 + basis2;
    final x = (basis0 * x0 + basis1 * x1 + basis2 * x2) / denom;
    if (x <= px) {
      return (0, 0);
    }

    return yPrime > 0 ? (1, 1) : (-1, 1);
  }

  /// Analytic crossings of a single cubic Bézier against the horizontal
  /// ray from `(px, py)` to `+x`. Mirrors [_quadCrossingsForRay] in
  /// shape: returns `(windingDelta, crossingCount)`.
  ///
  /// Setting `y(t) = py` on a cubic Bézier yields a cubic in `t`:
  ///
  ///     A·t³ + B·t² + C·t + D = 0
  ///     A = -y0 + 3y1 - 3y2 + y3
  ///     B = 3(y0 - 2y1 + y2)
  ///     C = 3(y1 - y0)
  ///     D = y0 - py
  ///
  /// Solved via the standard depression + Cardano / trig pipeline:
  ///
  /// 1. Normalize by `A`, substitute `t = u - B/(3A)` to drop the t²
  ///    term, leaving a depressed cubic `u³ + P·u + Q = 0`.
  /// 2. Pick the branch by discriminant `Δ = (Q/2)² + (P/3)³`:
  ///    - `Δ > 0`: one real root (Cardano).
  ///    - `Δ < 0`: three distinct real roots (trigonometric form).
  ///    - `Δ = 0`: double + simple root (or triple). Tangent guard
  ///      inside the per-root helper neutralizes the double root.
  /// 3. For each root `t` in `[0, 1]`, hand off to
  ///    [_cubicRootContribution] for the half-open endpoint tie-break
  ///    and `x(t) > px` check.
  ///
  /// Degenerate cases handled first: when `A = 0` the equation drops to
  /// a quadratic in `t`; when `B` is also zero it's linear; when `C` is
  /// also zero it's a constant (no crossings unless `D = 0`, in which
  /// case the curve lies on the ray for all `t` — treated as zero
  /// contribution).
  ///
  /// Note that `x(t)` is still a cubic regardless of which y-branch
  /// applies, so the quadratic-fallback can't simply delegate to
  /// [_quadCrossingsForRay] — it needs to evaluate the cubic `x(t)`.
  static (int, int) _cubicCrossingsForRay(
    double x0,
    double y0,
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
    double px,
    double py,
  ) {
    final A = -y0 + 3 * y1 - 3 * y2 + y3;
    final B = 3 * (y0 - 2 * y1 + y2);
    final C = 3 * (y1 - y0);
    final D = y0 - py;

    var winding = 0;
    var crossings = 0;

    // Degenerate: A = 0 → cubic in t collapses to quadratic.
    if (A == 0) {
      if (B == 0) {
        if (C == 0) {
          // Constant in t: y(t) - py = D for all t. No crossings.
          return (0, 0);
        }
        final t = -D / C;
        if (t >= 0 && t <= 1) {
          final (w, c) =
              _cubicRootContribution(t, A, B, C, x0, x1, x2, x3, px);
          winding += w;
          crossings += c;
        }
        return (winding, crossings);
      }
      final disc = C * C - 4 * B * D;
      if (disc < 0) {
        return (0, 0);
      }
      final sqrtDisc = math.sqrt(disc);
      final twoB = 2 * B;
      final t1 = (-C - sqrtDisc) / twoB;
      if (t1 >= 0 && t1 <= 1) {
        final (w, c) =
            _cubicRootContribution(t1, A, B, C, x0, x1, x2, x3, px);
        winding += w;
        crossings += c;
      }
      if (disc > 0) {
        final t2 = (-C + sqrtDisc) / twoB;
        if (t2 >= 0 && t2 <= 1) {
          final (w, c) =
              _cubicRootContribution(t2, A, B, C, x0, x1, x2, x3, px);
          winding += w;
          crossings += c;
        }
      }
      return (winding, crossings);
    }

    // True cubic. Depress: u³ + P·u + Q = 0 with t = u - p/3.
    final p = B / A;
    final q = C / A;
    final r = D / A;
    final pOver3 = p / 3;
    final P = q - p * p / 3;
    final Q = 2 * p * p * p / 27 - p * q / 3 + r;

    final halfQ = Q / 2;
    final p3 = P / 3;
    final discriminant = halfQ * halfQ + p3 * p3 * p3;

    if (discriminant > 0) {
      // One real root via Cardano.
      final sqrtD = math.sqrt(discriminant);
      final u = _cbrt(-halfQ + sqrtD) + _cbrt(-halfQ - sqrtD);
      final t = u - pOver3;
      if (t >= 0 && t <= 1) {
        final (w, c) = _cubicRootContribution(t, A, B, C, x0, x1, x2, x3, px);
        winding += w;
        crossings += c;
      }
    } else if (discriminant < 0) {
      // Three distinct real roots via the trigonometric form. P must be
      // negative (otherwise discriminant would be ≥ 0), so `-P/3` and
      // `-(P/3)³` are positive; the square roots and the acos argument
      // are well-defined.
      final m = 2 * math.sqrt(-p3);
      // 3Q / (P · m) can drift slightly outside [-1, 1] due to FP
      // rounding even when it's mathematically in range; clamp before
      // handing it to acos.
      final cosArg = (3 * Q) / (P * m);
      final clamped = cosArg < -1 ? -1.0 : (cosArg > 1 ? 1.0 : cosArg);
      final theta = math.acos(clamped) / 3;
      const twoPiOver3 = 2 * math.pi / 3;

      final u0 = m * math.cos(theta);
      final u1 = m * math.cos(theta - twoPiOver3);
      final u2 = m * math.cos(theta + twoPiOver3);

      final t0 = u0 - pOver3;
      if (t0 >= 0 && t0 <= 1) {
        final (w, c) = _cubicRootContribution(t0, A, B, C, x0, x1, x2, x3, px);
        winding += w;
        crossings += c;
      }
      final t1 = u1 - pOver3;
      if (t1 >= 0 && t1 <= 1) {
        final (w, c) = _cubicRootContribution(t1, A, B, C, x0, x1, x2, x3, px);
        winding += w;
        crossings += c;
      }
      final t2 = u2 - pOver3;
      if (t2 >= 0 && t2 <= 1) {
        final (w, c) = _cubicRootContribution(t2, A, B, C, x0, x1, x2, x3, px);
        winding += w;
        crossings += c;
      }
    } else {
      // discriminant == 0: double + simple root (or triple if Q = 0).
      // The tangent guard inside _cubicRootContribution suppresses the
      // double root since y'(t) = 0 there; we don't need to special-
      // case it.
      if (Q == 0) {
        // Triple root at u = 0 → t = -p/3.
        final t = -pOver3;
        if (t >= 0 && t <= 1) {
          final (w, c) =
              _cubicRootContribution(t, A, B, C, x0, x1, x2, x3, px);
          winding += w;
          crossings += c;
        }
      } else {
        final cbrt = _cbrt(-halfQ);
        final tSingle = 2 * cbrt - pOver3;
        final tDouble = -cbrt - pOver3;
        if (tSingle >= 0 && tSingle <= 1) {
          final (w, c) = _cubicRootContribution(
            tSingle, A, B, C, x0, x1, x2, x3, px,
          );
          winding += w;
          crossings += c;
        }
        if (tDouble >= 0 && tDouble <= 1) {
          final (w, c) = _cubicRootContribution(
            tDouble, A, B, C, x0, x1, x2, x3, px,
          );
          winding += w;
          crossings += c;
        }
      }
    }

    return (winding, crossings);
  }

  /// Contribution of a single root `t` of `y(t) = py` on a cubic Bézier
  /// to the ray-crossing count. Same shape and tie-break rules as
  /// [_quadRootContribution]; the only differences are the
  /// `y'(t) = 3A·t² + 2B·t + C` formula and the cubic `x(t)` evaluation.
  static (int, int) _cubicRootContribution(
    double t,
    double A,
    double B,
    double C,
    double x0,
    double x1,
    double x2,
    double x3,
    double px,
  ) {
    final yPrime = 3 * A * t * t + 2 * B * t + C;
    if (yPrime == 0) {
      return (0, 0); // tangent crossing
    }
    if (t == 0 && yPrime < 0) {
      return (0, 0);
    }
    if (t == 1 && yPrime > 0) {
      return (0, 0);
    }

    final omt = 1 - t;
    final omt2 = omt * omt;
    final t2 = t * t;
    final x = omt2 * omt * x0 +
        3 * omt2 * t * x1 +
        3 * omt * t2 * x2 +
        t2 * t * x3;
    if (x <= px) {
      return (0, 0);
    }

    return yPrime > 0 ? (1, 1) : (-1, 1);
  }

  /// Real-valued cube root, signed. `dart:math` only exposes `pow` which
  /// returns NaN for negative bases at non-integer exponents, so we
  /// reflect across zero by hand.
  static double _cbrt(double x) {
    if (x < 0) {
      return -math.pow(-x, 1 / 3).toDouble();
    }
    return math.pow(x, 1 / 3).toDouble();
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
