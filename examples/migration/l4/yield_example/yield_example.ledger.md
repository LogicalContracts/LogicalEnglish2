# Migration ledger: yield_example

Source: an L4 program (smucclaw/l4-ide) — yield-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 7 |
| residue | 10 |
| **total** | 23 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| all positive | wording | approximated | the template's words made from the name, its inputs appended | all positive for *a numbers* | to be reviewed: the name does not say where its inputs go |
| has negative | wording | approximated | the template's words made from the name, its inputs appended | *a numbers* has negative | to be reviewed: the name does not say where its inputs go |
| doubled list | wording | approximated | the template's words made from the name, its inputs appended | the doubled list for *a numbers* is *a list* | to be reviewed: the name does not say where its inputs go |
| only positive | wording | approximated | the template's words made from the name, its inputs appended | the only positive for *a numbers* is *a list* | to be reviewed: the name does not say where its inputs go |
| all adults | wording | approximated | the template's words made from the name, its inputs appended | all adults for *a people* | to be reviewed: the name does not say where its inputs go |
| negate | wording | approximated | the template's words made from the name, its inputs appended | the negate for *a predicate* is *a value* | to be reviewed: the name does not say where its inputs go |
| compose | wording | approximated | the template's words made from the name, its inputs appended | the compose for *a value* with *a second value* with *a third value* with *a fourth value* with *a fifth value* is *a sixth value* | to be reviewed: the name does not say where its inputs go |
| add one | definition | residue | a value with no LE form | r1 |  |
| add together | definition | residue | a value with no LE form | r2 |  |
| multiply values | definition | residue | a value with no LE form | r3 |  |
| double number | definition | residue | a value with no LE form | r4 |  |
| format pair | definition | residue | a value with no LE form | r5 |  |
| all positive | definition | encoded | pred | all positive for *a numbers* |  |
| has negative | definition | encoded | pred | *a numbers* has negative |  |
| doubled list | definition | encoded | func | the doubled list for *a numbers* is *a list* |  |
| only positive | definition | encoded | func | the only positive for *a numbers* is *a list* |  |
| all adults | definition | encoded | pred | all adults for *a people* |  |
| negate | definition | residue | a value with no LE form | r6 |  |
| compose | definition | residue | a value with no LE form | r7 |  |
| #eval at line 89 | test | residue | a value with no LE form: (`add one` OF 5) |  |  |
| #eval at line 90 | test | residue | a value with no LE form: (`add together` OF 3, 7) |  |  |
| #eval at line 91 | test | residue | a value with no LE form: (`double number` OF 21) |  |  |

## Residue

- **add one** (definition) — a value with no LE form; in the program: r1. 
- **add together** (definition) — a value with no LE form; in the program: r2. 
- **multiply values** (definition) — a value with no LE form; in the program: r3. 
- **double number** (definition) — a value with no LE form; in the program: r4. 
- **format pair** (definition) — a value with no LE form; in the program: r5. 
- **negate** (definition) — a value with no LE form; in the program: r6. 
- **compose** (definition) — a value with no LE form; in the program: r7. 
- **#eval at line 89** (test) — a value with no LE form: (`add one` OF 5); in the program: . 
- **#eval at line 90** (test) — a value with no LE form: (`add together` OF 3, 7); in the program: . 
- **#eval at line 91** (test) — a value with no LE form: (`double number` OF 21); in the program: . 

