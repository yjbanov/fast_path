# Changelog

## Unreleased

### Added

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
