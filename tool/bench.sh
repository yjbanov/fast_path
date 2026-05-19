#!/usr/bin/env bash
# Run the fast_path benchmark suite.
#
# Usage:
#   tool/bench.sh                       # JIT (default), table output
#   tool/bench.sh --json                # JIT, JSON output
#   tool/bench.sh --mode=aot            # AOT-compiled native binary
#   tool/bench.sh --mode=aot --json     # AOT, JSON output
#
# The --mode label is also forwarded into the benchmark's own metadata so
# JSON consumers can tell runs apart. dart2js, dart2wasm, and a Flutter
# desktop AOT runner will plug into this same script as additional cases.

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

  *)
    echo "Unknown --mode=$mode (expected: jit, aot)" >&2
    exit 2
    ;;
esac
