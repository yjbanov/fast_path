// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 500 [PathBuilder.addArc] calls per run on a reused builder, with
/// sweeps from a quarter turn to a full circle. Models gauge / progress
/// ring painting. Exercises the angle-chopping and conic-arc machinery
/// shared by arcTo.
class AddArcs500Benchmark extends FastPathBenchmark {
  AddArcs500Benchmark() : super('add_arcs_500');

  late PathBuilder _builder;
  late List<Rect> _ovals;
  late List<double> _sweeps;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(4096, 8192);
    _ovals = <Rect>[
      for (var i = 0; i < 500; i++)
        Rect.fromLTWH((i % 25) * 8.0, (i ~/ 25) * 8.0, 6.0, 6.0),
    ];
    _sweeps = <double>[
      for (var i = 0; i < 500; i++) (math.pi / 2) * (1 + i % 4),
    ];
  }

  @override
  void run() {
    _builder.reset();
    for (var i = 0; i < _ovals.length; i++) {
      _builder.addArc(_ovals[i], (i % 8) * math.pi / 4, _sweeps[i]);
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
