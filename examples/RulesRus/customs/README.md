# Customs classification in Logical English: Chapters 39, 61 and 62

Step 1 of the plan in RulesRUs §8 (customs, §1 of that report), scaled up:
the General Rules of Interpretation and the section and chapter notes of
**three whole chapters** of the tariff, run on the facts of published
classification rulings (US CBP rulings from CROSS, EU Binding Tariff
Information from EBTI) and compared with the offices' codes:

- **Chapter 39**, plastics and articles thereof: 26 headings (3901–3926) and
  131 six-digit subheadings — primary forms, waste, semi-manufactures,
  sanitary ware, builders' ware and articles;
- **Chapter 61**, apparel and clothing accessories, knitted or crocheted: 17
  headings (6101–6117), 106 subheadings;
- **Chapter 62**, apparel and clothing accessories, not knitted: 17 headings
  (6201–6217), 104 subheadings.

That is 60 headings and 341 six-digit subheadings, every one of the three
chapters, where the first prototype had 9 headings and 33 subheadings (the
upper-body garments of 6105, 6106, 6109, 6110, 6205, 6206 and the plastics
articles of 3923, 3924, 3926). Chapters 84/85 (machinery), the third family
the plan suggested, are not done.

## Files

One program per chapter, and one that includes them all:

| File | What it is |
|---|---|
| `gri.le` | The GRIs as a library: GRI 1 (the terms of the headings, read with the notes), GRI 3(a) (the more specific heading), 3(b) (a composite good or a set is classified as the component that gives it its essential character — a recorded judgment), 3(c) (the last heading in numerical order — also among the components of a good whose essential character the office finds in none), GRI 6 (the subheading within the heading); the claims that a good belongs to a heading outside the model; and the vocabulary all chapters share (the kind of a good and its family, its composition). |
| `section_xi.le` | Section XI: the textile material that predominates (note 2, subheading note 2 — man-made fibres counted together, then synthetic against artificial, wool against fine animal hair and cashmere), the garment vocabulary and the notes Chapters 61 and 62 share: suits and ensembles (note 3), shirts and blouses (note 4), T-shirts, tank tops and singlets (Explanatory Note, CBP's tests), men's and women's garments (note 9), babies' garments, the kinds of garments and accessories and the families the headings name. Includes `gri.le`. |
| `chapter_39.le` | Chapter 39 and Section VII note 2: polymers in primary forms by their heading (notes 4, 5) and their named subheading (subheading note 1), waste, monofilament, rods and profiles, tubes and fittings (rigid, burst pressure, fitted), floor coverings, self-adhesive and other flat shapes (note 10), sanitary ware, builders' ware (note 11), and the articles of 3923, 3924, 3926 by their principal use (a judgment). Four decision tables (78, 53, 7 and 7 rows). Includes `gri.le`. |
| `chapter_61.le`, `chapter_62.le` | The seventeen headings of each chapter and their subheadings as a decision table (106 and 103 rows), with the notes that give a heading precedence (babies' garments, garments of coated fabrics) and the residual headings (6114, 6211 "other garments"). Include `section_xi.le`. |
| `tariff.le` | The whole modelled tariff: includes the three chapters. Every scenario program includes it, so every good is classified against all 60 headings. |
| `cbp_39.le`, `cbp_61.le`, `cbp_62.le` | 125 CBP rulings (September 2026 selection, below), one scenario each, filed by the chapter of their first code. |
| `heldout_cbp_2.le` | 25 more CBP rulings of the same selection, run once the rules were frozen. |
| `apparel_cbp.le`, `apparel_ebti.le`, `plastics_cbp.le`, `plastics_ebti.le`, `heldout_apparel_cbp.le`, `heldout_plastics_cbp.le` | The first prototype's sample — 65 CBP rulings and 15 EU BTIs — now run through the whole tariff. |
| `by_hand.le` | Ten rulings left for transcription by hand through the editor (below). |
| `sources/` | The cited texts: `hts/` the HTSUS chapters (39, 61, 62 in full; the pages cited of the General Rules, Section XI and Chapters 50–56, 59; `=== page N ===` marks the PDF page), `cbp/` the 225 CBP rulings as CROSS serves them, `ebti/` the 15 BTIs. US federal texts are in the public domain; EBTI decisions are published by the European Commission for reuse. |

Run one of them the usual way, e.g.

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/RulesRus/customs/cbp_61.le', R), print_test_result(R), halt."
```

Queries: `subheading` (the six-digit subheading of each good), `heading`,
`unplaced` (the goods the model should classify and cannot), and in
`plastics_cbp.le` the flip query `household` (below).

## How the model reads a good

A ruling names the article — "a men's jacket", "a pair of women's trousers",
"ankle socks", "pellets", "a PVC hose": that is its **kind** (`the kind of
style 345H115C is jacket`), and each kind falls in a **family** that the
headings name (`jacket falls in the family outerwear`, with the heading's own
words as provenance). Tops — shirts, blouses, T-shirts, tank tops, sweaters,
cardigans — are told apart by what the ruling observes, as the notes and the
Explanatory Notes do: sleeves, openings, collar, fit, fabric, hem. A garment's
heading then follows from its family, its construction (knitted: Chapter 61;
woven or nonwoven: Chapter 62), its sex (note 9) and the notes that exclude
or give precedence; its subheading from the heading, a group (a suit, an
ensemble, the family) and the textile material that predominates. A polymer
in primary form goes by the monomer that predominates to its heading and by
its name to its subheading; a semi-manufacture by its form and its polymer;
an article of 3923, 3924 or 3926 by its principal use, which is the office's
judgment. A set or a composite good is classified as the component that gives
it its essential character (GRI 3(b)) — its family, sex and material are that
component's — or, when the office finds that no single component does, by GRI
3(c) among the headings its components lead to.

## Provenance: checking a rule or a fact against its source

Every rule and table is labelled and cites the passage it encodes
(docs/le_summary.md §15.5):

```
rule heading_6104 with provenance HTSUS Chapter 61,
        confer "Women's or girls' suits, ensembles, suit-type jackets, blazers, dresses, skirts, divided skirts, trousers, bib and brace overalls, breeches and shorts (other than swimwear), knitted or crocheted":
a garment is described by heading 6104
    if the construction of the garment is knitted
    and the gender of the garment is women
    and the subheading group of the garment is a group
    and the group is in [suit, ensemble, suit-type jacket, dress, skirt, trousers].
```

and every fact of every scenario points at the passage of its ruling that
states it — the scenario names the ruling once, `scenario ny_n362700 is, as
stated in ruling NY N362700:`, and each fact quotes its passage: `style 1025AD
has a collar, confer "zips through a self-fabric stand-up collar"`. The
documents say where they are published and where their text is (`HTSUS
Chapter 61 is published at "https://hts.usitc.gov/...#page=1"`, `the text of
ruling NY N362700 is at "sources/cbp/N362700.txt"`), so

- the verifier checks that each of the 3,028 quotations is in its document's
  text (`quote_not_found` otherwise);
- in the editor, the **§** badge of an explanation node opens the cited
  document with the passage highlighted, and *Open original* opens the
  published page. (Browser text anchors do not reach the exact sentence on
  these sites — CROSS shows each ruling as an embedded PDF, EBTI detail pages
  need a session — hence the copies in `sources/`.)

The subheading tables cite the tariff line by line: each row's last column
quotes its subheading in the chapter's text (`as stated in HTSUS Chapter 62`
for the Chapter 61 and 62 tables, whose own provenance is GRI 6; `confer` in
Chapter 39's, which cite the chapter), so the step that gives a good its
subheading points at "Of silk or silk waste:6214.10", not at GRI 6 alone. The
quotations were taken from `sources/hts/` by a script (the line that ends in
the six-digit code, or else the first ten-digit line under it); the verifier
checks all 354.

Rules that are the model's own devices rather than the tariff's have no
provenance and say so in a comment. The Explanatory Notes are not public;
rules that encode them cite the ruling or BTI that quotes them.

## Adding a ruling by hand: facts from its text

Open `by_hand.le` (or any scenario file) in the editor, then *Scenario Editor
→ Add → Write it in English…*, and under *From a document* give the
document's name (`ruling NY N348681`) and the address of its text (a copy in
`sources/cbp/`, or `https://rulings.cbp.gov/api/ruling/N348681`); *Fetch
text*, *Generate*. The language model is given the program's scenario
templates — those the program marks `; undefined` or `; judged` — each with
the values the rules read in its places (the kinds, materials, polymers,
genders, constructions the program knows), writes only the facts the text
states, each citing its passage, never the classification itself, and marks
the office's decisions as judgments; every passage is checked against the
text (docs/le_summary.md §17.9). Review the rows, *Insert*, run `subheading`.

`by_hand.le` names ten rulings kept out of everything else for this (a
knitted jacket, women's trousers, socks, gloves, a printed film, a PVC hose,
cashmere sweaters, dresses, swim shorts, flooring), with CBP's codes in its
comments. **A run of that path with `openai/gpt-oss-120b` on Groq** (the
Groq model of the editor's list; September 2026), headless, as the editor calls it:

- It works end to end: every ruling fetched, every reply parsed into facts
  whose passages are checked against the text, 11–26 s per ruling.
- The drafts are drafts: 51 facts for the ten rulings, but most miss what
  decides the heading — the kind (the model writes `style 345H115C is a
  jacket` rather than the template's `the kind of style 345H115C is jacket`)
  and the fabric construction — and some state what the text does not (a
  glove or a sweater as "a manufactured article", a phrase the plastics
  headings read). Unedited, none of the ten gets CBP's code: the reviewer has
  to add those rows, which is what the Scenario Editor's review step is for.
- The run found defects of the path itself, now fixed: replies cut off by
  the token limit (the extraction now asks for little reasoning and allows
  long replies), a percent sign in a reply read as the start of a comment,
  every template of the program offered instead of the scenario templates,
  none of them with the values its rules read, and two labelling bugs in the
  templates offered. Before the fixes the same model returned one or two
  facts per ruling, or nothing.

## Sources

- HTSUS Revision 18 (2026): General Rules of Interpretation, Section VII and
  XI notes, Chapters 39, 61, 62 — https://hts.usitc.gov/ (chapter PDFs via
  `https://hts.usitc.gov/reststop/file?release=currentRelease&filename=Chapter%2061`;
  the structure of headings and subheadings via
  `https://hts.usitc.gov/reststop/exportList?from=6101&to=6118&format=JSON`).
  The section and chapter notes used are the WCO text, identical in the EU
  Combined Nomenclature.
- CBP rulings: CROSS, https://rulings.cbp.gov/ (search API
  `/api/search?term=<code>*&collection=NY&sortBy=DATE_DESC` — the `*` matters:
  a bare six-digit term only matches the rare ruling that writes it — text at
  `/api/ruling/<number>`), retrieved 11 and 12 September 2026.
- EU BTIs: EBTI, https://ec.europa.eu/taxation_customs/dds2/ebti/ , retrieved
  11 September 2026 (German and French offices).

**Selection.** The first prototype: for each six-digit subheading in its
scope, the most recent New York rulings (3 to 7 per heading), keeping every
style of each ruling, and the most recent valid BTI in English, French or
German; its held-out set, the two most recent rulings per heading not used
before. **The scale-up:** for each six-digit subheading of the three chapters
not covered before, the most recent New York ruling of 2016 or later whose
codes (other than Chapter 98/99) all fall in the three chapters, not revoked
or modified — 160 rulings. With the first prototype's they cover all 60
headings and 220 of the 341 subheadings (the search found none for the
others: many primary-form polymers, rare hosiery and suit subheadings). Of these, 10 were set aside for
transcription by hand, 25 drawn at random (by chapter) as held out, 125 kept
in sample.

## Method

- **Only what the ruling states is a fact.** Each good is described by the
  facts its ruling gives — kind, construction, composition, features, form,
  polymer — each quoting its passage (`confer "..."`) under the scenario's
  default source. **The ruling's code is never a fact**; it is kept in a
  comment above the scenario (`% CBP: style 345H115C -> 6101.20`).
- **What the office decided is a judgment** (`; judged`), recorded with who
  and why: the principal use of a plastics article, the essential character of
  a composite good or set (or that no single component gives it), the answer
  to a claim that the good belongs to a heading outside the model. A judgment
  the ruling does not state is not recorded: printed plastics goods whose
  rulings say nothing about the printing (Section VII note 2) are left to the
  model's "judgment needed".
- **How the scenarios were written.** The first prototype's by the rules'
  author. The 150
  rulings of the scale-up by six language-model agents working in parallel
  (Claude, one batch per chapter half), each following the same written guide:
  the sentence forms and words the model reads (its scenario templates, kinds,
  materials, polymers), the rules above, and the verifier's and the model's
  output to check each file. Their files were then reviewed: judgments the
  rulings do not state removed, vocabulary gaps (a sash, a skirtall) filled
  once the model had the kinds, GRI 3(c) judgments that the vocabulary lacked
  added. The `.le` files are the source: edit them directly; the verifier
  checks every quotation against `sources/`.
- **Comparison at six digits** (the HS level both tariffs share). The
  expectation of each scenario is what the model derives; where that differs
  from the office's code the scenario says `DISAGREES` (or `NO CODE`,
  `CONDITIONAL`) and why, so the example suite stays a regression test of the
  model, not of the rulings. A code of a pre-2022 ruling that the 2022 edition
  renumbered counts as the same code. A ruling that classifies several goods
  (52 of the 225 CBP rulings span more than one subheading) has every good in
  its scenario and every code in its `% CBP:` comment; the Chapter 99 codes
  that follow some classifications (`9903.88.15`, `9903.01.24`: additional
  duties on goods of a given origin) are not classifications and are not
  compared. Eight- and ten-digit codes: RulesRUs §1, future work.

A classification's explanation is the audit trail the report asks for — the
GRI chain with every note and every fact's source. Abridged, for the cat toy of
NY N360066:

```
the subheading of the Pom Pom Launcher is 3924.90
  the heading of the Pom Pom Launcher is 3924
    the Pom Pom Launcher is within the scope of the model
      the Pom Pom Launcher is a manufactured article, as stated in ruling NY N360066, confer "It is a cat toy ..."
    the Pom Pom Launcher is clear of rival headings
      for case the Pom Pom Launcher is claimed to belong to toys of heading 9503,
        as stated in ruling NY N360066, confer "you suggest classification in heading 9503"
      it is true that the claim that the Pom Pom Launcher belongs to toys of heading 9503 is rejected,
        according to CBP, as stated in ruling NY N360066,
        confer "are identifiable as intended exclusively for animals"
    the Pom Pom Launcher is classified in heading 3924
      the Pom Pom Launcher is described by heading 3924
        the Pom Pom Launcher is an article of plastics
          the Pom Pom Launcher is classified as consisting of the launcher of the Pom Pom Launcher
            the Pom Pom Launcher is a set put up for retail sale, as stated in ruling NY N360066, ...
            the essential character of the Pom Pom Launcher is given by the launcher ...,
              according to CBP, as stated in ruling NY N360066,
              confer "with the PP plastic launcher providing essential character by bulk, weight, value, and importance to the set"
          the launcher of the Pom Pom Launcher is of plastics
        the principal use of the Pom Pom Launcher is household use, according to CBP,
          as stated in ruling NY N360066,
          confer "plastic pet supplies used by domestic household animals are classified as household articles"
      it is not the case that ... heading a heading prevails over heading 3924
  the subheading of the Pom Pom Launcher in heading 3924 is 3924.90
    the subheading in heading 3924 for household use is 3924.90 under table uses
      row u2 of table uses
```

## Results

| Set | Goods | Same six-digit code | No code | Conditional | Different code |
|---|---:|---:|---:|---:|---:|
| Chapter 39, CBP (45 rulings) | 62 | 52 | 6 | 0 | 4 |
| Chapter 61, CBP (50 rulings) | 103 | 94 | 2 | 0 | 7 |
| Chapter 62, CBP (30 rulings) | 64 | 57 | 0 | 2 | 5 |
| **Scale-up, in sample** | **229** | **203 (89%)** | **8** | **2** | **16** |
| Scale-up, held out (25 rulings) | 47 | 45 (96%) | 0 | 0 | 2 |
| First prototype, in sample (under the full tariff) | 95 | 90 (95%) | 0 | 0 | 5 |
| First prototype, held out | 15 | 13 | 0 | 0 | 2 |

The held-out figure needs a caveat: the agents' reports showed the held-out
outcomes before the rules were revised. The revisions were driven by the
in-sample cases (GRI 3(c) among components, sets without a kind of their
own, women's underpants other than briefs, tops with limited coverage), but
the same gaps occurred in held-out rulings and the revisions reached them too.

**Every disagreement of the scale-up, classified** (the scenario comments give
each case):

- *A judgment needed and not recorded* (7 goods): five printed plastics
  goods whose rulings do not say whether the printing is merely subsidiary
  (Section VII note 2) — no code — and two composite tops whose ruling
  states no essential character — conditional.
- *A fact the model needs that the ruling does not state* (8): the
  plasticizer content of a PVC tape (3920.43), whether a pipe is rigid
  (3917.23), the decitex of two tights' yarn (given only as less or more
  than 67), the material of a bidet seat, the stitch count that would keep
  a cardigan out of heading 6106, the fit or opening that would make two
  tops blouses (the first prototype's blouse gap, once in sample and once
  held out).
- *CBP's characterisation where the model reads the heading's terms* (4):
  two lightweight jackets and a costume cape that CBP holds to be "other
  garments" (6211) though heading 6202 names jackets and capes; a garment the
  ruling calls only an upper body garment, which CBP classifies as a
  suit-type jacket.
- *How the composition is counted* (2): a CBP laboratory's fibre shares in
  which man-made fibres together predominate, against CBP's cotton code;
  metalized yarn counted by fibre instead of as the whole yarn of heading
  5605.
- *Transcription choices* (3): a "modified" copolymer recorded as chemically
  modified (subheading note 1(a)(3) sends it to "Other"); hemicellulose
  recorded as a natural polymer, not a cellulose acetate; a vest's coated
  fabric recorded on its panels, not on the vest (held out).
- *CBP's codes against its own words* (4): a code whose description says
  "Of cotton" while its number is another subheading's; a polyester scarf
  classified under artificial fibres; two merino wool hoodies classified as
  "Other" rather than "Of wool".

Every difference traces, in its explanation, to one of these. The rulings
are short of a fact or a judgment, the office reads a heading beyond its
words, counts a composition differently, or its code contradicts its own
text; or the transcription chose one reading of the ruling. Only the blouse
gap is the model's own shortfall: it lacks the Explanatory Note's notion of
a blouse.

### The first prototype's sample (95 goods, 15 held out)

| Set | Items | Same six-digit code | No code | Different code |
|---|---:|---:|---:|---:|
| CBP apparel (29 rulings) | 53 styles | 50 | 0 | 3 |
| EBTI apparel (11 BTIs) | 11 | 9 | 0 | 2 |
| CBP plastics (21 rulings) | 27 articles | 27 | 0 | 0 |
| EBTI plastics (4 BTIs) | 4 | 4 | 0 | 0 |
| **In-sample total** | **95** | **90 (95%)** | **0** | **5** |
| Held-out CBP apparel (10 rulings) | 10 | 8 | 0 | 2 |
| Held-out CBP plastics (5 rulings) | 5 | 5 | 0 | 0 |
| **Held-out total** | **15** | **13 (87%)** | **0** | **2** |

The four CBP bag rulings N360188–N360191 are one bag imported from four
countries; counted once, the in-sample total is 87 of 92.

**Every disagreement of that sample, classified.** The figures are those of the first prototype; only the woven blouses changed. Its nine headings had nothing to say about them, so it abstained; the full tariff places them in the residual heading 6211, "other garments", and they now count as different codes.

1. *The woven blouse* (5 in-sample, 1 held-out): NY N361742,
   NY N356781 (two styles), BTI DEBTI9846/26-1, BTI FRBTIFR-BTI-2025-07180,
   held-out NY N350798 (heading 6211 under the full tariff). Note 4 to Chapter 62 defines blouses as loose-fitting;
   the offices call these woven tops blouses (heading 6206) without recording
   a loose fit, and they have no opening that would make them shirts. The EU
   offices say which definition they apply — the CN Explanatory Note to 6206:
   light, fancy garments, "mostly" loose-fitting, with trimmings. The knitted
   blouses of 6106, by contrast, all agree: CBP records "loose-fitting" for
   them, following HQ H325360. This is a *rule gap* (the Explanatory-Note
   notion of a blouse is broader than the note's) and a *fact gap* (the
   rulings do not record the fit). Nothing else in the sample failed; the
   scale-up met the same gap twice more.
2. *A ruling at odds with its own laboratory* (held-out NY N336309): CBP
   classifies the shirt as cotton (6205.20) on the stated 98% cotton, while
   its laboratory, testing the fabric for the short-supply claim in the same
   ruling, reports 96% polyester. The transcription took the laboratory's
   finding, so the model says 6205.30. A *fact conflict inside the ruling*,
   which a rules engine surfaces and a keyword matcher would not.

With nine headings the model never produced a wrong code where the facts
were consistent: it either agreed or abstained (GRI 4, "most akin", is
deliberately not modelled). With the residual headings of whole chapters it
can no longer abstain on a garment: what no other heading describes is an
"other garment" of 6114 or 6211.

**What the rules explain, and what the judgments carry.**

- *Apparel* is mostly rule-driven. Of the 74 garments (in-sample and
  held-out), 54 are decided from observations alone — no office judgment at
  all — and 50 of those agree. The judgments that do occur answer claims that
  the garment belongs elsewhere (outerwear, sleepwear, a brassiere, a swim
  cover-up: 12 garments), plus one pocket position (HQ H293112), one essential
  character (knit and woven), five laboratory findings (four on metalized
  yarn, one on fibre content), one importer's statement of fibre content, one
  office's statement of the predominant fibre, two characterisations.
- *Plastics* is judgment-driven. Every article's heading follows from its
  recorded principal use (Additional U.S. Rule 1(a)); the rules supply GRI
  3(b) for the 12 composite goods and sets, the rival-heading answers (10),
  the polymer rule that separates 3923.21 from 3923.29, the packing forms, and
  the subheadings by use. The agreement figure for plastics therefore says
  that the rules are right *given* the office's judgment of the use — which is
  where two offices can differ. The flip query in `plastics_cbp.le` makes the
  point on the bowl clamp of NY N363253 (the importer asked for 3924.10.40,
  CBP gave 3926.90): the minimal changes that make it heading 3924 are
  exactly the principal-use judgments of table, kitchen, household or toilet
  use.

**Caveats.** The in-sample facts were transcribed by the author of the rules,
who knew what the rules read — the figure is an upper bound on what a blind
fact extractor would reach. The held-out set is fairer (rules frozen, facts
read with the classification sentences removed) but small, and its selection
listing showed the codes. Six digits only: the US ten-digit statistical
suffixes (gender, sweater stitch counts, dress shirts) and the EU eight-digit
CN subheadings are not modelled. A heading outside the model is handled only
when the ruling mentions it (a claim and its answer); a good that silently
belongs elsewhere (rubber gloves of Chapter 40, a blanket of Chapter 63,
say) would be misclassified.


## Scaling up: what changed with ten times the rules

| | First prototype | Three chapters |
|---|---:|---:|
| Headings / six-digit subheadings | 9 / 33 | 60 / 341 |
| Lines of LE (rule programs) | 964 | 3,256 |
| Labelled rules / decision-table rows | 62 / 33 | 217 / 354 |
| Templates | 84 | 153 |
| Scenario files / scenarios / quotations checked | 6 / 87 / 937 | 10 / 241 / 3,028 |
| Load of the model (`tariff.le`; before: `apparel.le` + `plastics.le`) | 0.5 s | 7.6 s, 3.1 s after the fixes below |
| Load of a 50-scenario file in the editor (cold) | — | 17.6 s, 10.7 s after the fixes below |
| One scenario's `subheading` query (5 goods) | — | 0.9 s, 0.5 s after the fixes below |
| The first prototype's 87 tests | 5.2 s | 41 s |
| All 237 tests of the directory | — | about 130 s |

Queries grow about linearly with the number of headings: each good is tested
against every heading's rules and GRI 3 compares the candidates. Loading grows
with the number of templates each sentence is matched against. Both stay
usable in the editor: a program opens in seconds, a query and its explanation
(300 nodes) in about 2 s.

Getting there took seven fixes to the engine, each found by the scale-up;
the three that change behaviour have tests of their own:

- **The stratification check enumerated every path** of the dependency graph
  (`le_scasp.pl`). Now one reachability pass per negative edge.
- **The untested-predicate check** walked the paths from every query again
  for each predicate (`le_verifier.pl`). Now one pass per verification.
- **Facts with provenance were parsed twice** in case a template owned a
  trailer phrase ("as stated in your schedule"), in every program
  (`le_grammar.pl`): 1.8 s of the model's load. Now only when some template
  does. With the two fixes above, the load of the model went from 7.6 s to
  3.1 s.
- **Every query step called predicates that are not defined** (`le_type/1`,
  `detailed_failures/0`), sending the autoloader through the library index
  each time (`reasoner.pl`). Now guarded.
- **Three sibling includes ran out of depth** (`le_kbs.pl`): the depth and the
  base folder of one included resource leaked into the next, because the
  cleanup ran only on deterministic exit. A program including three chapters
  that each include a library failed to load.
- **The editor ran every embedded test at each load** (`le_verifier.pl`). The
  tests now share a time budget (flag `le_verify_tests_seconds`, 5 s); those
  left over are reported once (`tests_not_run`), and the test runner still
  runs them all.
- **A scenario template that reads like a system one** (`*a garment* is
  napped`, like `*a thing* is *a value*`) was reported at every load of the
  library as redefining it with no rules — which, for a template the program
  marks `; undefined`, is the point. No longer.

## What the scale-up taught about LE

- *Negation before binding flounders.* `it is not the case that the good is
  a manufactured article` as the first condition of a rule is evaluated
  before the good is known, and fails as soon as any good in the scenario is
  one — silently dropping every other good. The same with a judged condition
  whose question is not yet bound: the engine then assumes outcomes that the
  recorded judgment should have closed. Bind first, negate after.
- *A variable must be introduced before `the`.* `if the component is a
  component of the good` (with no `a component` before it) is accepted and
  silently means something else; the rule never applies. The verifier does
  not warn.
- *`the kind of the good is in [briefs, panties]`* parses as the template
  "the kind of *a good* is *a kind*" with the kind "in [briefs, panties]" —
  the longest template wins. Write `the kind of the good is a kind and the
  kind is in [...]`.
- *One predicate, two domains.* "contains N percent of" serves textiles and
  polymers; polyester is both a textile material and a polymer's name, so the
  plastics rule found a 100 percent polyester garment tied with itself.
  Shares of different domains need predicates of their own.
- *Scenario vocabulary is the interface.* Marking scenario templates
  `; undefined` and listing the values the rules read (kinds, materials,
  polymers) is what made transcription by agents — and by a language model in
  the editor — possible at this scale.

### From the first prototype

Two defects of the regulatory-decision constructs (docs/le_summary.md §17)
surfaced and are fixed with this prototype:

- A `; judged` template with an outcome argument ("the principal use of *a
  good* is *a use*") left every *other* outcome assumable after one was
  recorded — so a bin judged "household use" was also, conditionally, a
  packing article. The last argument of a judged template is now its outcome:
  once one is recorded for a question, no other is assumed (§17.1).
- Provenance trailers on facts of an *included* resource were read back from
  the including file's text (the document came out as garbage), and could be
  confused with a fact of the includer at the same offsets. The resource's own
  text is now used, and the fact's head disambiguates.

Smaller observations: identifiers with leading zeros are read as numbers
("style 014613" becomes "style 14613"), so such styles are named descriptively
with the style number in a comment; a hyphenated template word renders with
spaces in explanations ("T - shirt"); a flip query that adds an outcome to a
decided judgment leaves the recorded one in place rather than replacing it.


## Next steps

- Blind fact extraction at scale: the by-hand path is in place; with a
  stronger model or a second extraction pass that reads the scenario
  templates' values, measure how many of the 150 rulings it transcribes as
  well as the agents did.
- The blouse gap: encode the Explanatory-Note notion of a blouse (light,
  fancy, trimmings) and measure whether it over-captures tops.
- CBP's notion of outerwear (designed for protection against the weather)
  against the heading's list of kinds: jackets that CBP calls other garments.
- Ten-digit US and eight-digit CN subheadings (gender, stitch counts, dress
  shirts, "recreational performance outerwear").
- Chapters 84/85, where GRI 3 and the section notes on parts do more work.
