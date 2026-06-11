// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 500 [PathBuilder.addOval] calls per run on a reused builder. Each
/// oval is four conic verbs, so this also exercises the conic append
/// path under a realistic decorative-circles workload.
class AddOvals500Benchmark extends FastPathBenchmark {
  AddOvals500Benchmark() : super('add_ovals_500');

  late PathBuilder _builder;
  late List<Rect> _ovals;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(3072, 4608);
    _ovals = <Rect>[
      for (var i = 0; i < 500; i++)
        Rect.fromLTWH((i % 25) * 8.0, (i ~/ 25) * 8.0, 6.0, 5.0),
    ];
  }

  @override
  void run() {
    _builder.reset();
    for (var i = 0; i < _ovals.length; i++) {
      _builder.addOval(_ovals[i]);
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
