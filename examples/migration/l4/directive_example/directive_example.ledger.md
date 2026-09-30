# Migration ledger: directive_example

Source: an L4 program (smucclaw/l4-ide) — directive-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 1 |
| **total** | 2 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| person age | assume | encoded | a template the scenarios state (; undefined) | person age |  |
| #eval at line 12 | test | residue | the evaluator's answer is not a value LE writes: `person age` |  |  |

## Residue

- **#eval at line 12** (test) — the evaluator's answer is not a value LE writes: `person age`; in the program: . 

