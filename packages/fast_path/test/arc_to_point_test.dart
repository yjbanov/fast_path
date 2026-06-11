// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.arcToPoint', () {
    test('semicircle via arcToPoint contains by radius', () {
      // From (0, 50) to (100, 50) with radius 50, clockwise. On a clock
      // face this runs 9 → 12 → 3, i.e. over the TOP (y < 50). Closing
      // the diameter gives the upper half-disk.
      final path = (PathBuilder()
            ..moveTo(0, 50)
            ..arcToPoint(const Offset(100, 50),
                radius: const Radius.circular(50))
            ..close())
          .build();
      final below = path.contains(const Offset(50, 75));
      final above = path.contains(const Offset(50, 25));
      expect(below != above, isTrue,
          reason: 'exactly one half should be filled');
      expect(above, isTrue);
      // Radius discrimination inside the filled half.
      expect(path.contains(const Offset(50, 5)), isTrue); // r=45 < 50
      expect(path.contains(const Offset(85, 10)), isFalse); // r≈53 > 50
    });

    test('counterclockwise picks the other side', () {
      final path = (PathBuilder()
            ..moveTo(0, 50)
            ..arcToPoint(const Offset(100, 50),
                radius: const Radius.circular(50), clockwise: false)
            ..close())
          .build();
      expect(path.contains(const Offset(50, 75)), isTrue);
      expect(path.contains(const Offset(50, 25)), isFalse);
    });

    test('largeArc sweeps the long way around', () {
      // Quarter chord on a circle of radius 50: from (50, 0) to
      // (100, 50) (chord length ≈ 70.7 < diameter). Small arc bulges
      // one way; large arc wraps around the rest of the circle.
      final small = (PathBuilder()
            ..moveTo(50, 0)
            ..arcToPoint(const Offset(100, 50),
                radius: const Radius.circular(50))
            ..close())
          .build();
      final large = (PathBuilder()
            ..moveTo(50, 0)
            ..arcToPoint(const Offset(100, 50),
                radius: const Radius.circular(50), largeArc: true)
            ..close())
          .build();
      // Small CW arc: quarter on the circle centered (50, 50). Large
      // CW arc: three quarters on the circle centered (100, 0); its
      // fill includes (130, 10) (distance ≈ 31.6 from that center),
      // which the small variant cannot reach.
      expect(large.contains(const Offset(130, 10)), isTrue);
      expect(small.contains(const Offset(130, 10)), isFalse);
    });

    test('zero radius produces a straight line', () {
      final viaArc = (PathBuilder()
            ..moveTo(0, 0)
            ..arcToPoint(const Offset(100, 50)))
          .build();
      final viaLine = (PathBuilder()
            ..moveTo(0, 0)
            ..lineTo(100, 50))
          .build();
      expect(viaArc, equals(viaLine));
    });

    test('arc to the current point is a no-op', () {
      final path = (PathBuilder()
            ..moveTo(10, 10)
            ..arcToPoint(const Offset(10, 10),
                radius: const Radius.circular(5)))
          .build();
      final justMove = (PathBuilder()..moveTo(10, 10)).build();
      expect(path, equals(justMove));
    });

    test('undersized radii scale up to span the endpoints', () {
      // Endpoints 100 apart with radius 10: rx must scale to ≥ 50.
      // The result is the half-circle of radius 50 (the minimal
      // ellipse), same as asking for radius 50 directly.
      final scaled = (PathBuilder()
            ..moveTo(0, 50)
            ..arcToPoint(const Offset(100, 50),
                radius: const Radius.circular(10))
            ..close())
          .build();
      expect(scaled.contains(const Offset(50, 5)), isTrue);
      expect(scaled.contains(const Offset(85, 10)), isFalse);
    });

    test('relativeArcToPoint accumulates from the current point', () {
      final rel = (PathBuilder()
            ..moveTo(0, 50)
            ..relativeArcToPoint(const Offset(100, 0),
                radius: const Radius.circular(50))
            ..close())
          .build();
      final abs = (PathBuilder()
            ..moveTo(0, 50)
            ..arcToPoint(const Offset(100, 50),
                radius: const Radius.circular(50))
            ..close())
          .build();
      expect(rel, equals(abs));
    });
  });
}
