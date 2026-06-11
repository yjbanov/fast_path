// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 500 [PathBuilder.addRRect] calls per run on a reused builder. The
/// rounded-container workload — by far the most common decorative shape
/// in real Flutter apps. Exercises radii clamping plus mixed line/conic
/// appends.
class AddRRects500Benchmark extends FastPathBenchmark {
  AddRRects500Benchmark() : super('add_rrects_500');

  late PathBuilder _builder;
  late List<RRect> _rrects;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(5120, 8192);
    _rrects = <RRect>[
      for (var i = 0; i < 500; i++)
        RRect.fromRectAndRadius(
          Rect.fromLTWH((i % 25) * 8.0, (i ~/ 25) * 8.0, 6.0, 5.0),
          Radius.circular(1.0 + (i % 3) * 0.5),
        ),
    ];
  }

  @override
  void run() {
    _builder.reset();
    for (var i = 0; i < _rrects.length; i++) {
      _builder.addRRect(_rrects[i]);
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
