# Changelog

## Unreleased

### Added

- M3 begins — `Path.shift(Offset)`: a pure function returning a new
  translated [Path]. Verb and conic-weight buffers are shared with the
  original (both immutable, never mutated), so only the point buffer is
  allocated and translated. Parity verified via a new Path-level
  operation harness in the conformance suite. `shift_path_1k` benchmark
  pair added.
- `Path.transform(Float64List matrix4)`: pure function returning a new
  path with every point mapped through a column-major 4×4 matrix. Affine
  fast path (no per-point divide); perspective matrices apply the
  homogeneous divide per point. Verbs and conic weights are preserved
  unchanged under both — a probe against the engine confirmed dart:ui
  keeps the verb structure and conic weights and merely relocates
  control points, even under perspective (it does NOT recompute conic
  weights the way classic Skia's SkConic::TransformW would). Parity
  covers scale, 90° rotation, perspective-on-quad, and perspective-on-
  conic. `transform_path_1k` benchmark pair added.

### Changed

- `PathBuilder.addPath` / `extendWithPath` rewritten from replaying the
  source's verbs through the public builder methods to a bulk
  buffer-copy with an in-place point transform (translate / affine /
  perspective branches; conic weights and verb bytes copied directly).
  On the `add_path_100` benchmark (Flutter desktop AOT) this cut the
  per-run cost from 38.7 µs to 16.7 µs (−57%), and `extend_with_path`
  flipped from +43% slower than `dart:ui` to 39% faster. Perspective
  matrices are now supported (the M2 `UnimplementedError` is gone);
  see `addPath`'s doc for the one perspective-plus-non-zero-offset
  corner that still diverges from the engine.


- M2 begins — `PathBuilder.addRect(Rect)`: closed rectangular contour,
  clockwise from the top-left corner. Parity cases include nested
  same-direction rects (winding direction check) under both fill rules.
  `add_rects_500` benchmark pair added.
- `PathBuilder.addOval(Rect)`: four quarter-ellipse conics (weight
  √2/2) wound clockwise from the right edge midpoint, control points at
  the rect corners so loose bounds equal the oval rect — same
  representation as Skia. Parity cases discriminate circle membership
  by radius (catching any polygonal approximation) and verify the
  evenOdd annulus. `add_ovals_500` benchmark pair added.
- `PathBuilder.addRRect(RRect)`: straight edges joined by conic corner
  arcs. Radii normalize the way Skia's `SkRRect::scaleRadii` does —
  negatives clamp to zero; when adjacent radii overflow an edge, all
  radii scale down uniformly by the largest factor that fits every
  edge. Zero-radius corners stay sharp. Parity covers uniform radii,
  oversized radii (stadium shape), and per-corner elliptical radii.
  `add_rrects_500` benchmark pair added.
- `PathBuilder.arcTo(Rect, startAngle, sweepAngle, forceMoveTo)` and
  `PathBuilder.addArc(Rect, startAngle, sweepAngle)`: elliptical arcs
  chopped into ≤90° conic segments (weight cos(halfSweep), control at
  the tangent intersection). `forceMoveTo` chooses between starting a
  fresh contour and joining with a line from the current point. Sweeps
  clamp to ±2π (verified against dart:ui with a 3π parity case).
  `add_arcs_500` benchmark pair added.
- `PathBuilder.addPath(Path, Offset, {Float64List? matrix4})` and
  `PathBuilder.extendWithPath(...)`: append another path's contours,
  translated and optionally transformed by an affine matrix (the offset
  applies after the matrix, matching the engine). `extendWithPath`
  turns the source's first `moveTo` into a `lineTo` join when the
  builder already has a contour. Conic weights pass through unchanged
  (affine-invariant). Perspective matrices throw `UnimplementedError`
  (documented; planned alongside M3's `Path.transform`). `add_path_100`
  and `extend_with_path_100` benchmark pairs added.
- M2 complete — `PathBuilder.arcToPoint(Offset, {radius, rotation,
  largeArc, clockwise})` and `relativeArcToPoint`: SVG endpoint
  parameterization (spec F.6.5) converted to center form, emitted as
  rotated-conic segments. `rotation` is in degrees (verified against
  the engine empirically). Degenerate handling per the SVG rules: zero
  or non-finite radius → straight line; undersized radii scale up
  uniformly; identical endpoints → no-op. `arc_to_point_500` benchmark
  pair added.


- M1 complete (all curve verbs) — `PathBuilder.quadraticBezierTo`,
  `relativeQuadraticBezierTo`, `cubicTo`, `relativeCubicTo`, `conicTo`,
  and `relativeConicTo`. All match `dart:ui.Path` semantics including
  implicit-`moveTo` and post-`close` fresh-contour behavior.
- `conicTo` weight normalization matches *observed* current `dart:ui`
  (Impeller) behavior, verified empirically with a probe program:
  invalid weights (`w <= 0`, NaN, infinity) become a plain quadratic
  through the same control point. Note this differs from classic Skia
  documentation (which converts `w <= 0` to a line); a weight of
  exactly 1 is also stored as a quadratic since the two are
  geometrically identical.
- `Path.contains` learned the `verbQuad`, `verbConic`, and `verbCubic`
  cases via analytic root solvers. Quad solves a quadratic in `t`
  directly. Conic multiplies through by its (strictly positive)
  denominator, yielding the same quadratic shape with weighted
  coefficients and a rational `x(t)`. Cubic uses depression + Cardano
  (one real root) or trigonometric form (three real roots), with
  explicit fallbacks for the quadratic / linear / constant degenerate
  cases when the leading coefficient vanishes. For each root
  `t ∈ [0, 1]` the same per-root helper applies the half-open endpoint
  tie-break and `x(t) > px` filter; tangent crossings (`y'(t) = 0`)
  contribute nothing. Records `(winding, crossingCount)` so both
  nonZero and evenOdd fill rules remain accurate across curve segments.
- 7 quad, 7 cubic, and 7 conic parity cases in
  `fast_path_conformance/test/parity/`. All pass against `dart:ui.Path`.
- `build_quads_500`, `build_conics_500`, and `build_cubics_500`
  (per-frame builder reuse with 500 curve segments each);
  `contains_quads_grid_1024`, `contains_conics_grid_1024`, and
  `contains_cubics_grid_1024` (1024 contains queries against curve-
  heavy fixtures). All have `dart:ui` counterparts; the catalog wires
  them as `PairedBenchmark` entries.

### Changed

- `Path.contains` rejects curve segments cheaply before invoking the
  analytic solvers: if the query's y is strictly outside the segment's
  control-hull y-range, or px is at/beyond the hull's max x, the
  segment cannot contribute a crossing and the solver is skipped. On
  the 1024-query grid benchmarks (AOT) this cut quad contains by 33%,
  conic by 24%, and cubic by 75% — flipping cubic contains from 2.6×
  slower than `dart:ui` to 32% faster.
- `Path.getBounds` semantics clarified in the implementation comment:
  it returns **loose** bounds (bbox of every stored point, including
  off-curve control points). This matches `dart:ui.Path.getBounds()`
  and Skia's `SkPath::getBounds()`; the tight alternative
  (`computeTightBounds`-style) is deferred to a future API addition
  if a caller needs it.
- `Path.contains` quad handling: replaced an initial recursive-
  flattening implementation with the analytic solver described above.
  On the `contains_quads_grid_1024` benchmark (Flutter desktop AOT,
  macOS arm64), the per-query cost dropped from 2.33 µs (5× slower
  than `dart:ui`) to 398 ns (13% faster than `dart:ui`) — the no-FFI
  advantage now applies to curve queries as well as line queries.

- `packages/fast_path_bench/` — pure-Dart benchmark package backed by
  `package:benchmark_harness`. Each benchmark XORs its result into a sink
  that the runner observes after `measure()`, so JIT/AOT dead-code
  elimination cannot silently invalidate the numbers. M0 surface now has
  comprehensive coverage:
  - Construction: `build_polyline_1k` (per-frame reuse),
    `build_polyline_cold_1k` (fresh builder per iter), `add_polygon_1k`
    (convenience API), `relative_polyline_1k` (relativeMoveTo /
    relativeLineTo), `path_from_path_1k` (PathBuilder.from reseed).
  - Queries: `contains_grid_1024`, `bounds_warm_1k`, `bounds_cold_1k`.
  - Conversions (fp-only — dart:ui has no separate builder):
    `builder_from_path_1k` (Path → PathBuilder copy), `builder_snapshot_1k`
    (PathBuilder → Path snapshot), `builder_clone_1k` (PathBuilder →
    PathBuilder clone). Each isolates one direction so the existing
    `path_from_path_1k` round-trip can be attributed to its parts.
  - Identity: `path_equality_1k` (deep structural compare; no dart:ui
    counterpart since `ui.Path` uses identity equality).
- `bin/run_all.dart` runs every benchmark and prints either a
  human-readable table (default) or a JSON report (`--json`). The JSON
  format is the contract that future AOT / dart2js / dart2wasm runners
  will share.
- `tool/bench.sh` — supports `--mode=jit` (default, `dart run`),
  `--mode=aot` (compiles `bin/run_all.dart` to `build/run_all_aot` via
  `dart compile exe`, then runs it), and `--mode=flutter-desktop`
  (compiles + runs the Flutter desktop app via `flutter run --release`
  on macOS or Linux, then greps the canonical JSON out of the
  surrounding banner). The mode label is forwarded into the benchmark's
  own JSON metadata. dart2js / dart2wasm modes will plug in as
  additional cases on this same switch.
- `packages/fast_path_bench_flutter/` — Flutter-hosted bench app. Brings
  `dart:ui.Path` benchmarks alongside the existing fast_path ones so a
  single run produces side-by-side numbers. Desktop builds run benches
  at startup, write JSON to stdout, and exit (a platform window flashes
  briefly — Cocoa / GTK create it before Dart's `main()` runs). Web
  builds present a "Run benchmarks" button; results render on screen
  and `print()` to the browser console. To run the web suite manually:
  `cd packages/fast_path_bench_flutter && flutter run -d chrome --release`.
- `lib/src/catalog.dart` introduces a structured catalog: `PairedBenchmark`
  for workloads with both a fast_path and a `dart:ui` implementation,
  `SoloBenchmark` for fast_path-only features. The Flutter UI groups
  cards by category; the catalog also drives the JSON output (results
  are now emitted in pair-adjacent order, fp/ui interleaved).

### Changed

- `fast_path_bench_flutter` web UI replaced the raw JSON dump with
  Material 3 cards. Paired benchmarks show fast_path on the left and
  `dart:ui` on the right separated by a `VerticalDivider`, with a delta
  badge on the fast_path side ("−39% vs dart:ui" in green when winning,
  red when losing). Solo benchmarks render as a single-value card. The
  canonical JSON is still `print()`-ed to the browser console for
  copy-paste.
- `PathBuilder.relativeMoveTo`, `PathBuilder.relativeLineTo`, and
  `PathBuilder.addPolygon` round out the M0 builder surface to match
  `dart:ui.Path`.
- Conformance corpus expanded with relative-method, `addPolygon`, and
  post-close mutation cases (40 conformance tests total).

### Changed

- `tool/check.sh` now passes `--offline` to `dart pub get` and `--no-pub`
  to `flutter test`. Both skip a network round-trip / re-resolution that
  the workspace doesn't need on every check; total local check time stays
  in the ~3 s range despite the new bench package.
- CI's Flutter step also passes `--no-pub` for the same reason (the
  workspace is already resolved by the preceding `dart pub get`).

### Fixed

- `PathBuilder.lineTo` (and the new `relativeLineTo`) after `close` now
  inject an implicit `moveTo` at the just-closed contour's start, matching
  Skia / `dart:ui.Path` behavior. Previously the verb stream silently
  extended the closed contour, which produced subtly different `contains`
  results on shapes that mixed `close` with subsequent line segments.
- `PathBuilder.close` is now idempotent — repeated calls with no
  intervening mutation no longer emit duplicate `close` verbs.

- M0 — geometry types and the builder/path split.
  - Geometry value types: `Offset`, `Size`, `Rect`, `Radius`, `RRect`,
    `PathFillType`.
  - `PathBuilder` with `moveTo`, `lineTo`, `close`, `reset`, `reserve`,
    `fillType`, plus `from` / `fromBuilder` constructors and the
    snapshot `build()` handoff.
  - `Path` with `getBounds`, `contains` (nonZero and evenOdd), `fillType`,
    structural equality, and a cached `hashCode`.
- `fast_path_conformance` package with the first M0 parity tests against
  `dart:ui.Path`. 12 path programs replayed on both sides; `getBounds`
  agreement within the DESIGN.md §8.2 tolerances and `contains` agreement
  on hand-picked sample points.
- `tool/check.sh` runs analyzer, dart tests, and conformance tests across
  the workspace, with per-phase timings. Suite currently completes in
  ~3.5 s locally — keep it that way.
- GitHub Actions CI workflow at `.github/workflows/ci.yaml` mirroring the
  same steps.

## 0.1.0

- Initial package scaffold.
