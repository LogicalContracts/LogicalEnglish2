# Migration ledger: either_example

Source: an L4 program (smucclaw/l4-ide) — either-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 0 |
| residue | 5 |
| **total** | 6 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| api result | assume | encoded | a template the scenarios state (; undefined) | api result |  |
| error case | definition | residue | a value with no LE form | r1 |  |
| success case | definition | residue | a value with no LE form | r2 |  |
| handle the result | definition | residue | a pattern with no LE form | r3 |  |
| #eval at line 18 | test | residue | a value that is not a constant: `error case` |  |  |
| #eval at line 19 | test | residue | a value that is not a constant: `success case` |  |  |

## Residue

- **error case** (definition) — a value with no LE form; in the program: r1. 
- **success case** (definition) — a value with no LE form; in the program: r2. 
- **handle the result** (definition) — a pattern with no LE form; in the program: r3. 
- **#eval at line 18** (test) — a value that is not a constant: `error case`; in the program: . 
- **#eval at line 19** (test) — a value that is not a constant: `success case`; in the program: . 

