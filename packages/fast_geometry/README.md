# fast_geometry

Fast, **pure-Dart** 2D geometry and transforms for UI — no `dart:ui` dependency,
no native bindings. Part of the [fast_2d](../../README.md) family.

It provides:

- **Geometry value types** — `Offset`, `Size`, `Rect`, `Radius`, `RRect`,
  `Tangent` — immutable and structurally equal, mirroring the shapes Flutter
  developers already know.
- **`Matrix`** — an immutable, 2D-optimized 4×4 transform. Unlike a general 3D
  matrix library, its representation is shape-encoded: the full 2D-affine block
  (scale, rotation, skew, translation) lives inline, and only a genuine
  3D/perspective tail allocates extra storage. Identity, translation, scale, and
  rotation — the common UI transforms — stay allocation-light, and construction
  always lowers a matrix to its most specific shape so equal transforms compare
  and hash identically.

`Matrix` is deeply immutable: every "mutating" operation returns a new instance.
It covers construction (`rotationZ`, `skew`, `scale`, `orthographic`,
`perspective`, …), composition (`translated`, `scaled`, `rotatedZ`, …),
arithmetic (`*`, `+`, `determinant`, `invert`, `transposed`), and geometry
transformation (`transformPoint`, `transformRect`, `transformVector`). Its
numerical behavior is verified against `package:vector_math`'s `Matrix4`.

See [`design_docs/matrix.md`](../../design_docs/matrix.md) for the full design.

## Status

Early development. The public API is unstable.

## License

BSD-3-Clause. See the [project root LICENSE](../../LICENSE).
