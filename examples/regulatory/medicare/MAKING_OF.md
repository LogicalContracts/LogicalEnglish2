# How the examples in this folder were made

Every program in this folder was written by AI agents (Claude, working in
Claude Code) on 12 and 13 September 2026, at Miguel Calejo's request. The
agents read Medicare's published coverage policies for medical equipment and
wrote them as rules in Logical English. They also wrote the facts of 36
published appeal decisions as scenarios. A scenario is a named set of facts
that a question is asked about. No person typed these programs. The texts in
`sources/` are public documents, downloaded from the official sites by the
agents. One program, `blind_extraction.le`, holds text that two other
language models wrote, left unedited on purpose.

| File | Made by | How |
|---|---|---|
| `dmepos.le`, `GUIDE.md`, `pap.le`, `pmd.le`, `oxygen.le`, and their `_cases.le` | AI agent (Claude Fable 5.1, in Claude Code), 12 September 2026, at Miguel Calejo's request | the library that the policies share, the guide for writing the others, and the first three policies (positive airway pressure devices, power mobility devices, oxygen), each written from its Local Coverage Determination (LCD: the coverage rules of a Medicare contractor) and Policy Article in `sources/` |
| the other 54 policy programs (`aeds.le` … `wheelchair_seating.le`, `vitamin_d.le`) and their `_cases.le` | AI agents working in parallel (Claude Fable 5.1 on 12 September, Claude Opus 5 on 12–13 September 2026), each following `GUIDE.md`; then reviewed, repaired where needed and checked together by the agent in charge | each written from one or more LCDs and Policy Articles. DETAILS.md ("Effort") describes the process |
| `dmepos_all.le`, `all_cases.le`, `glucose_versions_cases.le` | the agent in charge (Claude Opus 5), 13 September 2026 | the whole model, cases that involve several policies, and the older versions of the glucose monitor rules, read from the LCDs' revision history |
| `council_pmd.le`, `council_other.le`, `council_more.le`, `council_supplies.le` | AI agents (Claude Fable 5.1, then Claude Opus 5), 12–13 September 2026 | the facts of 36 decisions of the Medicare Appeals Council, transcribed by the agents from the texts in `sources/council/`. `DETAILS.md` calls these the "hand transcriptions", to set them apart from the blind extraction below; they are still an agent's work |
| `blind_extraction.le` | two other language models, openai/gpt-oss-120b (on Groq) and moonshotai/Kimi-K3 (on Together), 13 September 2026; wrapped by the Claude agent | the facts are what the editor's "facts from a document" path produced, unedited, for ten of the Council decisions; the agent wrote only the program around them and its comments |
| `README.md`, `DETAILS.md` | AI agents (Claude, in Claude Code), 12–23 September 2026 | written with the programs, then split into a short guide and its details |
| `sources/lcd/*`, `sources/article/*`, `sources/ncd/*`, `sources/history/*`, `sources/ab/*.txt` | public documents of the Centers for Medicare & Medicaid Services (CMS) | taken by the agent from the weekly export of the Medicare Coverage Database (downloads.cms.gov), 12 September 2026, and written out as text, one file per document |
| `sources/icd10/*.csv`, `sources/ab/*_icd10_covered.csv` | the same export | the lists of diagnosis codes (ICD-10) that each Policy Article covers, written out as CSV files by the agent with a script it did not keep |
| `sources/cfr/*` | public law (the Code of Federal Regulations) | copied from the eCFR site by the agent, current as of 10 September 2026 |
| `sources/manuals/*` | public manuals of CMS | the text of the PDF chapters (Program Integrity Manual chapter 5, Benefit Policy Manual chapter 15), extracted by the agent |
| `sources/council/*` | public decisions of the Departmental Appeals Board, US Department of Health and Human Services | downloaded from hhs.gov by the agent, through a reading service (r.jina.ai) that turns a web page or PDF into text. Each file's first lines give the address it came from |
| `sources/courts/*` | public federal court opinions | downloaded from CourtListener by the agent, the same way |

Later changes, such as desks for an officer, calendar months, better
quotations, disclaimers and plainer comments, were also made by AI agents.
Some of them followed a review in which an agent played a Medicare officer
using the programs.

## The record

- LogicalEnglish2 commit `385423c` (12 September 2026), "Medicare DMEPOS
  PoC: the DMEPOS library, the PAP policy and its cases, the sources".
  Trailer "Co-Authored-By: Claude Fable 5.1".
- `589ddf5` … `1ada865` (12 September 2026): the first policies, the first
  21 Council decisions (`f68d35b`, `fb133ab`), Vitamin D across six
  contractors. All with the Claude Fable 5.1 trailer, though the
  author field says only "Miguel Calejo".
- `c51bc87` (12 September 2026) and the commits of 13 September 2026, up to
  `7637c48`: the other policies, the other 15 Council decisions, the versions,
  the whole model and `blind_extraction.le`. All marked "via Claude" and with
  a Claude Opus 5 trailer.
- InsurLE2 `0457837` (13 September 2026, via Claude): changes after the
  Medicare officer review.
- Every commit that touched these files in LogicalEnglish2, InsurLE2 and
  lpsPlus is marked "via Claude", written by Claude, or carries a Claude
  co-author trailer, except lpsPlus `a03941c` (23 September 2026), a person's
  commit that only removed the folder from lpsPlus when it moved here.
- The folder was `examples/RulesRus/medicare/` in LogicalEnglish2 (until
  13 September 2026), then `examples/medicare/` in InsurLE2 and in lpsPlus,
  and came back here on 23 September 2026 (`54eaf3e`).
- The plan the work followed, RulesRUs §2.1, is `docs/strategy/RulesRUs.md`
  of the lpsPlus repository (not public).
