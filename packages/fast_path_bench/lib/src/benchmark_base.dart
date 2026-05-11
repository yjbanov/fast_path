// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:benchmark_harness/benchmark_harness.dart';

/// Base class for all fast_path benchmarks.
///
/// Three adjustments to `package:benchmark_harness`'s defaults:
///
/// 1. [exercise] runs [run] once instead of ten times. The reported
///    `measure()` value is microseconds per [run] call, not per ten runs —
///    less surprising arithmetic when computing per-op timings.
/// 2. [opsPerRun] lets a benchmark loop internally for stability on cheap
///    operations (e.g. cached `getBounds`) while still reporting normalized
///    nanoseconds-per-op upstream. Defaults to 1.
/// 3. [sink] is a side-effect-bearing field that benchmarks XOR their
///    result into. The runner reads every benchmark's sink after
///    `measure()` finishes, which keeps the JIT from dead-code-eliminating
///    cheap operations whose return values would otherwise go unused
///    (notably the cached path of `Path.getBounds`).
abstract class FastPathBenchmark extends BenchmarkBase {
  FastPathBenchmark(super.name);

  /// Number of effective operations performed per [run] call. Override when
  /// [run] loops internally so the runner can normalize the per-op cost.
  int get opsPerRun => 1;

  /// Black-hole register. Benchmarks XOR observable bits of their return
  /// values into this so the JIT cannot prove the work is dead.
  int sink = 0;

  @override
  void exercise() => run();
}
