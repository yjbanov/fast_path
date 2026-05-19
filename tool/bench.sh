#!/usr/bin/env bash
# Run the fast_path benchmark suite.
#
# Usage:
#   tool/bench.sh                       # JIT (default), table output
#   tool/bench.sh --json                # JIT, JSON output
#   tool/bench.sh --mode=aot            # AOT-compiled native binary
#   tool/bench.sh --mode=aot --json     # AOT, JSON output
#   tool/bench.sh --mode=flutter-desktop
#                                       # Flutter desktop --release (AOT,
#                                       # has dart:ui — compares fast_path
#                                       # against dart:ui in the same run).
#                                       # Always emits JSON to stdout.
#
# The --mode label is also forwarded into the benchmark's own metadata so
# JSON consumers can tell runs apart. dart2js and dart2wasm modes will
# plug into this same switch as additional cases.
#
# To run the web benchmark suite manually:
#   cd packages/fast_path_bench_flutter
#   flutter run -d chrome --release    # opens browser, click "Run benchmarks"

set -euo pipefail

cd "$(dirname "$0")/.."

mode="jit"
args=()
for arg in "$@"; do
  case "$arg" in
    --mode=*) mode="${arg#--mode=}" ;;
    *) args+=("$arg") ;;
  esac
done

# Ensure workspace is resolved; --offline keeps this fast when nothing's
# changed and fails loudly if a new dep wasn't fetched yet.
dart pub get --offline >/dev/null

case "$mode" in
  jit)
    cd packages/fast_path_bench
    exec dart run bin/run_all.dart --mode=jit "${args[@]+"${args[@]}"}"
    ;;

  aot)
    mkdir -p build
    echo "==> compiling AOT native binary" >&2
    dart compile exe \
      packages/fast_path_bench/bin/run_all.dart \
      -o build/run_all_aot >&2
    echo >&2
    exec ./build/run_all_aot --mode=aot "${args[@]+"${args[@]}"}"
    ;;

  flutter-desktop)
    case "$(uname -s)" in
      Darwin) device="macos" ;;
      Linux)  device="linux" ;;
      *)
        echo "flutter-desktop mode: unsupported host OS $(uname -s)" >&2
        exit 2
        ;;
    esac
    cd packages/fast_path_bench_flutter
    # flutter run prints its own progress chatter to stderr/stdout.
    # --release gives us AOT-compiled Dart. The app's main() prints the
    # canonical JSON report to stdout and then exit(0)s, so `flutter run`
    # detaches and returns. We grep the JSON object out of the surrounding
    # banner so callers see clean machine-readable output on stdout.
    echo "==> flutter run --release -d $device" >&2
    flutter run --release -d "$device" 2>/dev/null \
      | awk '/^\{/{ printing=1 } printing { print } /^\}$/{ printing=0 }'
    ;;

  *)
    echo "Unknown --mode=$mode (expected: jit, aot, flutter-desktop)" >&2
    exit 2
    ;;
esac
