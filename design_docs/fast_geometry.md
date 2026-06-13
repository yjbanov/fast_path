# Proposal: split out `fast_geometry`, and adopt a first-party `Matrix`

This proposal covers two linked changes:

1. **Consolidate the geometry value types** (currently `geometry.dart` inside
   `fast_path`) and the matrix prototype (currently `package:uimatrix`) into a
   new standalone package, **`fast_geometry`**. `fast_path` depends on it.
2. **Switch the path transform APIs** — `Path.transform`,
   `PathBuilder.addPath`, `PathBuilder.extendWithPath` — from raw
   `Float64List` matrices to `fast_geometry`'s `Matrix` type.

Status: draft. The naming (`fast_geometry` + `fast_path`, class `Matrix`) is
settled; sequencing and the `Matrix` API surface are open.

---

## 1. Why — lead with the design case, not performance

This is primarily an **API-vocabulary** decision. `fast_path` already defines
and exposes its *own* geometry value types rather than `dart:ui`'s —
`contains(Offset)`, `addPolygon(List<Offset>)`, `shift(Offset)`,
`arcToPoint(Offset)` all take `fast_path.Offset`, not `ui.Offset`. Porting code
from `dart:ui` is already not mechanical at the type level: you substitute
`fast_path` geometry types throughout.

Against that backdrop, `Float64List matrix4` is the **odd primitive out** — the
one spot in the API that takes a raw representation instead of a structured
first-party value type. `transform(Matrix)` is the *consistent* choice, not a
deviation from the project's philosophy. Consolidating the geometry types and
the matrix into `fast_geometry` completes a coherent value-type vocabulary that
`fast_path` builds on.

> **Note for `skills/add-path-api/SKILL.md`.** That skill currently says: *"If
> `dart:ui.Path` takes `Float64List matrix4`, take `Float64List matrix4`. Don't
> 'improve' it to `Matrix4`."* That rule was written to prevent dragging in
> `package:vector_math`'s `Matrix4` — a heavy third-party dependency. A
> **first-party** `Matrix` living in the same geometry package as `Offset` and
> `Rect` is a different proposition, and is consistent with the project already
> substituting its own `Offset`/`Rect`/`RRect` for `dart:ui`'s. **This rule must
> be updated as part of the migration**, or it will contradict the code and
> mislead the next contributor.

---

## 2. Why — the performance case, honestly

Performance is a *secondary* justification, and it is important to be precise
about where it does and does not apply:

- **Inside `Path.transform` itself, the matrix-type win is marginal.** Whether
  the matrix shape is detected from a `Matrix`'s encoded invariant
  (`_rest == null`) or from raw `Float64List` entries (`matrix4[3] == 0 && …`),
  the per-point loop is identical and dominates the cost, and the matrix is
  allocated by the *caller*, not by `transform`. So the allocation and
  shape-detection savings do not meaningfully move `Path.transform` throughput.
  Do not sell the migration on this number.

- **At the geometry layer, the win is real and first-class.** Matrix algebra —
  multiply, invert, compose — is hot in its own right in any UI pipeline: an
  animated or re-laid-out subtree recomposes transforms every frame, entirely
  independent of paths. The monomorphic, shape-lowering representation (see §3)
  makes those operations fast and allocation-light. If `fast_geometry` ships a
  matrix, that matrix should be as fast as the path operations are — with its
  own benchmark suite (multiply / invert / map-point), held to the same
  standard as `fast_path`'s benchmarks.

- **Identity is an unconditional `O(1)` bypass.** Because the constructors lower
  to the most specific shape and canonicalize, *any* identity matrix built
  through the public API is `identical` to the single `Matrix.identity`
  constant — not just one built from the singleton. `identical(m,
  Matrix.identity)` is therefore a reliable fast path, and `transform` can
  `return this` for it (safe: `Path` is immutable).

- **Allocation footprint favors callers.** A `Float64List(16)` is a 128-byte
  heap array. A `Matrix` translation / scale-translate is a small object with
  four inline doubles and a `null` extension — no array. This benefits code that
  *builds* matrices (layout, animation), which is most UI code.

- **The path-transform fast loops are worth doing regardless of the type.**
  Identity → `return this`, translate-only, and scale-translate specialized
  loops are genuine speedups for those workloads. They are available with
  `Float64List` too; `Matrix` simply makes them *safe to dispatch* via a trusted
  shape invariant rather than re-deriving the shape from raw storage each call.
  These should land as their own change (with a benchmark that exercises them —
  the current `transform_path_1k` uses a general-affine matrix and would not
  show a translate-only win).

---

## 3. How the `Matrix` representation works

`Matrix` (today's `UiMatrix`) is **monomorphic** and immutable. It stores the
four values that the common 2D cases need inline, plus a nullable extension for
the rest:

```
class Matrix {
  double _m00, _m11;       // scaleX, scaleY
  double _m03, _m13;       // dx, dy
  _MatrixExtension? _rest; // the other 12 entries, or null
}
```

So identity, `translation2d`, and `simple2d` (scale + translate) all have
`_rest == null` — four doubles and a null pointer, **no 16-element array**.
"General 2D" (rotation / skew) and full 3D / perspective carry the extension.

Constructors **lower to the most specific shape**: the 16-argument
`Matrix.transform(...)` collapses to `simple2d` when the off-diagonals are zero,
`simple2d(1, 1, …)` collapses to `translation2d`, and `translation2d(0, 0)`
returns the canonical `identity` constant. Zero and identity are each a single
shared `const` instance.

The upshot for `fast_path`: matrix shape is an **encoded invariant**, not
something to re-derive. `_rest == null` *guarantees* the other 12 entries are
zero/identity, so the translate / scale-translate loops are reachable with a
null check instead of ~8 float comparisons.

---

## 4. API changes in `fast_path`

| Method | Current (`Float64List`) | Proposed (`Matrix`) |
| :--- | :--- | :--- |
| `Path.transform` | `Path transform(Float64List matrix4)` | `Path transform(Matrix matrix)` |
| `PathBuilder.addPath` | `void addPath(Path p, Offset o, {Float64List? matrix4})` | `void addPath(Path p, Offset o, {Matrix? matrix})` |
| `PathBuilder.extendWithPath` | `void extendWithPath(Path p, Offset o, {Float64List? matrix4})` | `void extendWithPath(Path p, Offset o, {Matrix? matrix})` |

Shape-dispatched `transform` (framing corrected — the branches are
specializations enabled cleanly by the encoded shape, not magic from the type):

```dart
Path transform(Matrix matrix) {
  if (identical(matrix, Matrix.identity)) {
    return this; // unconditional O(1) bypass via canonicalization
  }
  final n = _points.length;
  if (n == 0) return this;
  final newPoints = Float32List(n);

  if (matrix.isSimple2d) {                 // _rest == null
    final sx = matrix.scaleX, sy = matrix.scaleY;
    final dx = matrix.dx, dy = matrix.dy;
    if (sx == 1.0 && sy == 1.0) {
      for (var i = 0; i < n; i += 2) {     // translate-only: 2 adds
        newPoints[i] = _points[i] + dx;
        newPoints[i + 1] = _points[i + 1] + dy;
      }
    } else {
      for (var i = 0; i < n; i += 2) {     // scale+translate: 2 mul, 2 add
        newPoints[i] = sx * _points[i] + dx;
        newPoints[i + 1] = sy * _points[i + 1] + dy;
      }
    }
  } else if (matrix.isAffine2d) {          // rotation / skew, no perspective
    final m00 = matrix.scaleX, m01 = matrix.m01, m03 = matrix.dx;
    final m10 = matrix.m10, m11 = matrix.scaleY, m13 = matrix.dy;
    for (var i = 0; i < n; i += 2) {
      final x = _points[i], y = _points[i + 1];
      newPoints[i] = m00 * x + m01 * y + m03;
      newPoints[i + 1] = m10 * x + m11 * y + m13;
    }
  } else {                                 // perspective: homogeneous divide
    final m00 = matrix.scaleX, m01 = matrix.m01, m03 = matrix.dx;
    final m10 = matrix.m10, m11 = matrix.scaleY, m13 = matrix.dy;
    final m30 = matrix.m30, m31 = matrix.m31, m33 = matrix.m33;
    for (var i = 0; i < n; i += 2) {
      final x = _points[i], y = _points[i + 1];
      final w = m30 * x + m31 * y + m33;
      newPoints[i] = (m00 * x + m01 * y + m03) / w;
      newPoints[i + 1] = (m10 * x + m11 * y + m13) / w;
    }
  }
  return Path._(_verbs, newPoints, _conicWeights, fillType);
}
```

Verbs and conic weights are still shared by reference and preserved unchanged
(established in M3 — `dart:ui` keeps verb structure and conic weights even under
perspective; `Matrix` changes nothing about that).

---

## 5. `Matrix` API additions in `fast_geometry`

The prototype's shape predicates and component getters are package-private.
Since `fast_geometry` owns the type, expose what `fast_path` (and other callers)
need as public API, and **drop the `Ui` prefix** (`UiMatrix` → `Matrix`; the
prefix made sense for a standalone "UI matrix" package but is redundant inside a
geometry package):

```dart
extension MatrixShape on Matrix {
  bool get isTranslation2d => _rest == null && _m00 == 1.0 && _m11 == 1.0;
  bool get isSimple2d => _rest == null;
  bool get isAffine2d =>
      _rest == null ||
      (_rest._m30 == 0.0 && _rest._m31 == 0.0 && _rest._m33 == 1.0);

  double get m01 => _rest?._m01 ?? 0.0;
  double get m10 => _rest?._m10 ?? 0.0;
  double get m30 => _rest?._m30 ?? 0.0;
  double get m31 => _rest?._m31 ?? 0.0;
  double get m33 => _rest?._m33 ?? 1.0;
}
```

For a general-purpose geometry package it likely makes sense to expose all 16
entries (`m02`, `m12`, `m22`, …) as standard getters for completeness, even
though `fast_path` only needs the 2D-relevant subset above.

---

## 6. `Float64List` interop lives in core, not the Flutter bridge

This is the one place the earlier draft had the layering **backwards**. The
`Float64List ⇄ Matrix` bridge must live in **`fast_geometry`** (core), not in
`fast_path_flutter`:

```dart
// In fast_geometry.
extension Float64ListToMatrix on Float64List {
  /// Builds a [Matrix] from a column-major 4x4 list (the representation
  /// dart:ui.Path.transform and Matrix4.storage use).
  Matrix toMatrix() => Matrix.transform(
        m00: this[0], m10: this[1], m20: this[2], m30: this[3],
        m01: this[4], m11: this[5], m21: this[6], m31: this[7],
        m02: this[8], m12: this[9], m22: this[10], m32: this[11],
        m03: this[12], m13: this[13], m23: this[14], m33: this[15],
      );
}
```

Rationale: a **plain-Dart** caller (no Flutter) who already has a column-major
`Float64List` — from their own affine math, from `Matrix4.storage`, or copied
out of engine code — must be able to reach `transform` without depending on the
Flutter bridge package. Gating the conversion behind `fast_path_flutter` would
make the *standard* matrix representation (the one `dart:ui` itself uses) a
second-class citizen, which works against the portability and dart:ui-interop
goals. Keep it in core.

`fast_path_flutter` can still add `dart:ui`-specific sugar (e.g. converting a
`ui.Path` ↔ `fast_path.Path`, or accepting a `vector_math` `Matrix4`), but the
plain `Float64List` bridge is core.

---

## 7. Naming

Settled:

| Package | Holds |
| :--- | :--- |
| **`fast_geometry`** | `Offset`, `Size`, `Rect`, `RRect`, `Radius`, `Tangent`, and `Matrix` |
| **`fast_path`** | `PathBuilder` / `Path` (depends on `fast_geometry`) |

- Class rename: `UiMatrix` → `Matrix`.
- The "2D-first, UI-oriented, portable (no `dart:ui`), performant" positioning
  belongs in the package *descriptions* and READMEs, not the names — e.g.
  `fast_geometry`'s description: *"Fast, pure-Dart 2D geometry and transforms
  for UI (Flutter, web, SwiftUI-style layouts), with no `dart:ui` dependency."*
  This does the discovery and positioning work without a longer, worse name like
  `fast_ui_geometry` or `fast_2d_geometry`.
- **Check pub.dev availability** for `fast_path` and `fast_geometry` before
  publishing. If either collides, choose an umbrella codename and apply it
  across the *whole* family at once (`x_geometry` / `x_path`) rather than
  letting the two packages drift apart in naming — family coherence matters more
  than any single name.

---

## 8. Sequencing

The geometry-package consolidation is the prerequisite; doing the type swap
before it would churn the public API twice.

1. **Create `fast_geometry`.** Move the `geometry.dart` value types (`Offset`,
   `Size`, `Rect`, `RRect`, `Radius`, `Tangent`) and the matrix (renamed
   `Matrix`, with the public shape API from §5) into it. Add the `Float64List`
   bridge (§6) and a matrix benchmark suite (multiply / invert / map-point).
   Make `fast_path` depend on it; re-export geometry types from `fast_path` so
   existing imports keep working.
2. **Switch the path transform APIs** (`transform`, `addPath`,
   `extendWithPath`) to `Matrix`. Update unit tests (`transform_test.dart`,
   `add_path_test.dart`), the parity harness, and `TransformPath1kBenchmark`.
3. **Add the specialized transform loops** (identity → `this`, translate-only,
   scale-translate) plus a `transform_translate` benchmark that exercises them.
4. **Update docs and the skill.** Rewrite the `add-path-api` skill's matrix rule
   (§1 note); update `packages/fast_path/DESIGN.md` §11 (the open question is now resolved) and the
   public API section.

---

## 9. Open questions / risks

- **pub.dev name availability** (§7) — resolve before publishing; may force an
  umbrella codename across the family.
- **Where `Tangent` lives.** It is a geometry value type (`position`, `vector`,
  `angle`) → `fast_geometry`. `PathMetric` / `PathMetrics` stay in `fast_path`
  (they are path operations). Worth confirming when carving the package.
- **Re-export strategy.** `fast_path` should re-export `fast_geometry`'s types so
  `import 'package:fast_path/fast_path.dart'` still yields `Offset` etc. and the
  split is a non-breaking change for existing users.
- **`Matrix` precision.** `fast_geometry`/`Matrix` works in `double` (f64);
  `fast_path` stores points as f32. The transform reads f64 matrix entries and
  writes f32 points, same as today — no change, but worth noting the boundary.
