# Logical English examples

The example programs of LogicalEnglish2, by purpose. Every folder has a README
saying what its programs show; its title is the folder's description on the
server's landing page.

| Tree | Example names | What |
|---|---|---|
| [`moreExamples/`](moreExamples/README.md) | `citizenship`, `language/unknowns/unknowns`, … | the main tree: a first set at its top, then `language/` (one program per feature), `domains/`, `collections/` |
| [`regulatory/`](regulatory/README.md) | `regulatory/…` | the regulatory-decision constructs and views (docs/user/reference/language.md §17) |
| [`migration/`](migration/README.md) | `migration/<source>/<twin>/<twin>` | twins of other systems' programs (Blawx, LegalRuleML, Miniscript, s(CASP)) |
| [`es/`](es/README.md) [`fr/`](fr/README.md) [`it/`](it/README.md) [`pt/`](pt/README.md) | `pt/cidadania`, … | programs written in other languages |
| [`api/`](api/README.md) | | calling LE from Prolog |
| `../testing/fixtures/le/` | `fixtures/…` | the programs the test suites load (listed to logged-in users) |

The proprietary examples (InsurLE2) appear under `moreExamples/insureLE2` when
that repository is linked there, for users with access.

**Names.** An example is opened by its name: `/editor/index.html?example=<name>`.
When an example moves, its old name keeps working through
`example_alias/2` / `example_dir_alias/2` in `le_kbs.pl`.
