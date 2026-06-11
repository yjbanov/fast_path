// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 500 [PathBuilder.addRect] calls per run on a reused builder. Models
/// grid- or table-painting workloads where many rectangular cells land
/// in one path per frame.
class AddRects500Benchmark extends FastPathBenchmark {
  AddRects500Benchmark() : super('add_rects_500');

  late PathBuilder _builder;
  late List<Rect> _rects;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(2560, 2560);
    _rects = <Rect>[
      for (var i = 0; i < 500; i++)
        Rect.fromLTWH((i % 25) * 8.0, (i ~/ 25) * 8.0, 6.0, 6.0),
    ];
  }

  @override
  void run() {
    _builder.reset();
    for (var i = 0; i < _rects.length; i++) {
      _builder.addRect(_rects[i]);
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
