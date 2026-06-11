// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder.addRect', () {
    test('adds a closed rectangle equal to the explicit construction', () {
      final viaAddRect = (PathBuilder()
            ..addRect(const Rect.fromLTRB(10, 20, 110, 70)))
          .build();
      final explicit = (PathBuilder()
            ..moveTo(10, 20)
            ..lineTo(110, 20)
            ..lineTo(110, 70)
            ..lineTo(10, 70)
            ..close())
          .build();
      expect(viaAddRect, equals(explicit));
    });

    test('bounds equal the rect', () {
      final path =
          (PathBuilder()..addRect(const Rect.fromLTRB(10, 20, 110, 70)))
              .build();
      expect(path.getBounds(), equals(const Rect.fromLTRB(10, 20, 110, 70)));
    });

    test('contains interior, not exterior', () {
      final path =
          (PathBuilder()..addRect(const Rect.fromLTRB(0, 0, 100, 50)))
              .build();
      expect(path.contains(const Offset(50, 25)), isTrue);
      expect(path.contains(const Offset(-5, 25)), isFalse);
      expect(path.contains(const Offset(105, 25)), isFalse);
      expect(path.contains(const Offset(50, 55)), isFalse);
    });

    test('winding is clockwise (nested same-direction rects both fill)', () {
      // Two nested addRect calls wind the same way, so under nonZero the
      // inner region has winding 2 — still filled. (If directions were
      // opposite, the inner region would be a hole.)
      final path = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 100, 100))
            ..addRect(const Rect.fromLTRB(25, 25, 75, 75)))
          .build();
      expect(path.contains(const Offset(50, 50)), isTrue);
      expect(path.contains(const Offset(10, 10)), isTrue);
    });

    test('subsequent segments start fresh, not from the rect', () {
      // After addRect's close, a lineTo must open a new contour at the
      // rect's start corner (per post-close implicit moveTo semantics).
      final path = (PathBuilder()
            ..addRect(const Rect.fromLTRB(0, 0, 10, 10))
            ..lineTo(5, 20))
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(0, 0, 10, 20)),
      );
    });
  });
}
