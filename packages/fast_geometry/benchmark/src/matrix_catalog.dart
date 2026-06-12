// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;

import 'package:bench_core/bench_core.dart';
import 'package:fast_geometry/fast_geometry.dart';
import 'package:vector_math/vector_math_64.dart';

/// Internal loop count per `run`. Matrix operations are nanosecond-scale, so
/// each benchmark loops this many times internally and declares the count via
/// [Benchmark.opsPerRun]; the runner then normalizes to ns/op. This keeps the
/// timing resolution well above the harness floor.
const int _n = 10000;

/// Base for a matrix microbenchmark: loop [step] [_n] times, accumulate the
/// result as a double, and fold its bits into the anti-DCE [sink].
///
/// [step] is a virtual call rather than a closure so the JIT can devirtualize
/// and inline it (each instance is monomorphic), preserving the fidelity of
/// the original hand-inlined loops while keeping this file compact.
abstract class _LoopBench extends Benchmark {
  _LoopBench(super.name);

  @override
  int get opsPerRun => _n;

  @override
  void run() {
    var total = 0.0;
    for (var i = 0; i < _n; i++) {
      total += step();
    }
    sink ^= doubleBits(total);
  }

  /// One operation; returns an observable scalar derived from the result.
  double step();
}

// --------------------------------------------------------------------------
// Operand builders. Subject (fast_geometry Matrix) and reference (vector_math
// Matrix4) sides build the same conceptual matrices so the comparison is fair.
// Built once per benchmark in setup(), never on the hot path.
// --------------------------------------------------------------------------

Matrix _mIdentity() => Matrix.identity;
Matrix _mSimpleA() =>
    Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45);
Matrix _mSimpleB() =>
    Matrix.simple2d(scaleX: 1.3, scaleY: 2.4, dx: 0.5, dy: 3.46);
Matrix _mComplexA() => Matrix.transform2d(
      scaleX: math.cos(0.1),
      scaleY: math.cos(0.1),
      k1: -math.sin(0.1),
      k2: math.sin(0.1),
      dx: 0.4,
      dy: 3.45,
    );
Matrix _mComplexB() => Matrix.transform2d(
      scaleX: math.cos(0.2),
      scaleY: math.cos(0.2),
      k1: -math.sin(0.2),
      k2: math.sin(0.2),
      dx: 0.3,
      dy: 3.44,
    );

Matrix4 _m4Identity() => Matrix4.identity();
Matrix4 _m4SimpleA() => Matrix4.identity()
  ..translateByDouble(0.4, 3.45, 0.0, 1.0)
  ..scaleByDouble(1.2, 2.3, 1.0, 1.0);
Matrix4 _m4SimpleB() => Matrix4.identity()
  ..translateByDouble(0.5, 3.46, 0.0, 1.0)
  ..scaleByDouble(1.3, 2.4, 1.0, 1.0);
Matrix4 _m4ComplexA() => Matrix4.identity()
  ..rotateZ(0.1)
  ..translateByDouble(0.4, 3.45, 0.0, 1.0);
Matrix4 _m4ComplexB() => Matrix4.identity()
  ..rotateZ(0.2)
  ..translateByDouble(0.3, 3.44, 0.0, 1.0);

// --------------------------------------------------------------------------
// Instantiation. The constructed shape varies per case, so each is inlined in
// its own step() rather than parametrized by a per-op closure.
// --------------------------------------------------------------------------

class _InstMIdentity extends _LoopBench {
  _InstMIdentity() : super('Instantiate: identity');
  @override
  double step() => Matrix.identity.scaleX;
}

class _InstM4Identity extends _LoopBench {
  _InstM4Identity() : super('Instantiate: identity');
  @override
  double step() => Matrix4.identity().storage[0];
}

class _InstMTranslation extends _LoopBench {
  _InstMTranslation() : super('Instantiate: 2D translation');
  @override
  double step() => Matrix.translation2d(dx: 0.4, dy: 3.45).scaleX;
}

class _InstM4Translation extends _LoopBench {
  _InstM4Translation() : super('Instantiate: 2D translation');
  @override
  double step() => Matrix4.translationValues(0.4, 3.45, 0.0).storage[0];
}

class _InstMSimple extends _LoopBench {
  _InstMSimple() : super('Instantiate: simple 2D');
  @override
  double step() =>
      Matrix.simple2d(scaleX: 1.2, scaleY: 2.3, dx: 0.4, dy: 3.45).scaleX;
}

class _InstM4Simple extends _LoopBench {
  _InstM4Simple() : super('Instantiate: simple 2D');
  @override
  double step() => (Matrix4.identity()
        ..translateByDouble(0.4, 3.45, 0.0, 1.0)
        ..scaleByDouble(1.2, 2.3, 1.0, 1.0))
      .storage[0];
}

class _InstMComplex extends _LoopBench {
  _InstMComplex() : super('Instantiate: complex (rotate+translate)');
  @override
  double step() {
    // Trig is included on both sides: the reference's rotateZ computes it too.
    final c = math.cos(0.1);
    final s = math.sin(0.1);
    return Matrix.transform2d(
      scaleX: c,
      scaleY: c,
      k1: -s,
      k2: s,
      dx: 0.4,
      dy: 3.45,
    ).scaleX;
  }
}

class _InstM4Complex extends _LoopBench {
  _InstM4Complex() : super('Instantiate: complex (rotate+translate)');
  @override
  double step() => (Matrix4.identity()
        ..rotateZ(0.1)
        ..translateByDouble(0.4, 3.45, 0.0, 1.0))
      .storage[0];
}

// --------------------------------------------------------------------------
// Binary and unary operations. Operands vary by case but the operation is
// fixed, so one class per operation/side takes an operand builder run once in
// setup(); the hot loop is free of closures.
// --------------------------------------------------------------------------

class _MatrixMul extends _LoopBench {
  _MatrixMul(super.name, this._build);
  final (Matrix, Matrix) Function() _build;
  late Matrix _a;
  late Matrix _b;
  @override
  void setup() {
    final (a, b) = _build();
    _a = a;
    _b = b;
  }
  @override
  double step() => (_a * _b).scaleX;
}

class _Matrix4Mul extends _LoopBench {
  _Matrix4Mul(super.name, this._build);
  final (Matrix4, Matrix4) Function() _build;
  late Matrix4 _a;
  late Matrix4 _b;
  @override
  void setup() {
    final (a, b) = _build();
    _a = a;
    _b = b;
  }
  @override
  double step() => (_a * _b as Matrix4).storage[0];
}

class _MatrixAdd extends _LoopBench {
  _MatrixAdd(super.name, this._build);
  final (Matrix, Matrix) Function() _build;
  late Matrix _a;
  late Matrix _b;
  @override
  void setup() {
    final (a, b) = _build();
    _a = a;
    _b = b;
  }
  @override
  double step() => (_a + _b).scaleX;
}

class _Matrix4Add extends _LoopBench {
  _Matrix4Add(super.name, this._build);
  final (Matrix4, Matrix4) Function() _build;
  late Matrix4 _a;
  late Matrix4 _b;
  @override
  void setup() {
    final (a, b) = _build();
    _a = a;
    _b = b;
  }
  @override
  double step() => (_a + _b).storage[0];
}

class _MatrixInvert extends _LoopBench {
  _MatrixInvert(super.name, this._build);
  final Matrix Function() _build;
  late Matrix _a;
  @override
  void setup() => _a = _build();
  @override
  double step() => _a.invert()!.scaleX;
}

class _Matrix4Invert extends _LoopBench {
  _Matrix4Invert(super.name, this._build);
  final Matrix4 Function() _build;
  late Matrix4 _a;
  @override
  void setup() => _a = _build();
  @override
  double step() => (Matrix4.zero()..copyInverse(_a)).storage[0];
}

class _MatrixDet extends _LoopBench {
  _MatrixDet(super.name, this._build);
  final Matrix Function() _build;
  late Matrix _a;
  @override
  void setup() => _a = _build();
  @override
  double step() => _a.determinant();
}

class _Matrix4Det extends _LoopBench {
  _Matrix4Det(super.name, this._build);
  final Matrix4 Function() _build;
  late Matrix4 _a;
  @override
  void setup() => _a = _build();
  @override
  double step() => _a.determinant();
}

/// The matrix benchmark catalog: fast_geometry's [Matrix] as the subject,
/// `package:vector_math`'s `Matrix4` as the reference baseline.
Catalog matrixCatalog() => Catalog(
      subjectLabel: 'fast_geometry',
      referenceLabel: 'vector_math',
      entries: <BenchmarkEntry>[
        // Instantiation.
        const BenchmarkEntry(
          subject: _InstMIdentity.new,
          reference: _InstM4Identity.new,
          description: 'Construct an identity matrix and read one entry.',
        ),
        const BenchmarkEntry(
          subject: _InstMTranslation.new,
          reference: _InstM4Translation.new,
          description: 'Construct a 2D translation matrix.',
        ),
        const BenchmarkEntry(
          subject: _InstMSimple.new,
          reference: _InstM4Simple.new,
          description: 'Construct a scale + translation (simple 2D) matrix.',
        ),
        const BenchmarkEntry(
          subject: _InstMComplex.new,
          reference: _InstM4Complex.new,
          description: 'Construct a rotation + translation matrix (incl. trig).',
        ),

        // Multiplication.
        BenchmarkEntry(
          subject: () =>
              _MatrixMul('Multiply: identity × identity', () => (_mIdentity(), _mIdentity())),
          reference: () => _Matrix4Mul(
              'Multiply: identity × identity', () => (_m4Identity(), _m4Identity())),
        ),
        BenchmarkEntry(
          subject: () =>
              _MatrixMul('Multiply: simple × identity', () => (_mSimpleA(), _mIdentity())),
          reference: () => _Matrix4Mul(
              'Multiply: simple × identity', () => (_m4SimpleA(), _m4Identity())),
        ),
        BenchmarkEntry(
          subject: () =>
              _MatrixMul('Multiply: simple × simple', () => (_mSimpleA(), _mSimpleB())),
          reference: () => _Matrix4Mul(
              'Multiply: simple × simple', () => (_m4SimpleA(), _m4SimpleB())),
        ),
        BenchmarkEntry(
          subject: () =>
              _MatrixMul('Multiply: complex × complex', () => (_mComplexA(), _mComplexB())),
          reference: () => _Matrix4Mul(
              'Multiply: complex × complex', () => (_m4ComplexA(), _m4ComplexB())),
        ),

        // Addition.
        BenchmarkEntry(
          subject: () =>
              _MatrixAdd('Add: identity + identity', () => (_mIdentity(), _mIdentity())),
          reference: () => _Matrix4Add(
              'Add: identity + identity', () => (_m4Identity(), _m4Identity())),
        ),
        BenchmarkEntry(
          subject: () =>
              _MatrixAdd('Add: simple + identity', () => (_mSimpleA(), _mIdentity())),
          reference: () => _Matrix4Add(
              'Add: simple + identity', () => (_m4SimpleA(), _m4Identity())),
        ),
        BenchmarkEntry(
          subject: () =>
              _MatrixAdd('Add: simple + simple', () => (_mSimpleA(), _mSimpleB())),
          reference: () =>
              _Matrix4Add('Add: simple + simple', () => (_m4SimpleA(), _m4SimpleB())),
        ),
        BenchmarkEntry(
          subject: () =>
              _MatrixAdd('Add: complex + complex', () => (_mComplexA(), _mComplexB())),
          reference: () => _Matrix4Add(
              'Add: complex + complex', () => (_m4ComplexA(), _m4ComplexB())),
        ),

        // Inversion.
        BenchmarkEntry(
          subject: () => _MatrixInvert('Invert: identity', _mIdentity),
          reference: () => _Matrix4Invert('Invert: identity', _m4Identity),
        ),
        BenchmarkEntry(
          subject: () => _MatrixInvert('Invert: simple 2D', _mSimpleA),
          reference: () => _Matrix4Invert('Invert: simple 2D', _m4SimpleA),
        ),
        BenchmarkEntry(
          subject: () => _MatrixInvert('Invert: complex', _mComplexA),
          reference: () => _Matrix4Invert('Invert: complex', _m4ComplexA),
        ),

        // Determinant.
        BenchmarkEntry(
          subject: () => _MatrixDet('Determinant: identity', _mIdentity),
          reference: () => _Matrix4Det('Determinant: identity', _m4Identity),
        ),
        BenchmarkEntry(
          subject: () => _MatrixDet('Determinant: simple 2D', _mSimpleA),
          reference: () => _Matrix4Det('Determinant: simple 2D', _m4SimpleA),
        ),
        BenchmarkEntry(
          subject: () => _MatrixDet('Determinant: complex', _mComplexA),
          reference: () => _Matrix4Det('Determinant: complex', _m4ComplexA),
        ),
      ],
    );
