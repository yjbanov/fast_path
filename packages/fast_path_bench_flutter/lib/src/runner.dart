// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:convert';

import 'package:fast_path_bench/benchmarks.dart' as fp;

import 'ui_benchmarks.dart';

/// A single benchmark's measured result. Mirrors the per-row schema that
/// `fast_path_bench/bin/run_all.dart` emits so JSON consumers don't need
/// to special-case Flutter-hosted output.
class BenchResult {
  BenchResult(this.name, this.opsPerRun, this.nsPerOp);

  final String name;
  final int opsPerRun;
  final double nsPerOp;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'ns_per_op': nsPerOp,
        'ops_per_run': opsPerRun,
      };
}

/// Returns every benchmark this runner knows about: the fp suite from
/// [fp.allBenchmarks] plus the `dart:ui` mirrors defined in this package.
/// Order matches the fp catalog so the JSON output reads as a
/// side-by-side table. The `path_equality_1k` fp benchmark has no ui
/// counterpart (ui.Path uses identity equality) and falls at the end of
/// the fp block.
List<fp.FastPathBenchmark> allBenchmarks() => <fp.FastPathBenchmark>[
      ...fp.allBenchmarks(),
      // Construction.
      BuildPolylineUi1kBenchmark(),
      BuildPolylineColdUi1kBenchmark(),
      AddPolygonUi1kBenchmark(),
      RelativePolylineUi1kBenchmark(),
      PathFromPathUi1kBenchmark(),
      // Queries.
      ContainsGridUi1024Benchmark(),
      BoundsWarmUi1kBenchmark(),
      BoundsColdUi1kBenchmark(),
    ];

/// Runs every benchmark and returns the results in declaration order.
List<BenchResult> runAll() {
  final out = <BenchResult>[];
  for (final bench in allBenchmarks()) {
    final usPerRun = bench.measure();
    final nsPerOp = (usPerRun * 1000.0) / bench.opsPerRun;
    out.add(BenchResult(bench.name, bench.opsPerRun, nsPerOp));
  }
  return out;
}

/// Encodes results as the project's canonical JSON report — same shape as
/// `fast_path_bench/bin/run_all.dart --json`, so downstream tooling can
/// diff across modes without branching.
String encodeReport({
  required String mode,
  required String os,
  required String dartVersion,
  required List<BenchResult> results,
}) {
  final report = <String, Object?>{
    'metadata': <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'mode': mode,
      'os': os,
      'dart_version': dartVersion,
    },
    'results': [for (final r in results) r.toJson()],
  };
  return const JsonEncoder.withIndent('  ').convert(report);
}
