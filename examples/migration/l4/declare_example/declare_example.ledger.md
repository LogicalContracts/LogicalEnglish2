# Migration ledger: declare_example

Source: an L4 program (smucclaw/l4-ide) — declare-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 17 |
| approximated | 0 |
| residue | 0 |
| **total** | 17 |

Fidelity: **3 of 3** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Person | record | encoded | a type of individuals, one template per field | Person |  |
| Point | record | encoded | a type of individuals, one template per field | Point |  |
| Colour | choice | encoded | named individuals | Colour |  |
| Shape | choice | encoded | named individuals | Shape |  |
| Age | type | encoded | a type | Age |  |
| PersonName | type | encoded | a type | PersonName |  |
| Box | record | encoded | a type of individuals, one template per field | Box |  |
| MyPair | record | encoded | a type of individuals, one template per field | MyPair |  |
| the applicant | record | encoded | an individual with one fact per field | the_applicant |  |
| the origin | record | encoded | an individual with one fact per field | the_origin |  |
| my favourite colour | definition | encoded | func | the my favourite colour is *a value* |  |
| my shape | record | encoded | an individual with one fact per field | my_shape |  |
| box with number | record | encoded | an individual with one fact per field | box_with_number |  |
| box with text | record | encoded | an individual with one fact per field | box_with_text |  |
| #EVAL at line 53 | test | encoded | a query and the evaluator's answer | line_53 |  |
| #EVAL at line 54 | test | encoded | a query and the evaluator's answer | line_54 |  |
| #EVAL at line 55 | test | encoded | a query and the evaluator's answer | line_55 |  |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_53 | line_53 | pass |  |
| line_54 | line_54 | pass |  |
| line_55 | line_55 | pass |  |

