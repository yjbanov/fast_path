// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Per-frame painter pattern with cubic curves: reuse one [PathBuilder]
/// across runs to build a 500-cubic path. Mirrors a complex font outline
/// or stroke-rendered shape workload — each cubic consumes three points
/// (two controls + endpoint).
class BuildCubics500Benchmark extends FastPathBenchmark {
  BuildCubics500Benchmark() : super('build_cubics_500');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(512, 1536);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..moveTo(0, 0);
    for (var i = 0; i < 500; i++) {
      final c1x = (i * 2.7) % 200;
      final c1y = (i * 1.3) % 100;
      final c2x = (i * 3.1) % 180;
      final c2y = (i * 1.9) % 90;
      final ex = (i + 1) * 1.0;
      final ey = ((i + 1) * 1.7) % 80;
      _builder.cubicTo(c1x, c1y, c2x, c2y, ex, ey);
    }
    _builder.close();
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
