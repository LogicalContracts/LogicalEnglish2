# Migration ledger: ex9_alternatives

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex9-alternatives-normal.lrml
Translator: InsurLE2/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 18 |
| approximated | 10 |
| residue | 0 |
| **total** | 28 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel A/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | a holds |  |
| Rel B/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | b holds |  |
| Rel C/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | c holds |  |
| Rel D/0 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | d holds |  |
| prescriptive statement ps1 | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | ps1 |  |
| constitutive statement cs2 | statement | encoded | ConstitutiveStatement -> an LE rule | cs2 |  |
| constitutive statement cs_a-b_and_c | statement | encoded | ConstitutiveStatement -> an LE rule | cs_a_b_and_c_1 |  |
| constitutive statement cs_a-b_and_c | statement | encoded | ConstitutiveStatement -> an LE rule | cs_a_b_and_c_2 |  |
| constitutive statement cs_a-b | statement | encoded | ConstitutiveStatement -> an LE rule | cs_a_b |  |
| constitutive statement cs_a-c | statement | encoded | ConstitutiveStatement -> an LE rule | cs_a_c |  |
| constitutive statement cs_d-b_and_c | statement | encoded | ConstitutiveStatement -> an LE rule | cs_d_b_and_c_1 |  |
| constitutive statement cs_d-b_and_c | statement | encoded | ConstitutiveStatement -> an LE rule | cs_d_b_and_c_2 |  |
| constitutive statement cs_d-b | statement | encoded | ConstitutiveStatement -> an LE rule | cs_d_b |  |
| constitutive statement cs_d-c | statement | encoded | ConstitutiveStatement -> an LE rule | cs_d_c |  |
| source ref1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref1 |  |
| source ref2 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref2 |  |
| source ref8 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref8 |  |
| source ls3 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ls3 |  |
| Alternatives alt1 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt1 |  |
| Alternatives alt2 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt2 |  |
| Alternatives alt3 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt3 |  |
| Alternatives alt4 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt4 |  |
| source ls1 of cs_a-b_and_c | source | approximated | an Association names a source the document does not list: no provenance | cs_a-b_and_c |  |
| source ls1 of cs_a-b | source | approximated | an Association names a source the document does not list: no provenance | cs_a-b |  |
| source ls1 of cs_a-c | source | approximated | an Association names a source the document does not list: no provenance | cs_a-c |  |
| source ls2 of cs_d-b_and_c | source | approximated | an Association names a source the document does not list: no provenance | cs_d-b_and_c |  |
| source ls2 of cs_d-b | source | approximated | an Association names a source the document does not list: no provenance | cs_d-b |  |
| source ls2 of cs_d-c | source | approximated | an Association names a source the document does not list: no provenance | cs_d-c |  |

