# How the examples in this folder were made

Every program here is a *twin*: a Blawx project rewritten in Logical English by
a translator, a Prolog program that reads the project and writes the twin. No
person and no AI agent wrote the twins' rules or scenarios by hand. The
originals are the example projects that ship with Blawx, written by the Blawx
authors (Lexpedite). The translator itself, and this folder's README, were
written by an AI agent (Claude, in Claude Code) at Miguel Calejo's request.

| File | Made by | How |
|---|---|---|
| `*/<id>.le` | Translator program `lpsPlus/migration/blawx/build.pl` (`main/1`, which calls `blawx_twin:build_twin/4`) | Reads the project with `blawx_reader.pl`, writes the program through LE2's `le_writer.pl` and `le_migration.pl`. The rules come from the s(CASP) code Blawx compiled for each section, in the words of Blawx's own sentence forms. The scenarios are the project's own tests, plus cases written automatically from each rule by `blawx_cases.pl` (each rule met, each near miss, each defeat). The expected answers are those of Blawx's own reasoner, run by `oracle.py` and kept in `lpsPlus/migration/blawx/runs/`. The opening disclaimer comes from `le_migration:with_disclaimer/2`. |
| `*/<id>.ledger.md`, `*/<id>.ledger.json` | The same translator (`le_migration.pl`) | The migration ledger: what each part of the twin was translated from. Its notes on remaining warnings come from `blawx_twin:template_notes/7`; one note on the Bird Act ("except for pingu") was worded by the AI agent, as a `hand_template_note/3` in the translator. |
| `*/sources/<id>.yaml` | People: the authors of Blawx (Lexpedite Legal Technologies) | The example project, copied unchanged from Blawx v1.6.22-alpha (commit `3de892f6`, 18 October 2023), https://github.com/Lexpedite/blawx, fetched by `lpsPlus/migration/blawx/fetch_sources.sh`. |
| `*/sources/<id>.md` | The translator, from the project | The text of the Act, taken out of the project's rule document so that the twin can cite its sections. The words are the Blawx authors'. |
| `*/sources/BLAWX_LICENSE` | Lexpedite Legal Technologies | Blawx's MIT licence, copied beside each project. |
| `README.md` | AI agent (Claude, in Claude Code), at Miguel Calejo's request (it came from InsurLE2 with the twins on 16 September 2026 and was rewritten on 23 September) | Written by the agent itself, not by the translator. |
| `MAKING_OF.md` | AI agent (Claude, in Claude Code), 24 September 2026, at Miguel Calejo's request | This file. |

## The record

- Commit `c044cd0` (14 September 2026) "Phase 2c: s(CASP) and Blawx twins", in
  the InsurLE2 repository: the translator and the first build of the fifteen
  twins, by Miguel Calejo with Claude Opus 5 (the commit's `Co-Authored-By`
  line). Commit `a6daa9a` (15 September) applied the findings of a review of
  the twins, again by translator changes and a rebuild.
- The translator moved to the lpsPlus repository on 18 September 2026 (commit
  `44d3f65` there); the twins moved into this repository on 16 September
  (commit `9d42150`, "move examples").
- Later changes to the twins here came from rebuilding them after translator
  or writer fixes (for example commit `5612ff5`, 23 September, when the writer
  stopped using constructs outside core Logical English). One hand edit of
  `r34/r34.le` (commit `6e903fd`, 22 September, a `; memorable` marker) was
  taken back the same day (commit `55b4692`). The record shows no other hand
  edit of a twin.
- To build the twins again, from the LE2 checkout, with `library(scasp)` and
  Python 3 with PyYAML installed:

  ```sh
  /lpsPlus/migration/blawx/fetch_sources.sh
  ./myswipl.sh -q /lpsPlus/migration/blawx/build.pl            # all fifteen
  ./myswipl.sh -q /lpsPlus/migration/blawx/build.pl -- rps     # one
  ```

  The lpsPlus repository is not public.
