// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// A domain-agnostic benchmark harness shared across the workspace.
///
/// Provides the [Benchmark] base (with an anti-DCE [Benchmark.sink] and an
/// [Benchmark.opsPerRun] normalizer), a [Catalog] of subject/reference pairs,
/// and a [BenchmarkRunner] that measures, normalizes to ns/op, drains sinks,
/// and reports as a table or JSON. It knows nothing about paths or matrices.
library;

export 'src/benchmark.dart';
export 'src/catalog.dart';
export 'src/runner.dart';
