# vendor/

Copies of other repositories, made for the server's Docker image and never
committed here (`.gitignore`):

- `lpsplus/` — the parts of the private lpsPlus repository this server uses:
  `accounts/` (signing in with Google, GitHub or a password, and the table of
  licences) and `migration/` (the translators of other systems). Made by
  `./vendor_lpsplus.sh`, which `buildPush.sh` runs; the image finds it through
  `LPS_PLUS_DIR` (Dockerfile) and `le_plus.pl`.

The WebAssembly build never packs this directory (`wasm/pack.pl`, `never/1`):
it holds the licences and passwords tables.
