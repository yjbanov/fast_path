// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// fast_path benchmark catalog.
///
/// All benchmarks are pure-Dart and runnable from any host (a `dart run`
/// CLI, a Flutter desktop AOT app, a Flutter web build). The base class
/// and individual benchmarks are exported below; the canonical list is
/// returned by [allBenchmarks].
library;

import 'src/add_polygon.dart';
import 'src/benchmark_base.dart';
import 'src/bounds_cold.dart';
import 'src/bounds_warm.dart';
import 'src/build_polyline.dart';
import 'src/build_polyline_cold.dart';
import 'src/contains_grid.dart';
import 'src/path_equality.dart';
import 'src/path_from_path.dart';
import 'src/relative_polyline.dart';

export 'src/add_polygon.dart';
export 'src/benchmark_base.dart';
export 'src/bounds_cold.dart';
export 'src/bounds_warm.dart';
export 'src/build_polyline.dart';
export 'src/build_polyline_cold.dart';
export 'src/contains_grid.dart';
export 'src/path_equality.dart';
export 'src/path_from_path.dart';
export 'src/relative_polyline.dart';

/// The canonical list of fast_path benchmarks. Add new benchmarks here so
/// every runner picks them up.
///
/// Order: construction benches first, then queries, then identity. Mirror
/// pairs in `fast_path_bench_flutter/lib/src/ui_benchmarks.dart` should
/// follow the same order so the side-by-side table reads cleanly.
List<FastPathBenchmark> allBenchmarks() => <FastPathBenchmark>[
      // Construction.
      BuildPolyline1kBenchmark(),
      BuildPolylineCold1kBenchmark(),
      AddPolygon1kBenchmark(),
      RelativePolyline1kBenchmark(),
      PathFromPath1kBenchmark(),
      // Queries.
      ContainsGrid1024Benchmark(),
      BoundsWarm1kBenchmark(),
      BoundsCold1kBenchmark(),
      // Identity (no dart:ui counterpart — ui.Path uses identity equality).
      PathEquality1kBenchmark(),
    ];
