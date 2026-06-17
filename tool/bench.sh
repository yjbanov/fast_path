#!/usr/bin/env bash
# Run a benchmark suite.
#
# Usage:
#   tool/bench.sh                            # path suite, JIT, table
#   tool/bench.sh --json                     # path suite, JIT, JSON
#   tool/bench.sh --mode=aot                 # path suite, AOT native binary
#   tool/bench.sh --suite=geometry           # matrix vs vector_math, JIT
#   tool/bench.sh --suite=geometry --mode=aot
#   tool/bench.sh --suite=all                # path then geometry
#   tool/bench.sh --suite=geometry --smoke   # fast end-to-end wiring check
#   tool/bench.sh --mode=flutter-desktop     # path only: Flutter desktop
#                                            # --release (AOT, has dart:ui — so
#                                            # fast_path is compared against
#                                            # dart:ui in the same run). Always
#                                            # emits JSON to stdout.
#
# Suites:
#   path      fast_path vs dart:ui. dart:ui only exists under Flutter, so the
#             side-by-side comparison requires --mode=flutter-desktop; jit/aot
#             run fast_path alone.
#   geometry  fast_geometry Matrix vs package:vector_math Matrix4. Both are
#             pure Dart, so the comparison runs under jit/aot directly;
#             flutter-desktop does not apply.
#
# The --mode label is forwarded into each benchmark's JSON metadata so
# consumers can tell runs apart. dart2js and dart2wasm modes will plug into the
# same switch as additional cases.
#
# To run the web benchmark suite manually:
#   cd packages/fast_path_bench_flutter
#   flutter run -d chrome --release    # opens browser, click "Run benchmarks"

set -euo pipefail

cd "$(dirname "$0")/.."

suite="path"
mode="jit"
args=()
for arg in "$@"; do
  case "$arg" in
    --suite=*) suite="${arg#--suite=}" ;;
    --mode=*) mode="${arg#--mode=}" ;;
    *) args+=("$arg") ;;
  esac
done

# Ensure workspace is resolved; --offline keeps this fast when nothing's
# changed and fails loudly if a new dep wasn't fetched yet.
dart pub get --offline >/dev/null

run_path() {
  case "$mode" in
    jit)
      ( cd packages/fast_path_bench
        exec dart run bin/run_all.dart --mode=jit "${args[@]+"${args[@]}"}" )
      ;;

    aot)
      mkdir -p build
      echo "==> compiling AOT native binary (path)" >&2
      dart compile exe \
        packages/fast_path_bench/bin/run_all.dart \
        -o build/run_all_aot >&2
      echo >&2
      ./build/run_all_aot --mode=aot "${args[@]+"${args[@]}"}"
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

      ( cd packages/fast_path_bench_flutter
        # Build, then exec the binary directly. `flutter run --release` would
        # also AOT-compile, but its stdout handling is opaque (the daemon
        # protocol does not reliably forward the app's stdout to the parent).
        # `flutter build` produces the same binary and lets us read its stdout
        # straight.
        echo "==> flutter build $device --release" >&2
        flutter build "$device" --release >&2

        echo "==> running $binary_relpath" >&2
        # Suppress stderr from the binary itself: the macOS embedder prints a
        # "Running with merged UI and platform thread" banner there. Our JSON
        # goes to stdout, which is what callers consume.
        exec "$binary_relpath" 2>/dev/null )
      ;;

    *)
      echo "path suite: unknown --mode=$mode (expected: jit, aot, flutter-desktop)" >&2
      exit 2
      ;;
  esac
}

run_geometry() {
  case "$mode" in
    jit)
      ( cd packages/fast_geometry_bench
        exec dart run bin/run_all.dart --mode=jit \
          "${args[@]+"${args[@]}"}" )
      ;;

    aot)
      mkdir -p build
      echo "==> compiling AOT native binary (geometry)" >&2
      dart compile exe \
        packages/fast_geometry_bench/bin/run_all.dart \
        -o build/matrix_aot >&2
      echo >&2
      ./build/matrix_aot --mode=aot "${args[@]+"${args[@]}"}"
      ;;

    flutter-desktop)
      echo "geometry suite is pure Dart (Matrix vs vector_math); it has no" >&2
      echo "dart:ui baseline. Use --mode=jit or --mode=aot." >&2
      exit 2
      ;;

    *)
      echo "geometry suite: unknown --mode=$mode (expected: jit, aot)" >&2
      exit 2
      ;;
  esac
}

case "$suite" in
  path) run_path ;;
  geometry) run_geometry ;;
  all)
    run_path
    echo
    run_geometry
    ;;
  *)
    echo "Unknown --suite=$suite (expected: path, geometry, all)" >&2
    exit 2
    ;;
esac
