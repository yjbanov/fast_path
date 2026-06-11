// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Per-frame painter pattern with conic curves: reuse one [PathBuilder]
/// across runs to build a 500-conic path. Conics are what rounded
/// rectangles, ovals, and arcs decompose into, so this models the
/// rounded-container workload. Weights vary across segments (never
/// exactly 1, which would be stored as a quad).
class BuildConics500Benchmark extends FastPathBenchmark {
  BuildConics500Benchmark() : super('build_conics_500');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(512, 1024);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..moveTo(0, 0);
    for (var i = 0; i < 500; i++) {
      final cx = (i * 2.7) % 200;
      final cy = (i * 1.3) % 100;
      final ex = (i + 1) * 1.0;
      final ey = ((i + 1) * 1.7) % 80;
      final w = 0.3 + (i % 7) * 0.1; // 0.3 … 0.9
      _builder.conicTo(cx, cy, ex, ey, w);
    }
    _builder.close();
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
