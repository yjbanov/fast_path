// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'geometry.dart';

/// An immutable 4x4 transformation matrix optimized for 2D use.
///
/// The representation is monomorphic and shape-encoded. The full 2D-affine
/// block — the 2x2 linear part plus the 2D translation — is stored inline in
/// six doubles (`_m00, _m01, _m10, _m11, _m03, _m13`). The remaining ten
/// entries (the 3D / perspective tail) live in a nullable [_MatrixExtension];
/// for any 2D-affine matrix (identity, translation, scale, rotation, skew, and
/// their compositions) that extension is null, so no auxiliary object is
/// allocated and the fast paths read only inline fields.
///
/// Construction lowers every matrix to its most specific shape, so equal
/// transforms always share the same representation (see [operator ==]).
@immutable
final class Matrix {
  /// The identity transform.
  ///
  ///     1  0  0  0
  ///     0  1  0  0
  ///     0  0  1  0
  ///     0  0  0  1
  static const Matrix identity =
      Matrix._(m00: 1, m01: 0, m10: 0, m11: 1, m03: 0, m13: 0);

  /// Instantiates a 2D translation matrix.
  ///
  ///     1  0  0  dx
  ///     0  1  0  dy
  ///     0  0  1  0
  ///     0  0  0  1
  ///
  /// If both [dx] and [dy] are zero, returns the [identity] constant.
  static Matrix translation2d({required double dx, required double dy}) {
    if (dx == 0 && dy == 0) {
      return identity;
    }
    return Matrix._(m00: 1, m01: 0, m10: 0, m11: 1, m03: dx, m13: dy);
  }

  /// Instantiates a 2D transformation that includes scaling and translation.
  ///
  ///     sx 0  0  dx
  ///     0  sy 0  dy
  ///     0  0  1  0
  ///     0  0  0  1
  ///
  /// If both scales are 1, lowers to [translation2d].
  static Matrix simple2d({
    required double scaleX,
    required double scaleY,
    required double dx,
    required double dy,
  }) {
    if (scaleX == 1 && scaleY == 1) {
      return Matrix.translation2d(dx: dx, dy: dy);
    }
    return Matrix._(m00: scaleX, m01: 0, m10: 0, m11: scaleY, m03: dx, m13: dy);
  }

  /// Instantiates a general 2D-affine transform matrix.
  ///
  ///     sx k1 0  dx
  ///     k2 sy 0  dy
  ///     0  0  1  0
  ///     0  0  0  1
  ///
  /// If [k1] and [k2] are both zero, lowers to [simple2d] (and possibly
  /// further to [translation2d] / [identity]). The result never allocates an
  /// extension — the entire 2D-affine block is inline.
  static Matrix transform2d({
    required double scaleX,
    required double scaleY,
    required double dx,
    required double dy,
    required double k1,
    required double k2,
  }) {
    if (k1 == 0 && k2 == 0) {
      return Matrix.simple2d(scaleX: scaleX, scaleY: scaleY, dx: dx, dy: dy);
    }
    return Matrix._(
        m00: scaleX, m01: k1, m10: k2, m11: scaleY, m03: dx, m13: dy);
  }

  /// Instantiates a general 3D transform matrix from its 16 components.
  ///
  ///     m00 m01 m02 m03
  ///     m10 m11 m12 m13
  ///     m20 m21 m22 m23
  ///     m30 m31 m32 m33
  ///
  /// Lowers to a 2D-affine matrix (no extension) when the 3D tail is the
  /// identity tail, and further to [simple2d] / [translation2d] / [identity]
  /// where applicable.
  static Matrix transform({
    required double m00,
    required double m01,
    required double m02,
    required double m03,
    required double m10,
    required double m11,
    required double m12,
    required double m13,
    required double m20,
    required double m21,
    required double m22,
    required double m23,
    required double m30,
    required double m31,
    required double m32,
    required double m33,
  }) {
    // Lower to 2D affine if the 3D tail is the identity tail:
    //     *  *  0  *
    //     *  *  0  *
    //     0  0  1  0
    //     0  0  0  1
    if (m02 == 0 &&
        m12 == 0 &&
        m20 == 0 &&
        m21 == 0 &&
        m22 == 1 &&
        m23 == 0 &&
        m30 == 0 &&
        m31 == 0 &&
        m32 == 0 &&
        m33 == 1) {
      return Matrix.transform2d(
        scaleX: m00,
        scaleY: m11,
        dx: m03,
        dy: m13,
        k1: m01,
        k2: m10,
      );
    }

    return Matrix._(
      m00: m00,
      m01: m01,
      m10: m10,
      m11: m11,
      m03: m03,
      m13: m13,
      rest: _MatrixExtension(
        m02: m02,
        m12: m12,
        m20: m20,
        m21: m21,
        m22: m22,
        m23: m23,
        m30: m30,
        m31: m31,
        m32: m32,
        m33: m33,
      ),
    );
  }

  /// A 2D rotation about the Z axis by [radians] (counterclockwise).
  ///
  /// Lowers to [identity] when [radians] is a multiple of 2π. Numerically
  /// matches `Matrix4.rotationZ`.
  static Matrix rotationZ(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    return Matrix.transform2d(
        scaleX: c, scaleY: c, k1: -s, k2: s, dx: 0, dy: 0);
  }

  /// A rotation about the X axis by [radians]. Numerically matches
  /// `Matrix4.rotationX`.
  static Matrix rotationX(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    return Matrix.transform(
      m00: 1, m01: 0, m02: 0, m03: 0,
      m10: 0, m11: c, m12: -s, m13: 0,
      m20: 0, m21: s, m22: c, m23: 0,
      m30: 0, m31: 0, m32: 0, m33: 1,
    );
  }

  /// A rotation about the Y axis by [radians]. Numerically matches
  /// `Matrix4.rotationY`.
  static Matrix rotationY(double radians) {
    final double c = math.cos(radians);
    final double s = math.sin(radians);
    return Matrix.transform(
      m00: c, m01: 0, m02: s, m03: 0,
      m10: 0, m11: 1, m12: 0, m13: 0,
      m20: -s, m21: 0, m22: c, m23: 0,
      m30: 0, m31: 0, m32: 0, m33: 1,
    );
  }

  /// A 2D skew. [alpha] skews the x axis, [beta] the y axis; each angle's
  /// tangent becomes the corresponding off-diagonal term, matching
  /// `Matrix4.skew`. Lowers to [identity] when both angles are 0.
  static Matrix skew(double alpha, double beta) {
    return Matrix.transform2d(
      scaleX: 1,
      scaleY: 1,
      k1: math.tan(alpha),
      k2: math.tan(beta),
      dx: 0,
      dy: 0,
    );
  }

  /// A 2D scale. [sy] defaults to [sx] (uniform scale). Lowers to [identity]
  /// when both factors are 1.
  static Matrix scale(double sx, [double? sy]) {
    return Matrix.simple2d(scaleX: sx, scaleY: sy ?? sx, dx: 0, dy: 0);
  }

  /// An orthographic projection matrix. Numerically matches vector_math's
  /// `makeOrthographicMatrix`.
  static Matrix orthographic(
    double left,
    double right,
    double bottom,
    double top,
    double near,
    double far,
  ) {
    final double rml = right - left;
    final double tmb = top - bottom;
    final double fmn = far - near;
    return Matrix.transform(
      m00: 2.0 / rml, m01: 0, m02: 0, m03: -(right + left) / rml,
      m10: 0, m11: 2.0 / tmb, m12: 0, m13: -(top + bottom) / tmb,
      m20: 0, m21: 0, m22: -2.0 / fmn, m23: -(far + near) / fmn,
      m30: 0, m31: 0, m32: 0, m33: 1,
    );
  }

  /// A perspective projection matrix. [fovYRadians] is the vertical field of
  /// view. Numerically matches vector_math's `makePerspectiveMatrix`. The
  /// result is not affine (it has a perspective tail), so [isAffine2d] is
  /// false.
  static Matrix perspective(
    double fovYRadians,
    double aspectRatio,
    double zNear,
    double zFar,
  ) {
    final double height = 1.0 / math.tan(fovYRadians * 0.5);
    final double width = height / aspectRatio;
    final double nearMinusFar = zNear - zFar;
    return Matrix.transform(
      m00: width, m01: 0, m02: 0, m03: 0,
      m10: 0, m11: height, m12: 0, m13: 0,
      m20: 0, m21: 0,
      m22: (zFar + zNear) / nearMinusFar,
      m23: 2.0 * zNear * zFar / nearMinusFar,
      m30: 0, m31: 0, m32: -1, m33: 0,
    );
  }

  const Matrix._({
    required double m00,
    required double m01,
    required double m10,
    required double m11,
    required double m03,
    required double m13,
    _MatrixExtension? rest,
  })  : _m00 = m00,
        _m01 = m01,
        _m10 = m10,
        _m11 = m11,
        _m03 = m03,
        _m13 = m13,
        _rest = rest;

  // The full 2D-affine block, stored inline.
  final double _m00;
  final double _m01;
  final double _m10;
  final double _m11;
  final double _m03;
  final double _m13;

  // The 3D / perspective tail; null for any 2D-affine matrix.
  final _MatrixExtension? _rest;

  double get scaleX => _m00;
  double get scaleY => _m11;
  double get dx => _m03;
  double get dy => _m13;

  /// Whether this matrix is a pure 2D translation.
  bool get isTranslation2d =>
      _rest == null && _m00 == 1.0 && _m11 == 1.0 && _m01 == 0.0 && _m10 == 0.0;

  /// Whether this matrix is a simple 2D scale and/or translation (no shear or
  /// rotation).
  bool get isSimple2d => _rest == null && _m01 == 0.0 && _m10 == 0.0;

  /// Whether this matrix is 2D affine (requires no perspective divide for 2D
  /// points). True for every matrix with no extension, and for an extension
  /// whose bottom row is `(0, 0, _, 1)`.
  bool get isAffine2d =>
      _rest == null ||
      (_rest._m30 == 0.0 && _rest._m31 == 0.0 && _rest._m33 == 1.0);

  double get m00 => _m00;
  double get m01 => _m01;
  double get m02 => _rest?._m02 ?? 0.0;
  double get m03 => _m03;

  double get m10 => _m10;
  double get m11 => _m11;
  double get m12 => _rest?._m12 ?? 0.0;
  double get m13 => _m13;

  double get m20 => _rest?._m20 ?? 0.0;
  double get m21 => _rest?._m21 ?? 0.0;
  double get m22 => _rest?._m22 ?? 1.0;
  double get m23 => _rest?._m23 ?? 0.0;

  double get m30 => _rest?._m30 ?? 0.0;
  double get m31 => _rest?._m31 ?? 0.0;
  double get m32 => _rest?._m32 ?? 0.0;
  double get m33 => _rest?._m33 ?? 1.0;

  /// Computes a matrix equal to the element-wise negation of `this`.
  Matrix operator -() {
    return Matrix.transform(
      m00: -m00, m01: -m01, m02: -m02, m03: -m03,
      m10: -m10, m11: -m11, m12: -m12, m13: -m13,
      m20: -m20, m21: -m21, m22: -m22, m23: -m23,
      m30: -m30, m31: -m31, m32: -m32, m33: -m33,
    );
  }

  /// Computes the element-wise sum `this` + [other].
  Matrix operator +(Matrix other) {
    if (_rest == null && other._rest == null) {
      // Two 2D-affine matrices: the affine block adds inline, and the implicit
      // identity tails (m22 == m33 == 1 on each) sum to a fixed (m22 = m33 = 2)
      // tail — a shared constant, so no extension is allocated here.
      return Matrix._(
        m00: _m00 + other._m00,
        m01: _m01 + other._m01,
        m10: _m10 + other._m10,
        m11: _m11 + other._m11,
        m03: _m03 + other._m03,
        m13: _m13 + other._m13,
        rest: _affineSumTail,
      );
    }
    return Matrix.transform(
      m00: m00 + other.m00, m01: m01 + other.m01,
      m02: m02 + other.m02, m03: m03 + other.m03,
      m10: m10 + other.m10, m11: m11 + other.m11,
      m12: m12 + other.m12, m13: m13 + other.m13,
      m20: m20 + other.m20, m21: m21 + other.m21,
      m22: m22 + other.m22, m23: m23 + other.m23,
      m30: m30 + other.m30, m31: m31 + other.m31,
      m32: m32 + other.m32, m33: m33 + other.m33,
    );
  }

  /// Computes the product `this` * [other].
  Matrix operator *(Matrix other) {
    if (identical(other, Matrix.identity)) {
      return this;
    }
    if (identical(this, Matrix.identity)) {
      return other;
    }

    if (_rest == null && other._rest == null) {
      // Both 2D affine: the product is 2D affine, built directly with no
      // extension allocation and no static-factory call chain. This is the
      // common UI composition path. The result has `_rest == null`, so it is
      // already canonical for equality/hashing purposes (lowering to the
      // identity/translation constants is only a missed `identical` fast path,
      // not a correctness concern).
      final double a00 = _m00, a01 = _m01, a10 = _m10, a11 = _m11;
      final double a03 = _m03, a13 = _m13;
      final double b00 = other._m00, b01 = other._m01;
      final double b10 = other._m10, b11 = other._m11;
      final double b03 = other._m03, b13 = other._m13;
      return Matrix._(
        m00: a00 * b00 + a01 * b10,
        m01: a00 * b01 + a01 * b11,
        m10: a10 * b00 + a11 * b10,
        m11: a10 * b01 + a11 * b11,
        m03: a00 * b03 + a01 * b13 + a03,
        m13: a10 * b03 + a11 * b13 + a13,
      );
    }

    return _generalMultiply(this, other);
  }

  /// Computes the determinant of this matrix.
  double determinant() {
    final _MatrixExtension? rest = _rest;
    if (rest == null) {
      // 2D affine: det of the inline 2x2 linear block (z and w scales are 1).
      return _m00 * _m11 - _m01 * _m10;
    }
    return _generalDeterminant(this, rest);
  }

  /// Inverts this matrix, or returns null if it is singular ([determinant] is
  /// zero).
  Matrix? invert() {
    if (identical(this, Matrix.identity)) {
      return this;
    }

    final _MatrixExtension? rest = _rest;
    if (rest == null) {
      // 2D affine inverse.
      final double a = _m00, b = _m01, c = _m10, d = _m11;
      final double e = _m03, f = _m13;
      final double det = a * d - b * c;
      if (det == 0.0) {
        return null;
      }
      final double invDet = 1.0 / det;
      return Matrix._(
        m00: d * invDet,
        m01: -b * invDet,
        m10: -c * invDet,
        m11: a * invDet,
        m03: (b * f - d * e) * invDet,
        m13: (c * e - a * f) * invDet,
      );
    }
    return _generalInvert(this, rest);
  }

  /// Returns `this * T`, where `T` is a translation by ([dx], [dy]).
  ///
  /// The new transform is applied in `this`'s local space (post-multiplication):
  /// a point is translated *first*, then transformed by `this`. Equivalent to
  /// vector_math's in-place `Matrix4.translate`.
  Matrix translated(double dx, double dy) =>
      this * Matrix.translation2d(dx: dx, dy: dy);

  /// Returns `this * S`, where `S` is a scale by [sx] (and [sy], defaulting to
  /// [sx]). Applied in `this`'s local space; equivalent to vector_math's
  /// in-place `Matrix4.scale`.
  Matrix scaled(double sx, [double? sy]) => this * Matrix.scale(sx, sy);

  /// Returns `this * R`, where `R` is a Z-rotation by [radians]. Applied in
  /// `this`'s local space; equivalent to vector_math's in-place
  /// `Matrix4.rotateZ`.
  Matrix rotatedZ(double radians) => this * Matrix.rotationZ(radians);

  /// Returns `this * K`, where `K` is a skew by ([alpha], [beta]). Applied in
  /// `this`'s local space.
  Matrix skewed(double alpha, double beta) => this * Matrix.skew(alpha, beta);

  /// Transforms [point] (treated as `(x, y, 0, 1)`) by this matrix.
  ///
  /// Applies the perspective divide when the matrix is not affine
  /// ([isAffine2d] is false). Numerically matches vector_math's
  /// `Matrix4.perspectiveTransform` on `Vector3(x, y, 0)`.
  Offset transformPoint(Offset point) {
    final double x = point.dx;
    final double y = point.dy;
    final double nx = _m00 * x + _m01 * y + _m03;
    final double ny = _m10 * x + _m11 * y + _m13;
    final _MatrixExtension? rest = _rest;
    if (rest == null ||
        (rest._m30 == 0.0 && rest._m31 == 0.0 && rest._m33 == 1.0)) {
      return Offset(nx, ny);
    }
    final double invW = 1.0 / (rest._m30 * x + rest._m31 * y + rest._m33);
    return Offset(nx * invW, ny * invW);
  }

  /// Transforms [vector] as a direction (treated as `(x, y, 0, 0)`), ignoring
  /// translation and perspective. The entire 2D linear part is inline, so this
  /// never reads the extension.
  Offset transformVector(Offset vector) {
    final double x = vector.dx;
    final double y = vector.dy;
    return Offset(_m00 * x + _m01 * y, _m10 * x + _m11 * y);
  }

  /// Transforms [rect] and returns the axis-aligned bounding box of the result.
  ///
  /// A simple (axis-aligned) matrix transforms the two opposite corners and
  /// reorders them to absorb negative scales. Otherwise all four corners are
  /// transformed — without allocating per-corner [Offset]s — and bounded, with
  /// the perspective divide applied where the matrix is not affine.
  Rect transformRect(Rect rect) {
    final double a00 = _m00, a01 = _m01, a10 = _m10, a11 = _m11;
    final double a03 = _m03, a13 = _m13;
    final _MatrixExtension? rest = _rest;

    if (rest == null && a01 == 0.0 && a10 == 0.0) {
      // Axis-aligned: two opposite corners suffice.
      final double x1 = a00 * rect.left + a03;
      final double y1 = a11 * rect.top + a13;
      final double x2 = a00 * rect.right + a03;
      final double y2 = a11 * rect.bottom + a13;
      return Rect.fromLTRB(
        math.min(x1, x2),
        math.min(y1, y2),
        math.max(x1, x2),
        math.max(y1, y2),
      );
    }

    final double l = rect.left, t = rect.top, r = rect.right, b = rect.bottom;
    double c0x = a00 * l + a01 * t + a03, c0y = a10 * l + a11 * t + a13;
    double c1x = a00 * r + a01 * t + a03, c1y = a10 * r + a11 * t + a13;
    double c2x = a00 * r + a01 * b + a03, c2y = a10 * r + a11 * b + a13;
    double c3x = a00 * l + a01 * b + a03, c3y = a10 * l + a11 * b + a13;

    if (rest != null &&
        !(rest._m30 == 0.0 && rest._m31 == 0.0 && rest._m33 == 1.0)) {
      final double m30 = rest._m30, m31 = rest._m31, m33 = rest._m33;
      final double w0 = m30 * l + m31 * t + m33;
      final double w1 = m30 * r + m31 * t + m33;
      final double w2 = m30 * r + m31 * b + m33;
      final double w3 = m30 * l + m31 * b + m33;
      c0x /= w0;
      c0y /= w0;
      c1x /= w1;
      c1y /= w1;
      c2x /= w2;
      c2y /= w2;
      c3x /= w3;
      c3y /= w3;
    }

    return Rect.fromLTRB(
      math.min(math.min(c0x, c1x), math.min(c2x, c3x)),
      math.min(math.min(c0y, c1y), math.min(c2y, c3y)),
      math.max(math.max(c0x, c1x), math.max(c2x, c3x)),
      math.max(math.max(c0y, c1y), math.max(c2y, c3y)),
    );
  }

  /// Returns the transpose of this matrix (rows and columns swapped).
  ///
  /// A diagonal matrix (a scale, including [identity]) is symmetric, so its
  /// transpose is itself. A simple translation, by contrast, is not symmetric —
  /// transposing moves the translation from the right column into the bottom
  /// row, producing a general matrix.
  Matrix transposed() {
    if (_rest == null &&
        _m01 == 0.0 &&
        _m10 == 0.0 &&
        _m03 == 0.0 &&
        _m13 == 0.0) {
      // Diagonal (scale/identity): symmetric.
      return this;
    }
    return Matrix.transform(
      m00: m00, m01: m10, m02: m20, m03: m30,
      m10: m01, m11: m11, m12: m21, m13: m31,
      m20: m02, m21: m12, m22: m22, m23: m32,
      m30: m03, m31: m13, m32: m23, m33: m33,
    );
  }

  /// Whether [other] is a [Matrix] with the same 16 entries.
  ///
  /// Relies on the canonical-lowering invariant: equal transforms are always
  /// stored in the same shape, so a `_rest` null/non-null mismatch is enough to
  /// decide inequality without comparing the extension. Follows IEEE-754
  /// double semantics, so a matrix containing a NaN entry is not equal to
  /// itself (unless it is the identical instance); `+0.0` and `-0.0` compare
  /// equal.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Matrix) {
      return false;
    }
    final _MatrixExtension? rest = _rest;
    final _MatrixExtension? otherRest = other._rest;
    if ((rest == null) != (otherRest == null)) {
      return false;
    }
    if (_m00 != other._m00 ||
        _m01 != other._m01 ||
        _m10 != other._m10 ||
        _m11 != other._m11 ||
        _m03 != other._m03 ||
        _m13 != other._m13) {
      return false;
    }
    if (rest == null) {
      return true;
    }
    return rest._equals(otherRest!);
  }

  @override
  int get hashCode {
    final _MatrixExtension? rest = _rest;
    if (rest == null) {
      return Object.hash(
        _normalizeZero(_m00),
        _normalizeZero(_m01),
        _normalizeZero(_m10),
        _normalizeZero(_m11),
        _normalizeZero(_m03),
        _normalizeZero(_m13),
      );
    }
    return Object.hash(
      _normalizeZero(_m00),
      _normalizeZero(_m01),
      _normalizeZero(_m10),
      _normalizeZero(_m11),
      _normalizeZero(_m03),
      _normalizeZero(_m13),
      rest._hash,
    );
  }

  @override
  String toString() {
    String row(double a, double b, double c, double d) => '[$a, $b, $c, $d]';
    return 'Matrix(\n'
        '  ${row(m00, m01, m02, m03)}\n'
        '  ${row(m10, m11, m12, m13)}\n'
        '  ${row(m20, m21, m22, m23)}\n'
        '  ${row(m30, m31, m32, m33)}\n'
        ')';
  }
}

// Maps -0.0 to +0.0 (and leaves every other value, including NaN, untouched) so
// that the hashCode of two matrices that compare equal under `==` agrees even
// when one holds a negative zero. `-0.0 == 0.0` is true, so the hash must match.
double _normalizeZero(double v) => v == 0.0 ? 0.0 : v;

// The extension tail produced by adding two 2D-affine matrices: each
// contributes an identity tail, so the sum has m22 = m33 = 2 and zeros
// elsewhere. Shared (immutable) so `affine + affine` allocates no extension.
const _MatrixExtension _affineSumTail = _MatrixExtension(
  m02: 0,
  m12: 0,
  m20: 0,
  m21: 0,
  m22: 2,
  m23: 0,
  m30: 0,
  m31: 0,
  m32: 0,
  m33: 2,
);

/// The 3D / perspective tail of a [Matrix]: the ten entries outside the inline
/// 2D-affine block. Present only when at least one of them is non-default.
@immutable
final class _MatrixExtension {
  const _MatrixExtension({
    required double m02,
    required double m12,
    required double m20,
    required double m21,
    required double m22,
    required double m23,
    required double m30,
    required double m31,
    required double m32,
    required double m33,
  })  : _m02 = m02,
        _m12 = m12,
        _m20 = m20,
        _m21 = m21,
        _m22 = m22,
        _m23 = m23,
        _m30 = m30,
        _m31 = m31,
        _m32 = m32,
        _m33 = m33;

  final double _m02;
  final double _m12;
  final double _m20;
  final double _m21;
  final double _m22;
  final double _m23;
  final double _m30;
  final double _m31;
  final double _m32;
  final double _m33;

  /// Field-wise equality over the ten extension entries. Used by [Matrix.==]
  /// once the six inline fields have already matched.
  bool _equals(_MatrixExtension other) =>
      _m02 == other._m02 &&
      _m12 == other._m12 &&
      _m20 == other._m20 &&
      _m21 == other._m21 &&
      _m22 == other._m22 &&
      _m23 == other._m23 &&
      _m30 == other._m30 &&
      _m31 == other._m31 &&
      _m32 == other._m32 &&
      _m33 == other._m33;

  /// Structural hash over the ten extension entries (negative zeros
  /// normalized), folded into [Matrix.hashCode].
  int get _hash => Object.hash(
        _normalizeZero(_m02),
        _normalizeZero(_m12),
        _normalizeZero(_m20),
        _normalizeZero(_m21),
        _normalizeZero(_m22),
        _normalizeZero(_m23),
        _normalizeZero(_m30),
        _normalizeZero(_m31),
        _normalizeZero(_m32),
        _normalizeZero(_m33),
      );
}

// Full 4x4 product, used when at least one operand has a 3D tail. Reads both
// operands through their row-major getters (which supply identity-tail defaults
// for a null extension), then lowers the result via Matrix.transform.
Matrix _generalMultiply(Matrix m, Matrix n) {
  final double m00 = m.m00, m01 = m.m01, m02 = m.m02, m03 = m.m03;
  final double m10 = m.m10, m11 = m.m11, m12 = m.m12, m13 = m.m13;
  final double m20 = m.m20, m21 = m.m21, m22 = m.m22, m23 = m.m23;
  final double m30 = m.m30, m31 = m.m31, m32 = m.m32, m33 = m.m33;

  final double n00 = n.m00, n01 = n.m01, n02 = n.m02, n03 = n.m03;
  final double n10 = n.m10, n11 = n.m11, n12 = n.m12, n13 = n.m13;
  final double n20 = n.m20, n21 = n.m21, n22 = n.m22, n23 = n.m23;
  final double n30 = n.m30, n31 = n.m31, n32 = n.m32, n33 = n.m33;

  return Matrix.transform(
    m00: (m00 * n00) + (m01 * n10) + (m02 * n20) + (m03 * n30),
    m01: (m00 * n01) + (m01 * n11) + (m02 * n21) + (m03 * n31),
    m02: (m00 * n02) + (m01 * n12) + (m02 * n22) + (m03 * n32),
    m03: (m00 * n03) + (m01 * n13) + (m02 * n23) + (m03 * n33),
    m10: (m10 * n00) + (m11 * n10) + (m12 * n20) + (m13 * n30),
    m11: (m10 * n01) + (m11 * n11) + (m12 * n21) + (m13 * n31),
    m12: (m10 * n02) + (m11 * n12) + (m12 * n22) + (m13 * n32),
    m13: (m10 * n03) + (m11 * n13) + (m12 * n23) + (m13 * n33),
    m20: (m20 * n00) + (m21 * n10) + (m22 * n20) + (m23 * n30),
    m21: (m20 * n01) + (m21 * n11) + (m22 * n21) + (m23 * n31),
    m22: (m20 * n02) + (m21 * n12) + (m22 * n22) + (m23 * n32),
    m23: (m20 * n03) + (m21 * n13) + (m22 * n23) + (m23 * n33),
    m30: (m30 * n00) + (m31 * n10) + (m32 * n20) + (m33 * n30),
    m31: (m30 * n01) + (m31 * n11) + (m32 * n21) + (m33 * n31),
    m32: (m30 * n02) + (m31 * n12) + (m32 * n22) + (m33 * n32),
    m33: (m30 * n03) + (m31 * n13) + (m32 * n23) + (m33 * n33),
  );
}

double _generalDeterminant(Matrix matrix, _MatrixExtension rest) {
  final double a00 = matrix._m00;
  final double a01 = matrix._m10;
  final double a02 = rest._m20;
  final double a03 = rest._m30;
  final double a10 = matrix._m01;
  final double a11 = matrix._m11;
  final double a12 = rest._m21;
  final double a13 = rest._m31;
  final double a20 = rest._m02;
  final double a21 = rest._m12;
  final double a22 = rest._m22;
  final double a23 = rest._m32;
  final double a30 = matrix._m03;
  final double a31 = matrix._m13;
  final double a32 = rest._m23;
  final double a33 = rest._m33;

  final double b00 = a00 * a11 - a01 * a10;
  final double b01 = a00 * a12 - a02 * a10;
  final double b02 = a00 * a13 - a03 * a10;
  final double b03 = a01 * a12 - a02 * a11;
  final double b04 = a01 * a13 - a03 * a11;
  final double b05 = a02 * a13 - a03 * a12;
  final double b06 = a20 * a31 - a21 * a30;
  final double b07 = a20 * a32 - a22 * a30;
  final double b08 = a20 * a33 - a23 * a30;
  final double b09 = a21 * a32 - a22 * a31;
  final double b10 = a21 * a33 - a23 * a31;
  final double b11 = a22 * a33 - a23 * a32;
  return b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
}

Matrix? _generalInvert(Matrix matrix, _MatrixExtension rest) {
  final double a00 = matrix._m00;
  final double a01 = matrix._m10;
  final double a02 = rest._m20;
  final double a03 = rest._m30;
  final double a10 = matrix._m01;
  final double a11 = matrix._m11;
  final double a12 = rest._m21;
  final double a13 = rest._m31;
  final double a20 = rest._m02;
  final double a21 = rest._m12;
  final double a22 = rest._m22;
  final double a23 = rest._m32;
  final double a30 = matrix._m03;
  final double a31 = matrix._m13;
  final double a32 = rest._m23;
  final double a33 = rest._m33;

  final double b00 = a00 * a11 - a01 * a10;
  final double b01 = a00 * a12 - a02 * a10;
  final double b02 = a00 * a13 - a03 * a10;
  final double b03 = a01 * a12 - a02 * a11;
  final double b04 = a01 * a13 - a03 * a11;
  final double b05 = a02 * a13 - a03 * a12;
  final double b06 = a20 * a31 - a21 * a30;
  final double b07 = a20 * a32 - a22 * a30;
  final double b08 = a20 * a33 - a23 * a30;
  final double b09 = a21 * a32 - a22 * a31;
  final double b10 = a21 * a33 - a23 * a31;
  final double b11 = a22 * a33 - a23 * a32;
  final double det =
      b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
  if (det == 0.0) {
    return null;
  }
  final double invDet = 1.0 / det;

  // The inverse of a general matrix is general; build it via Matrix.transform
  // so it still lowers if (rarely) the inverse turns out 2D-affine. The
  // expression for each output entry is preserved exactly from the original
  // (parity-verified) implementation.
  return Matrix.transform(
    m00: (a11 * b11 - a12 * b10 + a13 * b09) * invDet,
    m01: (-a10 * b11 + a12 * b08 - a13 * b07) * invDet,
    m02: (a10 * b10 - a11 * b08 + a13 * b06) * invDet,
    m03: (-a10 * b09 + a11 * b07 - a12 * b06) * invDet,
    m10: (-a01 * b11 + a02 * b10 - a03 * b09) * invDet,
    m11: (a00 * b11 - a02 * b08 + a03 * b07) * invDet,
    m12: (-a00 * b10 + a01 * b08 - a03 * b06) * invDet,
    m13: (a00 * b09 - a01 * b07 + a02 * b06) * invDet,
    m20: (a31 * b05 - a32 * b04 + a33 * b03) * invDet,
    m21: (-a30 * b05 + a32 * b02 - a33 * b01) * invDet,
    m22: (a30 * b04 - a31 * b02 + a33 * b00) * invDet,
    m23: (-a30 * b03 + a31 * b01 - a32 * b00) * invDet,
    m30: (-a21 * b05 + a22 * b04 - a23 * b03) * invDet,
    m31: (a20 * b05 - a22 * b02 + a23 * b01) * invDet,
    m32: (-a20 * b04 + a21 * b02 - a23 * b00) * invDet,
    m33: (a20 * b03 - a21 * b01 + a22 * b00) * invDet,
  );
}

extension Float64ListToMatrix on Float64List {
  /// Builds a [Matrix] from a column-major 4x4 list (the representation
  /// dart:ui.Path.transform and Matrix4.storage use).
  Matrix toMatrix() => Matrix.transform(
        m00: this[0],
        m10: this[1],
        m20: this[2],
        m30: this[3],
        m01: this[4],
        m11: this[5],
        m21: this[6],
        m31: this[7],
        m02: this[8],
        m12: this[9],
        m22: this[10],
        m32: this[11],
        m03: this[12],
        m13: this[13],
        m23: this[14],
        m33: this[15],
      );
}
