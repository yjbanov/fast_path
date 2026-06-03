# Changelog

## Unreleased

### Added

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
