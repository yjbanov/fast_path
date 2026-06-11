// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

Path _buildStamp() {
  // A 40-segment mixed source: lines + quads + a conic — the shape a
  // reusable "stamp" path might have.
  final b = PathBuilder()..moveTo(0, 0);
  for (var i = 1; i <= 20; i++) {
    b.lineTo(i * 2.0, (i * 1.7) % 10);
  }
  for (var i = 0; i < 19; i++) {
    b.quadraticBezierTo(40 - i * 2.0, 12 + (i % 3) * 2.0, 38 - i * 2.0, 12);
  }
  b.conicTo(-2, 6, 0, 0, 0.8);
  b.close();
  return b.build();
}

/// 100 [PathBuilder.addPath] stampings per run with varying offsets.
/// Models scattering a reusable icon/marker path across a canvas.
class AddPath100Benchmark extends FastPathBenchmark {
  AddPath100Benchmark() : super('add_path_100');

  late PathBuilder _builder;
  late Path _stamp;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(4200, 10000);
    _stamp = _buildStamp();
  }

  @override
  void run() {
    _builder.reset();
    for (var i = 0; i < 100; i++) {
      _builder.addPath(
        _stamp,
        Offset((i % 10) * 45.0, (i ~/ 10) * 15.0),
      );
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}

/// 100 [PathBuilder.extendWithPath] joins per run. Same workload as
/// [AddPath100Benchmark] but every stamp joins the running contour, so
/// the result is one long connected chain.
class ExtendWithPath100Benchmark extends FastPathBenchmark {
  ExtendWithPath100Benchmark() : super('extend_with_path_100');

  late PathBuilder _builder;
  late Path _stamp;

  @override
  void setup() {
    _builder = PathBuilder()..reserve(4200, 10000);
    _stamp = _buildStamp();
  }

  @override
  void run() {
    _builder
      ..reset()
      ..moveTo(0, 0);
    for (var i = 0; i < 100; i++) {
      _builder.extendWithPath(
        _stamp,
        Offset((i % 10) * 45.0, (i ~/ 10) * 15.0),
      );
    }
    final path = _builder.build();
    sink ^= path.fillType.index;
  }
}
