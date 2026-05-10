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
- `tool/check.sh` runs analyzer and tests across the workspace.
- GitHub Actions CI workflow at `.github/workflows/ci.yaml`.

## 0.1.0

- Initial package scaffold.
