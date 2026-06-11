// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1024 [Path.contains] queries against a closed shape built from 64
/// quadratic Bézier segments. Each query walks the verb stream and, for
/// every quad, recursively flattens it down to the contains tolerance to
/// accumulate ray crossings — so this benchmark stresses both the
/// flattening recursion and the per-segment edge test together.
class ContainsQuadsGrid1024Benchmark extends FastPathBenchmark {
  ContainsQuadsGrid1024Benchmark() : super('contains_quads_grid_1024');

  late Path _path;
  late List<Offset> _samples;

  @override
  int get opsPerRun => _samples.length;

  @override
  void setup() {
    final builder = PathBuilder();
    const segs = 64;
    const r = 40.0;
    const rIn = 25.0;
    const cx = 50.0;
    const cy = 50.0;
    builder.moveTo(cx + r, cy);
    for (var i = 0; i < segs; i++) {
      final a0 = (2 * i + 1) * math.pi / segs;
      final a1 = (2 * i + 2) * math.pi / segs;
      // Control point alternates inside / outside so the curve waves.
      final rc = i.isEven ? rIn : r * 1.2;
      builder.quadraticBezierTo(
        cx + rc * math.cos(a0),
        cy + rc * math.sin(a0),
        cx + r * math.cos(a1),
        cy + r * math.sin(a1),
      );
    }
    builder.close();
    _path = builder.build();

    _samples = <Offset>[
      for (var ix = 0; ix < 32; ix++)
        for (var iy = 0; iy < 32; iy++)
          Offset(ix * 4.0 - 15.0, iy * 4.0 - 15.0),
    ];
  }

  @override
  void run() {
    var hits = 0;
    for (var i = 0; i < _samples.length; i++) {
      if (_path.contains(_samples[i])) {
        hits++;
      }
    }
    sink ^= hits;
  }
}
