// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Per-frame painter pattern with curves: reuse one [PathBuilder] across
/// runs to build a 500-quad path (1000 verb appends total — one moveTo
/// and 500 quads, since each quad consumes two points). Mirrors a font
/// glyph or rounded-rectangle outline workload.
class BuildQuads500Benchmark extends FastPathBenchmark {
  BuildQuads500Benchmark() : super('build_quads_500');

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
      _builder.quadraticBezierTo(cx, cy, ex, ey);
    }
    _builder.close();
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
