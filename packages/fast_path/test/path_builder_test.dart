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

  group('PathBuilder relative methods', () {
    test('relativeMoveTo before any contour treats current as origin', () {
      final path = (PathBuilder()..relativeMoveTo(5.0, 5.0)).build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(5.0, 5.0, 5.0, 5.0)),
      );
    });

    test('relativeMoveTo accumulates from current point', () {
      final path = (PathBuilder()
            ..moveTo(2.0, 3.0)
            ..lineTo(5.0, 7.0)
            ..relativeMoveTo(1.0, 2.0)) // expected start: (6, 9)
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(2.0, 3.0, 6.0, 9.0)),
      );
    });

    test('relativeLineTo before any contour starts at origin', () {
      final path = (PathBuilder()..relativeLineTo(10.0, 10.0)).build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)),
      );
    });

    test('relativeLineTo accumulates from current point', () {
      final path = (PathBuilder()
            ..moveTo(0.0, 0.0)
            ..relativeLineTo(3.0, 4.0)
            ..relativeLineTo(2.0, -1.0))
          .build();
      // Walks from (0,0) to (3,4) to (5,3).
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 5.0, 4.0)),
      );
    });

    test('relativeMoveTo after close starts from the just-closed start', () {
      final path = (PathBuilder()
            ..moveTo(0.0, 0.0)
            ..lineTo(10.0, 0.0)
            ..close() // current point reverts to (0, 0)
            ..relativeMoveTo(5.0, 5.0)) // start a new contour at (5, 5)
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 5.0)),
      );
    });
  });

  group('PathBuilder addPolygon', () {
    test('empty list is a no-op', () {
      final path = (PathBuilder()..addPolygon(const [], true)).build();
      expect(path.getBounds(), equals(Rect.zero));
    });

    test('builds a single contour from an offset list', () {
      final path = (PathBuilder()
            ..addPolygon(
              const [
                Offset(0.0, 0.0),
                Offset(10.0, 0.0),
                Offset(10.0, 10.0),
                Offset(0.0, 10.0),
              ],
              true,
            ))
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)),
      );
      // Closed polygon: interior is filled.
      expect(path.contains(const Offset(5.0, 5.0)), isTrue);
    });

    test('close=false leaves the polygon open', () {
      final path = (PathBuilder()
            ..addPolygon(
              const [
                Offset(0.0, 0.0),
                Offset(10.0, 0.0),
                Offset(10.0, 10.0),
              ],
              false,
            ))
          .build();
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(0.0, 0.0, 10.0, 10.0)),
      );
    });
  });

  group('PathBuilder close idempotency and post-close mutation', () {
    test('close on an already-closed contour is a no-op', () {
      final builderA = PathBuilder()
        ..moveTo(0.0, 0.0)
        ..lineTo(10.0, 0.0)
        ..close();
      final builderB = PathBuilder()
        ..moveTo(0.0, 0.0)
        ..lineTo(10.0, 0.0)
        ..close()
        ..close()
        ..close();
      // Same verb stream → structural equality holds.
      expect(builderB.build(), equals(builderA.build()));
    });

    test('lineTo after close starts a new contour at the closed start', () {
      // moveTo(5,5); lineTo(10,5); close; lineTo(7,8) should produce two
      // contours: the first closed segment, then a fresh segment from (5,5)
      // — not a phantom segment from (10,5).
      final path = (PathBuilder()
            ..moveTo(5.0, 5.0)
            ..lineTo(10.0, 5.0)
            ..close()
            ..lineTo(7.0, 8.0))
          .build();
      // (10, 5) is the end of the first contour and is no longer "current".
      // After the implicit moveTo back to (5, 5), the new segment is
      // (5,5)→(7,8), and the implicit close-for-fill brings it back to
      // (5,5) — degenerate, zero area. Bounds still cover everything we
      // touched.
      expect(
        path.getBounds(),
        equals(const Rect.fromLTRB(5.0, 5.0, 10.0, 8.0)),
      );
    });
  });
}
