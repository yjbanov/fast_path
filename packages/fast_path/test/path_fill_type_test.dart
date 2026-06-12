// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'package:fast_path/fast_path.dart';
import 'package:test/test.dart';

void main() {
  group('PathFillType', () {
    test('exposes both fill rules', () {
      expect(PathFillType.values, hasLength(2));
      expect(PathFillType.values, contains(PathFillType.nonZero));
      expect(PathFillType.values, contains(PathFillType.evenOdd));
    });
  });
}
