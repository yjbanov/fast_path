---
name: add-matrix-api
description: Use whenever a method, getter, factory constructor, operator, or related type is being added to or changed on fast_geometry's Matrix API surface (packages/fast_geometry/lib/src/matrix.dart). Trigger on phrases like "add rotationZ", "implement transformPoint", "add == and hashCode to Matrix", "Matrix.scaled", "transpose the matrix", "compare against vector_math", and on PRs touching matrix.dart, the _MatrixExtension representation, or fast_geometry.dart's exports. Apply this even when the user only says "add X to Matrix" without naming vector_math — numerical correctness against vector_math's Matrix4 and preservation of the canonical-lowering representation are the project's defining constraints for this type, and this skill enforces them.
---

# Adding or extending the Matrix API surface

`fast_geometry`'s `Matrix` is a **deeply immutable**, **monomorphic**, 2D-optimized
4×4 transform. It is not a port of any one library — it is a from-scratch type
whose representation is tuned for the matrices UI code actually uses (identity,
2D translation, scale+translate, 2D affine), with a 3D tail available when
needed. See `design_docs/matrix.md` for the full design and the
"Fully Featured API" plan this skill helps execute.

Two things make adding to `Matrix` different from adding to a normal class, and
this skill is the checklist for both:

1. **`vector_math`'s `Matrix4` is a correctness *oracle*, not an API contract.**
   We validate that `Matrix` produces the *same numbers* `Matrix4` does for the
   same transform — but we do **not** copy `Matrix4`'s signatures, mutability,
   or method names. `Matrix4` is mutable and 3D-first; `Matrix` is immutable and
   2D-first. The API is designed for *our* type; `Matrix4` only judges the math.

2. **The canonical-lowering representation is load-bearing.** Every `Matrix` is
   stored in its most-specific shape (identity is a shared constant; a transform
   that is secretly a translation has `_rest == null`). Equality, `hashCode`,
   and the `isTranslation2d` / `isSimple2d` / `isAffine2d` fast paths all rely
   on this invariant. A new method that produces a non-canonical `Matrix` —
   e.g. a general instance whose `_rest` is actually the identity extension —
   silently breaks `==` and every fast path. This is the `Matrix` analog of
   fast_path's builder/Path split: get it right when the method is fresh.

## Why this matters

Users reach for `fast_geometry` for two reasons: it gives the right answer, and
it allocates almost nothing for the common 2D cases. A method that disagrees
with `Matrix4` past tolerance is a silent trap. A method that allocates a
12-double `_MatrixExtension` for a transform that should have lowered to the
inline core throws away the entire performance premise — and worse, may make a
later `==` return false for two matrices that are mathematically equal.

Both properties are cheap to hit when the code is fresh and expensive to
retrofit. So: design the immutable API, get the math right against the oracle,
and keep every result canonical.

## When this skill applies

Apply when:

- Adding a public method, getter, factory constructor, or operator to `Matrix`
  (`rotationZ`, `transformPoint`, `transposed`, `translated`, `operator ==`, …).
- Adding a public type that participates in the surface (e.g. a decomposition
  result).
- Changing an existing `Matrix` method's signature, semantics, or numerical
  behavior.
- Touching the representation itself (`_MatrixExtension`, the inline core, the
  lowering constructors) — see the escalation note; representation changes are a
  cross-cutting decision.
- Reviewing a PR that does any of the above.

It does **not** apply to the benchmark harness (`bench_core`) or to the geometry
value types (`Offset`, `Rect`, …) unless a `Matrix` method is being added that
transforms them.

## Workflow

### 1. Confirm it belongs on Matrix, and find the oracle

`Matrix` is immutable. Anything that conceptually mutates returns a **new**
`Matrix`. There are no setters. If a request sounds like "change this matrix in
place," the answer is a method that returns a new instance (`translated`,
`scaled`, …) — never a mutator.

Locate the `Matrix4` equivalent in `package:vector_math/vector_math_64.dart` and
read what the math should be — but treat it as a reference for *results*, not for
API shape. Note where `Matrix4` is mutable (`..rotateZ(r)`) and translate that to
our immutable form (`m.rotatedZ(r)` returning a new matrix, or a `Matrix.rotationZ`
factory composed via `*`).

If there is no sensible `Matrix4` analog (an operation `Matrix4` doesn't
provide, or provides only via in-place mutation that doesn't translate), **stop
and ask** before inventing surface.

### 2. Design the immutable signature

Design for `Matrix`, not for `Matrix4`:

- Factory constructors are `static Matrix name(...)` returning a canonical
  instance (mirroring the existing `translation2d`, `simple2d`, `transform2d`,
  `transform`). Use named parameters where it aids call-site clarity.
- Composition methods return a new `Matrix` (`Matrix translated(double dx,
  double dy)` ≡ `this * Matrix.translation2d(dx: dx, dy: dy)`). Define the
  composition order explicitly in the dartdoc — `this` first or the new
  transform first — and pin it in a test (the existing `operator *` debate in
  `matrix_test.dart` is precisely this hazard).
- Geometry transforms take and return `fast_geometry` value types
  (`Offset transformPoint(Offset)`, `Rect transformRect(Rect)`).

### 3. Preserve canonical lowering — the load-bearing invariant

Every code path that produces a `Matrix` must produce it in its most-specific
shape:

- **Route results through the lowering constructors** (`Matrix.transform`,
  `transform2d`, `simple2d`, `translation2d`) rather than `Matrix._(...)`
  directly. Those constructors collapse a result to `_rest == null`, or to the
  `identity` constant, when its values permit.
- **Only construct `Matrix._` with a non-null `_rest` directly when the result
  is provably general** for *all* inputs — as `_generalInvert` does (the inverse
  of a general matrix is always general). If you can't prove it, lower it.
- **Index convention:** `mRC` is row `R`, column `C`. Translation lives in
  `m03`/`m13`. `Matrix4` is column-major, so `Matrix4.storage[C * 4 + R]` maps to
  `mRC` (see `Float64ListToMatrix`). Get this mapping right or every parity test
  is comparing transposed matrices.

Add a test that asserts the canonical outcome: e.g. a `rotationZ(0)` returns
`identity` (or at least `_rest == null` / `isSimple2d`), and a general-looking
construction whose off-diagonals are zero lowers to `isSimple2d`.

### 4. Provide shape fast paths

The representation exists to make the common shapes cheap. A new method should:

- Fast-path `isTranslation2d` and `isSimple2d` (`_rest == null`) with inline
  arithmetic on the four core fields, and only fall through to a general routine
  that reads `_rest` when necessary. `transformPoint`/`transformRect` especially
  must not walk `_rest` for a simple matrix.
- Handle the non-affine case (`!isAffine2d`, i.e. a perspective tail) correctly
  where it applies — `transformPoint` needs the `w` divide; don't silently drop
  it.

If you find the common 2D-affine-with-rotation case is forced through the
general `_rest` path and that dominates the benchmark, **do not widen the inline
core to fix it inline** — that representation change (4-inline → 6-inline) is the
deferred optimization tracked in `design_docs/matrix.md`. Note it and escalate.

### 5. Implement in pure Dart, allocation-aware

- **No `dart:ffi`, `dart:io`, or `dart:ui`.** `fast_geometry` runs on plain Dart
  VMs; keep it that way.
- The only allocation a `Matrix` op should make is the **result** `Matrix` (and
  its `_rest`, *only* when the result is genuinely general). A simple-shaped
  result must not allocate a `_MatrixExtension`.
- Read the four core fields directly (`_m00`, `_m11`, `_m03`, `_m13`); reach into
  `_rest` only on the general path. Mirror the structure of the existing
  `operator *` / `determinant` / `invert`, which branch on `_rest == null`.

### 6. Write the dartdoc

- One-sentence summary of the transform or operation.
- State that the result is a **new** immutable `Matrix` (for anything
  composition-like).
- For composition methods, state the **composition order** unambiguously.
- Name the `vector_math` `Matrix4` operation it corresponds to numerically, so a
  reader knows what the parity test pins. Phrase it as the numerical reference,
  not an API equivalence.
- Note any shape it canonicalizes to (e.g. "returns [identity] when `radians` is
  a multiple of 2π" only if that is actually implemented and tested — don't
  promise untested canonicalization).

### 7. Tests: unit + vector_math parity (same `dart test`)

`vector_math` is a **dev dependency** of `fast_geometry` and pure Dart, so unit
and parity tests live together in `packages/fast_geometry/test/` and run under a
plain `dart test` — there is no separate Flutter-only directory (the convenience
the path package lacks).

**Unit tests** (`test/matrix_test.dart` or a focused `test/matrix_<area>_test.dart`):

- Exercise the documented behavior and edge cases (identity inputs, zero/2π
  angles, singular matrices returning `null` from `invert`, degenerate scale).
- **Canonicalization assertions** (step 3): the result has the expected shape
  (`isSimple2d`, `_rest == null`, or `identical(result, Matrix.identity)`).
- Composition-order assertion for any `*`-based method.

**Parity tests** against `Matrix4`:

- Build the same transform with `Matrix` and `Matrix4`, then compare all 16
  entries (`m.mRC` vs `Matrix4.storage[C*4+R]`) within a documented tolerance.
- Pick tolerances by operation: exact/`1e-12` for construction and add/multiply
  of finite values; looser (`~1e-9`) after trig (`rotationZ`) or a division
  (`invert`, perspective `w`-divide). Document the chosen tolerance at the top of
  the test, as the path parity tests do.
- For geometry transforms, also compare `transformPoint(p)` against
  `Matrix4.transform3(Vector3(p.dx, p.dy, 0))` (or the 2D-projected equivalent),
  within tolerance.

A method is not done until its parity test is green.

### 8. Benchmark: required, paired against vector_math

Every public `Matrix` operation ships a benchmark — same bar as tests. Add a
`BenchmarkEntry` pair to
`packages/fast_geometry_bench/lib/src/matrix_catalog.dart` (the benchmarks live
in the separate `fast_geometry_bench` package, not in `fast_geometry`, so the
published package carries no dependency on the unpublished `bench_core`):

- **Subject** measures `Matrix`; **reference** measures the `Matrix4` equivalent.
  Both extend the file's `_LoopBench` (loops `_n` times via a monomorphic
  `step()`), and both fold their accumulated `double` into the anti-DCE `sink`
  via `doubleBits(...)`. Never leave a result unobserved — that is the exact
  dead-code-elimination defect `bench_core` was built to prevent.
- Cover the meaningful shapes for the op (identity / simple / complex), as the
  existing instantiation, multiply, add, invert, and determinant groups do.
- Operands are built once in `setup()` (or inlined in `step()` when the
  constructed shape *is* the thing being measured); never on the hot loop.
- The new pair is picked up automatically by the catalog. Verify wiring with
  `tool/bench.sh --suite=geometry --smoke`, then quote real numbers from
  `tool/bench.sh --suite=geometry` (and `--mode=aot`) in the PR. The matrix
  DCE-guard test (`test/matrix_benchmark_test.dart`) will assert your new
  benchmarks leave a non-zero sink.

The benchmark does not have to *win* on day one (several ops currently trail
`Matrix4` — that's known and is the input to the deferred optimization). It has
to *exist* so the optimization phase has a fixed target and regressions are
visible.

### 9. Update the index

- Export any new public type from `packages/fast_geometry/lib/fast_geometry.dart`
  (new methods/getters on `Matrix` need no export change).
- Add a `CHANGELOG.md` entry under the unreleased section.
- If the change affects the design narrative, update `design_docs/matrix.md`.

## Quick checklist (use before opening a PR)

- [ ] Operation returns a new immutable `Matrix` (or a value type); no setters,
      no in-place mutation.
- [ ] API designed for `Matrix`, not copied from `Matrix4`'s mutable/3D shape.
- [ ] Composition order is documented and tested.
- [ ] Results routed through lowering constructors; `Matrix._` with non-null
      `_rest` only where the result is provably general.
- [ ] Canonicalization asserted in a test (expected `isSimple2d` /
      `_rest == null` / `identical(_, identity)`).
- [ ] `mRC` ↔ `Matrix4.storage[C*4+R]` index mapping verified.
- [ ] Fast paths for `isTranslation2d` / `isSimple2d`; general path only when
      needed; perspective `w`-divide handled where applicable.
- [ ] No `dart:ffi` / `dart:io` / `dart:ui`; only the result (and its `_rest`,
      when general) is allocated.
- [ ] Dartdoc: summary, immutability, composition order, the `Matrix4` numerical
      reference.
- [ ] Unit test covers edges + canonicalization.
- [ ] Parity test vs `Matrix4` compares all 16 entries within a documented,
      operation-appropriate tolerance; green under `dart test`.
- [ ] Paired benchmark added to `matrix_catalog.dart`; both sides fold into
      `sink` via `doubleBits`; `--suite=geometry --smoke` passes; numbers quoted.
- [ ] `fast_geometry.dart` exports updated for new types; `CHANGELOG.md` updated.

## Things to escalate, not decide alone

- An operation with no sensible immutable / 2D analog of `Matrix4`'s behavior.
- A case where matching `Matrix4` numerically would require producing a
  **non-canonical** `Matrix` (breaking `==` / fast paths) — the invariant wins;
  ask how to reconcile.
- Any temptation to make `Matrix` mutable, add a setter, or expose `_rest`.
- A **representation change** (widening the inline core, changing the lowering
  rules, altering `_MatrixExtension`). This is cross-cutting — it affects every
  method and the deferred performance work in `design_docs/matrix.md`. Propose,
  don't unilaterally land.
- A numerical disagreement with `Matrix4` beyond tolerance where it's unclear
  which result is correct.
