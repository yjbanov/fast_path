// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathOperation', () {
    test('has the five dart:ui operations in the same order', () {
      expect(PathOperation.values, [
        PathOperation.difference,
        PathOperation.intersect,
        PathOperation.union,
        PathOperation.xor,
        PathOperation.reverseDifference,
      ]);
    });

    test('value names match dart:ui', () {
      expect(PathOperation.difference.name, 'difference');
      expect(PathOperation.intersect.name, 'intersect');
      expect(PathOperation.union.name, 'union');
      expect(PathOperation.xor.name, 'xor');
      expect(PathOperation.reverseDifference.name, 'reverseDifference');
    });
  });
}
