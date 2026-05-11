# Changelog

## Unreleased

### Added

- `PathBuilder.relativeMoveTo`, `PathBuilder.relativeLineTo`, and
  `PathBuilder.addPolygon` round out the M0 builder surface to match
  `dart:ui.Path`.
- Conformance corpus expanded with relative-method, `addPolygon`, and
  post-close mutation cases (40 conformance tests total).

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
