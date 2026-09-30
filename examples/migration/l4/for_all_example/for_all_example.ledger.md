# Migration ledger: for_all_example

Source: an L4 program (smucclaw/l4-ide) — for-all-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 18 |
| approximated | 6 |
| residue | 9 |
| **total** | 33 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Choice | choice | encoded | named individuals | Choice |  |
| Optional | choice | encoded | named individuals | Optional |  |
| Pair | record | encoded | a type of individuals, one template per field | Pair |  |
| Tree | choice | encoded | named individuals | Tree |  |
| myMap | wording | approximated | the template's words made from the name, its inputs appended | the my map for *a value* with *a second value* with *a third value* with *a list* is *a second list* | to be reviewed: the name does not say where its inputs go |
| myLength | wording | approximated | the template's words made from the name, its inputs appended | the my length for *a value* with *a list* is *a number* | to be reviewed: the name does not say where its inputs go |
| myReverse | wording | approximated | the template's words made from the name, its inputs appended | the my reverse for *a value* with *a list* is *a second list* | to be reviewed: the name does not say where its inputs go |
| append | wording | approximated | the template's words made from the name, its inputs appended | the append for *a value* with *a list1* with *a list2* is *a list* | to be reviewed: the name does not say where its inputs go |
| double | wording | approximated | the template's words made from the name, its inputs appended | the double for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| treeSize | wording | approximated | the template's words made from the name, its inputs appended | the tree size for *a value* with *a tree* is *a number* | to be reviewed: the name does not say where its inputs go |
| identity | assume | encoded | a template the scenarios state (; undefined) | identity |  |
| const | assume | encoded | a template the scenarios state (; undefined) | const |  |
| map | assume | encoded | a template the scenarios state (; undefined) | map |  |
| filter | assume | encoded | a template the scenarios state (; undefined) | filter |  |
| foldl | assume | encoded | a template the scenarios state (; undefined) | foldl |  |
| either | assume | encoded | a template the scenarios state (; undefined) | either |  |
| fromOptional | assume | encoded | a template the scenarios state (; undefined) | fromOptional |  |
| makePair | assume | encoded | a template the scenarios state (; undefined) | makePair |  |
| myMap | definition | residue | a value with no LE form | r1 |  |
| myLength | definition | residue | a value with no LE form | r2 |  |
| myReverse | definition | residue | a value with no LE form | r3 |  |
| append | definition | residue | a value with no LE form | r4 |  |
| numbers | definition | encoded | func | the numbers is *a list* |  |
| strings | definition | encoded | func | the strings is *a list* |  |
| double | definition | encoded | func | the double for *a number* is *a second number* |  |
| compose | assume | encoded | a template the scenarios state (; undefined) | compose |  |
| flip | assume | encoded | a template the scenarios state (; undefined) | flip |  |
| treeSize | definition | residue | a value with no LE form | r5 |  |
| exampleTree | record | encoded | an individual with one fact per field | example_tree |  |
| #eval at line 146 | test | residue | a value with no LE form: (`myLength` OF `numbers`) |  |  |
| #eval at line 147 | test | residue | a value with no LE form: (`myLength` OF `strings`) |  |  |
| #eval at line 153 | test | residue | a value with no LE form: (`myMap` OF `double`, `numbers`) |  |  |
| #eval at line 202 | test | residue | a value with no LE form: (`treeSize` OF `exampleTree`) |  |  |

## Residue

- **myMap** (definition) — a value with no LE form; in the program: r1. 
- **myLength** (definition) — a value with no LE form; in the program: r2. 
- **myReverse** (definition) — a value with no LE form; in the program: r3. 
- **append** (definition) — a value with no LE form; in the program: r4. 
- **treeSize** (definition) — a value with no LE form; in the program: r5. 
- **#eval at line 146** (test) — a value with no LE form: (`myLength` OF `numbers`); in the program: . 
- **#eval at line 147** (test) — a value with no LE form: (`myLength` OF `strings`); in the program: . 
- **#eval at line 153** (test) — a value with no LE form: (`myMap` OF `double`, `numbers`); in the program: . 
- **#eval at line 202** (test) — a value with no LE form: (`treeSize` OF `exampleTree`); in the program: . 

