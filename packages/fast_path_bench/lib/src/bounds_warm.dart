// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1000 calls to [Path.getBounds] on a path whose bounds cache has already
/// been primed. Should bottom out at "field load + null check" — anything
/// slower means the cache is being missed.
class BoundsWarm1kBenchmark extends FastPathBenchmark {
  BoundsWarm1kBenchmark() : super('bounds_warm_1k');

  late Path _path;

  @override
  int get opsPerRun => 1000;

  @override
  void setup() {
    final b = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 100; i++) {
      b.lineTo(i.toDouble(), (i * 1.3) % 50.0);
    }
    _path = b.build();
    _path.getBounds(); // prime the cache
  }

  @override
  void run() {
    var acc = 0;
    for (var i = 0; i < 1000; i++) {
      // XOR a low-bit projection of the bounds into the local sink so the
      // JIT cannot elide the call.
      acc ^= _path.getBounds().left.toInt();
    }
    sink ^= acc;
  }
}
