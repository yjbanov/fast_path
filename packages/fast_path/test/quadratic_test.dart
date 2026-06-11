// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.quadraticBezierTo', () {
    test('control point contributes to (loose) bounds', () {
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(50, 100, 100, 0))
          .build();
      // `getBounds()` matches `dart:ui.Path.getBounds()` semantics — the
      // bbox of every point stored in the path, including the off-curve
      // control point at (50, 100). Bottom is 100, not the curve's true
      // apex at y = 50.
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 100);
    });

    test('point inside a quad-bounded region is contained', () {
      // A closed shape: line from (0,0) to (100,0), a quad arcing up to
      // (50, 100) back down to (0,0). This encloses a single lobe whose
      // interior includes (50, 30).
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 0)
            ..quadraticBezierTo(50, 200, 0, 0)
            ..close())
          .build();
      expect(path.contains(const Offset(50, 30)), isTrue);
      // Outside, comfortably below the x-axis.
      expect(path.contains(const Offset(50, -10)), isFalse);
      // Outside, beyond the right endpoint.
      expect(path.contains(const Offset(110, 30)), isFalse);
    });

    test('relativeQuadraticBezierTo accumulates from current point', () {
      // Same shape as the absolute version below, just with deltas.
      final relPath = (PathBuilder()
            ..moveTo(10, 10)
            ..relativeQuadraticBezierTo(40, 100, 90, 0))
          .build();
      final absPath = (PathBuilder()
            ..moveTo(10, 10)
            ..quadraticBezierTo(50, 110, 100, 10))
          .build();
      expect(relPath.getBounds(), equals(absPath.getBounds()));
    });

    test('quadraticBezierTo without prior moveTo implicitly starts at origin',
        () {
      final path = (PathBuilder()..quadraticBezierTo(50, 100, 100, 0)).build();
      // Loose bounds again — the implicit start at (0, 0), the control at
      // (50, 100), and the endpoint at (100, 0) are all in the bbox.
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 100);
    });

    test('degenerate quad (collinear control) reduces to a line for bounds',
        () {
      // Control point on the chord — curve is the chord itself.
      final path = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(50, 0, 100, 0))
          .build();
      final bounds = path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 100);
      expect(bounds.top, 0);
      expect(bounds.bottom, 0);
    });

    test('PathBuilder.from reseeds a path that contains a quad', () {
      final original = (PathBuilder()
            ..moveTo(0, 0)
            ..quadraticBezierTo(50, 100, 100, 0)
            ..close())
          .build();
      final reseeded = PathBuilder.from(original).build();
      expect(reseeded, equals(original));
      expect(reseeded.getBounds(), equals(original.getBounds()));
    });
  });
}
