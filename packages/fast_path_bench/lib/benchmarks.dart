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

import 'src/benchmark_base.dart';
import 'src/bounds_warm.dart';
import 'src/build_polyline.dart';
import 'src/contains_grid.dart';

export 'src/benchmark_base.dart';
export 'src/bounds_warm.dart';
export 'src/build_polyline.dart';
export 'src/contains_grid.dart';

/// The canonical list of fast_path benchmarks. Add new benchmarks here so
/// every runner picks them up.
List<FastPathBenchmark> allBenchmarks() => <FastPathBenchmark>[
      BuildPolyline1kBenchmark(),
      ContainsGrid1024Benchmark(),
      BoundsWarm1kBenchmark(),
    ];
