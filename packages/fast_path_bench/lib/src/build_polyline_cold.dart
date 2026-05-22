// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Same 1k-segment construction as `build_polyline_1k`, but allocates a
/// fresh [PathBuilder] each iteration instead of reusing one via `reset`.
///
/// Captures the cost of the geometric buffer-growth path on the cold
/// side, where the realistic workload is "one-shot path construction"
/// (e.g. a path built once and stashed in a widget field) rather than
/// the per-frame painter reuse pattern `build_polyline_1k` covers.
class BuildPolylineCold1kBenchmark extends FastPathBenchmark {
  BuildPolylineCold1kBenchmark() : super('build_polyline_cold_1k');

  @override
  void run() {
    final builder = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      builder.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    builder.close();
    final path = builder.build();
    sink ^= path.fillType.index;
  }
}
