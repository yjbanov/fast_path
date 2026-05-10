#!/usr/bin/env bash
# Run analyzer and tests across all packages in the workspace.
#
# Mirrors what CI runs. Useful before opening a PR.

set -euo pipefail

# Move to repo root regardless of where the script is invoked from.
cd "$(dirname "$0")/.."

echo "==> dart pub get (workspace)"
dart pub get

echo "==> dart analyze (workspace)"
dart analyze

echo "==> dart test (packages/fast_path)"
(cd packages/fast_path && dart test)

# fast_path_conformance and fast_path_flutter require Flutter to test.
# Wire those in once they contain tests:
#   (cd packages/fast_path_conformance && flutter test)
#   (cd packages/fast_path_flutter && flutter test)

echo
echo "All checks passed."
