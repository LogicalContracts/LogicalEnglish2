# Migration ledger: life_act

Source: Life Act. — sources/life_act.yaml, https://github.com/Lexpedite/blawx/tree/3de892f67854292b304c9a55c5e2cd2058d3d418
Translator: lpsPlus/migration/blawx (blawx_twin.pl)
Date: 2026-09-23
Source licence: Blawx: MIT

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 0 |
| residue | 5 |
| **total** | 10 |

Fidelity: **0 of 0** source test expectation(s) reproduced (0%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| person/1 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* is a person | Read in the source only by clauses this twin keeps as residue blocks (see the residue entries), so no rule here reads its facts: the verifier reports them unconsumed. |
| dob/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* was born on *a time* | Read in the source only by clauses this twin keeps as residue blocks (see the residue entries), so no rule here reads its facts: the verifier reports them unconsumed. |
| dod/2 | category, attribute or relationship | encoded | its #pred wording -> a template | *a person* died on *a time* | Read in the source only by clauses this twin keeps as residue blocks (see the residue entries), so no rule here reads its facts: the verifier reports them unconsumed. |
| 2 clause(s) of events in section 3 | events | residue | not translated: kept verbatim as a residue block | section_3_events | Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically |
| 1 clause(s) of events in section 2 | events | residue | not translated: kept verbatim as a residue block | section_2_events | Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically |
| 1 clause(s) of events in section 1 | events | residue | not translated: kept verbatim as a residue block | section_1_events | Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically |
| 48 blawx_as_of / blawx_during clauses | temporal boilerplate | encoded | left out: nothing reads it | nothing | Blawx writes these for every attribute and relationship; no rule or test of this project reads them0 |
| 84 #pred annotations | natural language | encoded | the wording of each template; the holds / according_to / defeated forms are the rules themselves | the templates |  |
| blawxtest when_did_bob_live | test | residue | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | when_did_bob_live | the query blawx_during(_25008,alive(bob),_25012) is not translated:  |
| blawxtest when_is_bob_not_alive | test | residue | a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py) | when_is_bob_not_alive | the query blawx_during(_24868,-alive(bob),_24872) is not translated:  |

## Residue

- **2 clause(s) of events in section 3** (events) — not translated: kept verbatim as a residue block; in the program: section_3_events. Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically
- **1 clause(s) of events in section 2** (events) — not translated: kept verbatim as a residue block; in the program: section_2_events. Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically
- **1 clause(s) of events in section 1** (events) — not translated: kept verbatim as a residue block; in the program: section_1_events. Blawx's event calculus (blawx_becomes, blawx_initially, blawx_ultimately, blawx_as_of, blawx_during): a value that events change belongs in an LPS twin (a fluent), or in lib/temporal's periods; not translated automatically
- **blawxtest when_did_bob_live** (test) — a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py); in the program: when_did_bob_live. the query blawx_during(_25008,alive(bob),_25012) is not translated: 
- **blawxtest when_is_bob_not_alive** (test) — a Blawx test -> a scenario; its expected answers are Blawx's own (oracle.py); in the program: when_is_bob_not_alive. the query blawx_during(_24868,-alive(bob),_24872) is not translated: 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|

