// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Runs every fast_path benchmark and reports per-op timings.
///
/// Default output is a human-readable table. Pass `--json` to emit a
/// structured JSON report on stdout (the form a CI workflow can diff against a
/// baseline). The two formats carry the same data.
///
/// This is the pure-Dart host: there is no `dart:ui` baseline here (it cannot
/// run outside Flutter), so every benchmark reports as a subject-only result.
/// The `dart:ui` side-by-side comparison lives in the Flutter-hosted runner
/// (`fast_path_bench_flutter`, `tool/bench.sh --mode=flutter-desktop`).
///
/// Compiles cleanly with `dart run`, `dart compile exe`, `dart compile js`,
/// and `dart compile wasm`.
library;

import 'package:bench_core/bench_core.dart';
import 'package:fast_path_bench/benchmarks.dart';

void main(List<String> args) {
  BenchmarkRunner.subjects('fast_path', allBenchmarks()).run(args);
}
