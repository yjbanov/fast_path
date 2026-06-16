# Path Boolean Operations (`Path.combine`) — M4

This document scopes M4 of the `fast_path` roadmap (`packages/fast_path/DESIGN.md`
§10): `Path.combine`, the four/five boolean set operations over paths. It is the
riskiest surface in the library, so this scope deliberately phases the work and
picks the lowest-risk route to a shippable, parity-gated `combine` first.

Status: Approved scope. M4a not yet started.
Last updated: 2026-06-13.

## 1. The public surface

The surface is tiny; the implementation is the entire milestone.

```dart
/// Set-operation selector for [Path.combine]. Mirrors `dart:ui.PathOperation`.
enum PathOperation {
  /// Subtract the second path from the first.
  difference,
  /// Intersection — the region covered by both paths.
  intersect,
  /// Union — the region covered by either path.
  union,
  /// Exclusive-or — the region covered by exactly one path.
  xor,
  /// Subtract the first path from the second.
  reverseDifference,
}

// On Path (static, returns a new immutable Path — a pure function):
static Path combine(PathOperation op, Path a, Path b);
```

`dart:ui` exposes `Path.combine(PathOperation, Path, Path)` and the full
five-value `PathOperation` enum (including `reverseDifference`). We match the
names, order, and the receiver split (it lands on the immutable `Path` as a
pure function — see `packages/fast_path/DESIGN.md` §4.1 and the `add-path-api`
skill).

`PathOperation` is a new public enum: it goes in its own file
(`lib/src/path_operation.dart`), is exported from `lib/fast_path.dart`, and —
like `PathFillType` — carries no `fast_geometry` dependency.

## 2. Why this is the riskiest milestone

Boolean ops over Béziers are the hardest algorithm a 2D path library contains.
Skia's `src/pathops/` is ~15k lines of subtle C++. The genuinely hard parts:

1. **Curve–curve intersection.** Finding every crossing parameter `t` between
   two segments, for *every* curve-type pair (line/line, line/quad, line/conic,
   line/cubic, quad/quad, quad/conic, …, cubic/cubic). Skia spreads this across
   `SkIntersections`, `SkDLine`, `SkDQuad`, `SkDConic`, `SkDCubic`. This is the
   most numerically delicate code in the system and the place where our f32
   storage (DESIGN.md §5.1) is most likely to diverge from `dart:ui`.
2. **Coincident edges.** Overlapping collinear or identical segments need
   special winding bookkeeping (`SkOpCoincidence`). This is exactly where naive
   textbook clippers (Greiner–Hormann) fall over.
3. **Winding resolution + the walk.** After every segment is split at its
   intersections, decide which pieces belong in the output for the chosen
   operation, then re-assemble closed output contours.

A faithful full port is multi-session and divergence-prone. We do **not** start
there.

## 3. The lever: the parity gate is sampling-based, not output-identical

The contract that makes a phased approach legitimate is in DESIGN.md §8.2:

> `combine()` checked by sampling:
> `inside_combined(p) == op(inside_a(p), inside_b(p))`.

`dart:ui` *preserves curves* in its combined output. But our parity gate does
**not** assert curve-for-curve output identity — it asserts **containment
agreement** at sampled points: "is `p` inside `a ∪ b`?" must match between
`fast_path` and `dart:ui`, within tolerance.

That single fact means a **flattened, polygonal output can pass the gate.** We
do not need the Skia intersection engine to ship a correct-by-the-gate
`combine`. We need:

- curves flattened to polylines within a tolerance tighter than the parity
  sampling epsilon, and
- a robust *polygon* boolean that gets winding and coincidence right.

This is the same kind of documented divergence we already ship for
`PathMetric.extractPath` (flattened polyline output; `dart:ui` keeps curves;
lengths/containment still match — CHANGELOG M3).

## 4. Phasing

### M4a — Polygonal MVP (this milestone)

Ship a working, parity-gated `Path.combine` for all five operations with
**polygonal output**.

Pipeline:

1. **Flatten** each input `Path`'s contours to closed polygons, reusing the
   existing adaptive-subdivision flattener that already backs `computeMetrics`
   / `extractPath` (rational de Casteljau for conics included). Flatness
   threshold chosen tighter than the parity sampling epsilon so flattening
   error cannot flip a containment sample.
2. **Polygon boolean** via the **Martinez–Rueda–Feito** sweep-line algorithm
   (a.k.a. "Martinez clipping"). It handles all of union, intersection,
   difference, xor, and reverse-difference in one framework, is robust to
   coincident edges and self-intersection, and runs in `O((n+k) log n)`.
   Chosen over:
   - **Greiner–Hormann** — simpler but undefined on coincident/overlapping
     edges and degenerate crossings; exactly our hard cases.
   - **Vatti / Clipper** — battle-tested but a larger, heavier port, and
     Clipper's well-known implementation is non-permissively encumbered in
     some forms; Martinez is cleanly describable from the published paper.
3. **Assemble** the result polygons into a `PathBuilder` (moveTo + lineTo +
   close per output contour), set the fill type, `build()`.

Provenance note: Martinez–Rueda is **clean-room from the published paper**
("A new algorithm for computing Boolean operations on polygons", Martinez,
Rueda, Feito, 2009), *not* a Skia port — so the `port-from-skia` skill does
not govern M4a (no upstream header to carry). If we instead lift a specific
open-source implementation, it must be BSD/MIT/Apache and carry that file's
header per `port-from-skia` §2–§3.

Output is **polygonal** — a documented divergence from `dart:ui` (which
preserves curves). Documented in the `combine` dartdoc and the CHANGELOG, the
same way `extractPath` is.

Fill-type handling (empirically pinned by the §7.0 probe — see the
`combine_oracle_test.dart` regression test):

- **Each input is resolved to its filled region under its *own* `fillType`
  before the op.** Verified: a path of two stacked identical rects unions to
  the region under `nonZero` but to **empty** under `evenOdd` (the doubled
  region cancels). M4a must therefore evaluate each input's coverage under its
  own fill rule when flattening, not assume `nonZero`.
- **The result is always emitted as `PathFillType.evenOdd`** — every op, every
  input, unconditionally (matches Skia PathOps, which returns evenOdd
  non-overlapping contours). This *simplifies* M4a: output winding *direction*
  is irrelevant, because under evenOdd a hole is just a separate boundary
  contour (e.g. `difference(big, small-inside)` → an outer contour + an inner
  hole contour, `contains(center) == false`). We emit the correct set of
  boundary loops and tag the `Path` `evenOdd`.
- **Self-intersecting inputs are pre-resolved** under the input fill rule (a
  bowtie resolves into its two lobes before combining).

### M4b — Curve-preserving output (deferred, separately scoped)

Later, behind the *same* sampling gate, replace the polygonal core with a
curve-preserving implementation by porting Skia's intersection engine +
`SkOpBuilder` walk. This is where `port-from-skia` governs in full (pinned SHA,
upstream headers, structural fidelity, coincidence handling). Not scoped here;
revisit only when a real workload needs curves preserved through a boolean op.
The M4a public API (`PathOperation`, `Path.combine`) is unchanged by M4b — only
the output fidelity improves — so M4a is not throwaway.

## 5. Testing

Per the `add-path-api` skill, every public method ships unit + parity tests.
For `combine` the parity layer is the load-bearing one.

### 5.1 Unit tests (`test/combine_test.dart`, plain `dart test`)

Algebraic identities and edge cases that need no `dart:ui`:

- **Identities:** `union(a, a) ≈ a`; `intersect(a, a) ≈ a`;
  `intersect(a, empty) == empty`; `union(a, empty) ≈ a`;
  `difference(a, a) == empty`; `difference(a, empty) ≈ a`;
  `xor(a, a) == empty`.
- **Symmetry / antisymmetry:** `union`/`intersect`/`xor` commute under sampling;
  `difference(a, b) == reverseDifference(b, a)`.
- **Edge cases:** empty ⊕ empty; disjoint inputs (union = both contours,
  intersect = empty); one fully inside the other (all five ops); shared edge
  (coincident-edge regression); touching at a point.
- **Sampling helper:** identities are checked by sampling `contains` on a grid,
  not by structural `==` (polygonal output won't be structurally equal to a
  curved input).

### 5.2 Parity tests (`packages/fast_path_conformance/test/parity/`, Flutter)

The gate. Lands in the conformance package alongside the existing
`path_parity_test.dart` (per CLAUDE.md, that directory is the repo's single home
for `dart:ui` parity tests). For each `(op, a, b)` case, build `a` and `b` on both `fast_path` and
`dart:ui`, run `combine` on both, and assert:

- **Containment grid:** `fp.contains(p) == ui.contains(p)` over a sample grid,
  except within an epsilon band of either boundary (ties are inherent).
- **Bounds:** `getBounds` agreement within DESIGN.md §8.2 tolerances
  (1e-4 abs / 1e-6 rel) — loose, since flattening only shrinks/inflates by
  sub-epsilon.
- **Generated corpus:** the deterministic PRNG path generator (DESIGN.md §8.2)
  emits pairs with a configurable verb mix and degeneracies; failures shrink
  via the existing minimizer. This is where coincidence / near-tangency bugs
  surface.

A parity probe (`flutter test` one-off) first pins `dart:ui`'s actual result
fill type and its handling of the degenerate cases above, so we match observed
engine behavior rather than assumed behavior.

### 5.3 Property tests

Fold into the unit suite: the §5.1 identities, plus
`combine(op,a,b).getBounds()` ⊆ `a.getBounds() ∪ b.getBounds()` (a boolean
result never exceeds the inputs' combined bounds).

## 6. Benchmarks (both sides, per `add-path-api` §9)

- **fast_path:** `packages/fast_path_bench/lib/src/combine.dart` — e.g.
  `combine_union_organic`, intersect/difference/xor on two ~organic curved
  paths (overlapping ovals / rounded rects), registered in
  `benchmarks.dart`, result folded into `sink`.
- **dart:ui counterpart:** mirror in
  `packages/fast_path_bench_flutter/lib/src/ui_benchmarks.dart`.

Expectation-setting: DESIGN.md §3 explicitly does *not* target beating Skia on
boolean ops over cubics. The benchmark exists so regressions are visible and so
we know our standing; M4a being polygonal, it may well *win* on simple cases
(no curve-intersection engine to run) and we document that it's not
curve-preserving.

## 7. Work plan (M4a)

0. **Parity probe** — ✅ done. Findings folded into §4 and §8 and pinned as
   regression assertions in
   `packages/fast_path_conformance/test/parity/combine_oracle_test.dart`.
1. ✅ done (commit `e660364`). `PathOperation` enum + export + dartdoc
   (cross-references `dart:ui`).
2. ✅ done (commit `e660364`). Contour-flattening helper (`Path._flattenForOps`)
   reusing the metrics flattener; closed-polygon extraction (no duplicated
   closing vertex, arealess contours dropped) at the metric flatness tolerance.
3. ✅ done (commit `ce86ebe`). Martinez–Rueda sweep in `lib/src/martinez.dart`:
   binary-heap event queue, sorted-list sweep-line, edge labeling, all four
   primitive ops from one labeled subdivision (clean-room from the 2009 paper,
   attribution-preserving adaptation of the MIT w8r/martinez reference).
4. Output assembly into `PathBuilder` → `Path`; result fill type per the probe.
5. `Path.combine` wiring; empty/degenerate short-circuits.
6. Unit tests (§5.1), then parity tests + generated corpus (§5.2) until green.
7. Benchmarks both sides (§6); run `tool/bench.sh` + `--mode=aot`, quote numbers.
8. CHANGELOG (`### Added` M4 + the documented polygonal-output divergence);
   flip DESIGN.md §6.4 and §10 M4 from "deferred" to "M4a done, M4b deferred".

## 8. Resolved by the §7.0 probe

- **Result fill type — RESOLVED: always `evenOdd`.** `dart:ui` emits every
  combine result as `PathFillType.evenOdd`, unconditionally. M4a tags its
  output `evenOdd` and need not track output winding direction (holes are just
  separate boundary contours under evenOdd).
- **Input fill type — RESOLVED: honored per input.** Each input is resolved to
  its filled region under its own `fillType` before the op (an `evenOdd`
  double-covered region reads as empty). M4a's flattener must respect each
  input's fill rule when determining coverage.
- **Self-intersecting inputs — RESOLVED: pre-resolved per input fill rule.**
  Martinez naturally produces the same resolution; no special handling beyond
  feeding the flattened, fill-rule-resolved coverage in.
- **Degenerate output — RESOLVED (gate-safe either way).** `dart:ui` *keeps*
  sub-pixel slivers, but any sliver thin enough to worry about sits inside the
  parity gate's boundary epsilon band, so dropping exact-zero-area contours and
  keeping the rest is safe. Keep Martinez's natural output; drop only
  exact-zero-area loops.

### Still open

- **Sweep arithmetic precision — settled: f64.** The Martinez sweep runs in f64
  regardless of how points are *stored* (storage width is a separate, open
  question — fast_path/DESIGN.md §5.1 and §11). `_flattenForOps` already widens
  to f64 for exactly this reason. Revisit only if parity sampling diverges.
