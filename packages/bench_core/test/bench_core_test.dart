// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:bench_core/bench_core.dart';
import 'package:test/test.dart';

class _CountingBenchmark extends Benchmark {
  _CountingBenchmark(super.name, {this.loop = 1});

  final int loop;
  int runs = 0;

  @override
  int get opsPerRun => loop;

  @override
  void run() {
    runs++;
    double total = 0;
    for (var i = 0; i < loop; i++) {
      total += i * 1.5;
    }
    sink ^= doubleBits(total);
  }
}

void main() {
  group('doubleBits', () {
    test('is a pure reinterpretation of the IEEE-754 bits', () {
      // Distinct doubles map to distinct bit patterns; equal doubles map to
      // equal ones. That is all the blackhole needs: a cheap, deterministic
      // fold that keeps the value observable.
      expect(doubleBits(1.5), equals(doubleBits(1.5)));
      expect(doubleBits(1.5), isNot(equals(doubleBits(2.5))));
    });

    test('distinguishes +0.0 from -0.0', () {
      // The sign bit lives in the raw pattern even though 0.0 == -0.0, so a
      // benchmark accumulating either stays distinguishable to the compiler.
      expect(doubleBits(0.0), isNot(equals(doubleBits(-0.0))));
    });

    test('round-trips a known bit pattern', () {
      // 1.0 is 0x3FF0000000000000 in IEEE-754 double precision.
      expect(doubleBits(1.0), equals(0x3FF0000000000000));
    });
  });

  group('Benchmark', () {
    test('opsPerRun defaults to 1', () {
      expect(_CountingBenchmark('x').opsPerRun, 1);
    });

    test('exercise runs the body once per call', () {
      final bench = _CountingBenchmark('x');
      bench.exercise();
      bench.exercise();
      expect(bench.runs, 2);
    });

    test('accumulates into the sink', () {
      final bench = _CountingBenchmark('x', loop: 100);
      bench.run();
      expect(bench.sink, isNot(0));
    });
  });
}
