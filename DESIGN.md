# fast_path Design Document

Status: Draft. Living document — expect churn as the API lands.
Last updated: 2026-05-09.

## 1. Background

Flutter's `Path` (in `dart:ui`) is the engine's authoritative 2D path. It is
implemented in C++ on top of Skia (legacy) and Impeller (current). Every
`Path.lineTo`, `Path.cubicTo`, `Path.contains`, etc. crosses the Dart/C++
boundary and is backed by native memory that a finalizer eventually returns.

`fast_path` re-implements that surface area in pure Dart. The motivating
observations are:

1. The native boundary is not free. For path-heavy workloads (custom painters,
   text shaping previews, layout effects, hit testing on complex shapes) the
   per-call FFI cost and the marshaling of points and verbs add up.
2. Native-backed objects are tied to a finalizer. Allocating and discarding
   many short-lived `Path`s defers cleanup to GC + finalizer pump, which is
   harder to reason about than a plain Dart object.
3. Most Path algorithms (curve flattening, monotonic decomposition, even–odd
   winding fills, stroke expansion, boolean ops) are arithmetic over `double`s.
   Dart's JIT and AOT compile these tightly when the code is allocation-light
   and uses typed data.

In other words: Path is a numeric data structure with a complicated API. There
is no GPU buffer or texture handle hiding inside it that requires a native
backing. A pure-Dart implementation is feasible and removes a class of cost.

## 2. Goals

- **Behavioral parity** with `dart:ui`'s `Path` for every operation it
  exposes — same edge cases, same NaN/empty-path treatment, same tolerances
  — even though the *construction shape* differs (see "Builder/Path split"
  below). When you build the same path through both libraries and ask the
  same query, you get the same answer.
- **Builder/Path split.** Construction lives on a separate, mutable
  `PathBuilder`. The resulting `Path` is immutable and optimized for
  queries. This is a deliberate divergence from `dart:ui.Path` where one
  object plays both roles. The separation buys a sharper internal model:
  the builder can be optimized purely for fast appends, and the path can
  cache derived data eagerly without worrying about invalidation.
- **Pure Dart**. No FFI. No platform channels. No `dart:ui` import inside the
  library code. Runs on plain Dart VMs (server, CLI, tests) as well as inside
  Flutter apps.
- **Allocation discipline**. Hot paths use `Float32List` / `Float64List`
  storage and reuse buffers. Avoid wrapping every point in an `Offset` object
  in inner loops.
- **GC-friendly**. The package is plain Dart objects on the Dart heap. No
  finalizers, no manual `dispose`, no native handles.
- **License-clean**. BSD-3-Clause, matching Skia and Flutter so we can port
  algorithms upstream.

## 3. Non-goals

- **Rendering.** `fast_path` builds and queries paths; it does not rasterize
  them or hand them to a GPU. Rendering remains the engine's job.
- **API-shape compatibility with `dart:ui.Path`.** Our `Path` is immutable
  and queries-only; mutating methods like `lineTo` and `cubicTo` live on a
  separate `PathBuilder`. Code written against `dart:ui.Path` does not
  drop in. The migration is mechanical (move builder calls onto a
  `PathBuilder`, then call `.build()`) but it is not zero-touch.
- **A drop-in `dart:ui.Path` subclass.** We do not subclass or implement
  `dart:ui.Path`. Bridging to Flutter (converting a `fast_path.Path` into a
  `ui.Path` for painting) is out of scope for the core package and may live
  in a separate companion later.
- **Premature SIMD.** Dart's `Float32x4` is appealing but constrains the
  algorithms. We will reach for it only where benchmarks justify it.
- **Beating Skia at every operation.** Some operations (boolean ops over
  cubics, stroking) are heavily tuned in Skia. Our north star is parity and
  competitive performance for the common cases, not winning microbenchmarks
  across the board.

## 4. Public API shape

The package exposes two principal classes — a mutable `PathBuilder` and an
immutable `Path` — plus the geometry types they need and a couple of
helpers. Operations match `dart:ui.Path`'s behavior; the *shape* of the API
diverges deliberately along a build/query seam.

### 4.1 Builder/Path split

`dart:ui.Path` is one object that you mutate while you build it and then
query while you continue to mutate it. That conflation forces tradeoffs on
both sides: a query-time cache like `getBounds()` has to be invalidated on
every mutation, an active iterator over a `PathMetric` has to detect that
the underlying path moved, and the build-time append loop pays for caches
that the builder isn't even using yet.

We split it:

- `PathBuilder` is **mutable** and **write-optimized**. It owns growable
  verb and point buffers and supports the full set of construction
  primitives (`moveTo`, `lineTo`, `cubicTo`, `addRect`, …). It does not
  cache derived data — there's nothing to invalidate, because nothing has
  asked yet. `PathBuilder.build()` produces a `Path`.
- `Path` is **immutable** and **query-optimized**. It holds the verb and
  point buffers handed to it by `build()`, exposes only queries
  (`contains`, `getBounds`, `computeMetrics`, …), and caches derived data
  eagerly or lazily without invalidation logic, since it cannot change.
- `Path.combine(op, a, b)`, `Path.transform(matrix)`, and `Path.shift(o)`
  return *new* `Path` instances. They are pure functions.
- Editing an existing `Path` means: `PathBuilder.from(path)` to seed a
  fresh builder from the path's contents, mutate, then `build()` again.

This is the same divergence pattern as Java's `String` / `StringBuilder` or
Swift's `Data` / inout buffers: one type for the workload of constructing,
another for the workload of inspecting. It costs us drop-in compatibility
with `dart:ui.Path` (see §3) and buys us:

- The builder's append loop is straight-line — no cache bookkeeping in the
  hot path.
- The path's query cache (bounds, length tables, convexity) computes once
  per path and is then read-only; no `_genId` checks, no
  copy-on-mutate, no torn reads.
- Sharing a `Path` across isolates / threads / async boundaries is safe by
  construction.
- Algorithms that take a `Path` (intersection, transform, combine) can
  trust the buffers won't move underneath them and skip defensive copies.

### 4.2 Geometry types (own definitions)

`fast_path` defines its own value types. This keeps the package free of any
Flutter dependency and lets it run on plain Dart. Names and field order match
`dart:ui` so porting code is mechanical.

- `Offset(double dx, double dy)` — a 2D point/vector.
- `Size(double width, double height)`.
- `Rect.fromLTRB(double l, double t, double r, double b)` and the usual
  named constructors.
- `RRect.fromRectAndRadius(...)`, `RRect.fromRectAndCorners(...)`, etc.
- `Radius.circular(double r)` / `Radius.elliptical(double x, double y)`.
- Enums: `PathFillType { nonZero, evenOdd }`, `PathOperation`, plus the
  internal verb enum (see §5.1).

These are immutable, `const`-constructible where possible, and provide
`==`/`hashCode`/`toString` matching the engine's documented behavior.

A separate, optional package — tentatively `fast_path_flutter` — will provide
extension methods to convert between `fast_path` types and `dart:ui` types
without making the core depend on Flutter. That package is out of scope for
0.x.

### 4.3 PathBuilder methods

All construction lives here. Behavior of each method matches the
identically-named `dart:ui.Path` method. Initial milestone targets (see §10):

- Construction: `PathBuilder()`, `PathBuilder.from(Path)` (seeds from an
  existing path), `PathBuilder.fromBuilder(PathBuilder)` (clones a builder).
- Building: `moveTo`, `relativeMoveTo`, `lineTo`, `relativeLineTo`,
  `quadraticBezierTo`, `relativeQuadraticBezierTo`, `cubicTo`,
  `relativeCubicTo`, `conicTo`, `relativeConicTo`, `arcTo`,
  `arcToPoint`, `relativeArcToPoint`, `addArc`, `addOval`, `addRect`,
  `addRRect`, `addPolygon`, `addPath`, `extendWithPath`, `close`.
- State: `fillType` getter/setter, `reset()` (zero the buffers, keep
  capacity), `reserve(int verbCount, int pointCount)` (capacity hint).
- Handoff: `Path build()` — produces an immutable `Path`. See §5.4 for the
  semantics (the default is "snapshot, builder remains usable"; a
  destructive variant may be added if benchmarks justify it).

### 4.4 Path methods

All queries live here. The class is `final` (no subclassing) and all fields
are private; the public surface is observation-only.

- Queries: `contains(Offset)`, `getBounds()`,
  `computeMetrics({bool forceClosed = false})`.
- Pure transforms (return new `Path`): `transform(Float64List matrix4)`,
  `shift(Offset)`.
- Combine (static, returns new `Path`):
  `Path.combine(PathOperation op, Path a, Path b)`.
- State: `fillType` getter (read-only).
- Identity: `==` / `hashCode` based on verb+point buffers + fill type, so
  built-from-the-same-calls paths compare equal — useful for memoization
  and tests.

`PathMetric`, `PathMetricIterator`, and `Tangent` follow the same shape as
`dart:ui`. Because `Path` is immutable, these iterators do not need the
"underlying path mutated, throw" guard that `dart:ui` has.

## 5. Internal representation

The verb + point buffer shape is the same on both classes; what differs is
the storage discipline (growable on the builder, fixed on the path) and
what lives alongside the buffers (build-time cursors on the builder, query
caches on the path).

### 5.1 Verb + point buffers

Both `PathBuilder` and `Path` are, internally, the same two parallel buffers:

- `Uint8List _verbs` — one byte per command from a small enum:
  `move`, `line`, `quad`, `conic`, `cubic`, `close`. (Conics carry a weight;
  see below.)
- `Float32List _points` — packed `(x, y)` pairs consumed by the verb stream.

This is the same shape Skia uses (`SkPath::fVerbs`, `SkPath::fPoints`) and it
is the right data structure for our workload: appending is O(1) amortized, the
buffers iterate cache-friendly, and most algorithms (bounds, flattening,
contains) are single-pass over the verb stream.

A separate `Float32List _conicWeights` holds weights for `conic` verbs only.
We follow Skia's convention here so that ports are mechanical.

`Float32List` (not `Float64List`) is the working choice: Path coordinates in
Skia and Flutter are 32-bit floats, so f32 keeps us behavior-compatible and
halves memory traffic. We will revisit if parity tests show f32 rounding
divergences that matter.

### 5.2 PathBuilder fields (mutable, write-optimized)

The builder optimizes for cheap appends. It does not maintain query caches.

- `_verbs`, `_points`, `_conicWeights` — growable. Each has a backing
  `*List` and a separate `int` cursor, so we can amortize growth without
  paying for `List.add` style reallocation per element.
- `_fillType: PathFillType`.
- `_lastMoveToIndex: int` — index into `_points` of the most recent
  `moveTo`, used to implement `close` correctly without a verb scan.
- No `_cachedBounds`, no `_isConvex`, no `_genId`. Queries are not allowed
  on a builder; if you want a bound, build a `Path` and ask it.

### 5.3 Path fields (immutable, query-optimized)

The path optimizes for query throughput. It does not allow mutation.

- `_verbs`, `_points`, `_conicWeights` — exact-size, sealed. Backing
  storage is whatever `build()` handed in (typically a tightly-sized
  `Uint8List` / `Float32List` view).
- `_fillType: PathFillType`.
- `_cachedBounds: Rect?` — lazy on first call; never invalidated.
- `_isConvex: _Convexity { unknown, convex, concave }` — lazy on first
  call; never invalidated.
- `_lengthTable: Float64List?` — built lazily by the first `PathMetric`
  request and reused across subsequent metric calls.
- `_hashCode: int?` — lazy. Worth caching because `Path` may be used as a
  `Map` key (e.g. for memoizing `combine` results).

The "lazy and never invalidated" bit is the structural payoff of the
split. In `dart:ui.Path` every cache has to think about mutation; here, by
construction, none of them do.

### 5.4 The `build()` handoff

`PathBuilder.build()` returns a `Path` from the builder's current state.
The default semantics are **snapshot**: the path receives a tightly-sized
copy of the builder's buffers, and the builder remains usable for further
mutation (so callers can keep appending and call `build()` again to get an
extended snapshot).

The copy is a single `Uint8List.fromList` / `Float32List.fromList` per
buffer — fast, and importantly, it lets the path use exact-size storage
rather than the builder's geometric over-allocation. Tightly-sized backing
storage matters for query throughput (cache lines aren't wasted on slack)
and for any code that takes `Float32List.length` to mean "valid points".

A second variant, `PathBuilder.takePath()`, is on the table as a future
optimization: it would *move* the builder's buffers into the path and
leave the builder empty. This avoids the snapshot copy at the cost of
invalidating the builder. Defer until benchmarks show the copy is the
bottleneck. Likely callers: per-frame painters that build one path and
never reuse the builder.

### 5.5 Allocation strategy

- Builder buffers grow geometrically (×2) when full. They live in
  `Uint8List` / `Float32List` so primitive contents stay off the GC scan
  list and inner loops stay tight.
- `PathBuilder()` starts with empty buffers; we do not pre-allocate.
  `reserve(verbCount, pointCount)` is exposed for callers that know the
  size up front.
- `PathBuilder.from(Path)` is a block copy of the path's exact-size
  buffers into geometrically-sized builder buffers (capacity rounded up
  to the next power of two).
- `PathBuilder.reset()` zeros cursors but keeps capacity, so reusing a
  builder across frames does not thrash the heap. This is the canonical
  pattern for hot painters: one builder, reset every frame, build a fresh
  immutable `Path` each time.
- `Path` instances allocate their buffers exactly once at construction.
  There is no `Path.reset()`.

## 6. Algorithms

This section sketches the algorithm choices. Each ships behind a parity test
suite (§8) and is benchmarked against Flutter's `Path` (§9).

### 6.1 Curve flattening

Quadratic, cubic, and conic Béziers are flattened to line segments using
**adaptive subdivision** with a flatness threshold derived from the local
bounding box. This is the textbook Skia approach (`SkPathMeasure`,
`SkEdgeBuilder`). We pick adaptive subdivision over a fixed `t` step because
it produces ~the same number of segments on simple curves but far fewer on
nearly-straight ones.

Conic flattening goes through Skia's "conic to quads" technique
(`SkConic::chopIntoQuadsPOW2`) so we inherit a well-tested decomposition.

### 6.2 `contains(Offset)`

Ray casting (cast a ray to the right, count signed crossings) with the
appropriate fill rule:

- `nonZero`: sum signed crossings; nonzero ⇒ inside.
- `evenOdd`: count crossings; odd ⇒ inside.

Curves are tested analytically where cheap (lines, circular arcs) and via the
flattened representation otherwise. We mirror Skia's "on-edge" tie-breaking so
parity tests align.

### 6.3 `getBounds()`

Tight bounds: for cubics and conics we solve for derivative roots to find
extrema rather than just hulling control points. Computed on first call and
cached on the immutable `Path` indefinitely (no invalidation needed — see
§5.3).

### 6.4 `Path.combine(op, a, b)` (boolean ops)

Implementation deferred. The plan is to port Skia's `SkOpBuilder` /
`SkPathOpsCommon` algorithm. Boolean ops over cubics are notoriously fiddly;
this is the highest-risk parity surface. We will land it last, behind a
property test corpus that fuzzes pairs of paths and checks symmetry,
idempotence, and `contains` agreement on sample points.

### 6.5 `transform(Float64List matrix4)`

Affine transforms of points are trivial. Perspective components require
re-classifying lines/quads as cubics in general, matching Skia's behavior;
for the common 2D affine case we fast-path with no verb changes.

### 6.6 `computeMetrics()` / `PathMetric`

Per-contour arc length, position along, tangent. Length is integrated via
adaptive Gauss–Legendre on each segment (cubics) or in closed form (lines,
circular arcs). The length table is built lazily on first metric request
and stored on the immutable `Path`, so subsequent metric queries on the
same path are O(log n) lookups against a fixed table.

## 7. Performance

The wins we are chasing, roughly in priority order:

1. **No FFI.** Build/mutate/query operations are inlined Dart, no boundary
   crossing. This dominates for small paths with many calls (typical custom
   painters).
2. **Allocation-free hot paths.** No `Offset` objects allocated per point in
   `lineTo` etc.; the API takes `(double, double)` internally and only wraps
   on egress.
3. **Tight typed buffers.** `Float32List` and `Uint8List` are friendly to
   Dart's JIT/AOT codegen — array bounds checks hoist, range types are known.
4. **Cached derived data, no invalidation.** Because `Path` is immutable
   (§5.3), `getBounds()`, length tables, convexity, and `hashCode`
   memoize once and are read-only thereafter. No version checks in the
   query hot path.
5. **Reusable builders.** `PathBuilder.reset()` keeps capacity so per-frame
   painters can rebuild without GC churn: one builder, reset each frame,
   `build()` to produce the frame's immutable `Path`.

We deliberately do **not** start with SIMD or isolate-based parallelism.
They constrain the algorithms; we measure first. SIMD via `Float64x2`
extension types over `Offset` / `Size` is on the radar as an explicit
follow-up — see §11.

## 8. Testing

Three layers, in order of strength:

### 8.1 Unit tests

Per algorithm, normal Dart `package:test`. Edge cases: empty paths, single
points, zero-length segments, NaN/Inf inputs (matching `dart:ui`'s documented
behavior of silently ignoring).

### 8.2 Parity tests against `dart:ui.Path`

Lives in a `test/parity/` directory and only runs under Flutter (`flutter
test`). For each operation we replay the same call sequence on both sides
— a `fast_path.PathBuilder` followed by `.build()` on our side, and a
`ui.Path` (which conflates the two) on the engine side — then compare the
queries on the resulting paths and assert agreement:

- `getBounds()` to within 1e-4 absolute / 1e-6 relative.
- `contains()` exact agreement on a grid of sample points except within an
  epsilon-wide band around the curve (where ties are inherent).
- `computeMetrics().length` to within 1e-4.
- `combine()` checked by sampling: `inside_combined(p) == op(inside_a(p), inside_b(p))`.

The corpus is generated, not hand-written: a deterministic pseudo-random
generator emits paths with a configurable mix of verbs, magnitudes, and
degeneracies. Failures are minimized with a small shrinker.

### 8.3 Property tests

`package:test` with property-based helpers. Examples:

- `PathBuilder.from(p).build().getBounds() == p.getBounds()` (round-trip).
- `p.transform(I).getBounds() ≈ p.getBounds()` (identity transform is a
  no-op within float tolerance).
- `Path.combine(union, a, a) ≈ a`.
- `Path.combine(intersect, a, empty) == empty`.

## 9. Benchmarking

A `benchmark/` directory with `package:benchmark_harness`. Each benchmark
has two implementations — one using `fast_path.PathBuilder` + `Path`, one
using `ui.Path` — and the harness reports both in the same row so
regressions are obvious.

Initial benchmark set:

- **Build**: append N `lineTo` / `cubicTo` calls on `PathBuilder`,
  including the final `build()` cost.
- **Build + reset reuse**: per-frame pattern — one builder, `reset()`
  each iteration, `build()` to a fresh `Path` (mirrors painters).
- **Bounds**: `Path.getBounds()` on a 10k-segment path. Includes both
  cold (first call) and warm (cached) timings to expose the lazy cache.
- **Contains**: 1M `Path.contains()` queries on a complex path.
- **Metrics**: length and tangent at random `t` values.
- **Combine**: union / intersect on two organic paths.

The harness prints relative numbers (fast_path / ui) so a single glance shows
parity status. CI does not gate on absolute numbers but does gate on
ratio-vs-baseline: a >10% regression vs. the previous commit fails the build.

## 10. Roadmap

Rough order of attack. Each milestone is shippable on its own and unblocks
the next.

1. **M0 — Geometry types, builder/path split, polylines.** `Offset`,
   `Rect`, `RRect`, `Radius`, `PathFillType`. Both `PathBuilder` and
   `Path` lands in this milestone, including the `build()` snapshot
   handoff (§5.4). Builder methods: `moveTo`, `lineTo`, `close`, `reset`,
   `reserve`, `fillType`. Path methods: `getBounds`, `contains`,
   `fillType`. Internal verb/point buffer plumbing is shared between the
   two. The split lands now, not later — retrofitting it after queries
   are written would be expensive.
2. **M1 — Curves.** `quadraticBezierTo`, `cubicTo`, `conicTo`, adaptive
   flattening, tight bounds, contains for curves.
3. **M2 — Convenience builders.** `addRect`, `addOval`, `addRRect`,
   `addArc`, `arcTo`, `arcToPoint`, `addPolygon`, `addPath`,
   `extendWithPath`.
4. **M3 — Transform + metrics.** `transform`, `shift`, `computeMetrics`,
   `PathMetric` with length / position / tangent.
5. **M4 — Boolean ops.** `Path.combine(op, a, b)` for all four ops. This is
   the riskiest surface; we ship behind a parity-test gate.
6. **M5 — Polish.** Convexity heuristics, dartdoc pass, `0.x` → `1.0.0`
   stabilization, performance tuning informed by published benchmarks.

## 11. Open questions

- **f32 vs f64 internally.** Skia uses f32; a parity-first design follows.
  But Dart's hot loops over `Float64List` are sometimes faster than over
  `Float32List` because of how doubles are unboxed. Decide after M1 with
  benchmarks.
- **SIMD via `Float64x2` extension types.** `Offset(dx, dy)` and
  `Size(width, height)` are each a pair of doubles — exactly the shape of
  `Float64x2` from `dart:typed_data`. Dart 3 extension types let us define
  `Offset` (and `Size`) as a zero-cost facade over `Float64x2`, preserving
  the public API while giving inner-loop arithmetic (add, subtract, scale,
  dot, lerp) a direct SIMD lowering with no boxing. Implications worth
  exploring: (1) the point buffer becomes a `Float64x2List` instead of a
  `Float32List` of packed pairs, simplifying indexing; (2) `transform`'s
  affine multiply against rows of a `Matrix4` becomes a small fused-multiply
  pattern that the VM can vectorize; (3) we'd need to confirm the AOT path
  on web (dart2js / dart2wasm) doesn't fall back to scalar emulation badly
  enough to regret it. Defer until after M1; revisit during M3 (transform)
  benchmarking. Cross-cuts the f32/f64 question above — picking SIMD likely
  pins us to f64.
- **Bridging to `dart:ui.Path`.** Out of scope for the core, but Flutter
  users will want it. A separate `fast_path_flutter` package using
  conditional imports is the current sketch.
- **Stroking.** Flutter's `Path` does not expose a stroke-to-fill operation,
  but Skia does (`SkStroke`). Worth offering? Out of scope for 1.0.
- **Text paths.** Out of scope. Glyph outlines come from the engine's font
  system, not from Path itself.

## 12. Contributing notes

When porting algorithms or test cases from Skia / Flutter:

- Preserve the upstream copyright header in the file.
- Cite the source file and revision in a comment near the top of the port.
- Translate to idiomatic Dart, but resist restructuring on the first pass —
  match Skia's structure so the diff is reviewable, then refactor.
- Reject any dependency that is not BSD/MIT/Apache-style. GPL/LGPL/AGPL is a
  hard no — it would taint the package.

See `skills/port-from-skia/SKILL.md` and `skills/add-path-api/SKILL.md`
for the working checklists.
