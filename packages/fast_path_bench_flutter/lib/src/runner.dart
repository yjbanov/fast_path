// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:convert';

import 'package:fast_path_bench/benchmarks.dart' as fp;

import 'catalog.dart';

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

/// Measured result for a single [PairedBenchmark].
class PairResult {
  PairResult(this.spec, this.fp, this.ui);

  final PairedBenchmark spec;
  final BenchResult fp;
  final BenchResult ui;

  /// Percentage difference of `fp` relative to `ui`. Negative means
  /// fp is faster (lower ns/op), positive means slower. `null` when
  /// either side is zero or non-finite (defensive — shouldn't happen
  /// for real benchmarks, but `bounds_warm` is close enough to zero
  /// that we'd rather print "—" than `Infinity%`).
  double? get fpDeltaPercent {
    if (!ui.nsPerOp.isFinite || ui.nsPerOp == 0) {
      return null;
    }
    return ((fp.nsPerOp - ui.nsPerOp) / ui.nsPerOp) * 100;
  }
}

/// Measured result for a single [SoloBenchmark].
class SoloResult {
  SoloResult(this.spec, this.bench);

  final SoloBenchmark spec;
  final BenchResult bench;
}

/// All results from one catalog run.
class CatalogResults {
  CatalogResults({required this.pairs, required this.solos});

  final List<PairResult> pairs;
  final List<SoloResult> solos;
}

/// Runs every catalog entry and returns the structured results. Pair
/// entries run their fp side first then their ui side; solo entries
/// run in declaration order after all pairs.
CatalogResults runCatalog() {
  final pairResults = <PairResult>[];
  for (final pair in allPairs()) {
    final fpResult = _measure(pair.createFp());
    final uiResult = _measure(pair.createUi());
    pairResults.add(PairResult(pair, fpResult, uiResult));
  }
  final soloResults = <SoloResult>[];
  for (final solo in allSolos()) {
    soloResults.add(SoloResult(solo, _measure(solo.create())));
  }
  return CatalogResults(pairs: pairResults, solos: soloResults);
}

/// Flat list of every result, in the order pairs (fp, ui, fp, ui …)
/// then solos. Same order [encodeReport] uses for the canonical JSON.
List<BenchResult> flattenResults(CatalogResults c) {
  final out = <BenchResult>[];
  for (final p in c.pairs) {
    out..add(p.fp)..add(p.ui);
  }
  for (final s in c.solos) {
    out.add(s.bench);
  }
  return out;
}

/// Convenience: run the whole catalog and flatten in one call. Used by
/// the desktop entry where the JSON dump is the only output.
List<BenchResult> runAll() => flattenResults(runCatalog());

BenchResult _measure(fp.FastPathBenchmark bench) {
  final usPerRun = bench.measure();
  final nsPerOp = (usPerRun * 1000.0) / bench.opsPerRun;
  return BenchResult(bench.name, bench.opsPerRun, nsPerOp);
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
