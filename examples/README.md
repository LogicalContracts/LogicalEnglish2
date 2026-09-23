# Logical English examples

The example programs of LogicalEnglish2, by purpose. Every folder has a README
saying what its programs show; its title is the folder's description on the
server's landing page.

| Tree | Example names | What |
|---|---|---|
| [`moreExamples/`](moreExamples/README.md) | `citizenship`, `language/unknowns/unknowns`, … | the main tree: a first set at its top, then `language/` (one program per feature), `domains/`, `collections/` |
| [`regulatory/`](regulatory/README.md) | `regulatory/…`, `regulatory/customs/tariff`, `regulatory/medicare/pmd_cases` | the regulatory-decision constructs and views (docs/user/reference/language.md §17), and two large models built with them: customs classification and Medicare equipment coverage |
| [`migration/`](migration/README.md) | `migration/<source>/<twin>/<twin>` | twins of other systems' programs (Blawx, LegalRuleML, Miniscript, Oracle Insurance Policy Administration, s(CASP)) |
| [`es/`](es/README.md) [`fr/`](fr/README.md) [`it/`](it/README.md) [`pt/`](pt/README.md) | `pt/cidadania`, … | programs written in other languages |
| [`api/`](api/README.md) | | calling LE from Prolog |
| `../testing/fixtures/le/` | `fixtures/…` | the programs the test suites load (listed to logged-in users) |

The browser version of LE2 (the WebAssembly build, `wasm/`) is "LE light": it
leaves out `regulatory/customs/`, `regulatory/medicare/` and
`migration/oipa/` for their size (`light_excluded/1` in `wasm/pack.pl`); the
server has them.

The large models and the twins are provided "as is", without warranty of any
kind, and are not advice: each tree's README, and each program's opening
comment, says so in full.

The proprietary examples (InsurLE2) appear under `moreExamples/insureLE2` when
that repository is linked there, for users with access. The twins whose
sources carry no licence that allows publication (Oracle Intelligent Advisor,
Socotra, Epilog) are not published; they appear, the same way, under
`moreExamples/lpsPlus/migration`, for users with access.

**Names.** An example is opened by its name: `/editor/index.html?example=<name>`.
When an example moves, its old name keeps working through
`example_alias/2` / `example_dir_alias/2` in `le_kbs.pl`, and
`testing/test_example_alias.pl` checks every row. For readers, the same thing is
in the manual: [Example names, and the names they used to
have](../docs/user/guide/editor.md#example-names-and-the-names-they-used-to-have),
which carries the table of directory renamings (the test keeps the two in step).
