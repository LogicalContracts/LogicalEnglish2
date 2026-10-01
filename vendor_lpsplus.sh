#!/bin/bash
# vendor_lpsplus.sh — copy what this server uses of the private lpsPlus
# repository into vendor/lpsplus/, for the Docker image.
#
#   ./vendor_lpsplus.sh [/path/to/lpsPlus]      (default: $LPS_PLUS_DIR, then ../lpsPlus)
#
# What it copies: accounts/ (lc_accounts.pl, licenses.csv, passwords.csv —
# signing in and who holds which licence) and migration/ (the translators of
# other systems that File ▸ Open and Export offer). Only the files git knows
# about or would add: the gitignored caches of fetched sources and tools
# (gigabytes of them) stay behind.
#
# vendor/lpsplus/ is gitignored: it is a copy of a PRIVATE repository, with
# the licences and passwords tables in it. It must never be committed here,
# and the WebAssembly build never packs it (wasm/pack.pl).
set -e

cd "$(dirname "$0")"
PLUS="${1:-${LPS_PLUS_DIR:-../lpsPlus}}"
OUT="vendor/lpsplus"

if [ ! -f "$PLUS/accounts/lc_accounts.pl" ]; then
    echo "no lpsPlus at $PLUS (looking for accounts/lc_accounts.pl)." >&2
    echo "usage: ./vendor_lpsplus.sh /path/to/lpsPlus" >&2
    exit 1
fi

echo "vendoring lpsPlus (accounts, translators) from $PLUS"
rm -rf "$OUT"
mkdir -p "$OUT"
n=0
while IFS= read -r f; do
    [ -f "$PLUS/$f" ] || continue
    mkdir -p "$OUT/$(dirname "$f")"
    cp "$PLUS/$f" "$OUT/$f"
    n=$((n+1))
done < <(git -c safe.directory='*' -C "$PLUS" ls-files --cached --others --exclude-standard -- accounts migration)
{
    echo "lpsPlus, vendored for the LE2 image by vendor_lpsplus.sh."
    echo "Source: $PLUS"
    echo "Revision: $(git -c safe.directory='*' -C "$PLUS" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "Vendored: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT/VENDORED.txt"
echo "  $n files, $(du -sh "$OUT" | cut -f1)"
