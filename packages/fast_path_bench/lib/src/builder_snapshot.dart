// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// `PathBuilder.build()` in isolation: the snapshot copy that produces
/// the immutable [Path], with all construction work pushed into [setup].
///
/// [PathBuilder.build] does not mutate the builder, so we can pre-fill
/// the buffers once and call `build()` repeatedly. Each call produces a
/// fresh [Path] backed by a tightly-sized copy of the builder's verb
/// and point arrays — that copy is exactly the cost we want to measure.
///
/// fast_path-only — `dart:ui.Path` has no separate snapshot step, so
/// there is no counterpart. `build_polyline_1k` bundles `build()` with
/// the 1000 `lineTo` appends; this benchmark separates the snapshot
/// from the population.
class BuilderSnapshot1kBenchmark extends FastPathBenchmark {
  BuilderSnapshot1kBenchmark() : super('builder_snapshot_1k');

  late PathBuilder _builder;

  @override
  void setup() {
    _builder = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      _builder.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    _builder.close();
  }

  @override
  void run() {
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
