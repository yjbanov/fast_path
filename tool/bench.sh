#!/usr/bin/env bash
# Run the fast_path benchmark suite.
#
# This is the JIT entry point — runs `dart run` against the bench
# package's run_all.dart. AOT, dart2js, and dart2wasm modes will be added
# as separate scripts (or flags) in follow-ups; the JSON output of
# `--json` is the contract those modes will share.
#
# Usage:
#   tool/bench.sh           # human-readable table
#   tool/bench.sh --json    # machine-readable JSON to stdout

set -euo pipefail

cd "$(dirname "$0")/.."

# Make sure the workspace is resolved. Quiet on success.
dart pub get >/dev/null

cd packages/fast_path_bench
exec dart run bin/run_all.dart "$@"
