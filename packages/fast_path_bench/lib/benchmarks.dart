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
import 'src/build_conics.dart';
import 'src/build_cubics.dart';
import 'src/build_polyline.dart';
import 'src/build_polyline_cold.dart';
import 'src/build_quads.dart';
import 'src/builder_clone.dart';
import 'src/builder_from_path.dart';
import 'src/builder_snapshot.dart';
import 'src/contains_conics.dart';
import 'src/contains_cubics.dart';
import 'src/contains_grid.dart';
import 'src/contains_quads.dart';
import 'src/path_equality.dart';
import 'src/path_from_path.dart';
import 'src/relative_polyline.dart';

export 'src/add_polygon.dart';
export 'src/benchmark_base.dart';
export 'src/bounds_cold.dart';
export 'src/bounds_warm.dart';
export 'src/build_conics.dart';
export 'src/build_cubics.dart';
export 'src/build_polyline.dart';
export 'src/build_polyline_cold.dart';
export 'src/build_quads.dart';
export 'src/builder_clone.dart';
export 'src/builder_from_path.dart';
export 'src/builder_snapshot.dart';
export 'src/contains_conics.dart';
export 'src/contains_cubics.dart';
export 'src/contains_grid.dart';
export 'src/contains_quads.dart';
export 'src/path_equality.dart';
export 'src/path_from_path.dart';
export 'src/relative_polyline.dart';

/// The canonical list of fast_path benchmarks. Add new benchmarks here so
/// every runner picks them up.
///
/// Order: construction benches first, then queries, then conversions
/// (fp-only — dart:ui doesn't split builder from path), then identity
/// (fp-only — dart:ui uses identity equality). Mirror pairs in
/// `fast_path_bench_flutter/lib/src/ui_benchmarks.dart` follow the same
/// order so the side-by-side table reads cleanly.
List<FastPathBenchmark> allBenchmarks() => <FastPathBenchmark>[
      // Construction.
      BuildPolyline1kBenchmark(),
      BuildPolylineCold1kBenchmark(),
      AddPolygon1kBenchmark(),
      RelativePolyline1kBenchmark(),
      PathFromPath1kBenchmark(),
      BuildQuads500Benchmark(),
      BuildConics500Benchmark(),
      BuildCubics500Benchmark(),
      // Queries.
      ContainsGrid1024Benchmark(),
      ContainsQuadsGrid1024Benchmark(),
      ContainsConicsGrid1024Benchmark(),
      ContainsCubicsGrid1024Benchmark(),
      BoundsWarm1kBenchmark(),
      BoundsCold1kBenchmark(),
      // Conversions (fp-only).
      BuilderFromPath1kBenchmark(),
      BuilderSnapshot1kBenchmark(),
      BuilderClone1kBenchmark(),
      // Identity (fp-only).
      PathEquality1kBenchmark(),
    ];
