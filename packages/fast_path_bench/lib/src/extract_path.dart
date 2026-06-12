// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Extracts 32 overlapping sub-paths from a curve-heavy contour per run.
/// Models the dashed-line workload: walk a contour pulling out the "on"
/// segments of a dash pattern.
class ExtractPath32Benchmark extends FastPathBenchmark {
  ExtractPath32Benchmark() : super('extract_path_32');

  late PathMetric _metric;
  late double _len;

  @override
  int get opsPerRun => 32;

  @override
  void setup() {
    final b = PathBuilder()..moveTo(0, 0);
    for (var i = 0; i < 16; i++) {
      final x = (i + 1) * 12.0;
      b.cubicTo(
        x - 8, math.sin(i) * 30,
        x - 4, math.cos(i) * 30,
        x, (i.isEven ? 10 : -10).toDouble(),
      );
    }
    b.close();
    _metric = b.build().computeMetrics().first;
    _len = _metric.length;
  }

  @override
  void run() {
    var acc = 0;
    final step = _len / 32;
    for (var i = 0; i < 32; i++) {
      final start = i * step;
      final piece = _metric.extractPath(start, start + step * 0.6);
      acc ^= piece.getBounds().left.toInt();
    }
    sink ^= acc;
  }
}
