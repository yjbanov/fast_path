// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'benchmark.dart';
import 'catalog.dart';

/// Drives a set of benchmarks and reports per-op timings.
///
/// Default output is a human-readable table. Pass `--json` to emit a
/// structured JSON report on stdout (the form a CI workflow diffs against a
/// baseline). The two formats carry the same data.
///
/// Construct from a [Catalog] (subject + optional reference pairs) via
/// [BenchmarkRunner.catalog], or from a bare list of subjects via
/// [BenchmarkRunner.subjects] when the host has no baseline to compare against
/// (e.g. the pure-Dart fast_path runner, where `dart:ui` cannot run).
class BenchmarkRunner {
  BenchmarkRunner._({
    required this.subjectLabel,
    this.referenceLabel,
    required List<_Row> rows,
  }) : _rows = rows;

  /// Subject-only runner: no baseline. Every result reports just the subject
  /// timing.
  factory BenchmarkRunner.subjects(
    String subjectLabel,
    List<Benchmark> benchmarks,
  ) {
    return BenchmarkRunner._(
      subjectLabel: subjectLabel,
      rows: <_Row>[for (final b in benchmarks) _Row(subject: b)],
    );
  }

  /// Paired runner: instantiates each entry's subject and (if present)
  /// reference once, up front.
  factory BenchmarkRunner.catalog(Catalog catalog) {
    return BenchmarkRunner._(
      subjectLabel: catalog.subjectLabel,
      referenceLabel: catalog.referenceLabel,
      rows: <_Row>[
        for (final e in catalog.entries)
          _Row(
            subject: e.subject(),
            reference: e.reference?.call(),
            description: e.description,
          ),
      ],
    );
  }

  final String subjectLabel;
  final String? referenceLabel;
  final List<_Row> _rows;

  /// Runs every benchmark and prints the report. Reads `--json` and `--mode=`
  /// from [args]; the rest is the standard `main` signature so a consumer's
  /// entry point is a one-liner.
  ///
  /// `--smoke` short-circuits to a fast end-to-end check (see [_smoke]): every
  /// benchmark is exercised once instead of measured for ~2s. CI uses it to
  /// verify the catalog, runner, and each benchmark execute without the cost
  /// of a real measurement sweep.
  void run(List<String> args) {
    if (args.contains('--smoke')) {
      _smoke();
      return;
    }

    final asJson = args.contains('--json');
    final mode = _parseMode(args);

    final results = <_Result>[];
    for (final row in _rows) {
      // measure() returns microseconds per exercise; Benchmark overrides
      // exercise to call run once, so this is microseconds per run.
      final subjectNs = _nsPerOp(row.subject);
      final referenceNs =
          row.reference == null ? null : _nsPerOp(row.reference!);
      results.add(
        _Result(
          name: row.subject.name,
          description: row.description,
          opsPerRun: row.subject.opsPerRun,
          subjectNsPerOp: subjectNs,
          referenceNsPerOp: referenceNs,
        ),
      );
    }

    if (asJson) {
      _printJson(results, mode);
    } else {
      _printTable(results, mode);
    }

    _drainSinks();
  }

  static double _nsPerOp(Benchmark bench) =>
      (bench.measure() * 1000.0) / bench.opsPerRun;

  // Exercises every benchmark once through the real setup/run/teardown path,
  // then drains sinks. No timing — this is a wiring + anti-DCE smoke check
  // cheap enough for CI, not a measurement. Throws (failing the process) if
  // any benchmark errors; reports the count on success.
  void _smoke() {
    var subjects = 0;
    var references = 0;
    for (final row in _rows) {
      row.subject
        ..setup()
        ..exercise()
        ..teardown();
      subjects++;
      final reference = row.reference;
      if (reference != null) {
        reference
          ..setup()
          ..exercise()
          ..teardown();
        references++;
      }
    }
    _drainSinks();
    stdout.writeln(
      'smoke OK ($subjectLabel): $subjects subject + $references reference '
      'benchmarks ran',
    );
  }

  // Observe every benchmark's sink so the JIT/AOT compiler cannot prove the
  // inner work was dead. The XOR-and-compare is enough to keep the reads
  // alive; the branch is effectively never taken.
  void _drainSinks() {
    var totalSink = 0;
    for (final row in _rows) {
      totalSink ^= row.subject.sink;
      final reference = row.reference;
      if (reference != null) {
        totalSink ^= reference.sink;
      }
    }
    if (totalSink == 0xDEADBEEF) {
      stderr.writeln('blackhole tripped: $totalSink');
    }
  }

  void _printTable(List<_Result> results, String mode) {
    final hasReference = referenceLabel != null &&
        results.any((r) => r.referenceNsPerOp != null);

    final nameWidth = results
        .map((r) => r.name.length)
        .fold<int>(9, (a, b) => a > b ? a : b);

    stdout.writeln(
      'mode: $mode  os: ${Platform.operatingSystem}  subject: $subjectLabel'
      '${hasReference ? '  reference: $referenceLabel' : ''}',
    );
    stdout.writeln('');

    if (!hasReference) {
      stdout.writeln(
        '${'benchmark'.padRight(nameWidth)}  ${'ns/op'.padLeft(12)}  '
        '${'ops/run'.padLeft(8)}',
      );
      stdout.writeln('${'-' * nameWidth}  ${'-' * 12}  ${'-' * 8}');
      for (final r in results) {
        stdout.writeln(
          '${r.name.padRight(nameWidth)}  '
          '${_formatNs(r.subjectNsPerOp).padLeft(12)}  '
          '${r.opsPerRun.toString().padLeft(8)}',
        );
      }
      return;
    }

    // Paired layout: subject, reference, and the speedup ratio (reference /
    // subject — how many times faster the subject is). Solo rows in a paired
    // catalog leave the reference and ratio columns blank.
    stdout.writeln(
      '${'benchmark'.padRight(nameWidth)}  '
      '${'$subjectLabel ns/op'.padLeft(18)}  '
      '${'$referenceLabel ns/op'.padLeft(20)}  '
      '${'speedup'.padLeft(9)}',
    );
    stdout.writeln(
      '${'-' * nameWidth}  ${'-' * 18}  ${'-' * 20}  ${'-' * 9}',
    );
    for (final r in results) {
      final ref = r.referenceNsPerOp;
      final ratio = ref == null
          ? ''
          : '${(ref / r.subjectNsPerOp).toStringAsFixed(2)}x';
      stdout.writeln(
        '${r.name.padRight(nameWidth)}  '
        '${_formatNs(r.subjectNsPerOp).padLeft(18)}  '
        '${(ref == null ? '' : _formatNs(ref)).padLeft(20)}  '
        '${ratio.padLeft(9)}',
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
        'subject_label': subjectLabel,
        'reference_label': referenceLabel,
      },
      'results': <Object?>[
        for (final r in results)
          <String, Object?>{
            'name': r.name,
            'description': r.description,
            'ops_per_run': r.opsPerRun,
            'subject_ns_per_op': r.subjectNsPerOp,
            'reference_ns_per_op': r.referenceNsPerOp,
          },
      ],
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  }
}

/// Recognized values for `--mode=`. The runner doesn't enforce a closed set so
/// future deployments (dart2js, dart2wasm, flutter-desktop) can pass their own
/// label through without a code change here — but these are the labels the
/// project's tooling currently produces.
const Set<String> _knownModes = <String>{
  'jit',
  'aot',
  'flutter-desktop',
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

String _formatNs(double ns) {
  if (ns < 1000) {
    return '${ns.toStringAsFixed(1)} ns';
  }
  if (ns < 1000000) {
    return '${(ns / 1000).toStringAsFixed(2)} us';
  }
  return '${(ns / 1000000).toStringAsFixed(2)} ms';
}

class _Row {
  _Row({required this.subject, this.reference, this.description = ''});

  final Benchmark subject;
  final Benchmark? reference;
  final String description;
}

class _Result {
  _Result({
    required this.name,
    required this.description,
    required this.opsPerRun,
    required this.subjectNsPerOp,
    required this.referenceNsPerOp,
  });

  final String name;
  final String description;
  final int opsPerRun;
  final double subjectNsPerOp;
  final double? referenceNsPerOp;
}
