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
