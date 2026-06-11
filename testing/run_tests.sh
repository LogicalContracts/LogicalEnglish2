#!/usr/bin/env bash
#
# testing/run_tests.sh — run the LogicalEnglish2 test suites and aggregate the
# result. Lives in testing/ but always runs from the repo root.
#
# Suites:
#   unit  Prolog unit tests (plunit) in testing/test_*.pl  — fast, no server needed.
#   le    Logical English example tests (runTestsInDir over examples/moreExamples).
#   e2e   Playwright browser tests in editor/tests  — needs Node deps + browsers,
#         and starts its own Prolog server (see editor/playwright.config.ts).
#
# Usage (from anywhere):
#   testing/run_tests.sh              # run all suites (e2e is best-effort, see below)
#   testing/run_tests.sh unit         # run only the plunit suite
#   testing/run_tests.sh le           # run only the LE example suite
#   testing/run_tests.sh e2e          # run only the Playwright suite
#   testing/run_tests.sh unit le      # run a subset (space-separated)
#   testing/run_tests.sh --no-e2e     # run everything except e2e
#
# Environment:
#   SWIPL   swipl binary to use (default: swipl on PATH).
#   CI      when set, a missing e2e setup is treated as a FAILURE rather than a
#           skip (locally it is skipped so a plain run stays green).
#
# Exit status is 0 only if every suite that ran passed.

set -u
# This script lives in testing/; run all suites from the repo root so the
# relative paths used by le_kbs.pl, the examples dir, and editor/ resolve.
TESTING_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TESTING_DIR/.."

# Default to the ./myswipl.sh wrapper (we cd'd to the repo root above), which
# resolves $SWIPL / the macOS app bundle / `swipl` on PATH. An explicit SWIPL
# env var still wins.
SWIPL="${SWIPL:-./myswipl.sh}"

# --- argument parsing --------------------------------------------------------
run_unit=0 run_le=0 run_e2e=0
no_e2e=0
explicit=0
for arg in "$@"; do
  case "$arg" in
    unit) run_unit=1; explicit=1 ;;
    le)   run_le=1;   explicit=1 ;;
    e2e)  run_e2e=1;  explicit=1 ;;
    --no-e2e) no_e2e=1 ;;
    -h|--help)
      awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
      exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
if [ "$explicit" -eq 0 ]; then
  run_unit=1; run_le=1; run_e2e=1
fi
[ "$no_e2e" -eq 1 ] && run_e2e=0

# --- helpers -----------------------------------------------------------------
declare -a RESULTS
overall=0

record() { # name status   (status: PASS/FAIL/SKIP)
  RESULTS+=("$2  $1")
  [ "$2" = "FAIL" ] && overall=1
  return 0
}

hr() { printf '%s\n' "------------------------------------------------------------"; }

if ! command -v "$SWIPL" >/dev/null 2>&1; then
  echo "ERROR: swipl not found (set SWIPL=/path/to/swipl)." >&2
  exit 2
fi

# --- unit: plunit ------------------------------------------------------------
if [ "$run_unit" -eq 1 ]; then
  hr; echo "[unit] Prolog plunit tests (testing/test_*.pl)"; hr
  shopt -s nullglob
  unit_files=("$TESTING_DIR"/test_*.pl)
  shopt -u nullglob
  if [ ${#unit_files[@]} -eq 0 ]; then
    echo "No testing/test_*.pl files found."
    record "unit (plunit)" SKIP
  else
    load_args=()
    for f in "${unit_files[@]}"; do load_args+=(-l "$f"); done
    echo "Loading: ${unit_files[*]}"
    if "$SWIPL" -q "${load_args[@]}" -g "(run_tests -> halt(0) ; halt(1))"; then
      record "unit (plunit)" PASS
    else
      record "unit (plunit)" FAIL
    fi
  fi
fi

# --- le: Logical English example tests --------------------------------------
if [ "$run_le" -eq 1 ]; then
  hr; echo "[le] Logical English example tests"; hr
  # runTestsInDir over the default examples dir; also refreshes testSuiteStatus.txt
  # (as runTests/0 does) and exits non-zero if any example test fails or errors.
  if "$SWIPL" -q -l le_kbs.pl -g "
      le_kbs:le_examples_dir(Dir),
      le_kbs:runTestsInDir(Dir, Results),
      le_kbs:print_test_summary(Results),
      setup_call_cleanup(open('testSuiteStatus.txt', write, S),
                         with_output_to(S, le_kbs:print_test_summary(Results)),
                         close(S)),
      findall(1, (member(test_file(_,FR),Results), member(fail(_,_,_,_),FR)), Fs),
      findall(1, (member(test_file(_,FR),Results), member(error(_,_,_),FR)),  Es),
      length(Fs, NF), length(Es, NE),
      ( NF =:= 0, NE =:= 0 -> halt(0) ; halt(1) )
  "; then
    record "le (examples)" PASS
  else
    record "le (examples)" FAIL
  fi
fi

# --- e2e: Playwright ---------------------------------------------------------
if [ "$run_e2e" -eq 1 ]; then
  hr; echo "[e2e] Playwright browser tests (editor/tests)"; hr
  e2e_ready=1
  reason=""
  if ! command -v npx >/dev/null 2>&1; then
    e2e_ready=0; reason="npx (Node.js) not found"
  elif [ ! -d editor/node_modules ]; then
    e2e_ready=0; reason="editor/node_modules missing — run 'npm ci' in editor/"
  elif ! (cd editor && npx playwright --version >/dev/null 2>&1); then
    e2e_ready=0; reason="Playwright not installed — run 'npx playwright install' in editor/"
  fi

  if [ "$e2e_ready" -eq 1 ]; then
    if (cd editor && npm run test:e2e); then
      record "e2e (playwright)" PASS
    else
      record "e2e (playwright)" FAIL
    fi
  else
    echo "e2e prerequisites unavailable: $reason"
    if [ -n "${CI:-}" ]; then
      echo "CI is set — treating missing e2e setup as a failure."
      record "e2e (playwright)" FAIL
    else
      echo "Skipping e2e (set up the prerequisites, or this is fine for a quick local run)."
      record "e2e (playwright)" SKIP
    fi
  fi
fi

# --- summary -----------------------------------------------------------------
hr; echo "Summary"; hr
for line in "${RESULTS[@]}"; do printf '  %s\n' "$line"; done
hr
if [ "$overall" -eq 0 ]; then
  echo "OK — all suites that ran passed."
else
  echo "FAILED — see above."
fi
exit "$overall"
