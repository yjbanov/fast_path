# fast_2d

A family of fast, pure-Dart 2D libraries — geometry, transforms, and paths that
run entirely on the Dart heap, with no native bindings. See [README.md](README.md)
for the package overview; `fast_path`'s full design rationale is in
[packages/fast_path/DESIGN.md](packages/fast_path/DESIGN.md).

**The rules that apply depend on which package you are touching.** "fast_path"
is one package here, not the whole repo — don't apply its `dart:ui`-parity
contract to `fast_geometry`, which answers to a different oracle.

## Repo layout

```
packages/
  fast_path/                 Core path library — pure Dart, published to pub.dev
  fast_geometry/             Geometry + immutable Matrix transform — pure Dart, published
  fast_path_conformance/     Parity tests against dart:ui — Flutter only, not published
  fast_path_flutter/         Future Flutter bridge — not yet implemented
  bench_core/                Shared benchmark harness (subject/reference pairs, JSON)
  fast_path_bench/           Pure-Dart path benchmarks (JIT + AOT-native runners)
  fast_path_bench_flutter/   Flutter-hosted path benchmarks (desktop AOT + manual web)
skills/
  add-path-api/              Checklist for adding/changing PathBuilder or Path API
  add-matrix-api/            Checklist for adding/changing fast_geometry's Matrix API
  port-from-skia/            Checklist for porting algorithms from Skia/Flutter
                             (and other permissive third-party references)
design_docs/                 Cross-package design notes (matrix, bench, fast_geometry)
```

This is a Dart workspace (root `pubspec.yaml` lists the members). `tool/check.sh`
mirrors CI; `tool/bench.sh --suite=path|geometry` runs the benchmark suites.

## Hard rules

Non-negotiable. If a rule seems impossible for a task, stop and ask rather than
bend it.

### Every pure-Dart library (`fast_path`, `fast_geometry`, `bench_core`)

- **No native bindings in `lib/`.** No `dart:ffi`, `dart:io`, or `dart:ui`
  imports — these packages must run on plain Dart VMs. `dart:ui` is allowed only
  in the Flutter-only packages (`fast_path_conformance`, `fast_path_bench_flutter`,
  the future `fast_path_flutter`).
- **Every public method ships with tests and a benchmark** before it is "done."
  Performance is the pitch, so an operation that can't be measured can't be
  defended. The *kind* of test and benchmark differs per package (below).
- **Be allocation-conscious on hot paths.** Don't allocate per call in inner
  loops; reuse buffers and inline scalars.

### `fast_path`

- **Mutation lives on `PathBuilder`. Queries live on `Path`.** `Path` is
  immutable — never add a mutating method to it; never add a query method or
  derived cache to `PathBuilder`. The split is load-bearing; see
  `packages/fast_path/DESIGN.md` §4.1.
- **Parity with `dart:ui.Path` is the contract.** Every public method on
  `PathBuilder`/`Path` is a behavioral parity claim. When the correct behavior
  is unclear, observe actual `dart:ui.Path` behavior and pin it in a parity test
  before implementing. "Almost like Flutter's Path" is not acceptable.
- **Use `fast_geometry` types in the signature**, not raw engine shapes — a
  transform argument is a `Matrix`, not a `Float64List` (see `add-path-api` §3).
  Names, order, and defaults still track `dart:ui`.
- **No per-call allocations.** Builder methods append to `Uint8List`/`Float32List`
  buffers in place; query methods read them in place. No `Offset`/`List` per call.
- **Parity test required** in `packages/fast_path_conformance/test/parity/`
  (replays the same call sequence on `fast_path` and `dart:ui.Path`, within the
  tolerances in `packages/fast_path/DESIGN.md` §8.2), **plus** a benchmark in
  `packages/fast_path_bench/lib/src/` and a `dart:ui` counterpart in
  `packages/fast_path_bench_flutter/lib/src/ui_benchmarks.dart`. See
  `skills/add-path-api/SKILL.md`.

### `fast_geometry`

- **`Matrix` is deeply immutable.** Every "mutating" operation returns a new
  instance; no setters.
- **`package:vector_math`'s `Matrix4` is a correctness *oracle*, not an API
  contract.** Validate that `Matrix` produces the same numbers for the same
  transform — but design the API for our immutable, 2D-first type; do not copy
  `Matrix4`'s mutable/3D signatures.
- **The canonical-lowering representation is load-bearing.** Every result must
  be produced in its most-specific shape, or `==`/`hashCode` and the
  `isSimple2d`/`isTranslation2d` fast paths break. Representation changes are
  cross-cutting — propose, don't land unilaterally.
- **Unit + `vector_math` parity tests** (both run under a plain `dart test`,
  since `vector_math` is a pure-Dart dev dep) **plus a paired benchmark** in
  `packages/fast_geometry/benchmark/src/matrix_catalog.dart` (subject vs
  `Matrix4`, folded into the anti-DCE sink). See `skills/add-matrix-api/SKILL.md`.

### `bench_core`

- **Domain-agnostic.** Depends only on `benchmark_harness`; never on `fast_path`,
  `fast_geometry`, `vector_math`, or `dart:ui`. It knows how to measure,
  normalize, blackhole, pair, and report — nothing about paths or matrices.

## Skills

Read and follow the appropriate skill before starting:

- Adding/changing `PathBuilder` or `Path` → `skills/add-path-api/SKILL.md`
- Adding/changing `fast_geometry`'s `Matrix` → `skills/add-matrix-api/SKILL.md`
- Porting an algorithm from Skia, the Flutter engine, or any permissive
  third-party reference → `skills/port-from-skia/SKILL.md`

## Escalate, don't decide alone

Raise these rather than resolving them unilaterally:

- **fast_path:** an addition with no `dart:ui.Path` equivalent; a behavior where
  `dart:ui.Path` is itself buggy/undocumented; anything needing `dart:ui` inside
  `lib/`; a method that seems like it should mutate a `Path`; a Skia port that
  contradicts `dart:ui.Path`.
- **fast_geometry:** an operation with no sensible immutable/2D analog; a case
  where matching `Matrix4` numerically would force a non-canonical `Matrix`; any
  change to the representation (`_MatrixExtension`, the inline core, lowering).
