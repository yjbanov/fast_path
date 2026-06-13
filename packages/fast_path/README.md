# fast_path

A pure-Dart implementation of a 2D path API that aims for feature parity with
Flutter's `Path` class.

Flutter's `Path` is implemented in C++ on top of Skia and Impeller. `fast_path`
re-implements the same surface area in Dart so that geometry work stays on the
Dart heap, avoids native bindings, and is managed by Dart's garbage collector
— with no manual memory management to perform.

## Status

Early development. The public API is unstable and the implementation is
incomplete.

## Installing

Add `fast_path` to your `pubspec.yaml`:

```yaml
dependencies:
  fast_path: ^0.1.0
```

Then run `dart pub get` (or `flutter pub get`).

## Usage

```dart
import 'package:fast_path/fast_path.dart';

void main() {
  // API surface coming soon.
}
```

## License

BSD-3-Clause. See [LICENSE](LICENSE).
