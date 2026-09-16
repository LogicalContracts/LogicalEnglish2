# Migration ledger: ex10_mix

Source: a LegalRuleML document (OASIS LegalRuleML Core 1.0) — ex10-mix-normal.lrml
Translator: InsurLE2/migration/legalruleml (lrml_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 7 |
| residue | 20 |
| **total** | 40 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Rel rel2/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel2 |  |
| Rel rel3/1 | relation | approximated | Rel -> a template (a naive wording of its name, to be improved) | *a thing* is a rel3 |  |
| defeater ps2 | defeater | encoded | a defeater -> an exception (it is not the case that ...) of the rules it attacks | ps2 |  |
| Reparation rep1 (pen1 for ps1) | reparation | encoded | Reparation -> the penalty's chain of obligations on the violation | rep1 |  |
| source ref1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref1 |  |
| source ref6 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref6 |  |
| source ls1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ls1 |  |
| source ref2 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ref2 |  |
| source pen1-v1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | pen1-v1 |  |
| source ps2-v1 | source | encoded | LegalSource -> a document; the rules it is associated with cite it (with provenance) | ps2-v1 |  |
| temporal tblock1 | temporal | encoded | TemporalCharacteristics -> a period of the relevant date (Starts / Ends) | tblock1 |  |
| Alternatives alt1 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt1 |  |
| Alternatives alt1 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt1 |  |
| Alternatives alt3 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt3 |  |
| Alternatives alt4 | alternatives | encoded | Alternatives -> each alternative's rules hold when it is the interpretation adopted | alt4 |  |
| an Atom with no Rel | atom | residue | an Atom with no relation (a keyref the document does not resolve) |  |  |
| statement ps1 | statement | residue | a statement the translator could not read (an atom with no relation, a keyref to nothing): left out | ps1 |  |
| Violation of ps1 | violation | approximated | a Violation of a statement the document does not contain -> `the statement ... is violated`, a fact for the scenarios | ps1 |  |
| Reparation rep1 | reparation | residue | a Reparation whose penalty or statement is missing: dropped | rep1 |  |
| Reparation rep1 | reparation | approximated | a Reparation with nothing to conclude | rep1 |  |
| Override cs2 over cs1 | override | residue | an Override naming a rule the document does not contain: dropped | cs2 |  |
| association_1 -> obl101 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | obl101 |  |
| association_2 -> rule1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1 |  |
| association_3 -> rule2 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule2 |  |
| association_4 -> rule1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1 |  |
| association_4 -> rule2 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule2 |  |
| association_5 -> rule2 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule2 |  |
| association_5 -> rule3 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule3 |  |
| association_6 -> rule1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1 |  |
| association_6 -> rule2 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule2 |  |
| association_7 -> rule1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1 |  |
| association_8 -> nev1 | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | nev1 |  |
| association_8 -> nev2 | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | nev2 |  |
| association_9 -> rule1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1 |  |
| association_9 -> atom1 | context | approximated | an Association or Context of an element inside a rule (an atom, a deontic formula): LE cites sources per rule, so it is not carried | atom1 |  |
| association_9 -> body1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | body1 |  |
| association_11 -> ps3 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | ps3 |  |
| ruleContext1 -> stmt1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | stmt1 |  |
| ruleInfo4 -> rule1 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule1 |  |
| ruleInfo4 -> rule4 | context | residue | an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing | rule4 |  |

## Residue

- **an Atom with no Rel** (atom) — an Atom with no relation (a keyref the document does not resolve); in the program: . 
- **statement ps1** (statement) — a statement the translator could not read (an atom with no relation, a keyref to nothing): left out; in the program: ps1. 
- **Reparation rep1** (reparation) — a Reparation whose penalty or statement is missing: dropped; in the program: rep1. 
- **Override cs2 over cs1** (override) — an Override naming a rule the document does not contain: dropped; in the program: cs2. 
- **association_1 -> obl101** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: obl101. 
- **association_2 -> rule1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1. 
- **association_3 -> rule2** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule2. 
- **association_4 -> rule1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1. 
- **association_4 -> rule2** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule2. 
- **association_5 -> rule2** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule2. 
- **association_5 -> rule3** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule3. 
- **association_6 -> rule1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1. 
- **association_6 -> rule2** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule2. 
- **association_7 -> rule1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1. 
- **association_9 -> rule1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1. 
- **association_9 -> body1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: body1. 
- **association_11 -> ps3** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: ps3. 
- **ruleContext1 -> stmt1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: stmt1. 
- **ruleInfo4 -> rule1** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule1. 
- **ruleInfo4 -> rule4** (context) — an Association or Context targets a key the document does not define: its properties (source, strength, period) apply to nothing; in the program: rule4. 

