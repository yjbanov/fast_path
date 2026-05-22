// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// Reseed a [PathBuilder] from an existing [Path] and snapshot a fresh
/// [Path] back out. This is the "edit an existing path" pattern: you
/// hold a [Path], want to mutate it, so you go
/// `PathBuilder.from(path)..lineTo(...).build()`. The benchmark omits
/// the mutation step so the number isolates the buffer-copy cost.
class PathFromPath1kBenchmark extends FastPathBenchmark {
  PathFromPath1kBenchmark() : super('path_from_path_1k');

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
    final out = builder.build();
    sink ^= out.fillType.index;
  }
}
