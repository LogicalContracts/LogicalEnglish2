# How the examples in this folder were made

Every program here is a *twin*: a transaction of Oracle Insurance Policy
Administration (OIPA) rewritten in Logical English by a translator, a Prolog
program that reads the transaction's XML configuration and writes the twin.
There is no public OIPA configuration, so **the originals are not Oracle's and
were not written by a person**: an AI agent (Claude, in Claude Code) wrote two
made-up plans, a deferred annuity and a level term life policy, following the
forms of Oracle's public *OIPA XML Configuration Guide* (release 9.7). The
same agent wrote the translator, the independent program that computes the
expected values, and this folder's README, at Miguel Calejo's request.

| File | Made by | How |
|---|---|---|
| `*/<plan>_<transaction>.le` | Translator program `lpsPlus/migration/oipa/build.pl` (`main/1`, which calls `build_plan/2` of `oipa_twin.pl`) | Reads the transaction with `oipa_reader.pl` and writes the program through LE2's `le_writer.pl` and `le_migration.pl`. The scenarios are the policy lives of the plan's `cases.json`. The expected values are computed by `oipa_eval.py`, an interpreter of OIPA's arithmetic in Python that shares no code with the translator. The opening disclaimer comes from `le_migration:with_disclaimer/2`. |
| `*/<plan>_<transaction>.ledger.md`, `*.ledger.json` | The same translator (`le_migration.pl`) | What each MathVariable, check and spawn became. |
| `*/surrender_charge.csv` and other rate tables beside a twin | The translator | The plan's rates of one description, taken from `sources/Rates.csv`, for the twin to load as a decision table. |
| `*/temporal.le`, `*/temporal.pl` | A copy of LE2's `lib/temporal.le` and `lib/temporal.pl`, put there by the translator | The library of dates. It was written by the AI agent (commit `63c3591`, 13 September 2026). |
| `*/sources/<Transaction>/*.xml`, `*/sources/Rates.csv`, `*/sources/PlanFields.csv` | AI agent (Claude, in Claude Code), 14 September 2026 | The synthetic configuration: each transaction's XML and its attached rules, the plan's rates and plan fields. Written from the element and attribute forms of Oracle's public guide (https://docs.oracle.com/en/industries/insurance/policy-administration/); no Oracle configuration was copied. Kept in `lpsPlus/migration/oipa/corpus/` and copied beside each twin by the translator. |
| `README.md` | AI agent (Claude, in Claude Code), 23 September 2026, at Miguel Calejo's request | Written by the agent itself, not by the translator. |
| `MAKING_OF.md` | AI agent (Claude, in Claude Code), 24 September 2026, at Miguel Calejo's request | This file. |

## The record

- Commit `e5c9a1a` (14 September 2026) "Phase 2b: OIPA transactions as
  Logical English, on a synthetic corpus", in the InsurLE2 repository, by
  Miguel Calejo with Claude Opus 5 (the commit's `Co-Authored-By` line): the
  two synthetic plans, the reader, the translator, `oipa_eval.py` and the first
  build ("Two synthetic plans written from the public OIPA XML Configuration
  Guide 9.7"). Commit `3b378f2` (15 September) followed a review of the twins.
- The translator and the plans moved to the lpsPlus repository on 18 September
  2026 (commit `44d3f65` there). The twins were published in this repository
  on 23 September 2026 (commit `54eaf3e`, "rearrange some examples"), when
  Miguel Calejo decided to make them public; the record shows no hand edit of
  a twin.
- To build the twins again, from the LE2 checkout, with Python 3:

  ```sh
  ./myswipl.sh -q /lpsPlus/migration/oipa/build.pl
  ```

  The lpsPlus repository is not public.
