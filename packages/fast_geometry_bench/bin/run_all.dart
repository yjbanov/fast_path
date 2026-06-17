// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Runs the fast_geometry [Matrix] benchmark suite against
/// `package:vector_math`'s `Matrix4` and reports per-op timings.
///
/// Default output is a human-readable table with a subject/reference/speedup
/// layout. Pass `--json` for the structured report. Both the subject and the
/// reference are pure Dart, so the whole suite runs under `dart run` and AOT
/// with no Flutter host:
///
///   dart run fast_geometry_bench:run_all            # table
///   dart run fast_geometry_bench:run_all --json     # JSON
///
/// Driven by `tool/bench.sh --suite=geometry`.
library;

import 'package:bench_core/bench_core.dart';
import 'package:fast_geometry_bench/matrix_benchmarks.dart';

void main(List<String> args) {
  BenchmarkRunner.catalog(matrixCatalog()).run(args);
}
