// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1000-segment polyline built via [PathBuilder.relativeMoveTo] +
/// [PathBuilder.relativeLineTo]. Same shape as `build_polyline_1k` at
/// the buffer level, but each append hops through `_currentPoint()` —
/// this benchmark exposes that overhead.
///
/// Constant deltas are fine: the relative-add path doesn't fast-path on
/// value, only on "is there a current point to read".
class RelativePolyline1kBenchmark extends FastPathBenchmark {
  RelativePolyline1kBenchmark() : super('relative_polyline_1k');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(1024, 1024);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..relativeMoveTo(0, 0);
    for (var i = 0; i < 999; i++) {
      _builder.relativeLineTo(1.0, 0.5);
    }
    _builder.close();
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
