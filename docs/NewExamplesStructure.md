# New examples structure: findings and proposal

*Status: proposal for validation, 2026-09-16. §1 records what was done
today. From §2 on, nothing is implemented.*

This covers the example trees of LogicalEnglish2 (`/work/examples`, "LE2") and
LPS2 (`/lps2/examples`). InsurLE2's own examples (customs, medicare, testing,
the extension tests, and the migration twins that stay private) are out of
scope, apart from §1.

---

## 1. Done today: the migration twins left InsurLE2

`InsurLE2/examples/migration/<source>/` was split according to the language
each twin is written in.

| Source | Twin language | New home | Twins | Tests after the move |
|---|---|---|--:|---|
| blawx | LE (prolog target) | `LogicalEnglish2/examples/migration/blawx` | 15 | `test_blawx` twins pass¹ |
| legalruleml | LE | `LogicalEnglish2/examples/migration/legalruleml` | 12 (+12 `deontic.le` copies) | `test_lrml` green |
| miniscript | LE | `LogicalEnglish2/examples/migration/miniscript` | 12 (+ `temporal.le/.pl` copies) | `test_miniscript` green |
| scasp | LE (prolog and scasp targets) | `LogicalEnglish2/examples/migration/scasp` | 17 | 17/17 twins pass² |
| daml | LE for LPS | `lps2/examples/migration/daml` | 11 projects, 22 files | `test_daml` green |
| drools | LE for LPS (+1 timeless reading) | `lps2/examples/migration/drools` | 5 | `test_drools` green; `lps run fire_alarm.le` OK |
| solidity | LE for LPS | `lps2/examples/migration/solidity` | 8 | InsurLE2 `test_solidity` 43/43; LPS2 `solidity_test` 26/26 |
| oia, oipa | – | **stay** in InsurLE2 (as asked) | | |
| **socotra** | LE | **held back in InsurLE2** (see below) | 17 | |
| **epilog** | LE (3 rulesets) + LE for LPS (10 games) | **held back in InsurLE2** (see below) | 13 | |

¹ `blawx_import:import_a_project` fails because Blawx's reasoner preamble
isn't fetched on this machine (`.cache`). It imports into a temp dir and
doesn't touch the twins.
² The five `scasp_source`/`scasp_oracle` tests fail because `library(scasp)`
is no longer installed in this container.

**Why Socotra and Epilog were not moved.** Their own READMEs record that their
sources have no licence and that the twins are kept in the private repository
until that is settled:
- `socotra/README.md`: "publication awaits confirmation of the product-library
  licence"; every ledger header says the same.
- `epilog/README.md`: "The Epilog texts carry no licence statement … kept here
  … in this private repository".

LogicalEnglish2 is on GitHub, so moving them would put them one commit away
from publication. If you confirm they can go public, it takes two commands:
- `socotra` → `LogicalEnglish2/examples/migration/socotra`.
- `epilog` splits: `kinship`, `blocks`, `graphs` → `LogicalEnglish2/examples/migration/epilog`; the ten games → `lps2/examples/migration/epilog`.

In both cases, also flip the rows in `InsurLE2/migration/le2_paths.pl`
`twins_home/2` and update the test paths in `test_epilog.pl` and `test_socotra.pl`.

**Wiring changed so that nothing breaks.**
- **InsurLE2.**
  - `migration/le2_paths.pl` has a new `twins_dir(Source, Dir)` that says where
    each source's twins live.
  - Every build and test (`blawx`, `legalruleml`, `miniscript`, `scasp`,
    `daml`, `drools`, `solidity`, and `daml_gate`) now uses it.
  - Paths are updated in the reader READMEs, `miniscript/chain/package.json`,
    the reports and the guru/video scripts.
  - The Daml and Drools scripts that opened the twins *in the LE2 editor*
    carry a NOTE: they need re-pointing to the LPS2 IDE before a re-shoot.
- **LE2.**
  - `le_kbs.pl` registers `le_extra_examples_dir('migration', 'examples/migration')`.
    The twins are now listed on the landing page, in Open from server and in
    the MCP names (`migration/blawx/bird/bird`), and run by the core suite.
  - Three twin trees only work with the proprietary extensions, so they are
    added to `extension_dependent_path_fragment/1`:
    - `migration/miniscript/` (embedded Prolog goals)
    - `migration/blawx/bird/` (grouped alternatives)
    - `migration/scasp/turingcomplete/` (embedded Prolog)

    I found them by running every twin with and without `le_extensions.pl`.
  - `AGENTS.md` and `docs/le_migration.md` are updated.
  - `testing/run_tests.sh --no-e2e` is green, and `testSuiteCoreStatus.txt`
    was regenerated.
- **LPS2.**
  - `lps_http.pl` gains an `example_dir/2` clause for
    `examples/migration/<source>/<twin>/`. The IDE lists the 43 twin files, one
    folder per twin, and opens them.
  - `tools/solidity_test.pl` finds the twins in its own tree.
  - `CLAUDE.md` layout row updated.

---

## 2. The trees today

### 2.1 LogicalEnglish2 `examples/`

| Tree | `.le` | What it is | How it is reached |
|---|--:|---|---|
| `moreExamples/` (top level) | 37 | Tutorial programs (tea_party, happy_dragon, citizenship), feature demos (unknowns, synonyms, white_rabbit, named_vars, dates, only_if, assumption_constraints), older domain programs (cgt_assets, journal, royal_family, ecommerce, enclosure, sequencer) and **test fixtures** (error, rule_id_test, type_check_test, scenario_element_test, numbering_test, clp_coverage, AItest) | `le_examples_dir/1`: the landing page root and bare `?example=` names |
| `moreExamples/tax/` | 12 | Australian tax programs (the LE1 corpus) | listed |
| `moreExamples/testing/` | 14 | Regression fixtures, shown to users on the landing page | listed |
| `moreExamples/short/` | 4 | Small syntax samples | listed |
| `moreExamples/abduction/` | 4 | PEG 2026 paper examples | listed; `?dir=abduction` e2e |
| `moreExamples/rkBook/` | 22 | Kowalski's book, timeless chapters, in LE | listed |
| `moreExamples/LogicalThinkingInAgeOfAI/` | 4 | Talk examples | listed |
| `moreExamples/prolog_resources/` | 2 (+ .pl) | Including Prolog facts | listed |
| `moreExamples/insureLE2` → `/InsurLE2/examples` | – | Proprietary mount (restricted) | listed with login |
| `RulesRus/` | 11 | Regulatory-decision constructs (le_summary §17), views | `le_extra_examples_dir` |
| `migration/` | 68 (+ library copies) | Twins of Blawx, LegalRuleML, Miniscript, s(CASP) | `le_extra_examples_dir` (new) |
| `es/ fr/ it/ pt/` | 3/1/1/4 | Programs in other languages | `language_examples_dir/2` |
| `lps/` | 17 (+ 5 `.lps` companions, 17 `.expected.lpsw`) | **LE for LPS**: LE2's LPS-target regression corpus, and the "Logical English" folder of the LPS2 IDE | `testing/lps_test.pl`; LPS2 `le_examples_dir/1`; LPS2 `vendor_le2.sh` |
| `appExample1.pl` | – | Prolog API example for `appExample1_web.sh` | nothing lists it |

### 2.2 LPS2 `examples/`

| Tree | Files | What it is | How it is reached |
|---|---|---|---|
| top level | `blocks.lps`, `blocks3d.lps`, `lights.lps`, `thermostat.lps`, `goat_declarative.pl` (+`.lpst`) | The "start here" set | `START_HERE` (`main.js:1238`), the start page, `examples_test.pl` |
| `rkbook/` | 12 `.lps` | Kowalski's book, chapters on time, agents and the event calculus | `rkbook_test.pl` |
| `if/` | 13 `.le`, 3 `.lps`, `inform/` 11 `.ni`, `expected/`, `phase0/` | Interactive fiction: the library and its stories | `if_test`, `play_test`, `inform_test` |
| `pddl/` | 17 `.pddl` | Planning problems, converted on opening | `pddl_test` |
| `drools/` | 5 `.drl` + 1 `.wording` | Rule bases, converted on opening | `drools_test` |
| `agent/` | 2 `.lps` + `demo.mjs` | LLM agent (Part II) | docs |
| `minecraft/` | 3 `.lps` + a Node bot (logs, `node_modules`, world ignored) | Minecraft agent (Part III) | docs |
| `migration/` | Daml, Drools, Solidity twins | new | `example_dir/2` (new) |

---

## 3. Findings

### 3.1 Redundancies and near-duplicates

| Group | Files | Relationship | Suggestion |
|---|---|---|---|
| Happy dragon | `moreExamples/happy_dragon.le`, `testing/happpy_dragon.le` | The fixture is the same program plus one scenario (and a typo in the name) | Fold the scenario into `happy_dragon.le`, delete the fixture |
| Tea party | `tea_party.le`, `testing/tea_party2.le`, `tea_party3.le` | Variants with extra rules for tests | Keep them as fixtures, out of the gallery (§4) |
| Subset | `moreExamples/subset.le`, `short/sets.le`, `es/conjuntos.le`, `migration/scasp/subset/subset.le` | `sets.le` is `subset.le` plus a query; `conjuntos` translates it; the s(CASP) one is LE1's version | Keep one (`subset.le` with the query), keep the translation and the twin |
| CGT assets | `moreExamples/cgt_assets.le`, `tax/1_cgt_assets_and_exemptions_3.le` | Two versions of the same program (113 diff lines) | Keep the `tax/` one |
| Journal | `moreExamples/journal.le`, `tax/journal_balance.le` | Same domain, the tax one extended | Keep the `tax/` one |
| Sums | `sum_onto.le`, `sum_simple.le` | Two tiny aggregate samples, both unreferenced | Merge into one feature example |
| Grass is wet | `abduction/grass_is_wet.le`, `rkBook/grass_wet_abduction.le` | The same book example, written twice | Keep `abduction/grass_is_wet` (tests and docs use it); make the rkBook entry include or point to it |
| Citizenship | `citizenship.le`, `citizenship_including.le`, `testing/citizenship_premier.le`, `testing/citizenship_buggy.le`, `rkBook/bna_citizenship_1_1.le`, es/fr/it/pt translations, `migration/scasp/citizenshiptrust`, LPS2 `rkbook/citizenship_time.lps` | Intended family: the canonical program, include demo, fixtures, translations, LE1 twin, temporal LPS reading | Keep all; group the fixtures with the fixtures; cross-link in a README |
| Kowalski's book | LE2 `moreExamples/rkBook/` (22 `.le`) and LPS2 `rkbook/` (12 `.lps`) | Complementary halves: timeless chapters in LE, time and agent chapters in LPS. Only the underground notice, fox and crow, trolley and citizenship examples exist in both | Keep both, one README each, cross-linking the other half and `docs/RK_book/bookExamples.md` |
| Goat | LE2 `lps/goat.le`, `lps/goat_declarative.le`, `lps/prospective_goat.le`; LPS2 `goat_declarative.pl` | The same puzzle in LE for LPS and in LPS, intentional pairs | Keep; say so in the READMEs |
| Drools | LPS2 `drools/{discount,fire-alarm,insurance,shipping}.drl` and `migration/drools/<case>/sources/*.drl` | Same Drools examples: LPS2's are trimmed copies (35–129 diff lines) for the "open a DRL" door; the twins carry the upstream originals | Keep `drools/` as the door demo (tests use it); each twin README links the door file |
| Alice | LE2 `moreExamples/alice.le` vs LPS2 `if/alice.le` | Name clash only | Rename LE2's to a descriptive name when it moves (`test_proof_game` uses it) |
| IF companions | LPS2 `if/alice.lps`, `if/alice_pure_lps.lps` | **Byte-identical** | Keep one; make the other name resolve to it |
| Library copies in twins | 12 × `temporal.le`/`.pl` (Miniscript), 12 × `deontic.le` (LegalRuleML), 3 × `ownable.le`, 2 × `erc20.le`/`pausable.le` (Solidity) | `le_migration:copy_library` copies `lib/` files so a twin works on its own; the Solidity copies are the Wizard composition | Keep them (deliberate). Alternative: include `lib/` by path once the editor resolves `lib/` includes everywhere |
| LE for LPS in two repos | LE2 `examples/lps/` (17) vs LPS2 `if/*.le` and `migration/{daml,drools,solidity}` | Same language, different repositories | See §4.3, decision D2 |

### 3.2 Structural problems

1. **The gallery mixes fixtures with teaching material.**
   - `moreExamples/testing/` and the top-level `*_test.le`, `error.le` and
     `clp_coverage.le` show up on the public landing page.
   - `testing/test_fixtures_integrity.pl` already lists what the unit tests
     need.
2. **`moreExamples` is a name from history.** It is the main tree, and its
   folders are grouped by provenance (tax, rkBook, a talk, a paper), not by what
   a reader wants to learn.
3. **Three examples are public but only run with the proprietary extensions**
   (`migration/miniscript`, `blawx/bird`, `scasp/turingcomplete`).
   - `le_writer` has an `extensions(auto)` option. Rebuilding those twins with
     extensions off would make them core, as long as the readers can express
     the embedded Prolog goals (Miniscript's `temporal.pl` helpers) and
     grouped alternatives (`bird`) in core LE.
4. **The MCP `list_examples` only lists `moreExamples`.** RulesRus, migration
   and the language trees are invisible to MCP clients (`llm/mcp.pl:438-450`).
5. **Stale example references (already broken).**
   - `le_assistant_light.pl:357-358` and `appExample1_web.sh:109-114` still
     name `moreExamples/1_net_asset_value_test_3.le` and `payg.le` (now in
     `tax/`). The light assistant silently gets fewer examples.
   - `lps2/docs/lps_tutorial.md:393` names `examples/goat.pl`.
   - Many docs say "fifteen" `examples/lps` programs; there are 17.
6. **No READMEs at tree level.**
   - LE2 has READMEs only in `rkBook`, `abduction`,
     `LogicalThinkingInAgeOfAI` and the migration sources. LPS2 has them in
     `rkbook`, `if` and `minecraft`.
   - The `abduction` README is stale: it says LE has no integrity constraints.
7. **Orphans** (nothing but the generic listing reaches them):
   - LE2 main tree: `alice_propositional`, `ecommerce`, `enclosure`,
     `inequality`, `propositional`, `sum_*`, `unknowns_in_*`, `royal_family.md`,
     all of `short/`, most of `tax/`, `rkBook/` (except `amazing_animals`).
   - LPS2: `agent/approval_ide.lps`, `minecraft/hungry.lps`.
   - They are not wrong, but nothing says what they teach.
8. **LPS2's listing is a fixed table read one level deep.** A new subfolder
   needs a row, and the migration clause assumes exactly two levels.
9. **`examples/appExample1.pl`** sits at the root, where nothing lists it; it
   belongs with the script that uses it.

---

## 4. Proposal

### 4.1 Principles

- **Organise by purpose.**
  - *start* (the shortest way in)
  - *language* (one program per feature, named after the reference section
    it illustrates)
  - *domains* (larger programs)
  - *collections* (books, papers, talks)
  - *migration* (twins)
  - *languages* (non-English)

  Provenance goes in a README, not in the path.
- **Fixtures are not examples.** They move under `testing/fixtures/` and are no
  longer listed to users. The LE example suite still runs them.
- **Every folder has a README**: what it teaches and which doc section it goes
  with. The public doc site (see `docs/NewDocumentationStructure.md` §4.5)
  builds its Examples section from these READMEs.
- **Names users have seen keep working.** Old `?example=` names (links, QR
  codes, papers, videos, e2e specs) resolve through an alias table,
  `example_alias(Old, New)`, consulted by `le_example_relpath/2`. The same
  applies in LPS2 for `goat_declarative` and friends.
- **Each repository keeps the examples of the language it implements.** This is
  the rule applied to the twins today.

### 4.2 LogicalEnglish2 `examples/`

```
examples/
  README.md                      index of the trees
  start/                         ◀ main tree root (replaces moreExamples as le_examples_dir)
    README.md                    the tutorial path: IntroToLE2 uses these
    tea_party.le  happy_dragon.le  citizenship.le  alice.le→happy_person.le
    dates.le  numbers.le  royal_family.le (+ drop royal_family.md, or fold notes into comments)
  language/                      one program per feature, README maps file → le_summary §
    unknowns/        unknowns.le  unknowns_in_aggregates.le  unknowns_in_forall.le  assumption_constraints.le
    abduction/       ← moreExamples/abduction (grass_is_wet, sunglasses, loan_approval, diagnosis) + README fixed
    negation/        only_if.le  propositional.le  alice_propositional.le  inequality.le
    templates/       synonyms.le  named_vars.le  white_rabbit.le  is_a_class_of.le  longsentence.le  sets.le(=subset + query)
    aggregates/      sums.le (sum_onto + sum_simple)  ecommerce.le
    includes/        citizenship_including.le  prolog_resources/ (postcodes*)
    scasp/           dual_engine_demo.le
    views/           (the views-only programs, if any are split from regulatory/)
  regulatory/                    ← RulesRus (renamed; le_summary §17)
  domains/
    tax/             ← moreExamples/tax (+ cgt_assets, journal merged into their tax versions)
    other/           enclosure.le  sequencer.le  augmentedsem.le  flying_dragon.le  sunangel.le
  collections/
    kowalski-book/   ← moreExamples/rkBook (README links lps2 examples/rkbook)
    logical-thinking-talk/ ← moreExamples/LogicalThinkingInAgeOfAI
  migration/         blawx/ legalruleml/ miniscript/ scasp/ (+ socotra/ epilog/ if cleared)
  lang/              es/ fr/ it/ pt/          (or keep examples/<lang>/: see decision D4)
  lps/               see §4.3
  api/               appExample1.pl (+ appExample1_web.sh moves beside it or points here)
  proprietary        → the insureLE2 mount stays where the landing page shows it (start/insureLE2), restricted
testing/fixtures/le/
  error.le  rule_id_test.le  type_check_test.le  scenario_element_test.le  numbering_test.le
  clp_coverage.le  AItest.le  + all of moreExamples/testing/ (happpy_dragon folded into happy_dragon)
```

**Code and data touched in LE2.**
- **Tree registration.**
  - `le_kbs.pl`: `le_examples_dir` → `examples/start`; the extra dirs become
    `language`, `regulatory`, `domains`, `collections`, `migration`, `api`?;
    `language_examples_dir` → `examples/lang/<L>` (if D4); new
    `example_alias/2`; the suite runs `testing/fixtures/le` too; the
    `extension_dependent_path_fragment` rows are updated.
  - `classic_web_api.pl`: the landing page shows the trees in the order above,
    with each README's first line as the folder blurb; `?dir=` stays relative
    to its tree.
  - `llm/mcp.pl`: `list_examples` covers every registered tree, not only
    `moreExamples`.
- **Prompts and assistants.** `le_assistant_light.pl:354-361` gets its fixed
  list repaired. `AGENTS_LE_template*.md` point at `examples/start` and
  `examples/language`.
- **Tests and scripts.**
  - Unit tests with hard paths: about 30 files, listed per example by the
    reference scan. Most name `citizenship.le`, `happy_dragon.le`, `alice.le`,
    `synonyms.le` and fixtures. A `fixture_path/2` helper in
    `test_fixtures_integrity.pl` keeps this to one table.
  - E2E specs: about 15 files. They use `?example=` names, which the aliases
    keep working. New names can be adopted gradually.
  - `testing/le_writer_roundtrip.pl` and `scasp_roundtrip.pl` should use the
    `le_kbs` tree predicates instead of their own directory lists.
- **Docs and deployment.**
  - Docs: `IntroToLE2.md`, `le_summary.md` (about 25 example paths),
    `ProofGame.md`, `sCASP_on_LE.md`, `IntroducingLEViews.md`, `api.md`,
    `AGENTS.md`.
  - Deployment: `fly.toml:21` `ALLOWED_LE_EXPORTS`, `.dockerignore:9`,
    `InsurLE2/README.md` (symlink location).

### 4.3 LPS2 `examples/`

```
examples/
  README.md
  start/           blocks.lps  blocks3d.lps  lights.lps  thermostat.lps  goat_declarative.pl(+.lpst)
  collections/kowalski-book/   ← rkbook (README cross-links LE2's half)
  agents/          llm/ ← agent   minecraft/ ← minecraft
  doors/           pddl/ ← pddl   drools/ ← drools   (inform stays with if/, which needs it)
  if/              library + stories (+ inform/, expected/, phase0/ as today)
  le/              ← LE2 examples/lps  (decision D2)
  migration/       daml/ drools/ solidity/ (+ epilog/ if cleared)
```

**Code and data touched in LPS2.**
- **Listing and names.**
  - `lps_http.pl`: `example_dir/2` becomes a recursive walk of `examples/`
    with a label per folder taken from its README (the fixed table and the
    two-level migration clause go away); `folder_rank` follows.
  - An alias table keeps `goat_declarative`, `blocks`, `lights` and
    `thermostat`, which are start-page links and documented URLs.
  - `ui/src/main.js` `START_HERE` and `GROUP_BLURB`.
- **Tests and tools.**
  - `lps_le.pl:482` (the `examples/if` include base is unchanged) and
    `lps_le.pl:515-526` (searches one level down; make it the tree).
  - The per-folder prefixes in `tools/{sandbox,surface,pddl,drools,rkbook,if,inform,examples}_test.pl`.
  - `doc_shots.cjs`, `ide_check.cjs`, `.dockerignore` (minecraft lines).
- **Docs.** `lps_tutorial.md`, `IntroducingLPS2.md`, `UsingTheIDE.md`,
  `CLAUDE.md`, README.

**Where LE for LPS lives (D2).** LE2's `examples/lps/` is LE2's regression
corpus for its LPS target (`testing/lps_test.pl`, `.expected.lpsw`) and LPS2's
"Logical English" folder. Two options:
- **(a) Move it to `lps2/examples/le/`** (consistent with today's rule).
  - LE2's `lps_test.pl` then either reads the LPS2 checkout when present
    (skips otherwise), or keeps a minimal copy under
    `testing/fixtures/lps/`.
  - LPS2's `le_examples_dir/1`, `vendor_le2.sh:56-58`, `m8a_test.pl` and the
    `?example=le/...` links point at its own tree.
- **(b) Keep it in LE2** and say so in both READMEs: it is where the LPS
  *target* of LE2 is tested.

Recommendation: **(a)**. Users look for LE-for-LPS programs in the LPS2 IDE,
the language doc (`le_lps_surface.md`) is heading to lps2, and LE2 keeps a
small fixture set for its own target tests.

### 4.4 Cleanups that need no restructuring (can be done first)

1. Repair the stale references of §3.2.5 (`le_assistant_light.pl`,
   `appExample1_web.sh`, `le_grammar.pl:3654` comment, `lps_tutorial.md:393`,
   the "fifteen" counts).
2. Fold `testing/happpy_dragon.le` into `happy_dragon.le`.
3. Delete `short/sets.le` after adding its query to `subset.le`.
4. Retire `moreExamples/cgt_assets.le` and `journal.le` in favour of the `tax/`
   versions (both unreferenced).
5. Merge `sum_onto` and `sum_simple`.
6. Deduplicate `if/alice_pure_lps.lps`.
7. Fix the `abduction/README.md` sentence on integrity constraints.
8. Fix the `rkBook/README.md` link to `docs/RK_book/bookExamples.md`.
9. MCP `list_examples` over every registered tree.
10. Try rebuilding the three extension-dependent twins with
    `le_writer` extensions off.

---

## 5. Plan

| Step | Work | Risk |
|---|---|---|
| 1 | §4.4 cleanups; `--no-e2e` + status file | low |
| 2 | Alias tables in LE2 (`example_alias/2`) and LPS2; e2e for old names | low |
| 3 | LE2: fixtures → `testing/fixtures/le`; `moreExamples` → `start/ language/ domains/ collections/`, `RulesRus` → `regulatory`; READMEs; tests, docs and prompts updated; full suite | medium: about 45 test files and about 10 docs name paths; the aliases absorb the URLs |
| 4 | LPS2: recursive listing with README labels; folders of §4.3; tools and docs; IDE check + tools tests | medium |
| 5 | D2 (LE for LPS) and, when cleared, Socotra and Epilog | small once decided |

## 6. Decisions needed

- **D1.** Socotra and Epilog twins: may they be published (move as in §1)? NO, they stay "proprietary" until licensing is sorted out
- **D2.** LE for LPS (`examples/lps`): move to `lps2/examples/le` (recommended) or keep in LE2? Follow your recommendation
- **D3.** Rename `moreExamples` (with aliases) as in §4.2, or keep the name and only regroup inside it? only regroup
- **D4.** Language trees: `examples/<lang>/` as today (the folder name is the language code, and `?example=pt/...` links exist) or `examples/lang/<lang>/`? Recommendation: keep `examples/<lang>/`; it costs nothing and the aliases would be one more table. Follow your recommendation
- **D5.** Should fixtures stay visible to logged-in developers (e.g. a `?dir=fixtures` landing view), or be hidden entirely? Stay visible
- **D6.** Twin library copies (`temporal`, `deontic`): keep them self-contained (recommended) or include from `lib/`? keep them self-contained
