---
name: add-path-api
description: Use whenever a method, getter, setter, constructor, or related type is being added to or changed on fast_path's PathBuilder or Path API surface, or when existing fast_path behavior is being brought closer to Flutter's dart:ui Path. Trigger on phrases like "add arcTo", "implement contains", "match Flutter's behavior for X", "this should mirror dart:ui", "expose Y on Path", "add a builder method", and on PRs that touch lib/src/path.dart, lib/src/path_builder.dart, lib/fast_path.dart's exports, or anything in the Path/PathBuilder public surface. Apply this even when the user only says "add X to Path" without naming dart:ui — behavioral parity with dart:ui.Path is the project's defining constraint and this skill enforces it across the builder/path split.
---

# Adding or extending the PathBuilder / Path API surface

`fast_path` splits `dart:ui.Path` into two classes (see
`packages/fast_path/DESIGN.md` §4.1; the `DESIGN.md` §-references throughout
this skill all point to that file):

- **`PathBuilder`** — mutable, write-optimized. All construction primitives
  (`moveTo`, `lineTo`, `cubicTo`, `addRect`, …) live here.
- **`Path`** — immutable, query-optimized. All observers (`contains`,
  `getBounds`, `computeMetrics`, …) live here. Pure transforms
  (`transform`, `shift`) and `Path.combine` return new `Path` instances.

The behavior of each operation must match `dart:ui.Path`. The *shape* —
which class hosts the method — is the deliberate divergence. Every public
method, getter, and constructor we add is *also* a performance claim:
fast_path exists to be faster than the FFI boundary, and a method we
can't measure is one we can't defend. This skill is the checklist for
making both claims safely: pick the right class, match the operation's
behavior, stay allocation-clean, no native bindings, and ship tests +
benchmarks (both sides) that prove the parity and perf claims instead
of hoping for them.

## Why this matters

Users come to `fast_path` because they already know `dart:ui.Path`. A
method that returns a slightly different empty bounds, or rounds
differently on a degenerate cubic, or treats NaN inputs differently, is
worse than not having the method at all — it's a quiet trap. The whole
value proposition collapses the moment we say "almost like Flutter's Path."

The split itself is the second invariant. Mutation on `Path` is a category
error: the type is sealed and immutable for good reasons (lazy caches with
no invalidation, cross-isolate sharing, hashable for memoization — see
DESIGN.md §5.3). A query method that lives on `PathBuilder` is a similar
mistake — it forces the builder to track caches and bump generation IDs,
which is exactly what we split it apart to avoid.

At the same time, the project's other half is *speed*: pure-Dart, no FFI,
no GC churn. New API has to honor both invariants on day one. They're
cheap to hit when the method is fresh and expensive to retrofit later.

## When this skill applies

Apply this skill when:

- Adding a new public method, getter, setter, or constructor to
  `PathBuilder` or `Path`.
- Adding a public class that participates in the API (e.g. `PathMetric`,
  `Tangent`).
- Changing an existing fast_path method's signature, behavior, or
  documented contract.
- Reviewing a PR that does any of the above.

It does **not** apply to internal refactors that don't touch the public API
or change observable behavior.

## Workflow

### 1. Find the dart:ui.Path equivalent

Before touching `lib/`, locate the corresponding member in `dart:ui.Path` (the
authoritative reference) and read three things:

- **Signature**: parameter names, types, defaults, return type.
- **Doc comment**: especially edge cases — "if the path is empty…", "NaN is
  silently ignored", "the bounds may be larger than the tightest bounds".
- **Engine implementation**, if you can find it (the Flutter engine source
  for path.cc, or Skia's SkPath). Behavior subtleties live there.

If `dart:ui.Path` has no equivalent and you're proposing a brand-new method:
**stop and ask**. Adding to the surface is a much bigger commitment than
matching what's already there. The default answer for "should we extend
beyond dart:ui?" is "not in 1.0".

### 2. Pick the right class — PathBuilder or Path

Use the dart:ui method's *role* to decide where it lands in fast_path:

| dart:ui.Path method shape | fast_path home |
| --- | --- |
| Mutates the path (`moveTo`, `lineTo`, `cubicTo`, `addRect`, `close`, `reset`, `fillType=` setter) | `PathBuilder` |
| Observes the path (`contains`, `getBounds`, `computeMetrics`, `fillType` getter) | `Path` |
| Returns a new path from existing ones (`Path.combine`, transformations) | `Path` (static or instance, returns new `Path`) |
| Constructs (`Path()`, `Path.from(other)`) | Mostly `PathBuilder()` / `PathBuilder.from(Path)`. `Path` itself is constructed via `PathBuilder.build()`. |

If a method is genuinely both — e.g. dart:ui's `Path.shift` returns a new
path but conceptually mutates a copy — we host it on `Path` because it
returns a new immutable result. Pure functions belong with the immutable
side.

When the right home is unclear, ask. Putting a query on `PathBuilder` or a
mutator on `Path` undermines the split's whole point (DESIGN.md §4.1).

### 3. Match the signature (names, order, defaults — but fast_geometry types)

Use the same parameter names, parameter order, and defaults as dart:ui's
equivalent. Dart 3 records and named arguments mean callers will write
`builder.arcToPoint(arcEnd: ..., radius: ...)`; differing names break that.

For the argument *representation*, use `fast_geometry`'s structured types
rather than dart:ui's raw engine shapes. `fast_path` is built on `fast_geometry`
and speaks its vocabulary: a 4x4 transform is a `Matrix`, **not** a
`Float64List matrix4` (callers holding engine / `Matrix4` data bridge with the
`Float64List.toMatrix()` extension). Points and rects are `Offset` and `Rect`
for the same reason. The transform's *behavior* still matches dart:ui exactly —
only the argument type is the library's own.

There are thus two deliberate shape divergences from dart:ui. The first is the
receiver: `dart:ui.Path.lineTo(...)` becomes `PathBuilder.lineTo(...)` on our
side. The second is argument representation (`Matrix`/`Offset`/`Rect` over raw
engine types). Document both explicitly in the dartdoc (see step 6) so users
porting code know what to substitute.

If a fast_path-specific helper genuinely improves DX, expose it as an
**extension method** in a separate library, not as a method on
`PathBuilder` or `Path`.

### 4. Honor the engine's edge-case behavior

`dart:ui.Path` has a number of "documented but quiet" behaviors. These are
parity bugs in waiting. The split doesn't change which behaviors must
match; it only changes which class hosts the matching code (mutation
edge-cases land on `PathBuilder`, query edge-cases land on `Path`).
Common ones:

- Empty path: `Path.getBounds()` returns `Rect.zero`, not "throws".
- NaN / infinite inputs to builder methods: `dart:ui.Path` typically
  silently ignores or clamps. Match that on `PathBuilder`. Document it.
- `PathBuilder.close()` on an already-closed contour: idempotent, not an
  error.
- `PathBuilder.relative*` on a builder with no current point: dart:ui
  documents starting from `Offset.zero`. Implement that, not "throw".
- `PathBuilder.addPath` / `extendWithPath`: parameter order, matrix
  application, and whether the segment is connected all matter.
- `Path.contains` on a degenerate (zero-length, single-point) path:
  match dart:ui's behavior, which is typically "not contained".

When in doubt, write a tiny Flutter program (or a one-off test in the
`fast_path_conformance` package), observe the *actual* behavior, and pin it
down before implementing — ideally as an oracle test that asserts what
`dart:ui` does, so a future engine change trips a red test instead of silently
diverging your implementation.

Beware that `dart:ui`'s behavior is a **moving target**: it changes across
Flutter versions and channels, so a behavior you verify on `master` may not yet
be in `stable` (or vice versa). Record which engine you observed, and see §7 on
keeping the parity test itself robust to that drift.

### 5. Implement on the verb/point buffer (no native bindings)

Implementation rules, in priority order:

1. **No `dart:ffi`, no `dart:io`, no `dart:ui` imports in `lib/`.** This is
   non-negotiable — the package has to run on plain Dart VMs.
2. **Builder methods append to the verb/point buffers directly.** Most
   are 5-10 lines: append a verb byte to `_verbs`, write points into
   `_points`, update `_lastMoveToIndex`. No cache invalidation work —
   the builder doesn't carry caches (DESIGN.md §5.2).
3. **Path methods read the verb/point buffers, never write.** `Path`'s
   buffers are sealed by `build()`; treat them as `final` even though
   Dart can't enforce that on `Float32List` elements. If you find
   yourself wanting to mutate a `Path`, you actually want a
   `PathBuilder.from(path)` somewhere upstream.
4. **No allocations in the hot path.** A `PathBuilder.lineTo` should not
   allocate an `Offset` or a `List`. Take `(double, double)` internally;
   the public API wraps that. A `Path.contains` query likewise should
   not allocate per call.
5. **Cache derived data on `Path` lazily.** First `getBounds()` computes
   and stores; subsequent calls return the cached value. No `_genId`,
   no invalidation guard — the path is immutable, so the cache is
   trivially correct forever.
6. **Reuse scratch buffers across calls.** If an algorithm needs scratch
   space (curve flattening, intersection), keep it as a private field
   on `Path` (computed once, reused) or pass it as a function argument
   from the caller. Don't `Float32List(n)` per call.
7. **Prefer `switch` over the verb enum** to virtual dispatch. The JIT
   and AOT both produce tight code for switches on small `int` ranges.

If the algorithm is non-trivial (curve flattening, contains, combine), this
is also a port from Skia — use the `port-from-skia` skill in tandem.

### 6. Write the dartdoc

Public members get a doc comment. The comment should:

- Summarize what the method does in one sentence.
- Name the dart:ui equivalent and cross-reference it. Phrase it like:
  "Behaves identically to [`Path.arcTo`] in `dart:ui`, except that this
  method lives on [PathBuilder] rather than `Path` (see the package README
  on the Builder/Path split)." This is the one place users porting code
  will look to find out what changed.
- Spell out any edge case the engine has — empty path, NaN, ignored
  verbs. These are the parity claims; if they're documented, they're
  testable.
- Not promise behaviors we haven't tested. If we haven't run a parity
  test yet, the doc says "intended to mirror" rather than "mirrors".

### 7. Tests: unit + parity

Two test files, both required for the PR:

**Unit test** (`test/path_<area>_test.dart`):

- Build a path with `PathBuilder`, call `build()`, then call the new
  method (on the builder pre-build, or on the path post-build, depending
  which class hosts it). Assert observable state.
- Cover the documented edge cases: empty path, NaN, redundant calls,
  large inputs.
- These run under `dart test` with no Flutter dependency.

**Parity test** (in the **`fast_path_conformance` package**, under
`packages/fast_path_conformance/test/parity/`):

- Parity tests live in a *separate, Flutter-only package* — the one place in
  the repo that imports `dart:ui`. (The core `fast_path` package never does, so
  a plain `dart test` there has no parity tests to skip.) Most cases extend the
  existing `path_parity_test.dart` harness (`PathTarget`, `_buildFp`,
  `_buildUi`), which replays one call sequence on both sides.
- For each test case: replay the *same call sequence* on a
  `fast_path.PathBuilder` and on a `ui.Path`, then compare observable outputs of
  the resulting `fast_path.Path` (after `build()`) against the `ui.Path`:
  `getBounds`, `contains` over a sample grid, `computeMetrics().length`, etc.
- Tolerances are documented at the top of the file: `getBounds` to 1e-4 abs /
  1e-6 rel; `contains` exact except in an epsilon band around the curve;
  lengths to 1e-4.
- Runs only under `flutter test`.

A change is not done until the parity test for the affected behavior is
green — **on CI's engine, not just yours** (see below).

**Parity is a moving target — assert only channel-stable behavior.** CI runs
Flutter `stable`; contributors may run `master`. When `dart:ui`'s behavior for
a case differs across channels (it does — e.g. degenerate conic weights), a
parity test that hardcodes one channel's answer passes locally and fails on the
other. So:

- A `dart:ui` parity test may assert only behavior that is the *same on every
  channel we run*. Confirm the case on `stable` (CI), not just your local
  engine.
- Pin genuinely channel-sensitive behavior with a **channel-independent unit
  test** in the core package instead — one that exercises fast_path *alone*
  (assert the built path's structure, or `contains`), with no `dart:ui`
  comparison. It passes on any channel. Document the channel you targeted and
  the divergence in the method's dartdoc.

**Region/area-producing ops** (`Path.combine`; future simplify / stroke). The
output is a filled *region*, not a fixed verb structure, so parity is
*containment sampling*, not output identity: compare `fp.contains == ui.contains`
over a grid, **skipping points near either result's boundary** (where
polygon-vs-curve approximation and on-edge tie-breaks make disagreement
inherent). Detect "near a boundary" by perturbing the sample and checking
`ui.contains` is stable — perturb in **8 directions including diagonals**,
because a point exactly on an axis-aligned edge stays on it under axis-aligned
perturbation and only the diagonals catch the tie. Guard against a vacuous pass
(assert at least one stable point was actually compared).

### 8. Update the index

Add new top-level types to `lib/fast_path.dart`'s exports. Add an entry to
`CHANGELOG.md` under the unreleased section. If the change touches the
architecture (e.g. moves a method from `PathBuilder` to `Path` or vice
versa), update `DESIGN.md`.

### 9. Benchmarks: required, both sides

Every public `PathBuilder` / `Path` operation ships with at least one
benchmark — non-negotiable, same bar as tests. "It's not on the hot path"
is not an escape hatch: the project's whole pitch is performance, and a
method without a benchmark is a method whose perf claim is unmeasured.
Two files, both required for the PR:

**fast_path benchmark**
(`packages/fast_path_bench/lib/src/<area>.dart`, registered in
`packages/fast_path_bench/lib/benchmarks.dart`):

- Extends `FastPathBenchmark` (provides single-call `exercise()`,
  `opsPerRun` normalization, and the `sink` blackhole for defeating
  dead-code elimination — use it).
- Workload is realistic, not synthetic. A 1k-segment polyline, a
  1024-point hit-test grid, a 1000-call cached query loop — pick a
  shape that mirrors how the method will actually be called.
- Result is XOR-ed into `sink` so the JIT / AOT compiler cannot prove
  the work is dead.

**dart:ui counterpart benchmark**
(`packages/fast_path_bench_flutter/lib/src/ui_benchmarks.dart`):

- Mirrors the fast_path workload as closely as `dart:ui.Path`'s shape
  allows (one object that's both builder and path, no separate `build()`
  step, etc.). Document any unavoidable asymmetry inline.
- Extends the same `FastPathBenchmark` base so the runner is uniform.
- Picked up automatically by `tool/bench.sh --mode=flutter-desktop`
  (Linux/macOS AOT with real `dart:ui`) and the web "Run benchmarks"
  button.

The benchmarks don't have to *win* on day one. They have to *exist* so
regressions are visible. Run `tool/bench.sh` and `tool/bench.sh --mode=aot`
locally and quote the numbers in the PR description; if a number looks
wrong, dig in before merging.

## Quick checklist (use before opening a PR)

- [ ] Method lives on the right class — `PathBuilder` for mutation,
      `Path` for queries and pure transforms.
- [ ] `dart:ui.Path`'s equivalent has the same signature — parameter
      names, order, defaults — modulo the receiver class.
- [ ] Argument types use `fast_geometry`'s structured types (e.g. `Matrix`,
      not `Float64List matrix4`; `Offset` / `Rect` for points and rects),
      while parameter names, order, and defaults still match dart:ui.
- [ ] Documented edge cases (empty path, NaN, redundant calls) are
      matched.
- [ ] No `dart:ffi`, `dart:io`, or `dart:ui` import in `lib/`.
- [ ] No allocations in the hot path. Builder methods append in place;
      query methods read in place.
- [ ] If new state was added to `Path`: it's `final`, populated only by
      `PathBuilder.build()` or by another `Path` method that returns a
      new `Path`.
- [ ] If a query needs caching: lazy field on `Path`, no `_genId`, no
      invalidation guard.
- [ ] Dartdoc cross-references the dart:ui equivalent, calls out the
      receiver-class change, and lists edge cases.
- [ ] Unit test covers documented edges.
- [ ] Parity test in `packages/fast_path_conformance/test/parity/` replays the
      same call sequence on `PathBuilder` + `Path` and on `ui.Path`, and is
      green under `flutter test` — and asserts only channel-stable behavior
      (channel-sensitive cases pinned by a core-package unit test instead).
- [ ] `CHANGELOG.md` updated; `DESIGN.md` updated if architecture moved.
- [ ] Benchmark added in `packages/fast_path_bench/lib/src/` and
      registered in `packages/fast_path_bench/lib/benchmarks.dart`.
- [ ] `dart:ui` counterpart benchmark added in
      `packages/fast_path_bench_flutter/lib/src/ui_benchmarks.dart`
      (skip only if the operation has no `dart:ui.Path` equivalent — in
      which case it should have been escalated at step 1).
- [ ] Both benchmarks observe their result via `sink` (XOR pattern) so
      the JIT / AOT compiler cannot dead-code-eliminate the work.
- [ ] Local `tool/bench.sh` and `tool/bench.sh --mode=aot` runs quoted
      in the PR description.

## Things to escalate to the human, not decide alone

- A proposed addition that has no `dart:ui.Path` equivalent.
- A behavior where `dart:ui.Path` itself is buggy or undocumented and we'd
  need to pick a behavior.
- A case where matching dart:ui would force `fast_path` to allocate or use
  an algorithm that doesn't fit the verb/point buffer representation.
- A method that genuinely seems like it should mutate a `Path` rather
  than return a new one. The split is load-bearing; ask before bending it.
- Any change that would require importing `dart:ui` from `lib/`.
