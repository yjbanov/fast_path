// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1024 [Path.contains] queries against a ring of 8 quarter-circle
/// conics (w = sqrt(2)/2) — two concentric circles with evenOdd-style
/// winding via nonZero opposite directions is overkill; a single
/// 8-conic rounded ring suffices to stress the rational-crossing solver.
class ContainsConicsGrid1024Benchmark extends FastPathBenchmark {
  ContainsConicsGrid1024Benchmark() : super('contains_conics_grid_1024');

  late Path _path;
  late List<Offset> _samples;

  @override
  int get opsPerRun => _samples.length;

  @override
  void setup() {
    final w = math.sqrt(2) / 2;
    const cx = 50.0;
    const cy = 50.0;
    const r = 40.0;
    // A full circle from 4 conics, then an inner circle (radius 20)
    // from 4 more, creating a ring under nonZero (same winding fills
    // both; we keep one direction so the inner disk stays filled —
    // the workload is the solver, not the topology).
    final builder = PathBuilder()
      ..moveTo(cx + r, cy)
      ..conicTo(cx + r, cy + r, cx, cy + r, w)
      ..conicTo(cx - r, cy + r, cx - r, cy, w)
      ..conicTo(cx - r, cy - r, cx, cy - r, w)
      ..conicTo(cx + r, cy - r, cx + r, cy, w)
      ..close()
      ..moveTo(cx + 20, cy)
      ..conicTo(cx + 20, cy + 20, cx, cy + 20, w)
      ..conicTo(cx - 20, cy + 20, cx - 20, cy, w)
      ..conicTo(cx - 20, cy - 20, cx, cy - 20, w)
      ..conicTo(cx + 20, cy - 20, cx + 20, cy, w)
      ..close();
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
