// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

// Guards the matrix benchmark suite itself: every entry must run without
// throwing and must leave its anti-DCE sink observable. This is what keeps the
// suite honest — a benchmark whose result is dead-code-eliminated would leave
// sink == 0 and measure nothing (the defect that motivated bench_core). It
// also exercises the catalog wiring so a broken pair fails CI, not a manual
// bench run.

import 'package:fast_geometry_bench/matrix_benchmarks.dart';
import 'package:test/test.dart';

void main() {
  final catalog = matrixCatalog();

  test('catalog pairs every entry against a vector_math reference', () {
    expect(catalog.subjectLabel, 'fast_geometry');
    expect(catalog.referenceLabel, 'vector_math');
    expect(catalog.entries, isNotEmpty);
    // Matrix is always comparable to Matrix4 — no solo entries here.
    expect(catalog.entries.every((e) => e.reference != null), isTrue);
  });

  group('every benchmark is observable (no dead-code elimination)', () {
    for (final entry in catalog.entries) {
      final subject = entry.subject();
      test('${subject.name} — subject', () {
        subject.setup();
        subject.run();
        subject.teardown();
        expect(subject.sink, isNot(0),
            reason: 'subject result was eliminated; sink stayed 0');
      });

      test('${subject.name} — reference', () {
        final reference = entry.reference!();
        reference.setup();
        reference.run();
        reference.teardown();
        expect(reference.sink, isNot(0),
            reason: 'reference result was eliminated; sink stayed 0');
      });
    }
  });
}
