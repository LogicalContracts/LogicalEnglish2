# Migration ledger: ex9b_alternatives

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex9b-alternatives-normal.lrml
Translator: lpsPlus/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-23

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 3 |
| approximated | 2 |
| residue | 6 |
| **total** | 11 |

Fidelity: **8 of 8** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel A/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | a holds |  |
| Rel B/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | b holds |  |
| prescriptive statement ps1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps1 |  |
| constitutive statement cs2 | statement | encoded | ConstitutiveStatement -> an LE rule | cs2 |  |
| Alternatives alt1 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt1 |  |
| assoc2 -> cs_a-b_and_c | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | cs_a-b_and_c |  |
| assoc2 -> cs_a-b | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | cs_a-b |  |
| assoc2 -> cs_a-c | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | cs_a-c |  |
| association_1 -> cs_d-b_and_c | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | cs_d-b_and_c |  |
| association_1 -> cs_d-b | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | cs_d-b |  |
| association_1 -> cs_d-c | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | cs_d-c |  |

## Residue

- **assoc2 -> cs_a-b_and_c** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: cs_a-b_and_c. 
- **assoc2 -> cs_a-b** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: cs_a-b. 
- **assoc2 -> cs_a-c** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: cs_a-c. 
- **association_1 -> cs_d-b_and_c** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: cs_d-b_and_c. 
- **association_1 -> cs_d-b** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: cs_d-b. 
- **association_1 -> cs_d-c** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: cs_d-c. 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| prescriptive_reading | b | pass |  |
| prescriptive_reading | obligations | pass |  |
| prescriptive_reading | violated_obligations | pass |  |
| prescriptive_reading | breaches | pass |  |
| constitutive_reading | b | pass |  |
| constitutive_reading | obligations | pass |  |
| constitutive_reading | violated_obligations | pass |  |
| constitutive_reading | breaches | pass |  |

