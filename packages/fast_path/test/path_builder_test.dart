// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathBuilder', () {
    test('build of an empty builder produces an empty path', () {
      final path = PathBuilder().build();
      expect(path.getBounds(), equals(Rect.zero));
      expect(path.fillType, equals(PathFillType.nonZero));
    });

    test('default fillType is nonZero', () {
      final builder = PathBuilder();
      expect(builder.fillType, equals(PathFillType.nonZero));
    });

    test('fillType setter propagates into the produced Path', () {
      final builder = PathBuilder()..fillType = PathFillType.evenOdd;
      expect(builder.build().fillType, equals(PathFillType.evenOdd));
    });

    test('moveTo + lineTo + close produces a single-point bounds', () {
      final path = (PathBuilder()
            ..moveTo(5.0, 5.0)
            ..close())
          .build();
      expect(path.getBounds(), equals(const Rect.fromLTRB(5.0, 5.0, 5.0, 5.0)));
    });

    test('lineTo without prior moveTo implicitly starts at the origin', () {
      // This matches dart:ui.Path's behavior: drawing without an explicit
      // moveTo begins at (0, 0).
      final path = (PathBuilder()..lineTo(10.0, 0.0)).build();
      expect(path.getBounds(), equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 0.0)));
    });

    test('close on an empty builder is a no-op', () {
      // Should not throw and should not change observable state.
      final path = (PathBuilder()..close()).build();
      expect(path.getBounds(), equals(Rect.zero));
    });

    test('reset clears verbs and points but keeps capacity', () {
      final builder = PathBuilder()
        ..moveTo(0.0, 0.0)
        ..lineTo(100.0, 100.0)
        ..close();
      builder.reset();
      final path = builder.build();
      expect(path.getBounds(), equals(Rect.zero));
      // After reset the builder is reusable.
      builder
        ..moveTo(1.0, 1.0)
        ..lineTo(2.0, 2.0);
      expect(
        builder.build().getBounds(),
        equals(const Rect.fromLTRB(1.0, 1.0, 2.0, 2.0)),
      );
    });

    test('reset returns fillType to nonZero', () {
      final builder = PathBuilder()..fillType = PathFillType.evenOdd;
      builder.reset();
      expect(builder.fillType, equals(PathFillType.nonZero));
    });

    test('reserve accepts size hints without changing observable state', () {
      final builder = PathBuilder()
        ..reserve(1024, 1024)
        ..moveTo(0.0, 0.0)
        ..lineTo(1.0, 1.0);
      expect(
        builder.build().getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 1.0, 1.0)),
      );
    });

    test('build snapshot is independent of subsequent mutations', () {
      final builder = PathBuilder()
        ..moveTo(0.0, 0.0)
        ..lineTo(10.0, 0.0)
        ..lineTo(10.0, 10.0)
        ..lineTo(0.0, 10.0)
        ..close();
      final snapshot = builder.build();

      builder
        ..reset()
        ..moveTo(100.0, 100.0)
        ..lineTo(200.0, 200.0);

      expect(
        snapshot.getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)),
      );
    });

    test('PathBuilder.from seeds from an existing path', () {
      final original = (PathBuilder()
            ..moveTo(0.0, 0.0)
            ..lineTo(10.0, 10.0)
            ..close())
          .build();
      final reseeded = PathBuilder.from(original).build();
      expect(reseeded, equals(original));
    });

    test('PathBuilder.from + close on a re-seeded contour works', () {
      // Re-seeding must reconstruct _lastMoveToIndex so close() finds the
      // most recent moveTo from the original buffer.
      final original = (PathBuilder()
            ..moveTo(2.0, 3.0)
            ..lineTo(4.0, 5.0))
          .build();
      final extended = PathBuilder.from(original)
        ..lineTo(6.0, 7.0)
        ..close();
      final result = extended.build();
      expect(
        result.getBounds(),
        equals(const Rect.fromLTRB(2.0, 3.0, 6.0, 7.0)),
      );
    });

    test('PathBuilder.fromBuilder clones builder state', () {
      final original = PathBuilder()
        ..fillType = PathFillType.evenOdd
        ..moveTo(0.0, 0.0)
        ..lineTo(10.0, 10.0);
      final clone = PathBuilder.fromBuilder(original);
      expect(clone.fillType, equals(PathFillType.evenOdd));
      expect(clone.build(), equals(original.build()));
    });

    test('many appends grow the buffers without losing data', () {
      // Stress the geometric growth path.
      final builder = PathBuilder()..moveTo(0.0, 0.0);
      for (var i = 1; i <= 1000; i++) {
        builder.lineTo(i.toDouble(), i.toDouble());
      }
      expect(
        builder.build().getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 1000.0, 1000.0)),
      );
    });
  });
}
