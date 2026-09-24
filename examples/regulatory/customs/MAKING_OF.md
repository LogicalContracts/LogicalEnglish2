# How the examples in this folder were made

Every program in this folder was written by AI agents (Claude, working in
Claude Code) on 11 and 12 September 2026, at Miguel Calejo's request. The
agents read the US tariff (the Harmonized Tariff Schedule of the United
States, HTSUS) and wrote its rules in Logical English. They also wrote the
facts of 225 published customs rulings as scenarios. A scenario is a named
set of facts that a question is asked about. No person typed these programs.
The texts in `sources/` are public documents, copied from the official sites
by the agents.

| File | Made by | How |
|---|---|---|
| `gri.le`, `section_xi.le`, `chapter_39.le`, `chapter_61.le`, `chapter_62.le`, `tariff.le` | AI agent (Claude Opus 5, in Claude Code), 11–12 September 2026, at Miguel Calejo's request | written from the HTSUS text in `sources/hts/`: the General Rules of Interpretation, the notes of Section XI and of Chapters 39, 61 and 62, and their headings and subheadings. The agent first wrote a prototype of 9 headings (11 September), then all 60 headings of the three chapters (12 September). The quotations that tie each table row to its tariff line were copied from `sources/hts/` by a script the agent wrote and did not keep |
| `apparel_cbp.le`, `apparel_ebti.le`, `plastics_cbp.le`, `plastics_ebti.le`, `heldout_apparel_cbp.le`, `heldout_plastics_cbp.le` | the same agent, 11 September 2026 | the facts of 65 rulings of US Customs and Border Protection (CBP) and 15 European Binding Tariff Information decisions, transcribed by the agent from their texts. The first version was produced by Python scripts the agent wrote, `gen_apparel.py`, `gen_plastics.py` and `quotes.py`, holding the agent's transcription. The scripts were deleted the same day, and since then the `.le` files themselves are the source |
| `cbp_39.le`, `cbp_61.le`, `cbp_62.le`, `heldout_cbp_2.le` | six AI agents (Claude) working in parallel, 12 September 2026, then reviewed and corrected by the agent that wrote the rules | the facts of 150 more CBP rulings, each agent following the same written guide. DETAILS.md ("How the scenarios were written") describes the review |
| `by_hand.le` | the same agent, 12 September 2026 | names ten CBP rulings, with CBP's codes in comments, kept aside so that a person can write their facts in the editor. It has no facts yet. `DETAILS.md` reports a test of this path in which a language model (gpt-oss-120b) drafted the facts; those drafts are not stored here |
| `README.md`, `DETAILS.md` | AI agents (Claude, in Claude Code), 11–23 September 2026 | written with the programs, then split into a short guide and its details |
| `sources/hts/*` | public documents of the US International Trade Commission | the HTSUS chapters, downloaded as PDF from hts.usitc.gov by the agent, their text extracted, with `=== page N ===` marking each page |
| `sources/cbp/*` | public documents of US Customs and Border Protection | the 225 rulings, as the CROSS rulings site serves them (rulings.cbp.gov/api/ruling/…), downloaded by the agents. Each file's first lines say where it came from |
| `sources/ebti/*` | public documents of the European Commission | 15 Binding Tariff Information decisions, copied from the EBTI search site (ec.europa.eu/taxation_customs/dds2/ebti) by the agent |

Later changes, such as a view for a customs officer, citations on the table
rows, disclaimers and plainer comments, were also made by AI agents. Some of
them followed a review in which an agent played a customs officer using the
programs.

## The record

- LogicalEnglish2 commit `75411c9` (11 September 2026), "Customs
  classification prototype (RulesRUs §8 step 1)": the rules and the first 80
  rulings and decisions. Trailer "Co-Authored-By: Claude Opus 5 (1M context)".
- `9b265e1` (11 September 2026): every rule and fact cites its passage;
  adds `sources/` and the transcription scripts
  (`examples/RulesRus/customs/transcription/`).
- `348cf40` (11 September 2026): "its one-off transcription scripts are
  removed: the .le files are the source".
- `7629c6f` (12 September 2026), "Customs: Chapters 39, 61 and 62 in full":
  the three chapters, the 150 new rulings, `by_hand.le` and the 225 ruling
  texts.
- `0c0464e`, `806c3f0` (12 September 2026): the customs officer's review and
  the views built from it.
- Every commit that touched these files in LogicalEnglish2, InsurLE2 and
  lpsPlus is marked "via Claude", written by Claude, or carries a Claude
  co-author trailer, except lpsPlus `a03941c` (23 September 2026), a person's
  commit that only removed the folder from lpsPlus when it moved here.
- The folder was `examples/RulesRus/customs/` in LogicalEnglish2 (until
  13 September 2026), then `examples/customs/` in InsurLE2 and in lpsPlus,
  and came back here on 23 September 2026 (`54eaf3e`).
- The plan the work followed, RulesRUs §8, is
  `docs/strategy/RulesRUs.md` of the lpsPlus repository (not public).
