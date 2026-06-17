// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// fast_geometry benchmark catalog: the `Matrix` suite paired against
/// `package:vector_math`'s `Matrix4`. Both sides are pure Dart, so the suite
/// runs under `dart run` and AOT with no Flutter host.
///
/// The canonical catalog is [matrixCatalog]; the runner in `bin/run_all.dart`
/// drives it via `tool/bench.sh --suite=geometry`.
library;

export 'src/matrix_catalog.dart';
