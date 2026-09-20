#!/bin/bash
# build.sh — the whole of Logical English 2 as a static site.
#
# What comes out of wasm/dist/ is a directory a static host serves as it is:
# the pages (the editor, the Proof Game, the views, the documentation), the
# SWI-Prolog WebAssembly runtime, and one payload file holding LE2's Prolog,
# the dictionaries, the libraries and the examples. There is no server in it.
# Deploy it to Vercel with
#
#     cd wasm/dist && vercel deploy --prod
#
# or serve it from anywhere else that serves files (docs/dev/deploy-vercel.md).
#
# The fly.io deployment is untouched by any of this: the Dockerfile, fly.toml
# and buildPush.sh are the same as they were, and the only Prolog this build
# needs that the server does not is wasm/ itself.
#
#   ./wasm/build.sh                 the public build
#   ./wasm/build.sh --private       include the private trees (see below)
#   ./wasm/build.sh --skip-editor   reuse editor/dist as it stands
#   ./wasm/build.sh --out DIR       somewhere other than wasm/dist
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="$ROOT/wasm/dist"
PRIVATE=0
SKIP_EDITOR=0
PORT=3099
SWIPL_WASM_VERSION="8.1.3"

while [ $# -gt 0 ]; do
    case "$1" in
        --private)     PRIVATE=1 ;;
        --skip-editor) SKIP_EDITOR=1 ;;
        --out)         shift; OUT="$1" ;;
        --port)        shift; PORT="$1" ;;
        -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

SWIPL="$ROOT/myswipl.sh"
[ -x "$SWIPL" ] || SWIPL="swipl"

#  One clean-up for the whole script, installed once: a second `trap … EXIT`
#  replaces the first, so anything registered later would otherwise be the
#  only thing that ran.
TMPNPM=""; LISTFILE=""; LOG=""; SERVER_PID=""
BUILD_INFO_TEMP=0
cleanup() {
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    [ "$BUILD_INFO_TEMP" = "1" ] && rm -f "$ROOT/build_info.txt"
    rm -rf "$TMPNPM" 2>/dev/null
    rm -f "$LISTFILE" "$LOG" 2>/dev/null
    return 0
}
trap cleanup EXIT

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

#  What this build is, for the pages and for config.js — computed here because
#  step 4 needs it as well as step 7.
#  `-c safe.directory`: in a container the checkout is often owned by another
#  user, and git then refuses to read it, which would stamp every build
#  "unknown@unknown" rather than the revision it came from.
GIT="git -C $ROOT -c safe.directory=$ROOT"
GIT_HASH=$($GIT rev-parse --short HEAD 2>/dev/null || echo unknown)
GIT_BRANCH=$($GIT rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
BUILD_INFO="${GIT_BRANCH}@${GIT_HASH} (WebAssembly, $(date -u +%Y-%m-%dT%H:%M:%SZ))"

say "Logical English 2 → WebAssembly (out: $OUT)"
rm -rf "$OUT"
mkdir -p "$OUT/le-wasm/swipl"

# ---------------------------------------------------------------------------
# 1. the editor, built as it is for the server image
# ---------------------------------------------------------------------------
if [ "$SKIP_EDITOR" = "0" ]; then
    say "1/8  Building the editor"
    ( cd editor && npm install --legacy-peer-deps --no-audit --no-fund && npm run build )
else
    say "1/8  Editor: reusing editor/dist (--skip-editor)"
fi
[ -f editor/dist/client.js ] || { echo "editor/dist/client.js is missing: build the editor first" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 2. the SWI-Prolog WebAssembly runtime
#
# Vendored under wasm/vendor/swipl/ when there is a copy there (an offline or
# reproducible build); otherwise npm fetches the published one, which is the
# same three files the swipl-wasm package ships.
# ---------------------------------------------------------------------------
say "2/8  SWI-Prolog runtime (WebAssembly)"
if [ -f wasm/vendor/swipl/swipl-web.wasm ]; then
    echo "  vendored: wasm/vendor/swipl"
    cp wasm/vendor/swipl/swipl-web.* "$OUT/le-wasm/swipl/"
else
    TMPNPM="$(mktemp -d)"
    ( cd "$TMPNPM" && npm install --silent --no-audit --no-fund "swipl-wasm@$SWIPL_WASM_VERSION" >/dev/null )
    cp "$TMPNPM/node_modules/swipl-wasm/dist/swipl/swipl-web.js" \
       "$TMPNPM/node_modules/swipl-wasm/dist/swipl/swipl-web.wasm" \
       "$TMPNPM/node_modules/swipl-wasm/dist/swipl/swipl-web.data" "$OUT/le-wasm/swipl/"
    echo "  swipl-wasm@$SWIPL_WASM_VERSION from npm"
fi

# ---------------------------------------------------------------------------
# 3. the payload: what the worker's file system will hold
#
# wasm/pack.pl decides — and the rule it applies is restricted_paths.pl's own,
# for a visitor with no roles, so that nothing a server would ask a user to log
# in for can be published by this build. --private turns that off, for a
# deployment that is not public; it is never the default.
# ---------------------------------------------------------------------------
say "3/8  Payload"
#  The shims' autoload index. A predicate called without an explicit import —
#  call_with_time_limit/2 was, in four files — is found by the autoloader, and
#  the autoloader only looks in library directories that have an INDEX.pl.
#  Generated here rather than committed, so it cannot fall behind the shims.
"$SWIPL" -q -g "make_library_index('wasm/shims'), make_library_index('wasm/shims/http'), halt." 2>/dev/null || true
LISTFILE="$(mktemp)"
if [ "$PRIVATE" = "1" ]; then
    echo "  ⚠ --private: including the linked private trees. Do NOT deploy this publicly."
    "$SWIPL" -q -g "use_module('wasm/pack'), print_payload_files([private(true)]), halt." 2>/dev/null > "$LISTFILE"
else
    "$SWIPL" -q -g "use_module('wasm/pack'), print_payload_files, halt." 2>/dev/null > "$LISTFILE"
fi
[ -s "$LISTFILE" ] || { echo "wasm/pack.pl listed no files" >&2; exit 1; }
node wasm/runtime/mkpayload.mjs "$LISTFILE" "$ROOT" "$OUT/le-wasm/payload.bin"

# ---------------------------------------------------------------------------
# 4. the pages the server renders, fetched from the server that renders them
#
# The landing page and the multilingual ones are Prolog (classic_web_api.pl).
# Rather than write them a second time in HTML, the build starts the real
# server with LE_STATIC_EXPORT=1 — which drops the login link and the button
# that runs the test suite, the two things a static copy cannot honour — and
# saves what it answers.
# ---------------------------------------------------------------------------
say "4/8  Server-rendered pages"

#  The landing page prints the build it was served by (`build_info.txt`, which
#  the Dockerfile writes into the image). A checkout has none, so the page
#  would say "unknown build" while config.js next to it says the revision —
#  two answers to the same question. Write it for the length of the export,
#  and take it away again if it was not there before.
if [ ! -f build_info.txt ]; then
    echo "${BUILD_INFO}" > build_info.txt
    BUILD_INFO_TEMP=1
fi

LOG="$(mktemp)"
LE_STATIC_EXPORT=1 "$SWIPL" -q -g "use_module(classic_web_api), start_api_server($PORT)" \
    -t "repeat, sleep(100), fail" > "$LOG" 2>&1 &
SERVER_PID=$!

for i in $(seq 1 60); do
    if curl -fsS -m 2 "http://localhost:$PORT/build_info" >/dev/null 2>&1; then break; fi
    sleep 1
done
curl -fsS -m 30 "http://localhost:$PORT/build_info" >/dev/null || {
    echo "the export server did not start; its output:" >&2; tail -20 "$LOG" >&2; exit 1; }

grab() {  # grab <url-path> <out-file>
    curl -fsS -m 120 "http://localhost:$PORT$1" -o "$OUT/$2" && echo "  $1 → $2"
}
grab "/" "index.html"
grab "/multilingual" "multilingual.html"
for LANG in $("$SWIPL" -q -g "use_module(le_i18n), forall((le_i18n:known_language(L), L \\== en), writeln(L)), halt." 2>/dev/null); do
    grab "/multilingual?lang=$LANG" "multilingual.$LANG.html"
done
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""
[ "$BUILD_INFO_TEMP" = "1" ] && rm -f build_info.txt

# ---------------------------------------------------------------------------
# 5. the static pages, as they are
# ---------------------------------------------------------------------------
say "5/8  Pages and assets"

#  copy_tree <src> <dest> [tar options...]
#
#  Copies a directory, and *never* follows a symbolic link out of it. That is
#  not hypothetical: `web_extras/insurML2browse` is a link into the private
#  InsurLE2 repository, and a `tar -h` here publishes 576 kB of it. The same
#  rule as wasm/pack.pl's, for the trees that are copied rather than packed —
#  and it says which links it skipped, so that a new one cannot go unnoticed.
copy_tree() {
    local src="$1" dest="$2"; shift 2
    local excludes=() link
    while IFS= read -r link; do
        [ -z "$link" ] && continue
        excludes+=( --exclude="${link#./}" )
        echo "  skipped symbolic link: $src/${link#./}"
    done < <(cd "$src" && find . -name node_modules -prune -o -type l -print 2>/dev/null)
    mkdir -p "$dest"
    tar -C "$src" -cf - "${excludes[@]}" "$@" . | tar -C "$dest" -xf -
}

mkdir -p "$OUT/editor" "$OUT/web_extras" "$OUT/docs"
copy_tree editor "$OUT/editor" --exclude=node_modules --exclude=test-results \
    --exclude=playwright-report --exclude=tests
copy_tree web_extras "$OUT/web_extras" --exclude=node_modules
#  docs/user only — which is exactly what the server publishes (public_doc/1
#  in classic_web_api.pl). The rest of docs/ is developer and project
#  material: plans, papers, reviews and the private notebook, none of which is
#  served at /docs/ on the deployment this build is a copy of.
copy_tree docs/user "$OUT/docs/user"
cp -f web_extras/executive/index.html "$OUT/executive.html" 2>/dev/null || true

#  The examples' text, at the address the server serves it from (/source/<name>),
#  so that a link or a QR code into this deployment still resolves. Extensionless,
#  as the server's is; vercel.json gives them a content type.
say "6/8  Example sources"
mkdir -p "$OUT/source"
COUNT=0
while read -r REL; do
    case "$REL" in
        examples/*.le)
            DEST="$OUT/source/${REL%.le}"
            mkdir -p "$(dirname "$DEST")"
            cp "$REL" "$DEST"
            COUNT=$((COUNT+1)) ;;
    esac
done < "$LISTFILE"

#  …and under the names they used to have. An example that moved keeps its old
#  name on the server (le_kbs:example_alias/2, and example_dir_alias/2 for a
#  whole directory) precisely so that a link, a QR code or a paper still
#  resolves; a static copy that dropped them would break exactly the links the
#  aliases exist to keep. Asked of the Prolog, so the two cannot disagree.
ALIASES=0
EXDIR=$("$SWIPL" -q -g "use_module(le_kbs), le_examples_dir(D), writeln(D), halt." 2>/dev/null)
while read -r OLD NEW; do
    [ -z "$OLD" ] && continue
    SRC="$OUT/source/$EXDIR/$NEW"
    DEST="$OUT/source/$EXDIR/$OLD"
    if [ -f "$SRC" ] && [ ! -e "$DEST" ]; then
        mkdir -p "$(dirname "$DEST")"
        cp "$SRC" "$DEST"
        ALIASES=$((ALIASES+1))
    fi
done < <("$SWIPL" -q -g "use_module(le_kbs), forall(le_kbs:example_alias(O,N), format('~w ~w~n',[O,N])), halt." 2>/dev/null)
echo "  $COUNT example sources under /source/, $ALIASES of them also under an old name"

# ---------------------------------------------------------------------------
# 7. the runtime, the configuration, and the script tag that starts it
# ---------------------------------------------------------------------------
say "7/8  Browser runtime"
cp wasm/runtime/boot.js wasm/runtime/worker.js "$OUT/le-wasm/"

cat > "$OUT/le-wasm/config.js" <<EOF
/* The deployment's own settings. Edited in place — it is the one file here
 * that is not a build artefact in spirit, so that a proxy can be turned on or
 * off without rebuilding the pages. */
window.LE_WASM_CONFIG = {
    base: '/le-wasm/',
    build: '${BUILD_INFO}',
    /* A same-origin address that will forward a request this page may not
     * make itself — an LLM provider, a document at another origin. Vercel
     * deployments get one at /api/proxy (wasm/api/proxy.js); '' turns the
     * whole outbound half off. */
    proxy: '/api/proxy',
    network: true,
    banner: true
};
EOF

#  /telemetry.js is a script the server renders (Sentry, when it is
#  configured). There is no server here and nothing to report to: an empty
#  file keeps the pages' <script src="/telemetry.js"> from 404ing.
printf '/* no telemetry in the WebAssembly build */\n' > "$OUT/telemetry.js"

#  The script tag, into every page: a classic script in <head> runs before the
#  deferred module scripts that do the fetching, which is what lets boot.js
#  replace fetch before anything uses it.
node wasm/runtime/inject.mjs "$OUT"

# ---------------------------------------------------------------------------
# 8. the host's own configuration
# ---------------------------------------------------------------------------
say "8/8  Host configuration"
#  The redirects a document's old address needs (doc_moved/2 in
#  classic_web_api.pl): a link printed in a paper two years ago still has to
#  land somewhere, and on the server that is a 301. Asked of the Prolog rather
#  than listed here, so the two cannot disagree.
"$SWIPL" -q -g "use_module(classic_web_api), forall(classic_web_api:doc_moved(O,N), format('~w ~w~n',[O,N])), halt." \
    2>/dev/null > "$OUT/.doc-redirects" || true
node wasm/runtime/mkvercel.mjs "$OUT" "$ROOT"
rm -f "$OUT/.doc-redirects"
mkdir -p "$OUT/api"
cp wasm/api/*.js "$OUT/api/" 2>/dev/null || true

SIZE=$(du -sh "$OUT" | cut -f1)
say "Done: $OUT ($SIZE)"
cat <<EOF
  Try it locally:   node wasm/runtime/serve.mjs "$OUT" 8080   →  http://localhost:8080/
  Deploy to Vercel: (cd "$OUT" && vercel deploy --prod)
  The instructions, in full:  docs/dev/deploy-vercel.md
EOF
