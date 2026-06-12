// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'benchmark.dart';

/// One workload in a [Catalog]: a subject benchmark and, optionally, a
/// reference benchmark measuring the same workload via a baseline
/// implementation.
///
/// Both sides are factories (called once per run) rather than instances, so a
/// host that re-runs the suite — a Flutter app behind a button, say — gets
/// fresh `setup` state each time instead of leaking accumulated sink values
/// across runs.
///
/// A [reference] of null marks a solo benchmark: a subject-specific workload
/// the baseline has no equivalent for (structural `Path` equality, which
/// `dart:ui.Path` lacks; or any path workload measured in a pure-Dart host
/// where `dart:ui` cannot run).
class BenchmarkEntry {
  const BenchmarkEntry({
    required this.subject,
    this.reference,
    this.description = '',
  });

  /// Factory for the subject side. The result's name is read from the
  /// instance's [Benchmark.name].
  final Benchmark Function() subject;

  /// Factory for the reference side, or null for a solo benchmark. When
  /// present, it must report the same [Benchmark.opsPerRun] as the subject so
  /// the two ns/op figures are comparable.
  final Benchmark Function()? reference;

  /// One-line explanation of the workload, surfaced in rich hosts (the
  /// Flutter UI). Optional; the CLI runner does not print it.
  final String description;
}

/// A named collection of [BenchmarkEntry]s sharing a subject implementation
/// and (when paired) a single baseline.
///
/// The labels are constant across a suite — every fast_path entry's subject is
/// "fast_path" and every reference is "dart:ui"; every matrix entry's subject
/// is "fast_geometry" and every reference is "vector_math" — so they live here
/// rather than being repeated on each entry.
class Catalog {
  const Catalog({
    required this.subjectLabel,
    this.referenceLabel,
    required this.entries,
  });

  /// Label for the implementation under test, e.g. "fast_path".
  final String subjectLabel;

  /// Label for the baseline, e.g. "dart:ui" or "vector_math". Null when the
  /// catalog has no references in this host.
  final String? referenceLabel;

  final List<BenchmarkEntry> entries;
}
