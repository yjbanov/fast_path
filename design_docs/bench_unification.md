# Benchmark Harness Unification

This document describes the consolidation of the project's two benchmark
harnesses into a shared `bench_core` package, the fix for a dead-code
elimination (DCE) hole in the matrix benchmarks, and the generalization of the
"reference implementation" so a benchmark can be compared against something
other than `dart:ui` (specifically `package:vector_math`'s `Matrix4`).

## Motivation

The project grew two benchmark harnesses independently:

- **`fast_path_bench`** — the mature, pure-Dart suite. `FastPathBenchmark`
  extends `BenchmarkBase` with an integer `sink` blackhole and an `opsPerRun`
  normalizer. `run_all.dart` runs every bench, normalizes to ns/op, drains
  every sink at the runner level so the compiler cannot elide the work, and
  emits a table or JSON. `tool/bench.sh` drives it across `jit`, `aot`, and
  `flutter-desktop` modes. Subject-vs-`dart:ui` pairing lives in the Flutter
  package's `BenchmarkCatalog`, because `dart:ui` only runs under Flutter.

- **`fast_geometry/benchmark`** — a bespoke harness with a `group()`/
  `benchmark()` DSL and a TSV printer. It compares `Matrix` against
  `vector_math`'s `Matrix4`.

The bespoke harness has four defects, all consequences of the divergence:

1. **DCE hole.** `exercise()` runs `compute(); postCompute?.call(result)`, but
   `postCompute` is null for every real benchmark. The accumulated `total` is
   never observed, so the inner work is dead-code-eliminable. The numbers may
   be measuring nothing.
2. **No normalization.** Each benchmark hand-rolls an `N = 10000` internal loop
   and reports raw microseconds per loop. The `N` is invisible in the output
   and the result is not comparable to `fast_path`'s ns/op.
3. **Pairing by string suffix.** Subject and reference are paired only by a
   naming convention (`'Identity (Matrix4)'` vs `'Identity (Matrix)'`). There
   is no structural pair, so subject/reference ratios cannot be computed
   programmatically.
4. **Not wired in.** TSV-only, no metadata, absent from `bench.sh`, `check.sh`,
   and CI. Nobody runs it automatically, so defect 1 went unnoticed.

## The crux: the baseline is not always `dart:ui`

The path suite's reference is `dart:ui.Path`, which is Flutter-only — that is
why pairing lives in the Flutter-hosted runner and the pure-Dart runner has no
baseline at all.

The matrix suite's reference is `vector_math.Matrix4`, which is plain Dart. So
the matrix subject *and* its reference both run under `dart`/AOT with no Flutter
needed.

The harness upgrade this forces: **the reference implementation is a per-benchmark
property, not a global assumption.** A benchmark is a pair of
`(subject, reference)` where the reference carries a label (`"dart:ui"`,
`"vector_math"`) and a host requirement (pure-Dart vs Flutter-hosted). The
runner places each pair in the run mode it can execute in.

## Architecture: a shared `bench_core` package

Extract the reusable machinery into a domain-agnostic package that depends only
on `benchmark_harness` — never on `fast_path`, `fast_geometry`, `vector_math`,
or `dart:ui`:

```
packages/bench_core/lib/
  benchmark.dart   // Benchmark base: sink, opsPerRun, exercise => run;
                   // plus a double-sink helper for blackholing doubles.
  catalog.dart     // BenchmarkPair { subject, reference?, referenceLabel,
                   // requiresFlutter }; solo entries.
  runner.dart      // measure -> ns/op -> collect -> drain sinks ->
                   // emit JSON/table; --mode parsing.
```

Consumers:

- **`fast_path_bench`** keeps its path benches, builds a catalog, and its
  `run_all.dart` shrinks to a thin `BenchmarkRunner(pathCatalog).main(args)`.
  Pure-Dart mode stays subject-only; the `dart:ui` reference halves are marked
  `requiresFlutter` and only materialize in `flutter-desktop` mode.
- **`fast_path_bench_flutter`** reuses the same core for its `dart:ui` pairs
  (replacing the bespoke catalog). This retarget is optional cleanup and may be
  deferred.
- **`fast_geometry`'s benchmark** is rewritten against `bench_core` with
  `vector_math` as the reference. Because both halves are pure Dart, the whole
  pair runs in `jit`/`aot`.

### Why a shared package rather than a shared schema only

The thinner alternative — keep two harnesses, share only the JSON contract —
leaves the runner loop, sink-draining, and normalization duplicated, and lets
the pairing model drift again, which is how the divergence arose in the first
place. The shared base is on the order of 150 lines and eliminates defects 1–4
structurally rather than by convention. The cost is one new package plus
retargeting `bench.sh`, which is acceptable.

## Concrete fixes folded in

- **DCE (defect 1).** Matrix benches accumulate a `double`, then fold it into
  the integer sink via a `doubleSink()` helper in `bench_core`. Dart has no
  `double.toRawBits`, so the helper reinterprets the bits with
  `ByteData..setFloat64/getInt64`. The runner drains every sink exactly as
  `run_all.dart` does today.
- **Normalization (defect 2).** Declare the internal loop count as
  `opsPerRun = N`; output becomes ns/op, directly comparable to the path
  benches. Keeping a modest internal loop is correct here — matrix operations
  are nanosecond-scale, like `fast_path`'s cheap `opsPerRun` benches.
- **Pairing (defect 3).** A structural `BenchmarkPair`. The JSON schema carries
  the pairing explicitly (see below).
- **Wiring (defect 4).** `bench.sh` grows a suite selector,
  `tool/bench.sh --suite=path|geometry|all`, and `check.sh`/CI smoke-run the
  geometry suite in JIT to catch DCE regressions cheaply.

## JSON schema

Backward compatibility is not a constraint at this stage, so the schema is
redesigned for cleanliness rather than extended. The subject and reference
labels are constant across a suite, so they live in `metadata`; each result
carries the subject timing and, when paired, the reference timing:

```jsonc
{
  "metadata": {
    "timestamp": "...", "mode": "jit", "os": "macos", "dart_version": "...",
    "subject_label": "fast_geometry",
    "reference_label": "vector_math"   // null when the suite has no baseline
  },
  "results": [
    {
      "name": "Instantiate: identity",
      "description": "Construct an identity matrix and read one entry.",
      "ops_per_run": 10000,
      "subject_ns_per_op": 0.6,
      "reference_ns_per_op": 0.6        // null for solo benchmarks
    }
  ]
}
```

A solo benchmark (no reference) sets `reference_ns_per_op` to null. The path
suite's `dart:ui` halves are emitted as the reference of their pair when run
under `flutter-desktop`, and omitted in the subject-only pure-Dart modes (where
`reference_label` is null).

### Smoke mode

A full measurement sweep is ~2s per benchmark — far too slow for CI. The runner
therefore accepts `--smoke`, which exercises every benchmark once through the
real setup/run/teardown path and drains the sinks, then reports a count. It
verifies the catalog, runner, and every benchmark execute (and that no result
is dead-code-eliminated) without the cost of measuring. CI and `check.sh` run
`tool/bench.sh --suite=geometry --smoke`; the matrix DCE guard also lives as a
unit test (`fast_geometry/test/matrix_benchmark_test.dart`).

## Staged execution

Each phase is independently committable.

1. **Create `bench_core`** — base, catalog, runner — porting `run_all.dart`'s
   proven logic verbatim. No change to path output yet.
2. **Retarget `fast_path_bench`** onto `bench_core`; golden-compare the JSON and
   table output to de-risk the extraction before touching matrix.
3. **Rewrite the matrix suite** against `bench_core` with `vector_math` pairs.
   Defects 1–3 die here. Verify the numbers are stable and non-zero.
4. **Wire `bench.sh` + `check.sh`/CI** for the geometry suite (defect 4).
5. **Retarget `fast_path_bench_flutter`'s catalog** onto `bench_core` (optional
   cleanup; may be deferred).

## Decisions (settled)

1. Shared `bench_core` package — adopted.
2. Schema redesigned for cleanliness, not extended for back-compat — adopted.
3. CI smoke-runs the geometry suite in JIT — adopted.
