// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Builds a curve-heavy closed path once, then per run computes its
/// metrics and samples 64 tangents along the contour. Models the
/// dashed-stroke / path-following-animation workload that drives a
/// painter along a contour.
class Metrics64Benchmark extends FastPathBenchmark {
  Metrics64Benchmark() : super('metrics_tangents_64');

  late Path _path;

  @override
  int get opsPerRun => 64;

  @override
  void setup() {
    final b = PathBuilder()..moveTo(0, 0);
    // A wavy closed ribbon of cubics.
    for (var i = 0; i < 16; i++) {
      final x = (i + 1) * 12.0;
      b.cubicTo(
        x - 8, math.sin(i) * 30,
        x - 4, math.cos(i) * 30,
        x, (i.isEven ? 10 : -10).toDouble(),
      );
    }
    b.close();
    _path = b.build();
  }

  @override
  void run() {
    final metric = _path.computeMetrics().first;
    final len = metric.length;
    var acc = 0;
    for (var i = 0; i < 64; i++) {
      final t = metric.getTangentForOffset(len * i / 64);
      if (t != null) {
        acc ^= t.position.dx.toInt();
      }
    }
    sink ^= acc;
  }
}
