# Migration ledger: type_inference_example

Source: an L4 program (smucclaw/l4-ide) — type-inference-example.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 1 |
| approximated | 1 |
| residue | 0 |
| **total** | 2 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| add two numbers | wording | approximated | the template's words made from the name, its inputs appended | the add two numbers for *a number* with *a second number* is *a third number* | to be reviewed: the name does not say where its inputs go |
| add two numbers | definition | encoded | func | the add two numbers for *a number* with *a second number* is *a third number* |  |

