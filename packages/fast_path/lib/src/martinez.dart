// Boolean polygon operations via the Martínez–Rueda–Feito sweep-line algorithm.
//
// Algorithm: F. Martínez, A. J. Rueda, F. R. Feito, "A new algorithm for
// computing Boolean operations on polygons," Computers & Geosciences 35 (2009).
//
// This Dart implementation was adapted from the MIT-licensed reference
// implementation `martinez` by Alexander Milevski
// (https://github.com/w8r/martinez, `master` branch, fetched 2026-06-14). The
// field-computation rules, segment-intersection routine, coincident-edge
// handling, and edge-connection logic follow that reference; the code is
// restructured for fast_path's flattened-contour inputs and Float64List
// outputs, and the result-assembly step drops the reference's hole/depth
// nesting because fast_path emits boolean results under the even-odd fill rule
// (a hole is simply a separate contour — see design_docs/boolean_ops.md §4).
//
//   Copyright (c) 2018 Alexander Milevski (MIT License).
//
// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

/// The four primitive boolean operations on polygon sets. The public
/// `PathOperation` (difference / reverseDifference) maps onto [difference] by
/// swapping the operands; see [martinezBooleanOp]'s callers.
enum BoolOp { intersection, union, difference, xor }

// Edge-type tags for coincident (overlapping collinear) segments.
const int _kNormal = 0;
const int _kNonContributing = 1;
const int _kSameTransition = 2;
const int _kDifferentTransition = 3;

/// Computes the boolean [op] of two polygon sets and returns the result as a
/// list of closed rings (packed `[x0,y0,x1,y1,…]`, no duplicated closing
/// vertex). Each input is a list of closed rings as produced by
/// `Path._flattenForOps`; interiors are interpreted under the **even-odd** rule
/// (see the note in design_docs/boolean_ops.md §8 on nonZero self-overlap).
///
/// `subject` is the first operand, `clipping` the second. `difference` is
/// `subject − clipping`.
List<Float64List> martinezBooleanOp(
  List<Float64List> subject,
  List<Float64List> clipping,
  BoolOp op,
) {
  // Trivial operand cases.
  if (subject.isEmpty && clipping.isEmpty) {
    return const [];
  }
  if (subject.isEmpty || clipping.isEmpty) {
    switch (op) {
      case BoolOp.intersection:
        return const [];
      case BoolOp.difference:
        return _clone(subject); // subject − ∅ = subject; ∅ − clipping = ∅.
      case BoolOp.union:
      case BoolOp.xor:
        return _clone(subject.isEmpty ? clipping : subject);
    }
  }

  final sbbox = _bbox(subject);
  final cbbox = _bbox(clipping);

  // Trivial non-overlapping-bbox cases.
  if (sbbox[0] > cbbox[2] ||
      cbbox[0] > sbbox[2] ||
      sbbox[1] > cbbox[3] ||
      cbbox[1] > sbbox[3]) {
    switch (op) {
      case BoolOp.intersection:
        return const [];
      case BoolOp.difference:
        return _clone(subject);
      case BoolOp.union:
      case BoolOp.xor:
        return [..._clone(subject), ..._clone(clipping)];
    }
  }

  final queue = _EventQueue();
  var contourId = 0;
  for (final ring in subject) {
    _addContour(ring, true, contourId++, queue);
  }
  for (final ring in clipping) {
    _addContour(ring, false, contourId++, queue);
  }

  final sorted = _subdivide(queue, sbbox[2], cbbox[2], op);
  return _connectEdges(sorted);
}

// ---------------------------------------------------------------------------
// Sweep event
// ---------------------------------------------------------------------------

class _SweepEvent {
  _SweepEvent(this.px, this.py, this.left, this.isSubject);

  double px;
  double py;
  bool left;
  final bool isSubject;
  _SweepEvent? otherEvent;
  int type = _kNormal;
  int contourId = 0;

  // Filled in during the sweep.
  bool inOut = false;
  bool otherInOut = false;
  int resultTransition = 0;

  // Filled in during edge connection.
  int otherPos = -1;

  bool get inResult => resultTransition != 0;

  bool isVertical() => px == otherEvent!.px;

  /// Whether the segment lies strictly below point `(x, y)`.
  bool isBelow(double x, double y) {
    final o = otherEvent!;
    return left
        ? (px - x) * (o.py - y) - (o.px - x) * (py - y) > 0
        : (o.px - x) * (py - y) - (px - x) * (o.py - y) > 0;
  }

  bool isAbove(double x, double y) => !isBelow(x, y);
}

/// `(p0 − p2) × (p1 − p2)` — positive when `p2` is to the right of `p0→p1`.
double _signedArea(double p0x, double p0y, double p1x, double p1y, double p2x,
    double p2y) {
  return (p0x - p2x) * (p1y - p2y) - (p1x - p2x) * (p0y - p2y);
}

/// Orders sweep events: by x, then y, then right-before-left at a shared point,
/// then by segment slope, then subject-before-clipping. Returns -1/0/1.
int _compareEvents(_SweepEvent e1, _SweepEvent e2) {
  if (e1.px > e2.px) return 1;
  if (e1.px < e2.px) return -1;
  if (e1.py != e2.py) return e1.py > e2.py ? 1 : -1;
  if (e1.left != e2.left) return e1.left ? 1 : -1;
  final o1 = e1.otherEvent!;
  final o2 = e2.otherEvent!;
  if (_signedArea(e1.px, e1.py, o1.px, o1.py, o2.px, o2.py) != 0) {
    return !e1.isBelow(o2.px, o2.py) ? 1 : -1;
  }
  return (!e1.isSubject && e2.isSubject) ? 1 : -1;
}

/// Orders two segments (given their left events) by their height at the sweep
/// line. Returns -1/0/1; 0 only for the identical event.
int _compareSegments(_SweepEvent le1, _SweepEvent le2) {
  if (identical(le1, le2)) return 0;
  final o1 = le1.otherEvent!;
  final o2 = le2.otherEvent!;

  if (_signedArea(le1.px, le1.py, o1.px, o1.py, le2.px, le2.py) != 0 ||
      _signedArea(le1.px, le1.py, o1.px, o1.py, o2.px, o2.py) != 0) {
    // Not collinear.
    if (le1.px == le2.px && le1.py == le2.py) {
      return le1.isBelow(o2.px, o2.py) ? -1 : 1;
    }
    if (le1.px == le2.px) {
      return le1.py < le2.py ? -1 : 1;
    }
    if (_compareEvents(le1, le2) == 1) {
      return le2.isAbove(le1.px, le1.py) ? -1 : 1;
    }
    return le1.isBelow(le2.px, le2.py) ? -1 : 1;
  }

  // Collinear.
  if (le1.isSubject == le2.isSubject) {
    if (le1.px == le2.px && le1.py == le2.py) {
      if (o1.px == o2.px && o1.py == o2.py) return 0;
      return le1.contourId > le2.contourId ? 1 : -1;
    }
  } else {
    return le1.isSubject ? -1 : 1;
  }
  return _compareEvents(le1, le2) == 1 ? 1 : -1;
}

// ---------------------------------------------------------------------------
// Queue + sweep line
// ---------------------------------------------------------------------------

/// Binary min-heap of sweep events ordered by [_compareEvents].
class _EventQueue {
  final List<_SweepEvent> _h = [];

  bool get isEmpty => _h.isEmpty;

  void push(_SweepEvent e) {
    _h.add(e);
    var i = _h.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_compareEvents(_h[i], _h[parent]) < 0) {
        _swap(i, parent);
        i = parent;
      } else {
        break;
      }
    }
  }

  _SweepEvent pop() {
    final top = _h[0];
    final last = _h.removeLast();
    if (_h.isNotEmpty) {
      _h[0] = last;
      var i = 0;
      final n = _h.length;
      while (true) {
        final l = 2 * i + 1;
        final r = 2 * i + 2;
        var smallest = i;
        if (l < n && _compareEvents(_h[l], _h[smallest]) < 0) smallest = l;
        if (r < n && _compareEvents(_h[r], _h[smallest]) < 0) smallest = r;
        if (smallest == i) break;
        _swap(i, smallest);
        i = smallest;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final t = _h[a];
    _h[a] = _h[b];
    _h[b] = t;
  }
}

/// Status line: the segments currently crossing the sweep, kept sorted by
/// [_compareSegments]. A sorted list (binary-search insert, identity remove) is
/// the MVP choice; the doc flags swapping in a balanced BST as a perf follow-up.
class _SweepLine {
  final List<_SweepEvent> _s = [];

  int get length => _s.length;

  int insert(_SweepEvent e) {
    var lo = 0;
    var hi = _s.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_compareSegments(_s[mid], e) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    _s.insert(lo, e);
    return lo;
  }

  int indexOf(_SweepEvent e) {
    var lo = 0;
    var hi = _s.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final c = _compareSegments(_s[mid], e);
      if (c < 0) {
        lo = mid + 1;
      } else if (c > 0) {
        hi = mid;
      } else {
        if (identical(_s[mid], e)) return mid;
        break;
      }
    }
    for (var i = 0; i < _s.length; i++) {
      if (identical(_s[i], e)) return i;
    }
    return -1;
  }

  _SweepEvent? prevKey(int i) => i > 0 ? _s[i - 1] : null;

  _SweepEvent? nextKey(int i) => i + 1 < _s.length ? _s[i + 1] : null;

  void removeAt(int i) => _s.removeAt(i);
}

// ---------------------------------------------------------------------------
// Subdivision (the sweep)
// ---------------------------------------------------------------------------

void _addContour(
    Float64List ring, bool isSubject, int contourId, _EventQueue queue) {
  final n = ring.length ~/ 2;
  for (var i = 0; i < n; i++) {
    final x0 = ring[i * 2];
    final y0 = ring[i * 2 + 1];
    final j = (i + 1) % n;
    final x1 = ring[j * 2];
    final y1 = ring[j * 2 + 1];
    if (x0 == x1 && y0 == y1) continue; // skip zero-length edges
    final e1 = _SweepEvent(x0, y0, false, isSubject)..contourId = contourId;
    final e2 = _SweepEvent(x1, y1, false, isSubject)..contourId = contourId;
    e1.otherEvent = e2;
    e2.otherEvent = e1;
    if (_compareEvents(e1, e2) > 0) {
      e2.left = true;
    } else {
      e1.left = true;
    }
    queue.push(e1);
    queue.push(e2);
  }
}

List<_SweepEvent> _subdivide(
    _EventQueue queue, double sMaxX, double cMaxX, BoolOp op) {
  final sweep = _SweepLine();
  final sorted = <_SweepEvent>[];
  final rightbound = math.min(sMaxX, cMaxX);

  while (!queue.isEmpty) {
    final event = queue.pop();
    sorted.add(event);

    // Bbox optimization (from the reference): once past the relevant right
    // bound, no remaining event can contribute.
    if ((op == BoolOp.intersection && event.px > rightbound) ||
        (op == BoolOp.difference && event.px > sMaxX)) {
      break;
    }

    if (event.left) {
      final pos = sweep.insert(event);
      final prev = sweep.prevKey(pos);
      final next = sweep.nextKey(pos);

      _computeFields(event, prev, op);

      if (next != null) {
        if (_possibleIntersection(event, next, queue) == 2) {
          _computeFields(event, prev, op);
          _computeFields(next, event, op);
        }
      }
      if (prev != null) {
        if (_possibleIntersection(prev, event, queue) == 2) {
          final prevPos = sweep.indexOf(prev);
          final prevPrev = prevPos > 0 ? sweep.prevKey(prevPos) : null;
          _computeFields(prev, prevPrev, op);
          _computeFields(event, prev, op);
        }
      }
    } else {
      final le = event.otherEvent!;
      final pos = sweep.indexOf(le);
      if (pos >= 0) {
        final prev = sweep.prevKey(pos);
        final next = sweep.nextKey(pos);
        sweep.removeAt(pos);
        if (prev != null && next != null) {
          _possibleIntersection(prev, next, queue);
        }
      }
    }
  }
  return sorted;
}

void _computeFields(_SweepEvent event, _SweepEvent? prev, BoolOp op) {
  if (prev == null) {
    event.inOut = false;
    event.otherInOut = true;
  } else if (event.isSubject == prev.isSubject) {
    event.inOut = !prev.inOut;
    event.otherInOut = prev.otherInOut;
  } else {
    event.inOut = !prev.otherInOut;
    event.otherInOut = prev.isVertical() ? !prev.inOut : prev.inOut;
  }
  if (_inResult(event, op)) {
    event.resultTransition = _determineResultTransition(event, op);
  } else {
    event.resultTransition = 0;
  }
}

bool _inResult(_SweepEvent event, BoolOp op) {
  switch (event.type) {
    case _kNormal:
      switch (op) {
        case BoolOp.intersection:
          return !event.otherInOut;
        case BoolOp.union:
          return event.otherInOut;
        case BoolOp.difference:
          return (event.isSubject && event.otherInOut) ||
              (!event.isSubject && !event.otherInOut);
        case BoolOp.xor:
          return true;
      }
    case _kSameTransition:
      return op == BoolOp.intersection || op == BoolOp.union;
    case _kDifferentTransition:
      return op == BoolOp.difference;
    case _kNonContributing:
      return false;
  }
  return false;
}

int _determineResultTransition(_SweepEvent event, BoolOp op) {
  final thisIn = !event.inOut;
  final thatIn = !event.otherInOut;
  bool isIn;
  switch (op) {
    case BoolOp.intersection:
      isIn = thisIn && thatIn;
    case BoolOp.union:
      isIn = thisIn || thatIn;
    case BoolOp.xor:
      isIn = thisIn != thatIn;
    case BoolOp.difference:
      isIn = event.isSubject ? (thisIn && !thatIn) : (thatIn && !thisIn);
  }
  return isIn ? 1 : -1;
}

// ---------------------------------------------------------------------------
// Segment intersection + subdivision
// ---------------------------------------------------------------------------

int _possibleIntersection(
    _SweepEvent se1, _SweepEvent se2, _EventQueue queue) {
  final o1 = se1.otherEvent!;
  final o2 = se2.otherEvent!;
  final inter =
      _segmentIntersection(se1.px, se1.py, o1.px, o1.py, se2.px, se2.py, o2.px,
          o2.py);
  final n = inter == null ? 0 : inter.length ~/ 2;
  if (n == 0) return 0;

  // Intersect only at a shared endpoint of both segments.
  if (n == 1 &&
      ((se1.px == se2.px && se1.py == se2.py) ||
          (o1.px == o2.px && o1.py == o2.py))) {
    return 0;
  }

  // Overlapping edges of the same polygon: ignore.
  if (n == 2 && se1.isSubject == se2.isSubject) {
    return 0;
  }

  if (n == 1) {
    final ix = inter![0];
    final iy = inter[1];
    if (!(se1.px == ix && se1.py == iy) && !(o1.px == ix && o1.py == iy)) {
      _divideSegment(se1, ix, iy, queue);
    }
    if (!(se2.px == ix && se2.py == iy) && !(o2.px == ix && o2.py == iy)) {
      _divideSegment(se2, ix, iy, queue);
    }
    return 1;
  }

  // The segments overlap collinearly.
  final events = <_SweepEvent>[];
  var leftCoincide = false;
  var rightCoincide = false;

  if (se1.px == se2.px && se1.py == se2.py) {
    leftCoincide = true;
  } else if (_compareEvents(se1, se2) == 1) {
    events.add(se2);
    events.add(se1);
  } else {
    events.add(se1);
    events.add(se2);
  }

  if (o1.px == o2.px && o1.py == o2.py) {
    rightCoincide = true;
  } else if (_compareEvents(o1, o2) == 1) {
    events.add(o2);
    events.add(o1);
  } else {
    events.add(o1);
    events.add(o2);
  }

  if ((leftCoincide && rightCoincide) || leftCoincide) {
    se2.type = _kNonContributing;
    se1.type =
        se2.inOut == se1.inOut ? _kSameTransition : _kDifferentTransition;
    if (leftCoincide && !rightCoincide) {
      _divideSegment(events[1].otherEvent!, events[0].px, events[0].py, queue);
    }
    return 2;
  }

  if (rightCoincide) {
    _divideSegment(events[0], events[1].px, events[1].py, queue);
    return 3;
  }

  if (!identical(events[0], events[3].otherEvent)) {
    _divideSegment(events[0], events[1].px, events[1].py, queue);
    _divideSegment(events[1], events[2].px, events[2].py, queue);
    return 3;
  }

  _divideSegment(events[0], events[1].px, events[1].py, queue);
  _divideSegment(events[3].otherEvent!, events[2].px, events[2].py, queue);
  return 3;
}

void _divideSegment(_SweepEvent se, double px, double py, _EventQueue queue) {
  final other = se.otherEvent!;
  final r = _SweepEvent(px, py, false, se.isSubject)
    ..otherEvent = se
    ..contourId = se.contourId;
  final l = _SweepEvent(px, py, true, se.isSubject)
    ..otherEvent = other
    ..contourId = se.contourId;

  // Rounding guard: keep the new left event ordered before the original right.
  if (_compareEvents(l, other) > 0) {
    other.left = true;
    l.left = false;
  }

  other.otherEvent = l;
  se.otherEvent = r;

  queue.push(l);
  queue.push(r);
}

/// Intersection of segments `a1→a2` and `b1→b2`. Returns null for no
/// intersection, a 2-element list `[x, y]` for a single point, or a 4-element
/// list `[x0,y0,x1,y1]` for a collinear overlap. Ported from Schneider &
/// Eberly via the martinez reference.
Float64List? _segmentIntersection(double a1x, double a1y, double a2x,
    double a2y, double b1x, double b1y, double b2x, double b2y) {
  final vax = a2x - a1x;
  final vay = a2y - a1y;
  final vbx = b2x - b1x;
  final vby = b2y - b1y;
  final ex = b1x - a1x;
  final ey = b1y - a1y;

  var kross = vax * vby - vay * vbx;
  var sqrKross = kross * kross;
  final sqrLenA = vax * vax + vay * vay;

  if (sqrKross > 0) {
    final s = (ex * vby - ey * vbx) / kross;
    if (s < 0 || s > 1) return null;
    final t = (ex * vay - ey * vax) / kross;
    if (t < 0 || t > 1) return null;
    if (s == 0 || s == 1) {
      return Float64List.fromList([a1x + s * vax, a1y + s * vay]);
    }
    if (t == 0 || t == 1) {
      return Float64List.fromList([b1x + t * vbx, b1y + t * vby]);
    }
    return Float64List.fromList([a1x + s * vax, a1y + s * vay]);
  }

  kross = ex * vay - ey * vax;
  sqrKross = kross * kross;
  if (sqrKross > 0) return null; // parallel, not collinear

  final sa = (vax * ex + vay * ey) / sqrLenA;
  final sb = sa + (vax * vbx + vay * vby) / sqrLenA;
  final smin = math.min(sa, sb);
  final smax = math.max(sa, sb);

  if (smin <= 1 && smax >= 0) {
    if (smin == 1) {
      return Float64List.fromList([a1x + smin * vax, a1y + smin * vay]);
    }
    if (smax == 0) {
      return Float64List.fromList([a1x + smax * vax, a1y + smax * vay]);
    }
    final s0 = smin > 0 ? smin : 0.0;
    final s1 = smax < 1 ? smax : 1.0;
    return Float64List.fromList([
      a1x + s0 * vax,
      a1y + s0 * vay,
      a1x + s1 * vax,
      a1y + s1 * vay,
    ]);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Edge connection (result assembly)
// ---------------------------------------------------------------------------

List<Float64List> _connectEdges(List<_SweepEvent> sortedEvents) {
  final resultEvents = <_SweepEvent>[];
  for (final e in sortedEvents) {
    if ((e.left && e.inResult) || (!e.left && e.otherEvent!.inResult)) {
      resultEvents.add(e);
    }
  }
  resultEvents.sort(_compareEvents);

  for (var i = 0; i < resultEvents.length; i++) {
    resultEvents[i].otherPos = i;
  }
  for (final e in resultEvents) {
    if (!e.left) {
      final tmp = e.otherPos;
      e.otherPos = e.otherEvent!.otherPos;
      e.otherEvent!.otherPos = tmp;
    }
  }

  final processed = List<bool>.filled(resultEvents.length, false);
  final result = <Float64List>[];

  for (var i = 0; i < resultEvents.length; i++) {
    if (processed[i]) continue;

    final pts = <double>[];
    var pos = i;
    final origPos = i;
    pts.add(resultEvents[i].px);
    pts.add(resultEvents[i].py);

    while (true) {
      processed[pos] = true;
      pos = resultEvents[pos].otherPos;
      if (pos < 0 || pos >= resultEvents.length) break;
      processed[pos] = true;
      pts.add(resultEvents[pos].px);
      pts.add(resultEvents[pos].py);

      pos = _nextPos(pos, resultEvents, processed, origPos);
      if (pos == origPos || pos < 0 || pos >= resultEvents.length) break;
    }
    _addRing(result, pts);
  }
  return result;
}

int _nextPos(
    int pos, List<_SweepEvent> resultEvents, List<bool> processed, int origPos) {
  var newPos = pos + 1;
  final px = resultEvents[pos].px;
  final py = resultEvents[pos].py;
  final length = resultEvents.length;
  var p1x = 0.0;
  var p1y = 0.0;
  if (newPos < length) {
    p1x = resultEvents[newPos].px;
    p1y = resultEvents[newPos].py;
  }
  while (newPos < length && p1x == px && p1y == py) {
    if (!processed[newPos]) return newPos;
    newPos++;
    if (newPos < length) {
      p1x = resultEvents[newPos].px;
      p1y = resultEvents[newPos].py;
    }
  }
  newPos = pos - 1;
  while (newPos > origPos && processed[newPos]) {
    newPos--;
  }
  return newPos;
}

void _addRing(List<Float64List> out, List<double> pts) {
  var n = pts.length ~/ 2;
  if (n >= 2 && pts[(n - 1) * 2] == pts[0] && pts[(n - 1) * 2 + 1] == pts[1]) {
    n--; // drop trailing vertex coinciding with the first
  }
  if (n < 3) return;
  final ring = Float64List(n * 2);
  for (var i = 0; i < n * 2; i++) {
    ring[i] = pts[i];
  }
  out.add(ring);
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

Float64List _bbox(List<Float64List> contours) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final ring in contours) {
    for (var i = 0; i < ring.length; i += 2) {
      final x = ring[i];
      final y = ring[i + 1];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  return Float64List.fromList([minX, minY, maxX, maxY]);
}

List<Float64List> _clone(List<Float64List> contours) =>
    [for (final ring in contours) Float64List.fromList(ring)];
