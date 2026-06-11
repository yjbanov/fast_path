// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.addRRect', () {
    test('bounds equal the outer rect', () {
      final path = (PathBuilder()
            ..addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTRB(10, 20, 110, 80),
              const Radius.circular(15),
            )))
          .build();
      expect(path.getBounds(), equals(const Rect.fromLTRB(10, 20, 110, 80)));
    });

    test('rounds the corners but keeps the edges', () {
      // 100×100 rrect with radius 30.
      final path = (PathBuilder()
            ..addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTRB(0, 0, 100, 100),
              const Radius.circular(30),
            )))
          .build();
      // Center and edge midpoints: inside.
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(50, 5)), isTrue);
      expect(path.contains(const Offset(5, 50)), isTrue);
      // Extreme corner: outside the rounded corner. Corner circle is
      // centered (30, 30) radius 30; (5, 5) is at distance ≈ 35.4 > 30.
      expect(path.contains(const Offset(5, 5)), isFalse);
      // Just inside the corner arc: (12, 12) is at distance ≈ 25.5 < 30.
      expect(path.contains(const Offset(12, 12)), isTrue);
    });

    test('zero radius degenerates to addRect geometry', () {
      final rrectPath = (PathBuilder()
            ..addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTRB(0, 0, 100, 50),
              Radius.zero,
            )))
          .build();
      // Sharp corners: the bbox corner is inside.
      expect(rrectPath.contains(const Offset(2, 2)), isTrue);
      expect(rrectPath.contains(const Offset(98, 48)), isTrue);
      expect(rrectPath.getBounds(),
          equals(const Rect.fromLTRB(0, 0, 100, 50)));
    });

    test('negative radii clamp to zero', () {
      final path = (PathBuilder()
            ..addRRect(RRect.fromRectAndCorners(
              const Rect.fromLTRB(0, 0, 100, 50),
              topLeft: const Radius.circular(-10),
            )))
          .build();
      expect(path.contains(const Offset(2, 2)), isTrue); // sharp corner
    });

    test('oversized radii scale down uniformly (Skia scaleRadii)', () {
      // 100×50 rect with radius 40: top edge needs 40+40=80 ≤ 100 ✓ but
      // left edge needs 40+40=80 > 50, so all radii scale by 50/80 =
      // 0.625 → effective radius 25. The shape is a "stadium" (ends are
      // half circles of radius 25).
      final path = (PathBuilder()
            ..addRRect(RRect.fromRectAndRadius(
              const Rect.fromLTRB(0, 0, 100, 50),
              const Radius.circular(40),
            )))
          .build();
      expect(path.contains(const Offset(50, 25)), isTrue);
      // Corner circle now centered (25, 25) r=25. Point (4, 4): distance
      // from (25,25) ≈ 29.7 > 25 → outside.
      expect(path.contains(const Offset(4, 4)), isFalse);
      // Point (8, 13): distance ≈ 20.8 < 25 → inside.
      expect(path.contains(const Offset(8, 13)), isTrue);
    });

    test('per-corner radii are honored independently', () {
      final path = (PathBuilder()
            ..addRRect(RRect.fromRectAndCorners(
              const Rect.fromLTRB(0, 0, 100, 100),
              topLeft: const Radius.circular(40),
              // other corners sharp
            )))
          .build();
      // Sharp bottom-right: bbox corner inside.
      expect(path.contains(const Offset(97, 97)), isTrue);
      // Rounded top-left: bbox corner outside.
      expect(path.contains(const Offset(5, 5)), isFalse);
    });
  });
}
