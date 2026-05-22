// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 100 [Path] `==` comparisons per run, against a structurally-equal
/// but distinct [Path]. Worst case: the identity short-circuit misses,
/// the length checks pass, and we walk every verb and point byte to
/// confirm equality.
///
/// fast_path's structural equality (DESIGN.md §4.4) is what lets a
/// [Path] be used as a `Map` key — memoizing `combine` results, caching
/// derived geometry per shape, etc. This benchmark tells us whether
/// that pattern is cheap enough to lean on.
///
/// No `dart:ui` counterpart: `ui.Path` uses identity equality, so the
/// same comparison there is `O(1)` and tells us nothing about ours.
class PathEquality1kBenchmark extends FastPathBenchmark {
  PathEquality1kBenchmark() : super('path_equality_1k');

  late Path _a;
  late Path _b;

  @override
  int get opsPerRun => 100;

  @override
  void setup() {
    _a = _build();
    _b = _build();
    // _a and _b are structurally equal but not `identical`. Confirm so
    // the benchmark fails loudly if a future change breaks the
    // assumption that we're measuring the deep-compare path.
    assert(!identical(_a, _b));
    assert(_a == _b);
  }

  static Path _build() {
    final b = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      b.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    b.close();
    return b.build();
  }

  @override
  void run() {
    var hits = 0;
    for (var i = 0; i < 100; i++) {
      if (_a == _b) {
        hits++;
      }
    }
    sink ^= hits;
  }
}
