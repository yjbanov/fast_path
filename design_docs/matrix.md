# fast_geometry Matrix Design

This document details the design of the `Matrix` class in `fast_geometry` (originally `package:uimatrix`), a vector math library optimized for 2D use-cases. While general 3D operations are supported, the primary goal is to achieve maximum performance for 2D UI transformations.

## Hypotheses

The design is built on the following hypotheses about vector math usage in typical 2D applications (such as the Flutter framework, engine, and apps using them):

1. **Identity and 2D translations are the most common operations**. Therefore, the object representation must be heavily optimized for these kinds of matrices.
2. **Precision higher than float32/float64 is overkill** for the standard 2D UI use-case.

## Design Principles and Optimizations

Based on these hypotheses, `Matrix` employs several techniques to maximize performance and minimize allocation overhead:

### 1. Monomorphic Object Representation
The `Matrix` class is monomorphic for the fastest possible method and field access. To achieve this without carrying the payload of a full 4x4 matrix for every instance, the common 2D fields are stored inline, while the remaining fields are relegated to a nullable extension object.

The matrix shapes the class needs to be able to represent efficiently are:

```
Identity:
  1  0  0  0
  0  1  0  0
  0  0  1  0
  0  0  0  1

Translation 2D:
  1  0  0  x
  0  1  0  y
  0  0  1  0
  0  0  0  1

General 2D:
  sx k1 0  x
  k2 sy 0  y
  0  0  1  0
  0  0  0  1

Most general case:
  m00(sx) m01(k1) m02(m8) m03(x)
  m10(k2) m11(sy) m12(m9) m13(y)
  m20(m2) m21(m6) m22(sz) m23(z)
  m30(p1) m31(p2) m32(p3) m33(w)
```

```dart
class Matrix {
  final double _m00; // scaleX
  final double _m11; // scaleY
  final double _m03; // dx
  final double _m13; // dy
  final _MatrixExtension? _rest;
}
```

- **Identity and Translation**: `_rest` is `null`. Only 4 inline `double`s are needed.
- **General 2D / 3D**: `_rest` points to a `_MatrixExtension` object containing the other 12 entries.

#### `_MatrixExtension` Structure
The `_MatrixExtension` class holds the remaining 12 components of the 4x4 matrix:

```dart
class _MatrixExtension {
  final double _m01; final double _m02;
  final double _m10; final double _m12;
  final double _m20; final double _m21; final double _m22; final double _m23;
  final double _m30; final double _m31; final double _m32; final double _m33;
}
```

Like `Matrix`, `_MatrixExtension` is deeply immutable. It provides its own primitive operations, such as negation and addition. It also defines a static canonical `_identityExtension` constant used as a fallback when an extension is needed but absent (for example, when multiplying a general matrix with a simple 2D matrix), thereby avoiding unnecessary object allocation during matrix arithmetic.

This representation completely avoids allocating 16-element arrays (like `Float64List(16)`) for common operations, reducing memory footprint and boxing.

### 2. Deep Immutability and Canonicalization
- The `Matrix` class is deeply immutable and `const`.
- Zero and identity matrices are canonicalized. There is exactly one constant instance for the identity matrix (`Matrix.identity`).
- Checking if a matrix is the identity matrix is a trivial, O(1) `identical(this, Matrix.identity)` comparison, which serves as a rapid fast-path in matrix multiplication and transformation loops.

### 3. Lowering Initialization
Matrix initialization always "lowers" to the most specific, simplest matrix kind. 

- If you use the 16-argument `Matrix.transform(...)` constructor but provide values equivalent to a simple 2D scale/translate matrix, it will avoid allocating the extension object and instantiate a simple matrix (with `_rest == null`).
- If a 2D translation matrix is instantiated with `dx == 0` and `dy == 0`, the constructor canonicalizes to the `Matrix.identity` constant.

### 4. Specialized Algorithms
Because the matrix shape is encoded into the object structure (e.g., `_rest == null`), the library can safely dispatch to highly specialized, fast-path algorithms without having to re-derive the shape via costly float comparisons.

The API exposes convenient getters to query these shapes:
- `isTranslation2d`: `_rest == null && _m00 == 1.0 && _m11 == 1.0`
- `isSimple2d`: `_rest == null`
- `isAffine2d`: `_rest == null` or perspective elements are `0, 0, 1`

### 5. Concrete Types
Input types are always the most concrete numeric types (`double`, or typed lists via interop). It avoids varargs, `dynamic` typing, and runtime pattern matching on arguments to ensure peak compilation and execution efficiency.

## Implementation Plan: Fully Featured API

The current `Matrix` implementation is a proof-of-concept. To make it a fully featured 2D-focused library, we must expand its API surface to achieve feature parity with common operations found in libraries like `package:vector_math`'s `Matrix4`. 

Unlike `vector_math` which is mutable, `Matrix` is deeply immutable. Therefore, any operations that would conceptually "mutate" a matrix must instead return a new `Matrix` instance.

### 1. Benchmarking & Correctness Foundation
Before adding new features, we must establish a rigorous foundation for measuring performance and correctness:
- **Benchmark Harness**: Create a generalized benchmark harness capable of comparing `fast_path` against Flutter's `dart:ui`, and `fast_geometry`'s `Matrix` against `package:vector_math`'s `Matrix4`.
- **Baseline Benchmarks**: Write a comprehensive set of benchmarks for all *existing* matrix functionality, comparing it head-to-head with `vector_math`.
- **Skills Update**: Update or add AI guidance skills (similar to the existing `fast_path` skills) to cover both packages. These skills will ensure that all new functionality is implemented correctly, well-tested, and rigorously benchmarked.

### 2. Equality & Debugging
Basic object overrides are currently missing and are essential for testing and UI state comparison.
- `operator ==(Object other)`: Implement a structural equality check (fast-pathing with `identical`).
- `int get hashCode`: Compute a hash over the 16 matrix elements (optimizing for the `_rest == null` case).
- `String toString()`: Output a formatted 4x4 grid representation.

### 3. Factory Constructors
Add factory constructors for common transformations that we currently lack:
- `Matrix.rotationZ(double radians)`
- `Matrix.rotationX(double radians)`
- `Matrix.rotationY(double radians)`
- `Matrix.skew(double alpha, double beta)`
- `Matrix.scale(double sx, [double? sy])` (sy defaults to sx if omitted)
- `Matrix.orthographic(double left, double right, double bottom, double top, double near, double far)`
- `Matrix.perspective(double fovYRadians, double aspectRatio, double zNear, double zFar)`

### 4. Transformation Methods (Composition)
Since the matrix is immutable, we will add methods that compose a new transformation onto the current matrix (`this * new_transform`) and return the result:
- `Matrix translated(double dx, double dy)`
- `Matrix scaled(double sx, [double? sy])`
- `Matrix rotatedZ(double radians)`
- `Matrix skewed(double alpha, double beta)`

### 5. Geometry Transformation
The core utility of a matrix is transforming geometry. We will add methods to transform `fast_geometry` types, utilizing our shape-encoded fast paths:
- `Offset transformPoint(Offset point)`: Fast-paths for `isTranslation2d` and `isSimple2d`.
- `Rect transformRect(Rect rect)`: Transforms the corners and computes the bounding box. Fast-paths for `isSimple2d` (just scale/translate the left/top/right/bottom edges).
- `Offset transformVector(Offset vector)`: Transforms ignoring translation.

### 6. Matrix Operations
- `Matrix transposed()`: Returns a new matrix with the rows and columns swapped.
