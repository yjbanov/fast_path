// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'package:fast_geometry/fast_geometry.dart';
import 'package:vector_math/vector_math_64.dart';
import 'harness.dart';

const int N = 10000;

Future<void> main() async {
  benchmarkHarness = BenchmarkHarness(printer: TsvResultsPrinter());

  group('Harness overhead', () {
    benchmark('Empty benchmark', () {
      return null;
    }, postCompute: (Object? result) {});

    benchmark('Iteration', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += i;
      }
      return total;
    });
  });

  group('Instantiation', () {
    benchmark('Identity (Matrix4)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += Matrix4.identity().storage[0];
      }
      return total;
    });

    benchmark('Identity (Matrix)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += Matrix.identity.scaleX;
      }
      return total;
    });

    benchmark('2D translation (Matrix4)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += Matrix4.translationValues(0.4, 3.45, 0).storage[0];
      }
      return total;
    });

    benchmark('2D translation (Matrix)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += Matrix.translation2d(dx: 0.4, dy: 3.45).scaleX;
      }
      return total;
    });

    benchmark('Simple 2D (Matrix4)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += (Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0)).storage[0];
      }
      return total;
    });

    benchmark('Simple 2D (Matrix)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45).scaleX;
      }
      return total;
    });

    benchmark('Complex (Matrix4)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        total += (Matrix4.identity()
          ..rotateZ(0.1)
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)).storage[0];
      }
      return total;
    });

    benchmark('Complex (Matrix)', () {
      double total = 0;
      for (int i = 0; i < N; i++) {
        final cosAngle = math.cos(0.1);
        final sinAngle = math.sin(0.1);
        total += Matrix.transform2d(
          scaleX: cosAngle,
          scaleY: cosAngle,
          k1: -sinAngle,
          k2: sinAngle,
          dx: 0.4,
          dy: 3.45,
        ).scaleX;
      }
      return total;
    });
  });

  group('Multiplication', () {
    late Matrix a;
    late Matrix b;
    late Matrix4 a4;
    late Matrix4 b4;

    benchmark(
      'Identity x Identity (Matrix4)',
      setup: () {
        a4 = Matrix4.identity();
        b4 = Matrix4.identity();
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 * b4 as Matrix4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Identity x Identity (Matrix)',
      setup: () {
        a = Matrix.identity;
        b = Matrix.identity;
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a * b).scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D x Identity (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
        b4 = Matrix4.identity();
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 * b4 as Matrix4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D x Identity (Matrix)',
      setup: () {
        a = Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
        b = Matrix.identity;
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a * b).scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D x Simple 2D (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
        b4 = Matrix4.identity()
          ..translateByDouble(0.5, 3.46, 0.0, 1.0)
          ..scaleByDouble(1.7, 2.8, 1.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 * b4 as Matrix4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D x Simple 2D (Matrix)',
      setup: () {
        a = Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
        b = Matrix.simple2d(scaleX: 1.3, scaleY: 2.4, dx: 0.5, dy: 3.46);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a * b).scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Complex x Complex (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..rotateZ(0.1)
          ..translateByDouble(0.4, 3.45, 0.0, 1.0);
        b4 = Matrix4.identity()
          ..rotateZ(0.2)
          ..translateByDouble(0.3, 3.44, 0.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 * b4 as Matrix4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Complex x Complex (Matrix)',
      setup: () {
        a = Matrix.transform2d(
          scaleX: math.cos(0.1),
          scaleY: math.cos(0.1),
          k1: -math.sin(0.1),
          k2: math.sin(0.1),
          dx: 0.4,
          dy: 3.45,
        );
        b = Matrix.transform2d(
          scaleX: math.cos(0.2),
          scaleY: math.cos(0.2),
          k1: -math.sin(0.2),
          k2: math.sin(0.2),
          dx: 0.4,
          dy: 3.45,
        );
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a * b).scaleX;
        }
        return total;
      },
    );
  });

  group('Addition', () {
    late Matrix a;
    late Matrix b;
    late Matrix4 a4;
    late Matrix4 b4;

    benchmark(
      'Identity + Identity (Matrix4)',
      setup: () {
        a4 = Matrix4.identity();
        b4 = Matrix4.identity();
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 + b4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Identity + Identity (Matrix)',
      setup: () {
        a = Matrix.identity;
        b = Matrix.identity;
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a + b).scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D + Identity (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
        b4 = Matrix4.identity();
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 + b4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D + Identity (Matrix)',
      setup: () {
        a = Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
        b = Matrix.identity;
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a + b).scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D + Simple 2D (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
        b4 = Matrix4.identity()
          ..translateByDouble(0.5, 3.46, 0.0, 1.0)
          ..scaleByDouble(1.7, 2.8, 1.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 + b4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D + Simple 2D (Matrix)',
      setup: () {
        a = Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
        b = Matrix.simple2d(scaleX: 1.3, scaleY: 2.4, dx: 0.5, dy: 3.46);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a + b).scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Complex + Complex (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..rotateZ(0.1)
          ..translateByDouble(0.4, 3.45, 0.0, 1.0);
        b4 = Matrix4.identity()
          ..rotateZ(0.2)
          ..translateByDouble(0.3, 3.44, 0.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a4 + b4).storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Complex + Complex (Matrix)',
      setup: () {
        a = Matrix.transform2d(
          scaleX: math.cos(0.1),
          scaleY: math.cos(0.1),
          k1: -math.sin(0.1),
          k2: math.sin(0.1),
          dx: 0.4,
          dy: 3.45,
        );
        b = Matrix.transform2d(
          scaleX: math.cos(0.2),
          scaleY: math.cos(0.2),
          k1: -math.sin(0.2),
          k2: math.sin(0.2),
          dx: 0.4,
          dy: 3.45,
        );
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += (a + b).scaleX;
        }
        return total;
      },
    );
  });

  group('Inversion', () {
    late Matrix a;
    late Matrix4 a4;

    benchmark(
      'Identity (Matrix4)',
      setup: () {
        a4 = Matrix4.identity();
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          final Matrix4 m = Matrix4.zero()..copyInverse(a4);
          total += m.storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Identity (Matrix)',
      setup: () {
        a = Matrix.identity;
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a.invert()!.scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          final Matrix4 m = Matrix4.zero()..copyInverse(a4);
          total += m.storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D (Matrix)',
      setup: () {
        a = Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a.invert()!.scaleX;
        }
        return total;
      },
    );

    benchmark(
      'Complex (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..rotateZ(0.1)
          ..translateByDouble(0.4, 3.45, 0.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          final Matrix4 m = Matrix4.zero()..copyInverse(a4);
          total += m.storage[0];
        }
        return total;
      },
    );

    benchmark(
      'Complex (Matrix)',
      setup: () {
        a = Matrix.transform2d(
          scaleX: math.cos(0.1),
          scaleY: math.cos(0.1),
          k1: -math.sin(0.1),
          k2: math.sin(0.1),
          dx: 0.4,
          dy: 3.45,
        );
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a.invert()!.scaleX;
        }
        return total;
      },
    );
  });

  group('Determinant', () {
    late Matrix a;
    late Matrix4 a4;

    benchmark(
      'Identity (Matrix4)',
      setup: () {
        a4 = Matrix4.identity();
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a4.determinant();
        }
        return total;
      },
    );

    benchmark(
      'Identity (Matrix)',
      setup: () {
        a = Matrix.identity;
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a.determinant();
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..translateByDouble(0.4, 3.45, 0.0, 1.0)
          ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a4.determinant();
        }
        return total;
      },
    );

    benchmark(
      'Simple 2D (Matrix)',
      setup: () {
        a = Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a.determinant();
        }
        return total;
      },
    );

    benchmark(
      'Complex (Matrix4)',
      setup: () {
        a4 = Matrix4.identity()
          ..rotateZ(0.1)
          ..translateByDouble(0.4, 3.45, 0.0, 1.0);
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a4.determinant();
        }
        return total;
      },
    );

    benchmark(
      'Complex (Matrix)',
      setup: () {
        a = Matrix.transform2d(
          scaleX: math.cos(0.1),
          scaleY: math.cos(0.1),
          k1: -math.sin(0.1),
          k2: math.sin(0.1),
          dx: 0.4,
          dy: 3.45,
        );
      },
      () {
        double total = 0;
        for (int i = 0; i < N; i++) {
          total += a.determinant();
        }
        return total;
      },
    );
  });

  await benchmarkHarness.run();
}