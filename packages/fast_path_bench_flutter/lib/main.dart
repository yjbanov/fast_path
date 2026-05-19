// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Flutter-hosted benchmark entry point.
///
/// On desktop (macOS / Linux / Windows in --release): runs every
/// benchmark at startup, writes a JSON report to stdout, and exits. A
/// platform window flashes briefly because the embedder creates it
/// before Dart's `main()` runs, but no rendering work is performed.
///
/// On web: launches a tiny Material UI with a "Run benchmarks" button.
/// Results render on screen and are also `print()`-ed to the browser
/// console.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'src/bench_app.dart';

// Conditional import — desktop_runner imports dart:io and can't compile
// to web; the stub satisfies the type for web builds, where the runtime
// kIsWeb branch below never calls it anyway.
import 'src/desktop_runner_stub.dart'
    if (dart.library.io) 'src/desktop_runner.dart' as desktop;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    runApp(const BenchApp());
  } else {
    await desktop.runDesktopBenchmarksAndExit();
  }
}
