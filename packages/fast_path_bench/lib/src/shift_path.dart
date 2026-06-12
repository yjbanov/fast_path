// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1000 [Path.shift] calls per run against a pre-built 200-segment path.
/// Models repositioning a cached shape (a marker, a glyph) many times —
/// the pure-function translate that returns a fresh immutable path.
class ShiftPath1kBenchmark extends FastPathBenchmark {
  ShiftPath1kBenchmark() : super('shift_path_1k');

  late Path _path;

  @override
  void setup() {
    final b = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 200; i++) {
      b.lineTo(i.toDouble(), (i * 1.7) % 50);
    }
    b.close();
    _path = b.build();
  }

  @override
  void run() {
    var acc = 0;
    for (var i = 0; i < 1000; i++) {
      final shifted = _path.shift(Offset(i.toDouble(), -i.toDouble()));
      acc ^= shifted.getBounds().left.toInt();
    }
    sink ^= acc;
  }

  @override
  int get opsPerRun => 1000;
}
