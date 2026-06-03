// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// `PathBuilder.fromBuilder(other)` in isolation: the builder-to-builder
/// clone, useful when a caller wants to fork off a working copy without
/// going through the immutable [Path].
///
/// fast_path-only — `dart:ui.Path` has no builder, so cloning one is
/// not a meaningful concept on that side.
class BuilderClone1kBenchmark extends FastPathBenchmark {
  BuilderClone1kBenchmark() : super('builder_clone_1k');

  late PathBuilder _source;

  @override
  void setup() {
    _source = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      _source.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    _source.close();
  }

  @override
  void run() {
    final clone = PathBuilder.fromBuilder(_source);
    sink ^= clone.fillType.index;
  }
}
