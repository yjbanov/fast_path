# Changelog

## Unreleased

### Changed

- `PathBuilder.conicTo` re-pinned against the 2026-06 `dart:ui` (Impeller),
  which split its degenerate-weight handling: `w <= 0` still becomes a plain
  quadratic, but `w == +infinity` now collapses to the infinite-weight corner
  (two line segments through the control point) rather than a quadratic. A
  **NaN** weight is fast_path's one documented divergence — `dart:ui` treats it
  like `+infinity`, but fast_path keeps it a safe quadratic. (The April engine
  treated all of these as quadratics; the conformance suite caught the drift.)
- **Breaking:** `Path.transform`, `PathBuilder.addPath`, and
  `PathBuilder.extendWithPath` now take a `fast_geometry` `Matrix` instead of a
  column-major `Float64List` (the `matrix4:` named parameter is now `matrix:`).
  Callers holding `dart:ui` / `Matrix4`-style engine data bridge with the
  `Float64List.toMatrix()` extension. Behavior is otherwise unchanged.

### Added

- M4a — boolean ops (`Path.combine`).
  - `PathOperation` enum (`difference`, `intersect`, `union`, `xor`,
    `reverseDifference`) and `static Path.combine(op, a, b)`, mirroring
    `dart:ui`.
  - Implemented as a polygonal MVP: both operands are flattened to polygons and
    combined by a clean-room Martinez–Rueda–Feito sweep
    (`lib/src/martinez.dart`, attribution-preserving adaptation of the MIT
    `w8r/martinez` reference). Two documented divergences from `dart:ui`:
    **polygonal output** (curves are flattened — the result has no curve verbs),
    and **even-odd interiors** (each operand read under the even-odd rule, the
    result emitted as `evenOdd` — the fill type `dart:ui` returns; a `nonZero`
    operand whose own contours overlap may differ).
  - Verified by unit tests plus a `dart:ui` parity gate (hand-picked cases and a
    deterministic fuzz corpus comparing containment).
  - Benchmarks both sides. Current standing: ~13–19× slower than `dart:ui`'s
    native pathops — correctness-first; a tracked optimization pass is in the
    DESIGN.md §10 roadmap.
- M0 — geometry types and the builder/path split.
  - Geometry value types: `Offset`, `Size`, `Rect`, `Radius`, `RRect`,
    `PathFillType`.
  - `PathBuilder` with `moveTo`, `lineTo`, `close`, `reset`, `reserve`,
    `fillType`, plus `from` / `fromBuilder` constructors and the
    snapshot `build()` handoff. `relativeMoveTo`, `relativeLineTo`, and
    `addPolygon` round out the M0 builder surface.
  - `Path` with `getBounds`, `contains` (nonZero and evenOdd), `fillType`,
    structural equality, and a cached `hashCode`.
- `fast_path_conformance` package with parity tests against `dart:ui.Path`:
  path programs replayed on both sides, comparing `getBounds` within the
  DESIGN.md §8.2 tolerances and `contains` on hand-picked sample points.
- `tool/check.sh` runs analyzer, dart tests, and conformance tests across
  the workspace with per-phase timings (~3.5 s locally). GitHub Actions
  CI at `.github/workflows/ci.yaml` mirrors the same steps.
- `packages/fast_path_bench/` — pure-Dart benchmark package backed by
  `package:benchmark_harness`. Each benchmark XORs its result into a sink
  the runner observes after `measure()`, so JIT/AOT dead-code elimination
  cannot silently invalidate the numbers. `bin/run_all.dart` prints a
  human-readable table or, with `--json`, the canonical JSON report.
- `tool/bench.sh` supports `--mode=jit` (default), `--mode=aot`
  (`dart compile exe`), and `--mode=flutter-desktop` (Flutter desktop
  `--release`, comparing against `dart:ui`). dart2js / dart2wasm modes
  plug into the same switch later.
- `packages/fast_path_bench_flutter/` — Flutter-hosted bench app that runs
  the fast_path benches alongside `dart:ui.Path` counterparts. Desktop
  builds emit JSON and exit; web builds present a "Run benchmarks" button.
  `lib/src/catalog.dart` is the single source of truth: `PairedBenchmark`
  for workloads with a `dart:ui` mirror, `SoloBenchmark` for
  fast_path-only ones.
- M1 — curves. `PathBuilder.quadraticBezierTo`,
  `relativeQuadraticBezierTo`, `cubicTo`, `relativeCubicTo`, `conicTo`,
  and `relativeConicTo`, all matching `dart:ui.Path` semantics (implicit
  `moveTo`, post-`close` fresh-contour behavior).
  - `conicTo` weight normalization matches *observed* current `dart:ui`
    (Impeller) behavior, verified empirically: invalid weights
    (`w <= 0`, NaN, infinity) become a plain quadratic through the same
    control point. This differs from classic Skia docs (which convert
    `w <= 0` to a line); `w == 1` is also stored as a quadratic.
  - `Path.contains` handles `verbQuad`, `verbConic`, and `verbCubic` via
    analytic root solvers (quadratic; conic multiplied through by its
    positive denominator; cubic by depression + Cardano / trig form with
    quadratic / linear / constant fallbacks). Half-open endpoint
    tie-break, tangent crossings ignored, `(winding, crossingCount)`
    tracked so both fill rules stay accurate.
  - Benchmarks: `build_quads_500`, `build_conics_500`, `build_cubics_500`,
    `contains_quads_grid_1024`, `contains_conics_grid_1024`,
    `contains_cubics_grid_1024`, all with `dart:ui` counterparts.
- M2 — convenience builders, all with parity cases and benchmark pairs.
  - `addRect(Rect)`: closed rectangle, clockwise from top-left.
  - `addOval(Rect)`: four quarter-ellipse conics (weight √2/2), control
    points at the rect corners so loose bounds equal the oval rect.
  - `addRRect(RRect)`: edges + conic corners, with Skia's `scaleRadii`
    normalization (negatives clamp to zero; oversized adjacent radii
    scale down uniformly).
  - `arcTo(Rect, startAngle, sweepAngle, forceMoveTo)` and
    `addArc(Rect, startAngle, sweepAngle)`: elliptical arcs chopped into
    ≤90° conics, sweeps clamped to ±2π.
  - `addPath(Path, Offset, {matrix4})` and `extendWithPath(...)`: append
    another path's contours, transformed and translated.
  - `arcToPoint(Offset, {radius, rotation, largeArc, clockwise})` and
    `relativeArcToPoint`: SVG endpoint parameterization (spec F.6.5);
    `rotation` is in degrees (verified empirically).
- M3 — transforms and metrics.
  - `Path.shift(Offset)`: pure-function translate; shares verb/weight
    buffers with the original, allocates only the point buffer.
    `shift_path_1k` benchmark pair.
  - `Path.transform(Float64List matrix4)`: maps every point through a
    column-major 4×4 matrix (affine fast path; perspective applies the
    homogeneous divide). Verbs and conic weights preserved unchanged
    under both — a probe confirmed `dart:ui` does the same even under
    perspective (it does not recompute conic weights). `transform_path_1k`
    benchmark pair.
  - `Path.computeMetrics({forceClosed})` → `PathMetrics` (re-iterable,
    unlike `dart:ui`'s one-shot), plus `PathMetric` (`length`, `isClosed`,
    `contourIndex`, `getTangentForOffset`) and `Tangent` (`position`,
    `vector`, `angle`, `fromAngle`). Contours flatten to a cumulative
    arc-length table (adaptive subdivision incl. rational de Casteljau
    for conics). Length parity ~0.5%; tangent positions within 0.5 at
    equal fractions. `metrics_tangents_64` benchmark pair (≈ tied).
  - `PathMetric.extractPath(start, end, {startWithMoveTo})`: the sub-path
    between two arc-length distances (flattened polyline; `dart:ui`
    preserves curves — a documented divergence, lengths still match).
    `extract_path_32` benchmark pair.

### Changed

- `Path.contains` rejects curve segments via a control-hull bound before
  invoking the analytic solver: if the ray's y is outside the segment's
  control-hull y-range, or px is past its max x, the solver is skipped.
  AOT: quad contains −33%, conic −24%, cubic −75% (flipping cubic from
  2.6× slower than `dart:ui` to 32% faster).
- `Path.contains` quad handling replaced an initial recursive-flattening
  implementation with the analytic solver (the `contains_quads_grid_1024`
  per-query cost dropped from 2.33 µs to 398 ns — from 5× slower than
  `dart:ui` to 13% faster).
- `Path.getBounds` documented as returning **loose** bounds (bbox of all
  stored points, including control points), matching `dart:ui` / Skia; a
  tight variant is deferred.
- `PathBuilder.addRRect` starts its contour at `(left, bottom − blRadius)`
  winding clockwise, matching `dart:ui` / Skia's start vertex and
  direction. The filled shape is unchanged; the traversal now lines up
  segment-for-segment (surfaced by `computeMetrics`).
- `PathBuilder.addPath` / `extendWithPath` rewritten from verb-replay to a
  bulk buffer-copy with an in-place point transform (translate / affine /
  perspective branches). `add_path_100` AOT 38.7 µs → 16.7 µs (−57%);
  `extend_with_path` flipped from +43% vs `dart:ui` to −39%. Perspective
  matrices are now supported (the M2 `UnimplementedError` is gone); see
  `addPath`'s doc for the perspective-plus-non-zero-offset corner that
  still diverges.
- `fast_path_bench_flutter` web UI uses Material 3 cards (fast_path vs
  `dart:ui` split by a `VerticalDivider`, delta badge on the fast_path
  side) instead of a raw JSON dump; JSON still prints to the console.
- `tool/check.sh` passes `--offline` to `dart pub get` and `--no-pub` to
  `flutter test`; CI's Flutter step also passes `--no-pub`. Keeps the
  local suite at ~3 s.

### Fixed

- `PathBuilder.lineTo` (and `relativeLineTo`) after `close` now inject an
  implicit `moveTo` at the just-closed contour's start, matching Skia /
  `dart:ui`. Previously the verb stream silently extended the closed
  contour, producing subtly different `contains` results.
- `PathBuilder.close` is idempotent — repeated calls with no intervening
  mutation no longer emit duplicate `close` verbs.

## 0.1.0

- Initial package scaffold.
