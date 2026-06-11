// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 500 [PathBuilder.arcToPoint] calls per run chaining SVG-style arcs.
/// Models SVG path-data rendering, the main consumer of the endpoint
/// parameterization. Exercises the endpoint → center conversion plus
/// the rotated-conic emitter.
class ArcToPoint500Benchmark extends FastPathBenchmark {
  ArcToPoint500Benchmark() : super('arc_to_point_500');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(2048, 4096);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..moveTo(0, 0);
    for (var i = 0; i < 500; i++) {
      _builder.arcToPoint(
        Offset((i + 1) * 2.0, (i % 5) * 10.0),
        radius: Radius.elliptical(8 + (i % 4).toDouble(), 6),
        rotation: (i % 6) * 15.0,
        largeArc: i.isEven,
        clockwise: i % 3 != 0,
      );
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
