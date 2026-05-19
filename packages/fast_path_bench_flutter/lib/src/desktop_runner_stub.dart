// Copyright 2026 The fast_path Authors.
// Use of this source code is governed by the BSD-3-Clause license in the
// project root LICENSE file.

/// Stub picked up by web builds via the conditional import in
/// `lib/main.dart`. The desktop entry path is never hit on web (the
/// runtime `kIsWeb` branch takes over) but the symbol still has to
/// exist for the compiler.
Future<void> runDesktopBenchmarksAndExit() async {
  throw UnsupportedError(
    'runDesktopBenchmarksAndExit is not supported in this runtime',
  );
}
