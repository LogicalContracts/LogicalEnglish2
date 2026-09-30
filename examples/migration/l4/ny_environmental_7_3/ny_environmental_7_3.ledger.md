# Migration ledger: ny_environmental_7_3

Source: an L4 program (smucclaw/l4-ide) — ny-environmental-7.3.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 30 |
| approximated | 5 |
| residue | 5 |
| **total** | 40 |

Fidelity: **1 of 1** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Commission | record | encoded | a type of individuals, one template per field | Commission |  |
| Newspaper | record | encoded | a type of individuals, one template per field | Newspaper |  |
| Notice | record | encoded | a type of individuals, one template per field | Notice |  |
| Applicant | record | encoded | a type of individuals, one template per field | Applicant |  |
| File draft copy of EIS and cause notice of hearing to be published | record | encoded | a type of individuals, one template per field | File draft copy of EIS and cause notice of hearing to be published |  |
| Action that may have a significant adverse effect on the environment | record | encoded | a type of individuals, one template per field | Action that may have a significant adverse effect on the environment |  |
| Environmental Impact Statement | record | encoded | a type of individuals, one template per field | Environmental Impact Statement |  |
| Proceeding Record | record | encoded | a type of individuals, one template per field | Proceeding Record |  |
| Tentative or recommended decision | record | encoded | a type of individuals, one template per field | Tentative or recommended decision |  |
| Final EIS Issuance Extension Cause | choice | encoded | named individuals | Final EIS Issuance Extension Cause |  |
| Final EIS Issuance | choice | encoded | named individuals | Final EIS Issuance |  |
| Render decision on whether or not to approve action | record | encoded | a type of individuals, one template per field | Render decision on whether or not to approve action |  |
| Tentative or recommended decision will contain a final EIS | wording | approximated | the template's words made from the name, its inputs appended | tentative else recommended decision will contain a final EIS for *a decision* | to be reviewed: the name does not say where its inputs go |
| Determining issuance for final EIS | wording | approximated | the template's words made from the name, its inputs appended | the determining issuance for final EIS for *a decision* with *a cause for extension* is *a final EIS issuance* | to be reviewed: the name does not say where its inputs go |
| Determining days till issuance for final EIS | wording | approximated | the template's words made from the name, its inputs appended | the determining days till issuance for final EIS for *a decision* with *a cause for extension* with *a days of extension* is *a number* | to be reviewed: the name does not say where its inputs go |
| Notice of no significant adverse effect on the environment determination will be filed in accordance with 6 NYCRR 617.10 | wording | approximated | the template's words made from the name, its inputs appended | notice of no significant adverse effect on the environment determination will be filed in accordance with 6 NYCRR 617 10 for *a decision* | to be reviewed: the name does not say where its inputs go |
| Filing of draft copy of EIS and causing notice of hearing to be published | contract | residue | the contracts half (step 3) | Filing of draft copy of EIS and causing notice of hearing to be published |  |
| Example Commission | record | encoded | an individual with one fact per field | example_commission |  |
| Example EIS | record | encoded | an individual with one fact per field | example_eis |  |
| Example Action | record | encoded | an individual with one fact per field | example_action |  |
| Example Filing | definition | residue | a value with no LE form | r1 |  |
| Example Newspaper | record | encoded | an individual with one fact per field | example_newspaper |  |
| Example Hearing Notice | record | encoded | an individual with one fact per field | example_hearing_notice |  |
| Example Notice of EIS Completion | record | encoded | an individual with one fact per field | example_notice_of_eis_completion |  |
| Tentative or recommended decision will contain a final EIS | definition | encoded | pred | tentative else recommended decision will contain a final EIS for *a decision* |  |
| Example Proceeding Record | record | encoded | an individual with one fact per field | example_proceeding_record |  |
| Example Decision | record | encoded | an individual with one fact per field | example_decision |  |
| Determining issuance for final EIS | definition | encoded | func | the determining issuance for final EIS for *a decision* with *a cause for extension* is *a final EIS issuance* |  |
| Closing date | wording | approximated | the template's words made from the name, its inputs appended | the closing date for *a decision* is *a number* | to be reviewed: the name does not say where its inputs go |
| Closing date | definition | encoded | func | the closing date for *a decision* is *a number* |  |
| Determining days till issuance for final EIS | definition | encoded | func | the determining days till issuance for final EIS for *a decision* with *a cause for extension* with *a days of extension* is *a number* |  |
| Notice of no significant adverse effect on the environment determination will be filed in accordance with 6 NYCRR 617.10 | definition | encoded | pred | notice of no significant adverse effect on the environment determination will be filed in accordance with 6 NYCRR 617 10 for *a decision* |  |
| Copies of the decision (together with a notice of its completion) will be filed in accordance with 6 NYCRR 617.10. | definition | encoded | pred | copies of *a decision* together with a notice of its completion will be filed in accordance with 6 NYCRR 617 10 |  |
| Rendering of the decision on whether or not to approve action proposed by applicant | contract | residue | the contracts half (step 3) | Rendering of the decision on whether or not to approve action proposed by applicant |  |
| Never | definition | encoded | func | the never is *a number* |  |
| #eval at line 117 | test | residue | the evaluator's answer is not a value LE writes: PARTY `The commission` MUST `File draft copy of EIS and cause notice of hearing to be published` `Hearing Notice`                                                                            `Notice of EIS Completion`                                                                            `Prepared draft copy of EIS` PROVIDED (`Hearing Notice`'s `Scheduled date`) AT LEAST ((`Hearing Notice`'s `Publish date`) PLUS 14) AND (`Hearing Notice`'s `Scheduled date`) AT MOST ((`Hearing Notice`'s `Publish date`) PLUS 60) AND CONSIDER `Prepared draft copy of EIS` WHEN NOTHING THEN FALSE, WHEN JUST EIS THEN (`Hearing Notice`'s `Scheduled date`) AT LEAST ((EIS's `Draft filing date`) PLUS 15) AND (`Hearing Notice`'s `Scheduled date`) AT MOST ((EIS's `Draft filing date`) PLUS 60) AND ((`Hearing Notice`'s `Publishing medium`)'s `General circulation area`) EQUALS (`The action`'s `Potential effect area`) AND `Hearing Notice`'s `Is in accordance with the requirements of 6 NYCRR 617.10` AND `Notice of EIS Completion`'s `Is in accordance with the requirements of 6 NYCRR 617.10` WITHIN Day OF (`the week after` OF (March OF 2, 2028)) HENCE FULFILLED |  |  |
| #EVAL at line 160 | test | encoded | a query and the evaluator's answer | line_160 |  |
| #eval at line 205 | test | residue | a value that is not a constant: `NOTHING` |  |  |
| Filing of draft copy of EIS and causing notice of hearing to be published | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Filing of draft copy of EIS and causing notice of hearing to be published |  |
| Rendering of the decision on whether or not to approve action proposed by applicant | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Rendering of the decision on whether or not to approve action proposed by applicant |  |

## Residue

- **Filing of draft copy of EIS and causing notice of hearing to be published** (contract) — the contracts half (step 3); in the program: Filing of draft copy of EIS and causing notice of hearing to be published. 
- **Example Filing** (definition) — a value with no LE form; in the program: r1. 
- **Rendering of the decision on whether or not to approve action proposed by applicant** (contract) — the contracts half (step 3); in the program: Rendering of the decision on whether or not to approve action proposed by applicant. 
- **#eval at line 117** (test) — the evaluator's answer is not a value LE writes: PARTY `The commission` MUST `File draft copy of EIS and cause notice of hearing to be published` `Hearing Notice`                                                                            `Notice of EIS Completion`                                                                            `Prepared draft copy of EIS` PROVIDED (`Hearing Notice`'s `Scheduled date`) AT LEAST ((`Hearing Notice`'s `Publish date`) PLUS 14) AND (`Hearing Notice`'s `Scheduled date`) AT MOST ((`Hearing Notice`'s `Publish date`) PLUS 60) AND CONSIDER `Prepared draft copy of EIS` WHEN NOTHING THEN FALSE, WHEN JUST EIS THEN (`Hearing Notice`'s `Scheduled date`) AT LEAST ((EIS's `Draft filing date`) PLUS 15) AND (`Hearing Notice`'s `Scheduled date`) AT MOST ((EIS's `Draft filing date`) PLUS 60) AND ((`Hearing Notice`'s `Publishing medium`)'s `General circulation area`) EQUALS (`The action`'s `Potential effect area`) AND `Hearing Notice`'s `Is in accordance with the requirements of 6 NYCRR 617.10` AND `Notice of EIS Completion`'s `Is in accordance with the requirements of 6 NYCRR 617.10` WITHIN Day OF (`the week after` OF (March OF 2, 2028)) HENCE FULFILLED; in the program: . 
- **#eval at line 205** (test) — a value that is not a constant: `NOTHING`; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_160 | line_160 | pass |  |

