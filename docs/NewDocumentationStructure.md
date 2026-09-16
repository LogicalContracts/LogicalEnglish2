# New documentation structure: findings and proposal

*Status: proposal for validation, 2026-09-16. Nothing described under "Proposal"
has been implemented. Scope: the documentation shown to users by the LE2 editor
(`LogicalEnglish2`, here `/work`) and the LPS2 IDE (`/lps2`), and every document
in `LogicalEnglish2/docs`, `InsurLE2/docs` and `lps2/docs` (plus the READMEs
around them). The private `vibeCodingNotes.md` files were left out of the
inventory; they appear only in the exposure finding of §1.3.*

Contents: §1 what users are shown today · §2 the corpus by purpose · §3 problems
· §4 target structure · §5 disposition, document by document · §6 plan · §7
decisions needed.

---

## 1. What users are shown today

### 1.1 LE2 (editor and landing page)

| Entry point | Label | Document | Code |
|---|---|---|---|
| Editor Help menu | Introduction to Logical English | `docs/tutorial0/IntroToLE2.md` (+21 PNGs) | `editor/index.html:795` |
| Editor Help menu | Using this editor | `docs/howToUse.md` | `editor/index.html:796` |
| Editor Help menu | Logical English syntax | `docs/le_summary.md` | `editor/index.html:797` |
| Landing page `/`, "Documentation" | the same three documents | as above | `classic_web_api.pl:394-414` |
| Landing page `/multilingual?lang=pt` | syntax summary | `docs/le_summary.pt.md`. It exists only for pt, so es/fr/it get no documentation | `classic_web_api.pl:699-711` |
| Landing page | GitHub repository | `github.com/mcalejo/LogicalEnglish2` (redirects; the repo is `LogicalContracts/…`) | `classic_web_api.pl:392` |
| Doc viewer header | ← Logical English / Editor / View source on GitHub | `web_extras/docsview/viewer.html` | `:64-67, 80-81, 120` |
| Tooltips and verifier messages | cite `docs/le_summary.md §17.10`, `§17.4`, `§15.5` as plain text | – | `editor/index.html:915`; `i18n/messages.csv:168,190,192` |
| Links inside documents | `IntroducingLEViews.md` (from howToUse and le_summary) | opens as **raw markdown**: the LE2 viewer does not rewrite `.md` links | `howToUse.md:85`, `le_summary.md:1270` |

**Route.** `/docs/<path>` (`classic_web_api.pl:67`, `handle_docs` `:3249`). It
serves any file under `docs/`, and renders `<path>.md` through
`web_extras/docsview/viewer.html` (marked.js). The only check is that the path
stays inside `docs/`: no allow-list, no login.

There is **no** contextual help: no "?" on panes, no hover links, no About box,
no shortcut sheet. The executive view and the Contract Assistant page have no
documentation links at all.

### 1.2 LPS2 IDE (`/ide`) and landing page

| Entry point | Label | Document | Code |
|---|---|---|---|
| Help menu | All the examples | `/` (start page) | `ui/src/main.js:1635` |
| Help menu | Keyboard shortcuts… | in-app dialog | `main.js:1636, 1789` |
| Help menu | Using the editor | `docs/UsingTheIDE.md` | `main.js:1638` |
| Help menu | Learning LPS — the tutorial | `docs/lps_tutorial.md` | `main.js:1639` |
| Help menu | Language reference | `docs/lps_summary.md` | `main.js:1640` |
| Help menu | Glossary | `docs/glossary.md` | `main.js:1641` |
| Help menu | Introducing LPS2 | `docs/IntroducingLPS2.md` | `main.js:1642` |
| Help menu | About the icons… / About LPS2… | in-app dialogs (links `lps.doc.ic.ac.uk`, `logicalcontracts.com`) | `main.js:1644-1645` |
| View menu | Documentation beside the editor | `UsingTheIDE` docked in an iframe | `main.js:1602, 1781` |
| Pane header "?" | What this pane shows | `UsingTheIDE#timeline`, `#changes`, `#automaton`, `#2d`, `#3d`, `#internal` | `ui/static/index.html:154`, `main.js:829-843` |
| Monaco hover on declarations | "See the language reference" | `lps_summary` | `ui/src/lps-language.js:252` |
| Landing page "Documentation" | tutorial, guide, reference, glossary, Introducing LPS2, **LPS2abstract, ProfessorKsystemImpressions, ProfessorKsecondPass** | as named | `src/edges/lps_http.pl:188-215` |
| Doc page "← IDE" | goes to `/`, the landing page, not `/ide` | – | `ui/static/doc.html:26` |

**Routes.** `/docs/<Name>` renders `docs/<Name>.md` (a flat name only:
subdirectories cannot be rendered), `/docs-raw/<path>` serves any text file
under `docs/`, and `/docs/images/`. The viewer rewrites `.md` links. There is no
login and no i18n. Unknown names answer 200 with "no such document".

Documents reached through links inside the served ones: `deploy.md`,
`LPSplusLLM.md`, `selection_spec.md`, `conformance_lps2.md`, `ide.md`,
`le_lps_surface.md`, `LPS2abstract.md`.

### 1.3 Exposure and hygiene findings (act on these first)

1. **Both servers publish their entire `docs/` directory, private notes included.**
   The Dockerfiles copy it whole (`/work/Dockerfile:49`, `/lps2/Dockerfile:48`),
   neither `.dockerignore` excludes anything in it, and neither route has an
   allow-list. So the deployed servers answer `/docs/vibeCodingNotes`, and LPS2
   also answers `/docs-raw/vibeCodingNotes.md`. The file is also tracked in git
   in both repositories. LE2 additionally serves:
   - `docs/RK_book/CLandHT-HtobAI.pdf` (a copyrighted book, 326 pages) and its
     8,090-line markdown conversion;
   - `docs/papers/under-review-LE2areimplementation.pdf`.
2. **Documents that LLM features load, by path.** These constrain any move:

   | Feature | File(s) | Code |
   |---|---|---|
   | LE2 light assistant | `docs/le_summary[.<lang>].md` (inlined whole); `AGENTS_LE_template[.<lang>].md`; curated `examples/moreExamples/*.le` | `le_assistant_light.pl:220-372` |
   | LE2 deep assistant (opencode) | `AGENTS_LE_template.md`, which points at `docs/le_summary.md` and `examples/moreExamples/` | `le_assistant.pl:77, 505-526` |
   | LE2 Contract Assistant | `docs/le_summary[.<lang>].md`; `llm/contract_prompts/*.md` (22) | `le_contract_assistant.pl:4620-4640` |
   | LE2 MCP server | resource `le://docs/syntax` → **`docs/le_syntax.md`**, the obsolete syntax doc | `llm/mcp.pl:150-165, 246` |
   | LPS2 assistant | `docs/lps_summary.md` (whole, or sections by heading) | `src/edges/lps_assistant.pl:548-580` |

3. **Broken or inconsistent references.**
   - `/lps2/README.md:354` links `docs/introducingIFonLPS.mp4` and `.md`, neither of which exists.
   - Code comments in LE2 cite `docs/le_lps_design.md` and `docs/LPSplusLLM.md`, which exist only in `/lps2/docs`.
   - The Portuguese verifier messages cite `le_summary.pt.md §17`, which does not exist.
   - `/work/Dockerfile:50` does not copy `AGENTS_LE_template.pt.md`, so the deployed Portuguese assistant silently falls back to English.
   - `/lps2/CLAUDE.md` places LE2 at `/LogicalEnglish2`.
   - `examples/moreExamples/rkBook/README.md` links `../bookExamples.md`, which lives in `docs/RK_book/`.

---

## 2. The corpus, grouped by purpose

Categories: **P** project design, planning or management (plans, designs,
status, reviews); **L** language reference or tutorial; **I** IDE reference or
tutorial; **S** system feature description (including developer/ops); **M**
marketing, demos, papers. Audience: EU end user, Dev developer, Int internal,
Inv investor or prospect. ★ marks a document users are shown today (§1).
"Mixed" rows list their sections by category.

### 2.1 Language reference and tutorials (L)

| Document | Repo | Lines | Audience | State | Notes |
|---|---|--:|---|---|---|
| ★ `le_summary.md` | LE2 | 1276 | EU, Dev, LLM | current (09-15) | The LE reference. §1–14 core; **§15 extensions**; §16 humanizing; §17 regulatory constructs. Mixed: §17.6 services and §17.10 views are S; §14.2 `lib/` is S |
| ★ `le_summary.pt.md` | LE2 | 305 | EU, LLM | behind | Only §1–16. Marks only `qual`/`a menos que` as extensions, not grouped alternatives, numbered bodies, `prolog` goals or chaining |
| `le_syntax.md` | LE2 | 193 | EU | **superseded** | "LE 2.0" grammar with SWISH-era commands. Its banner defers to le_summary. Still the MCP syntax resource |
| `warningsSummary.md` | LE2 | 43 | EU | current | Verifier warnings; duplicated in `AGENTS_LE_template.md` "Some how-tos" |
| ★ `tutorial0/IntroToLE2.md` | LE2 | 760 | EU | current (07-23) | Mixed: L §2, 5, 6, 8; I §1, 3, 4, 7, 9–13, 15; S §14 s(CASP). Mentions inline `unless` (an extension) |
| `le_lps_surface.md` | LE2 **and** lps2 | 676 | EU, Dev | current | LE for LPS, construct by construct. **Byte-identical** in both repos, synced by hand |
| ★ `lps_summary.md` | lps2 | 834 | EU, Dev, LLM | 08-20, likely behind | LPS reference |
| ★ `lps_tutorial.md` | lps2 | 713 | EU | 09-02 | Mixed: I §1, 4, 13–14 |
| ★ `glossary.md` | lps2 | 222 | EU | 08-20, behind | Has none of the September terms (twin, legal view, refused, Solidity) |
| `selection_spec.md` | lps2 | 389 | Dev, research | stable | Semantics (SP1–SP20) |
| `LPSForInformUsers.md` | lps2 | 599 | EU | 09-08 | Interactive fiction on LPS. Mixed: I §3, §6a |
| `examples/if/README.md` | lps2 | 120 | EU, Dev | 09-08 | IF library conventions |
| Example READMEs: `moreExamples/{rkBook, abduction, LogicalThinkingInAgeOfAI}` | LE2 | 52–122 | EU | abduction README **stale** (says LE has no integrity constraints) | |

**Proprietary language features.** These are exactly what
`InsurLE2/le_extensions.pl` implements. All are documented only in the public
`le_summary.md §15`, each marked "[requires le_extensions.pl]":

| Feature | Reference | Implementation |
|---|---|---|
| `which` relative clauses and "big conclusions" | §15.2 | le_extensions §0–3 |
| `unless` / `and unless` | §15.3 | le_extensions §4 |
| Grouped alternatives: `either:`, `any of:`, `at least one of:`, `all of:` | §15.4 | le_extensions §5 |
| Numbered rule bodies (`1.`, `4.2.1.`, `; and` / `; or`) | §15.5 | le_extensions §6 |
| Embedded `prolog <goal>` resolution | §15.6, §14.1 | `le_extensions:resolve_prolog_tokens/5` |
| Prepositional chaining, "this <type>" anchors | §2.1, §15.7 | le_extensions §7 |
| *(system, not syntax)* the importers and exporters of other systems (File ▸ Open, Export) | `howToUse` (lists 4 of 11), `le_migration.md` | `InsurLE2/migration/le_importers.pl` |

Despite its name and location, `InsurLE2/docs/LE_extensions_proposal.md`
describes **core** constructs. Its §0 says so: provenance, `otherwise`, decision
tables, sections, scoped proof, services and flip queries all live in LE2 core
and in `le_summary §17`.

### 2.2 IDE reference and tutorials (I)

| Document | Repo | Lines | Audience | State | Notes |
|---|---|--:|---|---|---|
| ★ `howToUse.md` | LE2 | 286 | EU | current (09-14) | Editor manual. Mixed: S in "Advanced" (LPS run, legal view, graph, assistant, debugger, import). Its TOC is missing "Generate LE view". Lists 4 of the 11 importers |
| `editorSummary.md` | LE2 | 138 | Dev | **stale** (May) | client.ts-era architecture; overlaps howToUse and api.md |
| `editor/README.md` | LE2 | 56 | Dev | **stale** (April) | |
| `ProofGame.md` | LE2 | 274 | EU (teachers) | current | Mixed I+S |
| `IntroducingLEViews.md` (+8 PNG) | LE2 | 668 | EU, Dev | current | Mixed: S+I §1–10; L §11 (the view sentences); P §12–13. Reachable only as raw markdown |
| `QueryingApolicy/introduction.md` (+11 PNG) | InsurLE2 | 273 | EU | 09-13 | Querying tutorial built on a client policy (Hiscox); generic apart from the example |
| ★ `UsingTheIDE.md` | lps2 | 673 | EU | current (+ uncommitted edit) | LPS2 user guide; its anchors are wired to pane "?" buttons |
| `ide.md` | lps2 | 272 | Dev | 08-20, design record | Says it is not the guide, but the README index makes it sound like one |

### 2.3 System feature descriptions (S)

| Document | Repo | Lines | Audience | State | Notes |
|---|---|--:|---|---|---|
| `api.md` | LE2 | 571 | Dev | **incomplete** ("Preliminary DRAFT") | Documents 17 of about 41 `/leapi` operations |
| `llm/settings/README.md` | LE2 | 68 | Dev | current? | MCP client setup |
| `le_assistant.md` | LE2 | 485 | Dev | 06-02 | Deep assistant architecture |
| `le_assistant_light.md` | LE2 | 509 | Dev | mixed | Implemented, but still written as a proposal (P sections) |
| `sCASP_on_LE.md` | LE2 | 439 | Dev, EU | current | Mixed: L §4, §8. Two sections numbered 13 |
| `le_migration.md` | LE2 | 350 | Dev | current | Migration machinery (core) |
| `le_lps_interface.md` | LE2 **and** lps2 | 279 | Dev | current, v3 | Byte-identical in both repos |
| `telemetry.md` | LE2 and lps2 | 194 / 165 | Ops | current | Parallel versions (not copies); setup steps 1–4 near-duplicate |
| `i18n/README.md` | LE2 | 81 | Dev, translators | current | |
| `policyToLEAssistant.md` | InsurLE2 | 628 | Dev | 08-03 | **The only document on the Contract Assistant**, whose code is LE2 core. Mixed: P §9 |
| `migration/<source>/README.md` ×11 | InsurLE2 | 106–388 | Dev | current | Reader reference with mixed P (results, status) |
| `examples/{customs, medicare}/README.md` | InsurLE2 | 499, 281 | Dev, Int | 09-13 | Domain models; mixed P |
| `deploy.md` | lps2 | 433 | Dev, ops | current | Overlaps interface §3.5–3.6 and IntroducingLPS2 §24 |
| `conformance_report.md`, `conformance_lps2.md` | lps2 | 185, 204 | Dev | generated | Do not hand-edit |
| `README.md` (LE2) | LE2 | 188 | Dev | roadmap **stale** | Lists shipped features as to-do; line 19 sends readers to `le_syntax.md` |
| `README.md` (lps2) | lps2 | 365 | Dev, EU | current, 2 broken links | Doc index lives here |
| `README.md` (InsurLE2) | InsurLE2 | 15 | Dev | **stale** (May) | No migration setup, no doc index |

### 2.4 Project design, planning, management (P)

| Document | Repo | Lines | State |
|---|---|--:|---|
| `sCASP_plan.md` | LE2 | 371 | done → superseded by `sCASP_on_LE.md` |
| `MultilingualLEplan.md` | LE2 | 718 | done → operational part in `i18n/README.md` |
| `DebuggerDesign.md` | LE2 | 100 | built (`dap_server.pl`); says React (wrong) |
| `graphDesign.md` | LE2 | 63 | built (`le_graph.pl`) |
| `le_blocklyDRAFT.md` + `DiscardeBlocklyPrototype.png` | LE2 | 93 | **abandoned**; nothing links to it |
| `another bob's game thought.drawio`, `images/Bob's game concept.png` | LE2 | – | Proof Game origin sketches; orphans |
| `RK_book/bookExamples.md`, `vibingExamples/.AGENT_BRIEF.md` | LE2 | 4979, 78 | research; brief stale |
| `LE_extensions_proposal.md` | InsurLE2 | 813 | largely implemented (in LE2 core); §4.2–4.3 not started |
| `RulesRUs.md` | InsurLE2 | 864 | strategy / market survey (proprietary) |
| `MiggratingFromOtherSystems.md` | InsurLE2 | 3453 | roadmap + design + status, tangled; header status stale |
| Role-play reviews ×12: `CustomsOfficer`, `MedicareOfficer`, `InsuranceClaimsOfficer`, `OIAuser`, `SolidityDeveloper`, `{Miniscript, sCASP_Blawx, Daml, Drools, Epilog, LegalRuleML, OIPA}_guruReport` (+ PNG dirs) | InsurLE2 | 89–606 | dated records; each has "Engineer's response" / "Follow-up" sections that are S |
| `LPSplusLLM.md` | lps2 | 1931 | **plan of record**; its Status section is the single status source per CLAUDE.md, and is turning into a changelog |
| `le_lps_design.md`, `LEintegrationImprovementPlan.md` | lps2 | 530, 226 | superseded (interface v3) |
| `InformPlan.md` | lps2 | 1102 | done; mixed S §7a–f |
| `ProfessorKsystemImpressions.md`, `ProfessorKsecondPass.md`, `AnotherUserImpressions.md` | lps2 | 141, 119, 289 | user reviews, all implemented. **Two are linked from the public landing page** |
| `historicalDocs/` (LPS1 paper as markdown + 2 PNGs) | lps2 | – | historical |

### 2.5 Marketing, demos, papers (M)

| Document | Repo | Notes |
|---|---|---|
| `papers/LE2paperDraft.md`, `LE2paperAppendix.md`, `under-review-…pdf`, `LE2_PEG2026.pdf` | LE2 | Draft superseded by the appendix, which stops in July |
| `MidSeptemberLeap.md` (+27 PNG) | InsurLE2 | Dated aggregate of reports, READMEs and plans (§2.1 condenses the reviews, §2.4/2.7 the reader results) |
| `insurle-scripts.md` | InsurLE2 | July pitch scripts on the old UI; stale |
| `videos/*.cjs`, `guru/*.cjs`, `md2pdf.sh` | InsurLE2 | Tooling; the mp4s are not in any repo |
| `IntroducingLPS2.md` | lps2 | Mixed: M Parts 1, 2, 5; I §12–16; S §17–24 |
| `LPS2abstract.md` | lps2 | 08-20; predates LE-for-LPS v3, Solidity, IF |
| `introducingIFonLPSscript.md` | lps2 | Script of a video that is not in the repo |

---

## 3. Problems

1. **No boundary between user docs and project docs.** Plans, role-play
   reviews, private notes, a copyrighted book and a paper under review sit beside
   the manuals, and the servers publish all of it (§1.3).
2. **Flat directories named by history, not by purpose.** `docs/` in each repo
   mixes P, L, I, S, M. Nothing tells a reader or an agent which file is
   authoritative (e.g. `le_syntax` vs `le_summary`, `ide` vs `UsingTheIDE`).
3. **Hand-synced duplicates across repositories.** `le_lps_surface.md` and
   `le_lps_interface.md` exist twice; `telemetry.md` exists twice with shared
   prose. The LE-for-LPS reader must know to look in both.
4. **Gaps.**
   - No user documentation for the Contract Assistant (only a design doc in the
     private repo), the executive view, why-not, import/export (howToUse lists 4
     of 11 importers), or the migration twins as a user feature.
   - `api.md` covers less than half of the API.
   - The Portuguese reference lacks §17.
   - LE2 has no contextual help; LPS2's pane "?" links show it works.
5. **Staleness.**
   - LE2 README roadmap; `editorSummary.md`, `editor/README.md`;
     `le_assistant_light.md` written as a proposal; the abduction README.
   - LPS2 `lps_summary`/`glossary`/`LPS2abstract` date from August; screenshots
     predate the 09-13 UI; `LEintegrationImprovementPlan` cites contract v2.
   - `MiggratingFromOtherSystems.md` has a status header two phases behind.
6. **Status in too many places.**
   - Implementation status of the same work appears in the plan (§8 status
     paragraphs), the reader READMEs ("Results"), the reviews ("Follow-up"),
     the Leap report, and LPSplusLLM's Status.
   - The dated records are fine as records; the problem is that none of them is
     marked as the current source.
7. **Two separate doc viewers with different abilities.** LE2's does not
   rewrite `.md` links; LPS2's cannot render subdirectories. Neither has
   navigation, search or version.
8. **Extensions are documented only in the public reference.** For users that
   is right: they need to know a construct exists and where it runs. But
   nothing in InsurLE2 says which features it adds, and the `.pt` reference
   marks them inconsistently.

---

## 4. Proposal: target structure

### 4.1 Principles

- **Two kinds of documentation, two places.** *User documentation* (tutorials,
  guides, references, feature pages) is published, curated, versioned with the
  product and served by the IDEs. *Project documentation* (plans, designs,
  reviews, reports, papers, research) lives in the repositories and is **never**
  served.
- **One home per topic, by the language it is about.**
  - LE (the language, the LE2 editor, LE2 features): **LogicalEnglish2**.
  - LPS and LE for LPS (the surface, the LPS2 IDE): **lps2**. The LE2↔LPS2
    interface belongs there too (it is LPS2's API).
  - Proprietary extensions, domain models, migration readers, business
    material: **InsurLE2**.
  - LE2 docs that currently describe LPS link across instead of copying.
- **A document states its kind and status in a header line**, e.g.
  `Kind: guide · Audience: users · Status: current (2026-09-16)`, and so does
  every plan (`implemented → see X`). Superseded documents move to an archive
  instead of being deleted.
- **Served docs are an allow-list**, derived from the same navigation file that
  builds the Help menu and the landing page, so the three cannot drift.
- **Paths read by LLM features are an interface.** They move only together with
  the code that reads them (§1.3.2).

### 4.2 LogicalEnglish2

```
docs/
  README.md                    index: what is where; the nav for user docs
  user/                        ◀ the ONLY directory the server publishes
    nav.json                   ordered table of contents → Help menu, landing page, viewer sidebar
    tutorials/
      intro-to-le/             ← tutorial0/IntroToLE2.md (+ PNGs)
      querying-a-program.md    ← InsurLE2 QueryingApolicy, rewritten on a public example
      views.md                 ← IntroducingLEViews §1–10 (+ PNGs)
    guide/                     the LE2 editor
      editor.md                ← howToUse.md (completed: Generate LE view, 11 importers, executive view, why-not)
      executive-view.md        new
      proof-game.md            ← ProofGame.md
      assistants.md            new, user side of le_assistant*, Contract Assistant, "Write it in English"
      import-export.md         new, File ▸ Open and Export (the migration twins as a user feature)
      warnings.md              ← warningsSummary.md
    reference/
      language.md              ← le_summary.md (en)
      language.pt.md           ← le_summary.pt.md, brought up to §17
      extensions.md            ← le_summary §15, split out, header "available where le_extensions is installed (hosted service)"
      scasp.md                 ← sCASP_on_LE.md (user sections)
      lps-target.md            short: what `the target language is: lps` means + link to lps2's surface doc
    api/
      web-api.md               ← api.md, completed (all ~41 operations; generated table if possible)
      mcp.md                   ← llm/settings/README.md + api.md MCP section
  dev/                         developer reference, not served
    architecture.md            ← editorSummary.md (rewritten) + README "Architecture"
    assistant.md               ← le_assistant.md + le_assistant_light.md (as built)
    contract-assistant.md      ← InsurLE2 policyToLEAssistant.md §1–8 (the code is LE2 core)
    migration.md               ← le_migration.md
    debugger.md                ← DebuggerDesign.md (as built)
    graph.md                   ← graphDesign.md
    i18n.md                    → link to i18n/README.md (stays beside the CSVs)
    telemetry.md               ← telemetry.md (LE2 part; shared setup steps linked)
  project/                     not served
    plans/                     sCASP_plan, MultilingualLEplan (each with "implemented → see …" header)
    papers/                    LE2paperDraft, LE2paperAppendix, PEG2026 slides (the under-review PDF out of the repo)
    research/rk-book/          bookExamples.md, vibingExamples brief (the book PDF and its conversion OUT of the repo)
    archive/                   le_syntax.md, le_blocklyDRAFT(+png), drawio, Bob's game png
```

Code touched:
- `handle_docs` serves only `docs/user/**`.
- `editor/index.html` Help menu and `landing_*` in `classic_web_api.pl` read
  `nav.json`.
- The viewer rewrites `.md` links and shows the nav as a sidebar.
- `le_assistant_light.pl`, `le_contract_assistant.pl` and
  `AGENTS_LE_template*.md` point at `docs/user/reference/language.md`.
- `llm/mcp.pl` serves that same file instead of `le_syntax.md`.
- The `i18n/messages.csv` citations are updated.
- `.dockerignore` excludes `docs/project`, `docs/dev`.

### 4.3 lps2

```
docs/
  README.md                    index (moved out of the repository README)
  user/                        served
    nav.json
    tutorials/lps-tutorial.md  ← lps_tutorial.md
    tutorials/inform-users.md  ← LPSForInformUsers.md
    guide/ide.md               ← UsingTheIDE.md   (anchors kept: the pane "?" links use them)
    reference/lps.md           ← lps_summary.md (updated past 08-20)
    reference/le-for-lps.md    ← le_lps_surface.md  (single copy, LE2 links here)
    reference/glossary.md      ← glossary.md (September terms added)
    overview/introducing-lps2.md ← IntroducingLPS2.md
    overview/abstract.md       ← LPS2abstract.md
  dev/
    le-lps-interface.md        ← le_lps_interface.md (single copy)
    semantics/selection-spec.md
    ide-design.md              ← ide.md
    deploy.md, telemetry.md
    conformance/               generated reports
  project/
    plan-of-record.md          ← LPSplusLLM.md (Status stays its single source)
    plans/                     InformPlan, le_lps_design, LEintegrationImprovementPlan (superseded headers)
    reviews/                   ProfessorK ×2, AnotherUserImpressions (removed from the landing page)
    videos/                    introducingIFonLPSscript.md
    historical/                ← historicalDocs/
```

Code touched:
- `lps_http.pl:188-215` (landing list) and `ui/src/main.js:1635-1645` (Help)
  read `nav.json`.
- `docs.js` accepts subpaths.
- `/docs-raw` is limited to `docs/user`.
- `lps_assistant.pl:548` reads the new reference path.
- `doc.html` "← IDE" goes to `/ide`.
- `README.md:354` links are fixed.

### 4.4 InsurLE2

```
docs/
  README.md                    index + "what InsurLE2 adds to LE2" (the extensions table of §2.1)
  extensions/                  developer notes on le_extensions.pl (the user reference stays public, §4.2)
  migration/
    roadmap.md                 ← MiggratingFromOtherSystems §0, §4–§8 (plan), with ONE status table
    landscape.md               ← MiggratingFromOtherSystems §2–§3 (market research)
    readers/                   the 11 migration/<source>/README.md stay beside their code; linked from here
  strategy/                    RulesRUs.md, LE_extensions_proposal.md (marked "implemented in LE2 core; §4.2–4.3 open")
  reviews/                     the 12 role-play reports + their PNG dirs + guru/*.cjs
  reports/                     MidSeptemberLeap.md (+PNGs), future dated reports
  sales/                       insurle-scripts.md (marked stale), video scripts (videos/*.cjs), md2pdf.sh
```

Out of InsurLE2 (§4.2):
- `policyToLEAssistant.md` → LE2 `docs/dev/contract-assistant.md`.
- `QueryingApolicy/` → LE2 tutorial, re-shot on a public example. The Hiscox
  version stays in InsurLE2 as a sales asset.

### 4.5 Online user documentation

Two steps, the first cheap:

1. **In-product (both IDEs).**
   - One shared markdown viewer behaviour: link rewriting, subpaths, a sidebar
     from `nav.json`, heading anchors, "edit on GitHub".
   - Help menus and landing pages generated from `nav.json`.
   - LE2 gains what LPS2 already proved works: a "?" on each panel (query,
     scenario, explanation, drill, views, proof game) linking to an anchor of
     `guide/editor.md`, and hover links from diagnostics to reference sections
     (the verifier messages already cite section numbers; make them links).
   - Language-aware links: `language.<lang>.md` when it exists, English
     otherwise, as the `/multilingual` landing page already does.
2. **A public documentation site** (e.g. `docs.logicalcontracts.com` or GitHub
   Pages), built in CI from `LogicalEnglish2/docs/user` and `lps2/docs/user`
   with a static generator (MkDocs Material is the lowest-effort fit for plain
   markdown; it provides search, versioned builds and cross-site nav).
   - Sections: *Logical English* (tutorials, guide, reference, extensions page
     marked "hosted service") · *LPS* · *Logical English for LPS* · *API &
     integrations* · *Examples* (generated from the example READMEs; see
     `docs/NewExamplesStructure.md`).
   - The IDEs keep serving the same files offline; the site adds search and a
     stable public URL.

---

## 5. Disposition, document by document

Keep: stays, maybe retitled. Move: new path, same content. Merge: content goes
into the named target. Rewrite: substantial update. Archive: moved to
`project/archive`, marked superseded. Remove: out of the repository.

| Document | Action | Target |
|---|---|---|
| LE2 `le_summary.md` | Move + split §15 | `user/reference/language.md`, `extensions.md` |
| LE2 `le_summary.pt.md` | Rewrite (add §17, mark §15 consistently) | `user/reference/language.pt.md` |
| LE2 `le_syntax.md` | Archive (after MCP points at the reference) | `project/archive/` |
| LE2 `tutorial0/IntroToLE2.md` | Move | `user/tutorials/intro-to-le/` |
| LE2 `howToUse.md` | Rewrite (gaps §3.4) | `user/guide/editor.md` |
| LE2 `IntroducingLEViews.md` | Split: §1–11 user, §12–13 dev | `user/tutorials/views.md`; `dev/` |
| LE2 `ProofGame.md` | Move | `user/guide/proof-game.md` |
| LE2 `warningsSummary.md` | Move; AGENTS template links it instead of repeating it | `user/guide/warnings.md` |
| LE2 `sCASP_on_LE.md` | Move (fix numbering) | `user/reference/scasp.md` |
| LE2 `api.md` | Rewrite (complete) | `user/api/web-api.md` |
| LE2 `llm/settings/README.md` | Merge | `user/api/mcp.md` |
| LE2 `editorSummary.md`, `editor/README.md` | Rewrite into one | `dev/architecture.md` (editor/README → build steps only) |
| LE2 `le_assistant.md`, `le_assistant_light.md` | Merge as built | `dev/assistant.md` |
| LE2 `le_migration.md` | Move | `dev/migration.md` |
| LE2 `le_lps_surface.md`, `le_lps_interface.md` | Remove the copy; link to lps2 | – |
| LE2 `telemetry.md` | Move | `dev/telemetry.md` |
| LE2 `DebuggerDesign.md`, `graphDesign.md` | Move (as-built note) | `dev/` |
| LE2 `sCASP_plan.md`, `MultilingualLEplan.md` | Move | `project/plans/` |
| LE2 `le_blocklyDRAFT.md`, `DiscardeBlocklyPrototype.png`, `.drawio`, `Bob's game concept.png` | Archive | `project/archive/` |
| LE2 `papers/*` | Move; under-review PDF removed from the repo | `project/papers/` |
| LE2 `RK_book/CLandHT-HtobAI.pdf` + conversion | **Remove from the repo** (copyright) | a private location |
| LE2 `RK_book/bookExamples.md`, brief | Move | `project/research/rk-book/` |
| LE2 `README.md` | Rewrite roadmap; syntax link → reference | – |
| LE2 `docs/vibeCodingNotes.md` | **Stop serving and shipping it**; your call on keeping it in git | `.dockerignore` + not under `user/` |
| lps2 `lps_summary`, `lps_tutorial`, `glossary`, `UsingTheIDE`, `LPSForInformUsers`, `IntroducingLPS2`, `LPS2abstract` | Move (update Aug docs) | `user/…` |
| lps2 `le_lps_surface.md` | Move (single copy) | `user/reference/le-for-lps.md` |
| lps2 `le_lps_interface.md`, `selection_spec`, `ide.md`, `deploy`, `telemetry`, conformance reports | Move | `dev/…` |
| lps2 `LPSplusLLM.md` | Move, keep Status as the source | `project/plan-of-record.md` |
| lps2 `InformPlan`, `le_lps_design`, `LEintegrationImprovementPlan` | Move (superseded headers) | `project/plans/` |
| lps2 `ProfessorK*`, `AnotherUserImpressions` | Move; **remove from the landing page** | `project/reviews/` |
| lps2 `introducingIFonLPSscript.md`, `historicalDocs/`, `uglyStateTransitions.png` | Move / archive | `project/` |
| lps2 `docs/vibeCodingNotes.md` | as LE2 | – |
| InsurLE2 `policyToLEAssistant.md` | Move to LE2 (generic parts) | LE2 `dev/contract-assistant.md` |
| InsurLE2 `QueryingApolicy/` | Copy to LE2 on a public example; the original stays as a sales asset | LE2 `user/tutorials/querying-a-program.md` |
| InsurLE2 `MiggratingFromOtherSystems.md` | Split plan / landscape, one status table | `migration/roadmap.md`, `landscape.md` |
| InsurLE2 `LE_extensions_proposal.md`, `RulesRUs.md` | Move | `strategy/` |
| InsurLE2 reviews ×12 (+ dirs), `guru/` | Move | `reviews/` |
| InsurLE2 `MidSeptemberLeap.md` (+ dir) | Move | `reports/` |
| InsurLE2 `insurle-scripts.md`, `videos/`, `md2pdf.sh` | Move | `sales/` |
| InsurLE2 `README.md` | Rewrite: setup (le_extensions link, examples mount, migration), doc index, extensions table | – |

---

## 6. Plan

Each phase ends green: `testing/run_tests.sh` in LE2, LPS2's tools and e2e
where menus change.

| Phase | Work | Size |
|---|---|---|
| **0. Exposure (now)** | Allow-list `/docs` to the files the menus use today (LE2 `handle_docs`, LPS2 `docs_page` and `docs-raw`); `.dockerignore` `docs/vibeCodingNotes.md`, `docs/RK_book`, `docs/papers`; remove the ProfessorK / impressions links from the LPS2 landing page; fix the broken links of §1.3.3; copy `AGENTS_LE_template.pt.md` in the Dockerfile | small, independent of the rest |
| **1. Skeleton and moves** | Create `user/ dev/ project/` in LE2 and lps2; `git mv` per §5; add header lines; nav.json; menus, landing pages and viewers read nav.json; LLM paths updated together with their code; MCP resource → language reference; single copies of the LE-for-LPS docs | medium (mostly mechanical; e2e specs that open docs need path updates) |
| **2. Gaps and staleness** | Complete `howToUse` → `guide/editor.md`; new `executive-view`, `assistants`, `import-export`; complete `api.md`; bring `language.pt.md` to §17; update LPS2 reference, glossary and abstract; re-shoot screenshots; InsurLE2 README and migration roadmap split | large (writing) |
| **3. Contextual help** | "?" per LE2 panel; diagnostic → reference links; language-aware doc links | small–medium (code + e2e) |
| **4. Public site** | MkDocs build in CI from both `docs/user`; search; deploy; "Examples" section from the example READMEs | medium |

---

## 7. Decisions needed

1. **Scope of "user docs" in the public repos.** Should the extensions
   reference (`extensions.md`) stay public (my recommendation: it tells users
   what the hosted service adds) or move to InsurLE2? STAY PUBLIC
2. **Private notes.** Keep `vibeCodingNotes.md` tracked in the public repos
   (excluded from images and routes), or move them out of git? KEEP THEM TRACKED
3. **RK book PDF, its conversion, and the under-review paper.** Remove them from
   the public repository? (Recommended; they are also served today.) Remove them
4. **Home of the LE↔LPS documents.** lps2 (recommended: the surface and the
   interface are LPS2's) or LE2?  lps2
5. **Public site.** Is a separate documentation site wanted now (Phase 4), or
   are in-product docs enough for the moment?  In-product docs are enough for now
6. **Querying tutorial.** Rewrite on a public example (e.g.
   `RulesRus/eu261_integration`), or keep it proprietary? Rewrite on public example
