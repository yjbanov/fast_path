// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

import 'dart:io';

import 'runner.dart';

/// Runs every benchmark, writes the canonical JSON report to stdout, then
/// terminates the process. Used by Flutter desktop AOT runs invoked from
/// `tool/bench.sh --mode=flutter-desktop`.
///
/// The window the embedder creates is unavoidable on macOS / Linux desktop
/// — Cocoa / GTK construct it before Dart's `main()` runs — but we exit
/// before doing any rendering work, so it flashes briefly and disappears.
Future<void> runDesktopBenchmarksAndExit() async {
  final results = runAll();
  final json = encodeReport(
    mode: 'flutter-desktop',
    os: Platform.operatingSystem,
    dartVersion: Platform.version,
    results: results,
  );
  stdout.writeln(json);
  await stdout.flush();
  exit(0);
}
