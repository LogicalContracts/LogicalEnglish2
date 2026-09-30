# Migration ledger: coercion_example

Source: an L4 program (smucclaw/l4-ide) — coercion-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 18 |
| approximated | 1 |
| residue | 17 |
| **total** | 36 |

Fidelity: **0 of 0** source test expectation(s) reproduced (0%).

**18 further expectation(s) are pending** (waits for residue r1; waits for residue r10; waits for residue r11; waits for residue r12; waits for residue r13; waits for residue r14; waits for residue r15; waits for residue r16; waits for residue r17; waits for residue r2; waits for residue r3; waits for residue r4; waits for residue r5; waits for residue r6; waits for residue r7; waits for residue r8; waits for residue r9): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| parseAndDouble | wording | approximated | the template's words made from the name, its inputs appended | the parse as well as double for *an input* is *a text* | to be reviewed: the name does not say where its inputs go |
| numberText | definition | residue | a value with no LE form | r1 |  |
| boolText | definition | residue | a value with no LE form | r2 |  |
| dateText | definition | residue | a value with no LE form | r3 |  |
| boolAsString | definition | residue | a value with no LE form | r4 |  |
| dateAsString | definition | residue | a value with no LE form | r5 |  |
| parsedGood | definition | residue | a value with no LE form | r6 |  |
| parsedSci | definition | residue | a value with no LE form | r7 |  |
| parsedBad | definition | residue | a value with no LE form | r8 |  |
| parsedISODate | definition | residue | a value with no LE form | r9 |  |
| parsedSlashDate | definition | residue | a value with no LE form | r10 |  |
| parsedNamedDate | definition | residue | a value with no LE form | r11 |  |
| parsedBadDate | definition | residue | a value with no LE form | r12 |  |
| truncWhole | definition | residue | a value with no LE form | r13 |  |
| truncDecimals | definition | residue | a value with no LE form | r14 |  |
| truncNegativeDigits | definition | residue | a value with no LE form | r15 |  |
| truncNegativeNumber | definition | residue | a value with no LE form | r16 |  |
| parseAndDouble | definition | residue | a value with no LE form | r17 |  |
| #EVAL at line 6 | test | encoded | a query and the evaluator's answer | line_6 |  |
| #EVAL at line 9 | test | encoded | a query and the evaluator's answer | line_9 |  |
| #EVAL at line 12 | test | encoded | a query and the evaluator's answer | line_12 |  |
| #EVAL at line 16 | test | encoded | a query and the evaluator's answer | line_16 |  |
| #EVAL at line 19 | test | encoded | a query and the evaluator's answer | line_19 |  |
| #EVAL at line 23 | test | encoded | a query and the evaluator's answer | line_23 |  |
| #EVAL at line 26 | test | encoded | a query and the evaluator's answer | line_26 |  |
| #EVAL at line 29 | test | encoded | a query and the evaluator's answer | line_29 |  |
| #EVAL at line 33 | test | encoded | a query and the evaluator's answer | line_33 |  |
| #EVAL at line 36 | test | encoded | a query and the evaluator's answer | line_36 |  |
| #EVAL at line 39 | test | encoded | a query and the evaluator's answer | line_39 |  |
| #EVAL at line 42 | test | encoded | a query and the evaluator's answer | line_42 |  |
| #EVAL at line 46 | test | encoded | a query and the evaluator's answer | line_46 |  |
| #EVAL at line 49 | test | encoded | a query and the evaluator's answer | line_49 |  |
| #EVAL at line 52 | test | encoded | a query and the evaluator's answer | line_52 |  |
| #EVAL at line 55 | test | encoded | a query and the evaluator's answer | line_55 |  |
| #EVAL at line 65 | test | encoded | a query and the evaluator's answer | line_65 |  |
| #EVAL at line 66 | test | encoded | a query and the evaluator's answer | line_66 |  |

## Residue

- **numberText** (definition) — a value with no LE form; in the program: r1. 
- **boolText** (definition) — a value with no LE form; in the program: r2. 
- **dateText** (definition) — a value with no LE form; in the program: r3. 
- **boolAsString** (definition) — a value with no LE form; in the program: r4. 
- **dateAsString** (definition) — a value with no LE form; in the program: r5. 
- **parsedGood** (definition) — a value with no LE form; in the program: r6. 
- **parsedSci** (definition) — a value with no LE form; in the program: r7. 
- **parsedBad** (definition) — a value with no LE form; in the program: r8. 
- **parsedISODate** (definition) — a value with no LE form; in the program: r9. 
- **parsedSlashDate** (definition) — a value with no LE form; in the program: r10. 
- **parsedNamedDate** (definition) — a value with no LE form; in the program: r11. 
- **parsedBadDate** (definition) — a value with no LE form; in the program: r12. 
- **truncWhole** (definition) — a value with no LE form; in the program: r13. 
- **truncDecimals** (definition) — a value with no LE form; in the program: r14. 
- **truncNegativeDigits** (definition) — a value with no LE form; in the program: r15. 
- **truncNegativeNumber** (definition) — a value with no LE form; in the program: r16. 
- **parseAndDouble** (definition) — a value with no LE form; in the program: r17. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|

