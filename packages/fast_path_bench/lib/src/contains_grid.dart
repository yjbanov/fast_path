// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1024 [Path.contains] queries against a 100-vertex star polygon. Mirrors
/// the hit-testing workload (one path, many pointer/coordinate queries).
class ContainsGrid1024Benchmark extends FastPathBenchmark {
  ContainsGrid1024Benchmark() : super('contains_grid_1024');

  late Path _path;
  late List<Offset> _samples;

  @override
  int get opsPerRun => _samples.length;

  @override
  void setup() {
    final builder = PathBuilder();
    const verts = 100;
    for (var i = 0; i < verts; i++) {
      final angle = i * 2 * math.pi / verts;
      // Alternating radii produce a star-ish shape that exercises both
      // crossings and tie-breakers.
      final r = (i.isEven ? 40.0 : 20.0);
      final x = 50 + r * math.cos(angle);
      final y = 50 + r * math.sin(angle);
      if (i == 0) {
        builder.moveTo(x, y);
      } else {
        builder.lineTo(x, y);
      }
    }
    builder.close();
    _path = builder.build();

    // 32×32 grid spanning roughly 1.5× the path's bounds.
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
