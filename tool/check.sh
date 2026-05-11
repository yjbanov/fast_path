#!/usr/bin/env bash
# Run analyzer and tests across all packages in the workspace.
#
# Mirrors what CI runs. Useful before opening a PR.
#
# Each phase is timed. The whole suite should stay tight — fast_path is in
# the sweet spot where comprehensive tests can still finish in seconds. If
# a phase grows surprisingly slow, suspect a heavy dependency that snuck
# in rather than the tests themselves.

set -euo pipefail

# Move to repo root regardless of where the script is invoked from.
cd "$(dirname "$0")/.."

# Sub-second timestamps. Python 3 is reliably present on dev machines and
# CI runners; using it avoids the macOS/Linux `date +%s.%N` portability
# trap.
now_ms() {
  python3 -c 'import time; print(int(time.time()*1000))'
}

format_ms() {
  local ms="$1"
  if [[ "$ms" -lt 1000 ]]; then
    printf '%dms' "$ms"
  else
    awk -v ms="$ms" 'BEGIN { printf "%.2fs", ms/1000 }'
  fi
}

TIMINGS=()

run_phase() {
  local name="$1"; shift
  printf '\n==> %s\n' "$name"
  local start; start=$(now_ms)
  "$@"
  local elapsed=$(( $(now_ms) - start ))
  TIMINGS+=("$(printf '%-44s %s' "$name" "$(format_ms "$elapsed")")")
}

T_START=$(now_ms)

run_phase "dart pub get (workspace)" \
  dart pub get --offline

run_phase "dart analyze (workspace)" \
  dart analyze

run_phase "dart test (fast_path)" \
  bash -c "cd packages/fast_path && dart test --reporter=compact"

if command -v flutter >/dev/null 2>&1; then
  # --no-pub: the workspace was already resolved by `dart pub get` above.
  # Flutter would otherwise re-resolve, which scales with workspace size
  # and noticeably dominates this phase once the workspace has more than
  # a couple of packages.
  run_phase "flutter test (fast_path_conformance)" \
    bash -c "cd packages/fast_path_conformance && flutter test --reporter=compact --no-pub"
else
  echo
  echo "==> SKIPPED: flutter test (fast_path_conformance) — flutter not in PATH"
  TIMINGS+=("$(printf '%-44s %s' "flutter test (fast_path_conformance)" "SKIPPED")")
fi

T_TOTAL=$(( $(now_ms) - T_START ))

echo
echo "Timings"
echo "-------"
for t in "${TIMINGS[@]}"; do
  printf '  %s\n' "$t"
done
printf '  %-44s %s\n' "TOTAL" "$(format_ms "$T_TOTAL")"
echo
echo "All checks passed."
