// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// First-call `getBounds` on a fresh 1k-segment path each iteration.
///
/// Companion to `bounds_warm_1k`: the warm version measures the cached
/// field load, this one measures the actual O(N) walk over points. The
/// build cost is bundled in because there's no way to invalidate the
/// cache short of starting from a new [Path] — but that matches the
/// realistic workload (first `getBounds()` on a freshly-built path).
class BoundsCold1kBenchmark extends FastPathBenchmark {
  BoundsCold1kBenchmark() : super('bounds_cold_1k');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(1024, 1024);
  }

  @override
  void run() {
    _builder
      ..reset()
      ..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      _builder.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    _builder.close();
    final path = _builder.build();
    final bounds = path.getBounds();
    sink ^= bounds.left.toInt();
  }
}
