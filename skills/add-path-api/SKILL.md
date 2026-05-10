---
name: add-path-api
description: Use whenever a method, getter, setter, constructor, or related type is being added to or changed on fast_path's Path API surface, or when an existing fast_path API is being brought closer to Flutter's dart:ui Path. Trigger on phrases like "add Path.arcTo", "implement contains", "match Flutter's behavior for X", "this should mirror dart:ui", "expose Y on Path", and on PRs that touch lib/src/path.dart, lib/fast_path.dart's exports, or anything in the Path public surface. Apply this even when the user only says "add X to Path" without naming dart:ui — Path parity is the project's defining constraint and this skill enforces it.
---

# Adding or extending the Path API surface

`fast_path`'s Path is meaningful only insofar as it behaves like
`dart:ui.Path`. Every public method, getter, and constructor we add is a
parity claim. This skill is the checklist for making that claim safely:
matching shape, matching behavior, allocation-clean, no native bindings, and
covered by tests that prove the parity claim instead of just hoping for it.

## Why this matters

Users come to `fast_path` because they already know `dart:ui.Path`. A method
that takes the wrong argument order, returns a slightly different empty
bounds, or rounds differently on a degenerate cubic is worse than not having
the method at all — it's a quiet trap. The whole value proposition collapses
the moment we say "almost like Flutter's Path."

At the same time, the project's other half is *speed*: pure-Dart, no FFI, no
GC churn. New API has to honor both invariants on day one. They're cheap to
hit when the method is fresh and expensive to retrofit later.

## When this skill applies

Apply this skill when:

- Adding a new public method, getter, setter, or constructor to `Path`.
- Adding a public class that participates in the Path API (e.g.
  `PathMetric`, `Tangent`).
- Changing an existing fast_path Path method's signature, behavior, or
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

### 2. Match the signature exactly

Use the same parameter names, the same parameter order, and the same
defaults. Dart 3 records and named arguments mean callers will write
`p.arcToPoint(arcEnd: ..., radius: ...)`; differing names break that.

If `dart:ui.Path` takes `Float64List matrix4`, take `Float64List matrix4`.
Don't "improve" it to `Matrix4` — users who already work with engine code
expect the engine shape.

If a fast_path-specific helper genuinely improves DX, expose it as an
**extension method** in a separate library, not as a method on `Path`.

### 3. Honor the engine's edge-case behavior

`dart:ui.Path` has a number of "documented but quiet" behaviors. These are
parity bugs in waiting. Common ones to think about:

- Empty path: `getBounds()` returns `Rect.zero`, not "throws".
- NaN / infinite inputs: `dart:ui.Path` typically silently ignores or
  clamps. Match that. Document it.
- `close()` on an already-closed contour: idempotent, not an error.
- `relative*` methods on a path with no current point: documented as starting
  from `Offset.zero`. Implement that, not "throw".
- `addPath` / `extendWithPath`: parameter order, matrix application, and
  whether the segment is connected matter.

When in doubt, write a tiny Flutter test program, observe the actual
behavior, and pin it down in a parity test before implementing.

### 4. Implement on the verb/point buffer (no native bindings)

Implementation rules, in priority order:

1. **No `dart:ffi`, no `dart:io`, no `dart:ui` imports in `lib/`.** This is
   non-negotiable — the package has to run on plain Dart VMs.
2. **Mutate the verb and point buffers directly.** Most builder methods
   (`lineTo`, `cubicTo`, `addRect`) are 5-10 lines: append a verb byte, write
   the points into `_points`, update `_lastMoveToIndex`, bump `_genId`.
3. **No allocations in the hot path.** A `lineTo` should not allocate an
   `Offset` or a `List`. Take `(double, double)` internally; the public API
   wraps that.
4. **Invalidate cached state.** Bump `_genId`. Clear `_cachedBounds`. Reset
   `_isConvex` to `unknown`. Iterators outliving the mutation should detect
   the bump and throw, matching `dart:ui` behavior.
5. **Reuse buffers across calls.** If the algorithm needs scratch space
   (e.g. flattening), allocate it once on `Path` and reuse, or pass it down
   as a function argument from the caller.
6. **Prefer `switch` over the verb enum** to virtual dispatch. The JIT and
   AOT both produce tight code for switches on small `int` ranges.

If the algorithm is non-trivial (curve flattening, contains, combine), this
is also a port from Skia — use the `port-from-skia` skill in tandem.

### 5. Write the dartdoc

Public members get a doc comment. The comment should:

- Summarize what the method does in one sentence.
- Cross-reference the `dart:ui.Path` equivalent so users know they can rely
  on parity. Phrase it like: "Behaves identically to [`Path.arcTo`] in
  `dart:ui` (modulo the floating-point tolerances documented in the
  package README)."
- Spell out any edge case the engine has — empty path, NaN, ignored verbs.
  These are the parity claims; if they're documented, they're testable.
- Not promise behaviors we haven't tested. If we haven't run a parity test
  yet, the doc says "intended to mirror" rather than "mirrors".

### 6. Tests: unit + parity

Two test files, both required for the PR:

**Unit test** (`test/path_<area>_test.dart`):

- Construct the path, call the new method, assert observable state.
- Cover the documented edge cases: empty path, NaN, redundant calls, large
  inputs.
- These run under `dart test` with no Flutter dependency.

**Parity test** (`test/parity/path_<area>_parity_test.dart`):

- Imports `dart:ui` (this directory is the only place in the repo that may).
- For each test case: build the same input on `fast_path.Path` and on
  `ui.Path`, then compare observable outputs (`getBounds`, `contains` over
  a sample grid, `computeMetrics().length`, etc.).
- Tolerances are documented at the top of the file. `getBounds` agreement
  to 1e-4 absolute / 1e-6 relative; `contains` exact except in an
  epsilon-band around the curve; lengths to 1e-4.
- Runs only under `flutter test` (the file should be guarded so a plain
  `dart test` ignores it cleanly — typically by living under
  `test/parity/` and being excluded by `dart_test.yaml`).

A change is not done until the parity test for the affected behavior is
green.

### 7. Update the index

Add the new symbol to `lib/fast_path.dart`'s exports if it's a new top-level
type. Add an entry to `CHANGELOG.md` under the unreleased section. If the
change touches the architecture, update `DESIGN.md`.

### 8. Benchmark anything in the hot path

If the new method is plausibly called in a tight loop (`lineTo`, `cubicTo`,
`contains`, builder methods on every frame), add a benchmark under
`benchmark/` that compares against `dart:ui.Path` for the same workload. The
benchmark doesn't have to win on day one; it has to exist, so we notice
regressions later.

## Quick checklist (use before opening a PR)

- [ ] `dart:ui.Path` has the same signature — name, parameter order, defaults.
- [ ] Parameter types match dart:ui (e.g. `Float64List` not `Matrix4`).
- [ ] Documented edge cases (empty path, NaN, redundant calls) are matched.
- [ ] No `dart:ffi`, `dart:io`, or `dart:ui` import in `lib/`.
- [ ] No allocations in the hot path; verb/point buffers are mutated in place.
- [ ] `_genId` bumped, `_cachedBounds` cleared, `_isConvex` reset on mutation.
- [ ] Dartdoc cross-references the dart:ui equivalent and lists edge cases.
- [ ] Unit test covers documented edges.
- [ ] Parity test under `test/parity/` covers the dart:ui-equivalent
      behavior and is green under `flutter test`.
- [ ] `CHANGELOG.md` updated; `DESIGN.md` updated if architecture moved.
- [ ] If on the hot path: benchmark added under `benchmark/`.

## Things to escalate to the human, not decide alone

- A proposed addition that has no `dart:ui.Path` equivalent.
- A behavior where `dart:ui.Path` itself is buggy or undocumented and we'd
  need to pick a behavior.
- A case where matching dart:ui would force `fast_path` to allocate or use
  an algorithm that doesn't fit the verb/point buffer representation.
- Any change that would require importing `dart:ui` from `lib/`.
