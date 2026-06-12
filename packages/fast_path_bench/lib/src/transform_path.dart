// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:typed_data';

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// 1000 affine [Path.transform] calls per run against a 200-segment
/// path. The common case — scale/rotate/translate a cached shape. Uses
/// a rotation+scale matrix (affine fast path, no per-point divide).
class TransformPath1kBenchmark extends FastPathBenchmark {
  TransformPath1kBenchmark() : super('transform_path_1k');

  late Path _path;
  late Float64List _matrix;

  @override
  void setup() {
    final b = PathBuilder()..moveTo(0, 0);
    for (var i = 1; i < 200; i++) {
      b.lineTo(i.toDouble(), (i * 1.7) % 50);
    }
    b.close();
    _path = b.build();
    // Rotate 30° and scale 1.5 — a representative affine transform.
    const c = 0.8660254037844387 * 1.5; // cos30 * 1.5
    const s = 0.5 * 1.5; // sin30 * 1.5
    _matrix = Float64List.fromList([
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      3, 7, 0, 1,
    ]);
  }

  @override
  void run() {
    var acc = 0;
    for (var i = 0; i < 1000; i++) {
      final transformed = _path.transform(_matrix);
      acc ^= transformed.getBounds().left.toInt();
    }
    sink ^= acc;
  }

  @override
  int get opsPerRun => 1000;
}
