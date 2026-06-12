#!/bin/sh
# myswipl.sh — resolve which SWI-Prolog interpreter to run and exec it with all
# arguments forwarded. Lets every caller (run_tests.sh, playwright.config.ts,
# ad-hoc commands) avoid hardcoding the macOS app-bundle path.
#
# Resolution order:
#   1. $SWIPL env var, when set to something other than this wrapper (override).
#   2. The macOS SWI-Prolog app bundle, when that binary exists.
#   3. `swipl` on PATH.
MAC_SWIPL="/Applications/SWI-Prolog10.0.0-1.app/Contents/MacOS/swipl"

case "${SWIPL:-}" in
    "" | */myswipl.sh | myswipl.sh ) : ;;   # unset or pointing back at us: ignore
    * ) exec "$SWIPL" "$@" ;;
esac

if [ -x "$MAC_SWIPL" ]; then
    exec "$MAC_SWIPL" "$@"
else
    exec swipl "$@"
fi
