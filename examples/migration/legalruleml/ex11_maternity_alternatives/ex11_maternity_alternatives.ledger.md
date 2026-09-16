# Migration ledger: ex11_maternity_alternatives

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex11-maternity_alternatives-normal.lrml
Translator: InsurLE2/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 2 |
| residue | 0 |
| **total** | 12 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel earned/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *an income* is earned in *a year* |  |
| Rel paybenefit/2 | relation | encoded | Rel -> a template (the reviewer's wording) | the maternity benefit is *an amount* in *a year* |  |
| Rel reported/2 | relation | encoded | Rel -> a template (the reviewer's wording) | *an income* is reported in *a year* |  |
| prescriptive statement literal | statement | encoded | PrescriptiveStatement -> rules concluding obligations, permissions or prohibitions (deontic.le) | literal |  |
| constitutive statement tax1 | statement | encoded | ConstitutiveStatement -> an LE rule | tax1 |  |
| constitutive statement tax2 | statement | encoded | ConstitutiveStatement -> an LE rule | tax2 |  |
| source ref1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref1 |  |
| source ref2 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref2 |  |
| source ex-ref1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ex-ref1 |  |
| Alternatives maternity-alts | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | maternity-alts |  |
| Fun 80_percent_of_five-twelfths_of | function | approximated | a function the document names but does not define -> a relation between its arguments and its value, for the scenarios to state | 80_percent_of_five-twelfths_of |  |
| deontic(obligation,none,true) | deontic | approximated | a deontic element with no content: nothing to conclude |  |  |

