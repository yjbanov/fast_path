// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1024 [Path.contains] queries against a closed shape built from 32
/// cubic Bézier segments. Each query walks the verb stream and, for
/// every cubic, solves the cubic in `t` analytically to count ray
/// crossings — stressing the Cardano / trig solver hot path.
class ContainsCubicsGrid1024Benchmark extends FastPathBenchmark {
  ContainsCubicsGrid1024Benchmark() : super('contains_cubics_grid_1024');

  late Path _path;
  late List<Offset> _samples;

  @override
  int get opsPerRun => _samples.length;

  @override
  void setup() {
    final builder = PathBuilder();
    const segs = 32;
    const r = 40.0;
    const cx = 50.0;
    const cy = 50.0;
    builder.moveTo(cx + r, cy);
    for (var i = 0; i < segs; i++) {
      final a0 = i * 2 * math.pi / segs;
      final a1 = (i + 1) * 2 * math.pi / segs;
      // Two control points placed inside/outside the unit circle to make
      // the curve undulate, exercising the trig-form three-real-root
      // branch of the cubic solver.
      final r1 = i.isEven ? r * 0.55 : r * 1.25;
      final r2 = i.isEven ? r * 1.25 : r * 0.55;
      final t1 = a0 + (a1 - a0) * 0.33;
      final t2 = a0 + (a1 - a0) * 0.67;
      builder.cubicTo(
        cx + r1 * math.cos(t1),
        cy + r1 * math.sin(t1),
        cx + r2 * math.cos(t2),
        cy + r2 * math.sin(t2),
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
