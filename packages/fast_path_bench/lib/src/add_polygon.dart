// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Builds the same 1k-vertex polygon as `build_polyline_1k`, but via the
/// convenience [PathBuilder.addPolygon] API instead of an explicit
/// `moveTo` + `lineTo` loop. Lets us see whether the high-level API
/// carries any overhead beyond the raw verb-stream appends.
class AddPolygon1kBenchmark extends FastPathBenchmark {
  AddPolygon1kBenchmark() : super('add_polygon_1k');

  late List<Offset> _points;
  late PathBuilder _builder;

  @override
  void setup() {
    _points = <Offset>[
      for (var i = 0; i < 1000; i++)
        Offset(i.toDouble(), (i * 1.3) % 100.0),
    ];
    _builder = PathBuilder()..reserve(1024, 1024);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..addPolygon(_points, true);
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
