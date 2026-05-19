// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Runs every fast_path benchmark and reports per-op timings.
///
/// Default output is a human-readable table. Pass `--json` to emit a
/// structured JSON report on stdout (the form a future CI workflow can
/// diff against a baseline). The two formats carry the same data.
///
/// This entry point compiles cleanly with `dart run`, `dart compile exe`,
/// `dart compile js`, and `dart compile wasm`. The first deployment is
/// JIT (`dart run`); the rest are deliberate follow-ups.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fast_path_bench/benchmarks.dart';

void main(List<String> args) {
  final asJson = args.contains('--json');
  final mode = _parseMode(args);

  final benches = allBenchmarks();
  final results = <_Result>[];
  for (final bench in benches) {
    // measure() returns microseconds per exercise; FastPathBenchmark
    // overrides exercise to call run once, so this is microseconds per run.
    final usPerRun = bench.measure();
    final nsPerOp = (usPerRun * 1000.0) / bench.opsPerRun;
    results.add(_Result(bench.name, bench.opsPerRun, nsPerOp));
  }

  if (asJson) {
    _printJson(results, mode);
  } else {
    _printTable(results, mode);
  }

  // Observe every benchmark's sink so the JIT / AOT compiler cannot prove
  // the inner work was dead. Print only when the value happens to land on
  // an unreachable bit pattern; the comparison itself is enough to keep
  // the read alive.
  var totalSink = 0;
  for (final b in benches) {
    totalSink ^= b.sink;
  }
  if (totalSink == 0xDEADBEEF) {
    stderr.writeln('blackhole tripped: $totalSink');
  }
}

class _Result {
  _Result(this.name, this.opsPerRun, this.nsPerOp);
  final String name;
  final int opsPerRun;
  final double nsPerOp;
}

/// Recognized values for `--mode=`. The runner doesn't enforce a closed
/// set so future deployments (dart2js, dart2wasm, flutter-desktop) can
/// pass through their own label without needing a code change here — but
/// these are the labels the project's tooling currently produces.
const _knownModes = <String>{
  'jit',
  'aot',
};

String _parseMode(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--mode=')) {
      final v = arg.substring('--mode='.length);
      if (!_knownModes.contains(v)) {
        stderr.writeln(
          'warning: unrecognized --mode=$v '
          '(known: ${_knownModes.join(', ')})',
        );
      }
      return v;
    }
  }
  return 'jit';
}

void _printTable(List<_Result> results, String mode) {
  final nameWidth = results
      .map((r) => r.name.length)
      .fold<int>(8, (a, b) => a > b ? a : b);

  stdout.writeln('mode: $mode  os: ${Platform.operatingSystem}');
  stdout.writeln('');
  stdout.writeln(
    '${'benchmark'.padRight(nameWidth)}  ${'ns/op'.padLeft(12)}  '
    '${'ops/run'.padLeft(8)}',
  );
  stdout.writeln('${'-' * nameWidth}  ${'-' * 12}  ${'-' * 8}');
  for (final r in results) {
    stdout.writeln(
      '${r.name.padRight(nameWidth)}  '
      '${_formatNs(r.nsPerOp).padLeft(12)}  '
      '${r.opsPerRun.toString().padLeft(8)}',
    );
  }
}

void _printJson(List<_Result> results, String mode) {
  final report = <String, Object?>{
    'metadata': <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'mode': mode,
      'os': Platform.operatingSystem,
      'dart_version': Platform.version,
    },
    'results': [
      for (final r in results)
        <String, Object?>{
          'name': r.name,
          'ns_per_op': r.nsPerOp,
          'ops_per_run': r.opsPerRun,
        },
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

String _formatNs(double ns) {
  if (ns < 1000) {
    return '${ns.toStringAsFixed(1)} ns';
  }
  if (ns < 1000000) {
    return '${(ns / 1000).toStringAsFixed(2)} us';
  }
  return '${(ns / 1000000).toStringAsFixed(2)} ms';
}
