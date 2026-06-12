// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:bench_core/bench_core.dart';

/// Base class for all fast_path benchmarks.
///
/// An alias for the workspace-shared [Benchmark] — the anti-DCE [sink], the
/// [opsPerRun] normalizer, and the `exercise => run` adjustment all live in
/// `bench_core` now. The name is retained because the path benchmarks (and the
/// Flutter-hosted catalog) refer to it widely.
typedef FastPathBenchmark = Benchmark;
