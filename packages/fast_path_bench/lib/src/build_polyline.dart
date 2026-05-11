// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Per-frame painter pattern: reset the same builder, append 1000 line
/// segments, close, snapshot to an immutable [Path]. Measures the cost of
/// the construction loop plus the [PathBuilder.build] handoff.
class BuildPolyline1kBenchmark extends FastPathBenchmark {
  BuildPolyline1kBenchmark() : super('build_polyline_1k');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(1024, 1024);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      _builder.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    _builder.close();
    final path = _builder.build();
    // Read a field off the produced path so the JIT cannot prove `build`
    // is dead. The buffer writes inside `lineTo` are observable side
    // effects on their own, but observing the result hardens the bench
    // against future inlining changes.
    sink ^= path.fillType.index;
  }
}
