# Migration ledger: ex2_references

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex2-references-normal.lrml
Translator: lpsPlus/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 12 |
| approximated | 4 |
| residue | 1 |
| **total** | 17 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel P/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | p holds |  |
| Rel Q/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | q holds |  |
| constitutive statement statement_5 | statement | encoded | ConstitutiveStatement -> an LE rule | statement_5 |  |
| source ref1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref1 |  |
| source ref6 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref6 |  |
| source ref2 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref2 |  |
| source ref3 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref3 |  |
| source ref4 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref4 |  |
| source ref5 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref5 |  |
| source ref7 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref7 |  |
| source ref8 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref8 |  |
| source ref9 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref9 |  |
| source ex-rule_1b | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ex-rule_1b |  |
| source oasis-rule_1b | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | oasis-rule_1b |  |
| association_2 -> ex-rule_1b | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | ex-rule_1b |  |
| association_4 -> oasis-rule_1b | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | oasis-rule_1b |  |
| ruleInfo2 -> stmt_1a | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | stmt_1a |  |

## Residue

- **ruleInfo2 -> stmt_1a** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: stmt_1a. 

