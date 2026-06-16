// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';

import 'benchmark_base.dart';

/// A rounded rectangle — curved corners, so `combine` exercises the conic
/// flattener, not just polygon edges.
Path _organicA() => (PathBuilder()
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTRB(0, 0, 100, 100), const Radius.circular(25))))
    .build();

/// An oval overlapping [_organicA] across roughly its lower-right quadrant.
Path _organicB() =>
    (PathBuilder()..addOval(const Rect.fromLTRB(50, 30, 160, 120))).build();

/// 20 [Path.combine] calls per run on a fixed pair of overlapping curved
/// shapes. Each call re-flattens both operands and runs the full sweep (no
/// result caching), so this measures the boolean-op cost end to end.
abstract class _CombineBenchmark extends FastPathBenchmark {
  _CombineBenchmark(super.name, this._op);

  final PathOperation _op;
  late Path _a;
  late Path _b;

  @override
  void setup() {
    _a = _organicA();
    _b = _organicB();
  }

  @override
  void run() {
    var acc = 0;
    for (var i = 0; i < 20; i++) {
      acc ^= Path.combine(_op, _a, _b).getBounds().left.toInt();
    }
    sink ^= acc;
  }

  @override
  int get opsPerRun => 20;
}

/// Union of a rounded rect and an overlapping oval.
class CombineUnionBenchmark extends _CombineBenchmark {
  CombineUnionBenchmark() : super('combine_union', PathOperation.union);
}

/// Intersection of a rounded rect and an overlapping oval.
class CombineIntersectBenchmark extends _CombineBenchmark {
  CombineIntersectBenchmark()
      : super('combine_intersect', PathOperation.intersect);
}

/// Difference of a rounded rect and an overlapping oval.
class CombineDifferenceBenchmark extends _CombineBenchmark {
  CombineDifferenceBenchmark()
      : super('combine_difference', PathOperation.difference);
}

/// Exclusive-or of a rounded rect and an overlapping oval.
class CombineXorBenchmark extends _CombineBenchmark {
  CombineXorBenchmark() : super('combine_xor', PathOperation.xor);
}
