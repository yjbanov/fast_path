# Changelog

## Unreleased

- `RRect.toString()`: added, for parity with `dart:ui.RRect` and the other
  geometry value types (it previously fell back to `Instance of 'RRect'`).
  Renders the edges plus each corner radius (circular or elliptical).
- `Matrix` (performance): widened the inline core from four doubles to six, so
  the full 2D-affine block (the 2x2 linear part plus 2D translation) is stored
  inline and the extension holds only the 3D/perspective tail. Rotation, skew,
  and general 2D-affine matrices — the common UI case — no longer allocate an
  extension. Net effect across the benchmark suite: large wins on affine
  instantiation, factories, invert, determinant, equality, hashing, and
  geometry transforms (several now faster than `package:vector_math`); modest
  regressions on pure diagonal-scale cases (the wider object and the dropped
  diagonal-specific multiply fast path). `transformRect` is now allocation-free.
- `Matrix` (fix): `operator +` and unary `operator -` are now true element-wise
  operations matching `Matrix4` (the previous versions ignored the `m22`/`m33`
  tail for extension-free matrices). Affine `+` reuses a shared constant tail,
  so it stays allocation-light.

- `Matrix`: added structural `operator ==`, `hashCode`, and `toString`. Equality
  and hashing exploit the canonical-lowering representation (a `_rest`
  null/non-null mismatch decides inequality without comparing the extension) and
  normalize `-0.0` so equal matrices hash equally.
- `Matrix`: added factory constructors `rotationZ`, `rotationX`, `rotationY`,
  `skew`, `scale`, `orthographic`, and `perspective`. Each lowers to the most
  specific shape (e.g. `rotationZ(0)` and `scale(1)` return `identity`) and is
  numerically verified against `package:vector_math`.
- `Matrix`: added composition methods `translated`, `scaled`, `rotatedZ`, and
  `skewed`, each returning `this * factory(...)` — the new transform applied in
  the receiver's local space (post-multiplication), matching vector_math's
  in-place `translate`/`scale`/`rotateZ`.
- `Matrix`: added geometry transforms `transformPoint`, `transformVector`, and
  `transformRect` (returning `fast_geometry`'s `Offset`/`Rect`). They fast-path
  `isSimple2d` matrices, apply the perspective divide when not affine, and are
  parity-tested against `package:vector_math`.
- `Matrix`: added `transposed()`. A diagonal matrix (scale/identity) is
  symmetric and returns itself; a translation transposes into a general matrix.
