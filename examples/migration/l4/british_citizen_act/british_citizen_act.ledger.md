# Migration ledger: british_citizen_act

Source: an L4 program (smucclaw/l4-ide) — british-citizen-act.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 25 |
| approximated | 19 |
| residue | 4 |
| **total** | 48 |

Fidelity: **2 of 2** source test expectation(s) reproduced (100%).

**16 further expectation(s) are pending** (waits for residue r2): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Place | record | encoded | a type of individuals, one template per field | Place |  |
| Date | record | encoded | a type of individuals, one template per field | Date |  |
| Maybe | choice | encoded | named individuals | Maybe |  |
| NaturalPerson | record | encoded | a type of individuals, one template per field | NaturalPerson |  |
| mother of | wording | approximated | the template's words made from the name, its inputs appended | the mother of *a person* is *a second person* | to be reviewed: the name does not say where its inputs go |
| father of | wording | approximated | the template's words made from the name, its inputs appended | the father of *a person* is *a second person* | to be reviewed: the name does not say where its inputs go |
| is born in the United Kingdom after commencement | wording | approximated | the template's words made from the name, its inputs appended | *a person* is born in the united kingdom after commencement | to be reviewed: the name does not say where its inputs go |
| is born in a qualifying territory after the appointed day | wording | approximated | the template's words made from the name, its inputs appended | *a person* is born in a qualifying territory after the appointed day | to be reviewed: the name does not say where its inputs go |
| is settled in the United Kingdom | wording | approximated | the template's words made from the name, its inputs appended | *a person* is settled in the united kingdom | to be reviewed: the name does not say where its inputs go |
| is settled in the qualifying territory in which the person is born | wording | approximated | the template's words made from the name, its inputs appended | *a person* is settled in the qualifying territory in what the person is born | to be reviewed: the name does not say where its inputs go |
| isBOT | wording | approximated | the template's words made from the name, its inputs appended | *a place* is BOT | to be reviewed: the name does not say where its inputs go |
| qualifying territory | wording | approximated | the template's words made from the name, its inputs appended | qualifying territory for *a place* | to be reviewed: the name does not say where its inputs go |
| after | wording | approximated | the template's words made from the name, its inputs appended | after for *a date* with *a second date* | to be reviewed: the name does not say where its inputs go |
| isBornInUK | wording | approximated | the template's words made from the name, its inputs appended | *a natural person* is born in UK | to be reviewed: the name does not say where its inputs go |
| isBornInUS | wording | approximated | the template's words made from the name, its inputs appended | *a natural person* is born in US | to be reviewed: the name does not say where its inputs go |
| afterCommencement | wording | approximated | the template's words made from the name, its inputs appended | after commencement for *a natural person* | to be reviewed: the name does not say where its inputs go |
| afterAppointedDay | wording | approximated | the template's words made from the name, its inputs appended | after appointed day for *a natural person* | to be reviewed: the name does not say where its inputs go |
| plus | wording | approximated | the template's words made from the name, its inputs appended | the plus for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| is a British citizen if anything | wording | approximated | the template's words made from the name, its inputs appended | *a person* is a british citizen whether anything for *a boolean* | to be reviewed: the name does not say where its inputs go |
| is a British citizen (local) | wording | approximated | the template's words made from the name, its inputs appended | *a person* is a british citizen local | to be reviewed: the name does not say where its inputs go |
| for father or mother of | wording | approximated | the template's words made from the name, its inputs appended | for father else mother of *a person* with *a property* | to be reviewed: the name does not say where its inputs go |
| is a British citizen (variant) | wording | approximated | the template's words made from the name, its inputs appended | *a person* is a british citizen variant | to be reviewed: the name does not say where its inputs go |
| mother of | assume | encoded | a template the scenarios state (; undefined) | mother of |  |
| father of | assume | encoded | a template the scenarios state (; undefined) | father of |  |
| is born in the United Kingdom after commencement | assume | encoded | a template the scenarios state (; undefined) | is born in the United Kingdom after commencement |  |
| is born in a qualifying territory after the appointed day | assume | encoded | a template the scenarios state (; undefined) | is born in a qualifying territory after the appointed day |  |
| is settled in the United Kingdom | assume | encoded | a template the scenarios state (; undefined) | is settled in the United Kingdom |  |
| is settled in the qualifying territory in which the person is born | assume | encoded | a template the scenarios state (; undefined) | is settled in the qualifying territory in which the person is born |  |
| British Overseas Territories | record | encoded | a list of individuals, one fact per field | british_overseas_territories |  |
| isBOT | definition | encoded | pred | *a place* is BOT |  |
| akdh | record | encoded | an individual with one fact per field | akdh |  |
| commencement | record | encoded | an individual with one fact per field | commencement |  |
| appointed day | record | encoded | an individual with one fact per field | appointed_day |  |
| qualifying territory | definition | encoded | pred | qualifying territory for *a place* |  |
| after | definition | encoded | pred | after for *a date* with *a second date* |  |
| isBornInUK | definition | encoded | pred | *a natural person* is born in UK |  |
| isBornInUS | definition | encoded | pred | *a natural person* is born in US |  |
| afterCommencement | definition | encoded | pred | after commencement for *a natural person* |  |
| afterAppointedDay | definition | encoded | pred | after appointed day for *a natural person* |  |
| plus | definition | encoded | func | the plus for *a number* with *a second number* is *a third number* |  |
| is a British citizen if anything | definition | encoded | pred | *a person* is a british citizen whether anything for *a boolean* |  |
| father or mother | wording | approximated | the template's words made from the name, its inputs appended | father else mother for *a person* with *a property* | to be reviewed: the name does not say where its inputs go |
| father or mother | definition | residue | a value with no LE form | r1 |  |
| is a British citizen (local) | definition | residue | a condition with no LE form | r2 |  |
| for father or mother of | definition | residue | a value with no LE form | r3 |  |
| is a British citizen (variant) | definition | residue | a condition with no LE form | r4 |  |
| #EVAL at line 57 | test | encoded | a query and the evaluator's answer | line_57 |  |
| #EVAL at line 73 | test | encoded | a query and the evaluator's answer | line_73 |  |

## Residue

- **father or mother** (definition) — a value with no LE form; in the program: r1. 
- **is a British citizen (local)** (definition) — a condition with no LE form; in the program: r2. 
- **for father or mother of** (definition) — a value with no LE form; in the program: r3. 
- **is a British citizen (variant)** (definition) — a condition with no LE form; in the program: r4. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_57 | line_57 | pass |  |
| line_73 | line_73 | pass |  |

