// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fast_path_bench/benchmarks.dart' show FastPathBenchmark;

/// Mirrors `BuildPolyline1kBenchmark` from `package:fast_path_bench`, but
/// drives `dart:ui.Path` instead of `fast_path.PathBuilder`. Note that
/// `dart:ui.Path` does not have a separate snapshot step — the path is its
/// own queryable object — so the fp version's `build()` cost has no
/// counterpart here. Both sides reuse path storage across runs via
/// `reset()` for fairness.
class BuildPolylineUi1kBenchmark extends FastPathBenchmark {
  BuildPolylineUi1kBenchmark() : super('build_polyline_ui_1k');

  late ui.Path _path;

  @override
  void setup() {
    _path = ui.Path();
  }

  @override
  void run() {
    _path
      ..reset()
      ..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      _path.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    _path.close();
    sink ^= _path.fillType.index;
  }
}

/// Mirrors `ContainsGrid1024Benchmark`. 1024 hit-test queries against a
/// 100-vertex star polygon built once in [setup].
class ContainsGridUi1024Benchmark extends FastPathBenchmark {
  ContainsGridUi1024Benchmark() : super('contains_grid_ui_1024');

  late ui.Path _path;
  late List<ui.Offset> _samples;

  @override
  int get opsPerRun => _samples.length;

  @override
  void setup() {
    _path = ui.Path();
    const verts = 100;
    for (var i = 0; i < verts; i++) {
      final angle = i * 2 * math.pi / verts;
      final r = i.isEven ? 40.0 : 20.0;
      final x = 50 + r * math.cos(angle);
      final y = 50 + r * math.sin(angle);
      if (i == 0) {
        _path.moveTo(x, y);
      } else {
        _path.lineTo(x, y);
      }
    }
    _path.close();

    _samples = <ui.Offset>[
      for (var ix = 0; ix < 32; ix++)
        for (var iy = 0; iy < 32; iy++)
          ui.Offset(ix * 4.0 - 15.0, iy * 4.0 - 15.0),
    ];
  }

  @override
  void run() {
    var hits = 0;
    for (var i = 0; i < _samples.length; i++) {
      if (_path.contains(_samples[i])) {
        hits++;
      }
    }
    sink ^= hits;
  }
}

/// Mirrors `BoundsWarm1kBenchmark`. 1000 `getBounds` calls on a path whose
/// cache has already been primed. Skia caches bounds on `SkPath`, so this
/// should bottom out at a cached-field load — the same ceiling as the fp
/// version, just inside the engine's address space.
class BoundsWarmUi1kBenchmark extends FastPathBenchmark {
  BoundsWarmUi1kBenchmark() : super('bounds_warm_ui_1k');

  late ui.Path _path;

  @override
  int get opsPerRun => 1000;

  @override
  void setup() {
    _path = ui.Path()..moveTo(0, 0);
    for (var i = 1; i < 100; i++) {
      _path.lineTo(i.toDouble(), (i * 1.3) % 50.0);
    }
    _path.getBounds(); // prime the cache
  }

  @override
  void run() {
    var acc = 0;
    for (var i = 0; i < 1000; i++) {
      acc ^= _path.getBounds().left.toInt();
    }
    sink ^= acc;
  }
}
