// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';

/// Base class for every benchmark in the workspace.
///
/// Three adjustments to `package:benchmark_harness`'s defaults:
///
/// 1. [exercise] runs [run] once instead of ten times. The reported
///    `measure()` value is microseconds per [run] call, not per ten runs —
///    less surprising arithmetic when the runner computes per-op timings.
/// 2. [opsPerRun] lets a benchmark loop internally for stability on cheap
///    operations (e.g. a single matrix multiply, or a cached `getBounds`)
///    while the runner still reports normalized nanoseconds-per-op upstream.
///    Defaults to 1.
/// 3. [sink] is a side-effect-bearing field that benchmarks XOR observable
///    bits of their result into. The runner reads every benchmark's sink
///    after `measure()` finishes, which keeps the JIT/AOT compiler from
///    dead-code-eliminating cheap operations whose return values would
///    otherwise go unused.
abstract class Benchmark extends BenchmarkBase {
  Benchmark(super.name);

  /// Number of effective operations performed per [run] call. Override when
  /// [run] loops internally so the runner can normalize the per-op cost.
  int get opsPerRun => 1;

  /// Black-hole register. Benchmarks XOR observable bits of their return
  /// values into this so the compiler cannot prove the work is dead. For
  /// floating-point results, fold them in via [doubleBits].
  int sink = 0;

  @override
  void exercise() => run();
}

// A single reusable 8-byte view for reinterpreting doubles as their raw bit
// pattern. Allocation-free on the hot path; benchmarks are single-threaded so
// a shared buffer is safe.
final ByteData _doubleBitsBuffer = ByteData(8);

/// Reinterprets [value]'s IEEE-754 bits as an integer, for folding a
/// floating-point benchmark result into an integer [Benchmark.sink].
///
/// Dart has no `double.toRawBits`, so this round-trips through a [ByteData]
/// view. Use it when a benchmark accumulates a `double` (e.g. a matrix entry)
/// that must be kept observable:
///
/// ```dart
/// sink ^= doubleBits(total);
/// ```
int doubleBits(double value) {
  _doubleBitsBuffer.setFloat64(0, value);
  return _doubleBitsBuffer.getInt64(0);
}
