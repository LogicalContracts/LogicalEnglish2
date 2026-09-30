# Migration ledger: annotation_example

Source: an L4 program (smucclaw/l4-ide) — annotation-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 0 |
| residue | 1 |
| **total** | 4 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| age | assume | encoded | a template the scenarios state (; undefined) | age |  |
| applicantAge | assume | encoded | a template the scenarios state (; undefined) | applicantAge |  |
| eligible | assume | encoded | a template the scenarios state (; undefined) | eligible |  |
| #eval at line 13 | test | residue | the evaluator's answer is not a value LE writes: age |  |  |

## Residue

- **#eval at line 13** (test) — the evaluator's answer is not a value LE writes: age; in the program: . 

