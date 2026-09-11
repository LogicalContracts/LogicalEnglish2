# Customs classification in Logical English: a first prototype

Step 1 of the plan in RulesRUs §8 (customs, §1 of that report): encode the
General Rules of Interpretation and the section and chapter notes for a few
chapters, then run the rules on the facts of published classification rulings
(US CBP rulings from CROSS, EU Binding Tariff Information from EBTI) and
compare the codes. This directory is that prototype. It covers two families of
goods:

- **upper-body garments** of Chapters 61 (knitted) and 62 (not knitted):
  headings 6105, 6106, 6109, 6110, 6205, 6206;
- **articles of plastics** of Chapter 39: headings 3923, 3924, 3926.

Chapters 84/85 (machinery), the third family the plan suggested, are not done.

## Files

| File | What it is |
|---|---|
| `gri.le` | The GRIs as a library: GRI 1 (the terms of the headings, read with the notes), GRI 3(a) (the more specific heading), 3(b) (a composite good or a set is classified as the component that gives it its essential character — a recorded judgment), 3(c) (the last heading in numerical order), and the claims that a good belongs to a heading outside the model. |
| `apparel.le` | Section XI note 2 and subheading note 2 (the textile material that predominates by weight, man-made fibres counted together, metalized yarn as one material), Chapter 61 notes 1, 4, 5, 9 and Chapter 62 notes 1, 4, 9, the Explanatory Note definitions of T-shirts, singlets and heading 6110, CBP's tank-top and T-shirt fabric tests, and the six-digit subheadings as a decision table. Includes `gri.le`. |
| `plastics.le` | Chapter 39 notes 1 and 2, subheading note 1 (the predominant polymer), Chapter 59 note 2(a)(5), Section VII note 2, and headings 3923/3924/3926 decided by the article's principal use (a judgment); subheadings by use, form and polymer as decision tables. Includes `gri.le`. |
| `apparel_cbp.le`, `plastics_cbp.le` | One scenario per CBP ruling (29 apparel, 21 plastics), each fact citing the ruling. |
| `apparel_ebti.le`, `plastics_ebti.le` | One scenario per EU BTI (11 apparel, 4 plastics), run through the same rules. |
| `heldout_apparel_cbp.le`, `heldout_plastics_cbp.le` | 15 more CBP rulings, transcribed and run after the rules were frozen. |
| `sources/` | The cited texts: `hts/` the pages of the HTSUS cited (General Rules of Interpretation; Section VII and Chapter 39; Section XI and Chapters 50–56, 59, 61, 62; `=== page N ===` marks the PDF page), `cbp/` the 65 CBP rulings as CROSS serves them, `ebti/` the 15 BTIs. US federal texts are in the public domain; EBTI decisions are published by the European Commission for reuse. |

Run one of them the usual way, e.g.

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/RulesRus/customs/apparel_cbp.le', R), print_test_result(R), halt."
```

Queries: `subheading` (the six-digit subheading of each good), `heading`,
`unplaced` (the goods the model should classify and cannot), and in
`plastics_cbp.le` the flip query `household` (below).

## Provenance: checking a rule or a fact against its source

Every rule and table is labelled and cites the passage it encodes
(docs/le_summary.md §15.5):

```
rule note_61_4_pockets with provenance as stated in HTSUS Chapter 61
        at "Headings 6105 and 6106 do not cover garments with pockets below the waist",
        because "the same in Chapter 62 note 4 for headings 6205 and 6206":
a garment is excluded from heading a heading
    if heading the heading is a shirt heading
    and the garment has pockets below the waist.
```

and every fact of every scenario cites the passage of its ruling that states
it (`style 1025AD has a collar, as stated in ruling NY N362700 at "zips
through a self-fabric stand-up collar"`). The documents say where they are
published and where their text is (`HTSUS Chapter 61 is published at
"https://hts.usitc.gov/...#page=2"`, `the text of ruling NY N362700 is at
"sources/cbp/N362700.txt"`), so

- the verifier checks that each of the 928 quotations is in its document's
  text (`quote_not_found` otherwise);
- in the editor, the **§** badge of an explanation node opens the cited
  document with the passage highlighted, and *Open original* opens the
  published page. (Browser text anchors do not reach the exact sentence on
  these sites — CROSS shows each ruling as an embedded PDF, EBTI detail pages
  need a session — hence the copies in `sources/`.)

Rules that are the model's own devices rather than the tariff's say so in
their `because`. The Explanatory Notes are not public; rules that encode them
cite the ruling or BTI that quotes them.

## Adding a ruling: facts from its text

Open the scenario file in the editor, then *Scenario Editor → Add → Write it
in English…*, and under *From a document* give the document's name
(`ruling NY N363001`) and the address of its text (for a CBP ruling, a copy
in `sources/cbp/`, or `https://rulings.cbp.gov/api/ruling/N363001`); *Fetch
text*, *Generate*. The language model is given the program's templates (with
those of `apparel.le` or `plastics.le`), writes only the facts the text
states, each citing its passage, never the classification itself, and marks
the office's decisions as judgments; every passage is checked against the
text. Review the facts, *Insert*, run the `subheading` query (docs/le_summary.md
§17.9). The scenarios of this directory were transcribed before that path
existed, by the transcription scripts described under *Method*.

## Sources

- HTSUS Revision 18 (2026): General Rules of Interpretation, Section VII and
  XI notes, Chapters 39, 61, 62 — https://hts.usitc.gov/ (chapter PDFs via
  `https://hts.usitc.gov/reststop/file?release=currentRelease&filename=Chapter%2061`).
  The section and chapter notes used are the WCO text, identical in the EU
  Combined Nomenclature.
- CBP rulings: CROSS, https://rulings.cbp.gov/ (search API
  `/api/search?term=<subheading>&collection=NY&sortBy=DATE_DESC`, text at
  `/api/ruling/<number>`), retrieved 11 September 2026.
- EU BTIs: EBTI, https://ec.europa.eu/taxation_customs/dds2/ebti/ , retrieved
  the same day (German and French offices).

**Selection.** For each six-digit subheading in scope, the most recent New
York rulings returned by CROSS (3 to 7 per heading), keeping every style of each
ruling, and the most recent valid BTI in English, French or German. The
held-out set: for each modelled heading the two most recent rulings not used
before whose codes (other than Chapter 98/99) all fall in modelled headings
(three for 3926; none were left for 6105 and 3923).

## Method

- **Only what the ruling states is a fact.** Each style is described by the
  facts its ruling gives — construction, fibre content, closure, sleeves,
  openings, pockets and bottom, fit, neckline, straps; for plastics the
  material, the components, the form, the polymer — each with its source
  (`as stated in ruling NY N362700`). **The ruling's code is never a fact.**
- **What the office decided is a judgment** (`; judged`), recorded with who
  and why: the principal use of a plastics article, the essential character of
  a composite good or set, and the answer to a claim that the good belongs to
  a heading outside the model (`the claim that style 1025AD belongs to
  outerwear is rejected, according to CBP, ..., because "the garment lacks the
  character of an outerwear jacket ..."`). Laboratory findings and importers'
  statements carry their source the same way.
- **Characterisations are flagged.** Twice a ruling calls a garment a tank top
  without describing its back; the characterisation is recorded as such, and
  the scenario's comment says the agreement rests on it.
- **How the scenarios were written.** The scenario files are generated by
  `transcription/gen_apparel.py` and `gen_plastics.py` (run them from any
  folder: `python3 transcription/gen_apparel.py`) from a hand transcription of
  each ruling — its styles, their facts, the office's judgments, the office's
  code — and `quotes.py`, which picks for each fact the clause of the style's
  own description that states it (a few chosen by hand, where a use would
  otherwise have been quoted from the classification sentence). The verifier
  then checks every quotation against the text.
- **Comparison at six digits** (the HS level both tariffs share). The
  expectation of each scenario is what the model derives; where that differs
  from the office's code the scenario says `DISAGREES` and why, so the example
  suite stays a regression test of the model, not of the rulings.

A classification's explanation is the audit trail the report asks for — the
GRI chain with every note and every fact's source. Abridged, for the cat toy of
NY N360066:

```
the subheading of the Pom Pom Launcher is 3924.90
  the heading of the Pom Pom Launcher is 3924
    the Pom Pom Launcher is clear of rival headings
      the claim that the Pom Pom Launcher belongs to toys of heading 9503 is rejected,
        according to CBP, as stated in ruling NY N360066, because "Chapter 95 note 5: ..."
    the Pom Pom Launcher is classified in heading 3924
      the Pom Pom Launcher is described by heading 3924
        the Pom Pom Launcher is classified as consisting of the launcher of the Pom Pom Launcher
          the essential character of the Pom Pom Launcher is given by the launcher ...,
            according to CBP, ..., because "the launcher gives the essential character by bulk, weight, value ..."
        the principal use of the Pom Pom Launcher is household use, according to CBP, ...,
          because "plastic pet toys used by domestic animals are household articles (Hartz Mountain ...)"
      it is not the case that ... heading 3926 prevails over heading 3924
        heading 3924 is more specific than heading 3926
  the subheading in heading 3924 for household use is 3924.90 under table uses  (row u2)
```

## Results

| Set | Items | Same six-digit code | No code (model abstains) | Different code |
|---|---:|---:|---:|---:|
| CBP apparel (29 rulings) | 53 styles | 50 | 3 | 0 |
| EBTI apparel (11 BTIs) | 11 | 9 | 2 | 0 |
| CBP plastics (21 rulings) | 27 articles | 27 | 0 | 0 |
| EBTI plastics (4 BTIs) | 4 | 4 | 0 | 0 |
| **In-sample total** | **95** | **90 (95%)** | **5** | **0** |
| Held-out CBP apparel (10 rulings) | 10 | 8 | 1 | 1 |
| Held-out CBP plastics (5 rulings) | 5 | 5 | 0 | 0 |
| **Held-out total** | **15** | **13 (87%)** | **1** | **1** |

The four CBP bag rulings N360188–N360191 are one bag imported from four
countries; counted once, the in-sample total is 87 of 92.

**Every disagreement, classified.**

1. *The woven blouse* (5 in-sample, 1 held-out; all abstentions): NY N361742,
   NY N356781 (two styles), BTI DEBTI9846/26-1, BTI FRBTIFR-BTI-2025-07180,
   held-out NY N350798. Note 4 to Chapter 62 defines blouses as loose-fitting;
   the offices call these woven tops blouses (heading 6206) without recording
   a loose fit, and they have no opening that would make them shirts. The EU
   offices say which definition they apply — the CN Explanatory Note to 6206:
   light, fancy garments, "mostly" loose-fitting, with trimmings. The knitted
   blouses of 6106, by contrast, all agree: CBP records "loose-fitting" for
   them, following HQ H325360. This is a *rule gap* (the Explanatory-Note
   notion of a blouse is broader than the note's) and a *fact gap* (the
   rulings do not record the fit). Nothing else in the sample failed.
2. *A ruling at odds with its own laboratory* (held-out NY N336309): CBP
   classifies the shirt as cotton (6205.20) on the stated 98% cotton, while
   its laboratory, testing the fabric for the short-supply claim in the same
   ruling, reports 96% polyester. The transcription took the laboratory's
   finding, so the model says 6205.30. A *fact conflict inside the ruling*,
   which a rules engine surfaces and a keyword matcher would not.

The model never produced a wrong code where the facts were consistent: it
either agreed or abstained (GRI 4, "most akin", is deliberately not modelled).

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
belongs elsewhere (a babies' garment of 6111, say) would be misclassified.

## What the prototype taught about LE

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

- The blouse gap: encode the Explanatory-Note notion of a blouse (light,
  fancy, trimmings) and measure whether it over-captures T-shirts and tops.
- Blind fact extraction: the facts of a ruling's description paragraph are
  within reach of a parser or a language model (a `; via service` template,
  §17.6) that never sees the code — the honest version of the evaluation.
- Ten-digit US and eight-digit CN subheadings for apparel (they are mostly
  more of the same: gender, stitch counts, dress shirts).
- Chapters 84/85, where GRI 3 and the section notes on parts do more work.
