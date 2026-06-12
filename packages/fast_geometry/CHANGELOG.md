# Changelog

## Unreleased

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
