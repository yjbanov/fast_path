// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// `PathBuilder.from(path)` in isolation: the Path → PathBuilder copy
/// step on its own, no surrounding mutation or follow-up `build()`.
///
/// fast_path-only — `dart:ui.Path` has no separate builder, so there is
/// nothing to compare against. `path_from_path_1k` (paired) measures
/// the round-trip `PathBuilder.from(path).build()`; this benchmark
/// isolates just the inbound half so we can attribute the cost.
class BuilderFromPath1kBenchmark extends FastPathBenchmark {
  BuilderFromPath1kBenchmark() : super('builder_from_path_1k');

  late Path _source;

  @override
  void setup() {
    final b = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      b.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    b.close();
    _source = b.build();
  }

  @override
  void run() {
    final builder = PathBuilder.from(_source);
    // Read a field off the builder so the JIT cannot prove the copy
    // is dead.
    sink ^= builder.fillType.index;
  }
}
