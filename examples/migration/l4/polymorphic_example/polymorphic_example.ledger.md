# Migration ledger: polymorphic_example

Source: an L4 program (smucclaw/l4-ide) — polymorphic-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 2 |
| approximated | 2 |
| residue | 2 |
| **total** | 6 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| length of list | wording | approximated | the template's words made from the name, its inputs appended | the length of *a list* for *a value* is *a number* | to be reviewed: the name does not say where its inputs go |
| go | wording | approximated | the template's words made from the name, its inputs appended | the go for *an acc* with *a value* is *a second value* | to be reviewed: the name does not say where its inputs go |
| go | definition | encoded | func | the go for *an acc* with *a value* is *a second value* |  |
| length of list | definition | encoded | func | the length of *a list* for *a value* is *a number* |  |
| #eval at line 14 | test | residue | a value with no LE form: (`length of list` OF (LIST 1, 2, 3)) |  |  |
| #eval at line 15 | test | residue | a value with no LE form: (`length of list` OF (LIST "a", "b", "c")) |  |  |

## Residue

- **#eval at line 14** (test) — a value with no LE form: (`length of list` OF (LIST 1, 2, 3)); in the program: . 
- **#eval at line 15** (test) — a value with no LE form: (`length of list` OF (LIST "a", "b", "c")); in the program: . 

