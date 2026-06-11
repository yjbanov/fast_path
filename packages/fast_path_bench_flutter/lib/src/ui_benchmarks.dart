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

/// Mirrors `BoundsColdUi1kBenchmark`. Fresh path each iteration so the
/// engine's bounds cache always misses. Like the fp side, the build cost
/// is bundled in — there's no way to reset the cache without starting
/// from a new `ui.Path`.
class BoundsColdUi1kBenchmark extends FastPathBenchmark {
  BoundsColdUi1kBenchmark() : super('bounds_cold_ui_1k');

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
    final bounds = _path.getBounds();
    sink ^= bounds.left.toInt();
  }
}

/// Mirrors `BuildPolylineCold1kBenchmark`. Fresh `ui.Path` each iteration
/// (no `reset` reuse). Captures the cost of the cold construction path
/// — the realistic workload for one-shot path objects stashed in widget
/// fields, as opposed to per-frame painter reuse.
class BuildPolylineColdUi1kBenchmark extends FastPathBenchmark {
  BuildPolylineColdUi1kBenchmark() : super('build_polyline_cold_ui_1k');

  @override
  void run() {
    final path = ui.Path()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      path.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    path.close();
    sink ^= path.fillType.index;
  }
}

/// Mirrors `AddPolygon1kBenchmark`. Builds the same 1k-vertex polygon via
/// `ui.Path.addPolygon`. Same workload as `build_polyline_ui_1k`, just
/// through the high-level convenience API.
class AddPolygonUi1kBenchmark extends FastPathBenchmark {
  AddPolygonUi1kBenchmark() : super('add_polygon_ui_1k');

  late List<ui.Offset> _points;
  late ui.Path _path;

  @override
  void setup() {
    _points = <ui.Offset>[
      for (var i = 0; i < 1000; i++)
        ui.Offset(i.toDouble(), (i * 1.3) % 100.0),
    ];
    _path = ui.Path();
  }

  @override
  void run() {
    _path
      ..reset()
      ..addPolygon(_points, true);
    sink ^= _path.fillType.index;
  }
}

/// Mirrors `RelativePolyline1kBenchmark`. 1000 segments built via
/// `relativeMoveTo` + `relativeLineTo`. Exposes the engine's
/// current-point bookkeeping cost.
class RelativePolylineUi1kBenchmark extends FastPathBenchmark {
  RelativePolylineUi1kBenchmark() : super('relative_polyline_ui_1k');

  late ui.Path _path;

  @override
  void setup() {
    _path = ui.Path();
  }

  @override
  void run() {
    _path
      ..reset()
      ..relativeMoveTo(0, 0);
    for (var i = 0; i < 999; i++) {
      _path.relativeLineTo(1.0, 0.5);
    }
    _path.close();
    sink ^= _path.fillType.index;
  }
}

/// Mirrors `PathFromPath1kBenchmark`. `ui.Path.from(source)` copies the
/// engine's path-ref into a new instance. Measures the per-copy cost
/// crossing the FFI boundary in addition to the actual buffer copy.
class PathFromPathUi1kBenchmark extends FastPathBenchmark {
  PathFromPathUi1kBenchmark() : super('path_from_path_ui_1k');

  late ui.Path _source;

  @override
  void setup() {
    _source = ui.Path()..moveTo(0, 0);
    for (var i = 1; i < 1000; i++) {
      _source.lineTo(i.toDouble(), (i * 1.3) % 100.0);
    }
    _source.close();
  }

  @override
  void run() {
    final clone = ui.Path.from(_source);
    sink ^= clone.fillType.index;
  }
}

/// Mirrors `BuildQuads500Benchmark`. 500-quad construction on a reused
/// `ui.Path` to match the per-frame painter pattern.
class BuildQuadsUi500Benchmark extends FastPathBenchmark {
  BuildQuadsUi500Benchmark() : super('build_quads_ui_500');

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
    for (var i = 0; i < 500; i++) {
      final cx = (i * 2.7) % 200;
      final cy = (i * 1.3) % 100;
      final ex = (i + 1) * 1.0;
      final ey = ((i + 1) * 1.7) % 80;
      _path.quadraticBezierTo(cx, cy, ex, ey);
    }
    _path.close();
    sink ^= _path.fillType.index;
  }
}

/// Mirrors `ContainsQuadsGrid1024Benchmark`. Same 64-quad wavy ring built
/// once in [setup]; 1024 contains queries per run.
class ContainsQuadsGridUi1024Benchmark extends FastPathBenchmark {
  ContainsQuadsGridUi1024Benchmark() : super('contains_quads_grid_ui_1024');

  late ui.Path _path;
  late List<ui.Offset> _samples;

  @override
  int get opsPerRun => _samples.length;

  @override
  void setup() {
    _path = ui.Path();
    const segs = 64;
    const r = 40.0;
    const rIn = 25.0;
    const cx = 50.0;
    const cy = 50.0;
    _path.moveTo(cx + r, cy);
    for (var i = 0; i < segs; i++) {
      final a0 = (2 * i + 1) * math.pi / segs;
      final a1 = (2 * i + 2) * math.pi / segs;
      final rc = i.isEven ? rIn : r * 1.2;
      _path.quadraticBezierTo(
        cx + rc * math.cos(a0),
        cy + rc * math.sin(a0),
        cx + r * math.cos(a1),
        cy + r * math.sin(a1),
      );
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
