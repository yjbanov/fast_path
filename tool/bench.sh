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
      Darwin)
        device="macos"
        binary_relpath="build/macos/Build/Products/Release/fast_path_bench_flutter.app/Contents/MacOS/fast_path_bench_flutter"
        ;;
      Linux)
        device="linux"
        case "$(uname -m)" in
          x86_64) linux_arch="x64" ;;
          aarch64|arm64) linux_arch="arm64" ;;
          *)
            echo "flutter-desktop mode: unsupported linux arch $(uname -m)" >&2
            exit 2
            ;;
        esac
        binary_relpath="build/linux/$linux_arch/release/bundle/fast_path_bench_flutter"
        ;;
      *)
        echo "flutter-desktop mode: unsupported host OS $(uname -s)" >&2
        exit 2
        ;;
    esac

    cd packages/fast_path_bench_flutter

    # Build, then exec the binary directly. `flutter run --release` would
    # also AOT-compile, but its stdout handling is opaque (the daemon
    # protocol does not reliably forward the app's stdout to the parent).
    # `flutter build` produces the same binary and lets us read its stdout
    # straight.
    echo "==> flutter build $device --release" >&2
    flutter build "$device" --release >&2

    echo "==> running $binary_relpath" >&2
    # Suppress stderr from the binary itself: the macOS embedder prints
    # a "Running with merged UI and platform thread" banner there. Our
    # JSON goes to stdout, which is what callers consume.
    exec "$binary_relpath" 2>/dev/null
    ;;

  *)
    echo "Unknown --mode=$mode (expected: jit, aot, flutter-desktop)" >&2
    exit 2
    ;;
esac
