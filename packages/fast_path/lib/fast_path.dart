/// A pure-Dart implementation of a 2D path API with feature parity to
/// Flutter's `Path` class.
///
/// The library lives entirely on the Dart heap — there are no native
/// bindings to manage and no manual memory management to perform.
///
/// Path construction is split across two classes: [PathBuilder] (mutable,
/// write-optimized) and [Path] (immutable, query-optimized). See the
/// package README for the rationale.
library;

export 'package:fast_geometry/fast_geometry.dart';
export 'src/path.dart';
