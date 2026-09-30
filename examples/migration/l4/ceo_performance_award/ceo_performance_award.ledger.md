# Migration ledger: ceo_performance_award

Source: an L4 program (smucclaw/l4-ide) — ceo-performance-award.l4
Translator: lpsPlus/migration/l4 (l4_twin.pl)
Date: 2026-09-29
Source licence: Apache-2.0, Singapore Management University

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 102 |
| approximated | 47 |
| residue | 7 |
| **total** | 156 |

Fidelity: **15 of 15** source test expectation(s) reproduced (100%).

**7 further expectation(s) are pending** (waits for residue r1): they are written as comments in their scenarios, and are not counted above. Each is restored when what it waits for is done.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| Tesla Performance Metrics | record | encoded | a type of individuals, one template per field | Tesla Performance Metrics |  |
| Service Status | choice | encoded | named individuals | Service Status |  |
| Termination Reason | choice | encoded | named individuals | Termination Reason |  |
| Covered Event Type | choice | encoded | named individuals | Covered Event Type |  |
| CEO Award State | record | encoded | a type of individuals, one template per field | CEO Award State |  |
| Vesting Category | choice | encoded | named individuals | Vesting Category |  |
| Tranche Status | record | encoded | a type of individuals, one template per field | Tranche Status |  |
| Award Participant | record | encoded | a type of individuals, one template per field | Award Participant |  |
| Award Action | choice | encoded | named individuals | Award Action |  |
| Required Market Cap For Tranche | wording | approximated | the template's words made from the name, its inputs appended | the required market cap for tranche for *a tranche number* is *a number* | to be reviewed: the name does not say where its inputs go |
| Market Cap Milestone Met | wording | approximated | the template's words made from the name, its inputs appended | market cap milestone met given *a tranche number* with *a metrics* | to be reviewed: the name does not say where its inputs go |
| Market Cap Milestone Met For Change In Control | wording | approximated | the template's words made from the name, its inputs appended | market cap milestone met for change in control for *a tranche number* with *a metrics* | to be reviewed: the name does not say where its inputs go |
| Operational Milestone Met | wording | approximated | the template's words made from the name, its inputs appended | operational milestone met for *a tranche number* with *a metrics* | to be reviewed: the name does not say where its inputs go |
| EBITDA Milestone Met | wording | approximated | the template's words made from the name, its inputs appended | EBITDA milestone met for *a tranche number* with *a metrics* | to be reviewed: the name does not say where its inputs go |
| Deemed Achievement Applies | wording | approximated | the template's words made from the name, its inputs appended | deemed achievement applies for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| Covered Event Affects Product Goals | wording | approximated | the template's words made from the name, its inputs appended | covered event affects product goals for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| All Market Cap Averages Met | wording | approximated | the template's words made from the name, its inputs appended | all market cap averages met for *a tranche number* with *a metrics* | to be reviewed: the name does not say where its inputs go |
| Tranche Can Be Earned | wording | approximated | the template's words made from the name, its inputs appended | tranche can be earned for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| Musk In Eligible Service | wording | approximated | the template's words made from the name, its inputs appended | musk in eligible service for *an award state* | to be reviewed: the name does not say where its inputs go |
| CEO Succession Framework Required Met | wording | approximated | the template's words made from the name, its inputs appended | CEO succession framework required met for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| Tranche Already Earned | wording | approximated | the template's words made from the name, its inputs appended | tranche already earned for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| Operational Milestone Already Used | wording | approximated | the template's words made from the name, its inputs appended | operational milestone already used for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| Product Goal Already Used | wording | approximated | the template's words made from the name, its inputs appended | product goal already used for *a tranche number* with *an award state* | to be reviewed: the name does not say where its inputs go |
| Issuance Conditions Met | wording | approximated | the template's words made from the name, its inputs appended | issuance conditions met for *an award state* | to be reviewed: the name does not say where its inputs go |
| Determine Vesting Category | wording | approximated | the template's words made from the name, its inputs appended | the determine vesting category for *an earn date* is *a vesting category* | to be reviewed: the name does not say where its inputs go |
| Determine Vesting Date | wording | approximated | the template's words made from the name, its inputs appended | the determine vesting date for *a vesting category* is *a date* | to be reviewed: the name does not say where its inputs go |
| Tranche Is Vested | wording | approximated | the template's words made from the name, its inputs appended | tranche is vested for *a tranche number* with *a current date* with *an earn date* | to be reviewed: the name does not say where its inputs go |
| Immediate Vesting Applies | wording | approximated | the template's words made from the name, its inputs appended | immediate vesting applies for *an award state* | to be reviewed: the name does not say where its inputs go |
| Forfeiture Applies | wording | approximated | the template's words made from the name, its inputs appended | forfeiture applies for *an award state* | to be reviewed: the name does not say where its inputs go |
| Offset Amount For Tranche | wording | approximated | the template's words made from the name, its inputs appended | the offset amount for tranche for *a tranche number* is *a number* | to be reviewed: the name does not say where its inputs go |
| Holding Period Met | wording | approximated | the template's words made from the name, its inputs appended | holding period met for *an earn date* with *a current date* | to be reviewed: the name does not say where its inputs go |
| Tranche Is Earned | wording | approximated | the template's words made from the name, its inputs appended | *a tranche* is earned for *an award state* | to be reviewed: the name does not say where its inputs go |
| Get Earn Date For Tranche | wording | approximated | the template's words made from the name, its inputs appended | the get earn date for *a tranche* for *an award state* is *a date* | to be reviewed: the name does not say where its inputs go |
| Get Index Of Tranche | wording | approximated | the template's words made from the name, its inputs appended | the get *an index* of *a tranche* for *a tranche list* is *a number* | to be reviewed: the name does not say where its inputs go |
| Get Date At Index | wording | approximated | the template's words made from the name, its inputs appended | the get date at *an index* for *a date list* is *a date* | to be reviewed: the name does not say where its inputs go |
| Million | wording | approximated | the template's words made from the name, its inputs appended | the million for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| Billion | wording | approximated | the template's words made from the name, its inputs appended | the billion for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| Trillion | wording | approximated | the template's words made from the name, its inputs appended | the trillion for *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| years after | wording | approximated | the template's words made from the name, its inputs appended | the years after for *a number* with *a date* is *a second date* | to be reviewed: the name does not say where its inputs go |
| Number In List | wording | approximated | the template's words made from the name, its inputs appended | number in *a list* for *an item* | to be reviewed: the name does not say where its inputs go |
| Any Earned Tranche Uses Same Product Goal | wording | approximated | the template's words made from the name, its inputs appended | any earned tranche uses same product goal for *a tranche number* with *an earned tranches* | to be reviewed: the name does not say where its inputs go |
| Product Goals Are Same | wording | approximated | the template's words made from the name, its inputs appended | product goals are same for *a tranche1* with *a tranche2* | to be reviewed: the name does not say where its inputs go |
| Forfeiture Reason | wording | approximated | the template's words made from the name, its inputs appended | the forfeiture reason for *an award state* is *a text* | to be reviewed: the name does not say where its inputs go |
| Immediate Vesting Reason | wording | approximated | the template's words made from the name, its inputs appended | the immediate vesting reason for *an award state* is *a text* | to be reviewed: the name does not say where its inputs go |
| Grant Date | definition | encoded | func | the grant date is *a value* |  |
| Performance Period Years | definition | encoded | func | the performance period years is *a number* |  |
| Performance End Date | definition | encoded | func | the performance end date is *a value* |  |
| Reference Stock Price | definition | encoded | func | the reference stock price is *a number* |  |
| Total Award Shares | definition | encoded | func | the total award shares is *a number* |  |
| Shares Per Tranche | definition | encoded | func | the shares per tranche is *a number* |  |
| Number Of Tranches | definition | encoded | func | the number of tranches is *a number* |  |
| Third Anniversary | definition | encoded | func | the third anniversary is *a value* |  |
| Fifth Anniversary | definition | encoded | func | the fifth anniversary is *a value* |  |
| Seventh And Half Anniversary | definition | encoded | func | the seventh as well as half anniversary is *a value* |  |
| Acquisition Threshold | definition | encoded | func | the acquisition threshold is *a value* |  |
| EBITDA Threshold | definition | encoded | func | the EBITDA threshold is *a value* |  |
| Required Market Cap For Tranche | definition | encoded | func | the required market cap for tranche for *a tranche number* is *a number* |  |
| Required Market Cap | wording | approximated | the template's words made from the name, its inputs appended | the required market cap given *a tranche number* is *a number* | to be reviewed: the name does not say where its inputs go |
| Required Market Cap | definition | encoded | func | the required market cap given *a tranche number* is *a number* |  |
| Market Cap Milestone Met | definition | encoded | pred | market cap milestone met given *a tranche number* with *a metrics* |  |
| Required Market Cap | wording | approximated | the template's words made from the name, its inputs appended | the required market cap in market cap milestone met for change in control for *a tranche number* is *a number* | to be reviewed: the name does not say where its inputs go |
| Change In Control Market Cap | wording | approximated | the template's words made from the name, its inputs appended | the change in control market cap for *a metrics* is *a number* | to be reviewed: the name does not say where its inputs go |
| Higher Price | wording | approximated | the template's words made from the name, its inputs appended | the higher price for *a metrics* is *a value* | to be reviewed: the name does not say where its inputs go |
| Required Market Cap | definition | encoded | func | the required market cap in market cap milestone met for change in control for *a tranche number* is *a number* |  |
| Change In Control Market Cap | definition | encoded | func | the change in control market cap for *a metrics* is *a number* |  |
| Higher Price | definition | encoded | func | the higher price for *a metrics* is *a value* |  |
| Market Cap Milestone Met For Change In Control | definition | encoded | pred | market cap milestone met for change in control for *a tranche number* with *a metrics* |  |
| Operational Milestone Met | definition | encoded | pred | operational milestone met for *a tranche number* with *a metrics* |  |
| EBITDA Milestone Met | definition | encoded | pred | EBITDA milestone met for *a tranche number* with *a metrics* |  |
| Deemed Achievement Applies | definition | encoded | pred | deemed achievement applies for *a tranche number* with *an award state* |  |
| Covered Event Affects Product Goals | definition | encoded | pred | covered event affects product goals for *a tranche number* with *an award state* |  |
| Required Market Cap | wording | approximated | the template's words made from the name, its inputs appended | the required market cap in all market cap averages met for *a tranche number* is *a number* | to be reviewed: the name does not say where its inputs go |
| Required Market Cap | definition | encoded | func | the required market cap in all market cap averages met for *a tranche number* is *a number* |  |
| All Market Cap Averages Met | definition | encoded | pred | all market cap averages met for *a tranche number* with *a metrics* |  |
| Tranche Can Be Earned | definition | encoded | pred | tranche can be earned for *a tranche number* with *an award state* |  |
| Musk In Eligible Service | definition | encoded | pred | musk in eligible service for *an award state* |  |
| CEO Succession Framework Required Met | definition | encoded | pred | CEO succession framework required met for *a tranche number* with *an award state* |  |
| Tranche Already Earned | definition | encoded | pred | tranche already earned for *a tranche number* with *an award state* |  |
| Operational Milestone Already Used | definition | encoded | pred | operational milestone already used for *a tranche number* with *an award state* |  |
| Product Goal Already Used | definition | encoded | pred | product goal already used for *a tranche number* with *an award state* |  |
| Issuance Conditions Met | definition | encoded | pred | issuance conditions met for *an award state* |  |
| Determine Vesting Category | definition | encoded | func | the determine vesting category for *an earn date* is *a vesting category* |  |
| Determine Vesting Date | definition | encoded | func | the determine vesting date for *a vesting category* is *a date* |  |
| vesting category | wording | approximated | the template's words made from the name, its inputs appended | the vesting category for *an earn date* is *a vesting category* | to be reviewed: the name does not say where its inputs go |
| vesting date | wording | approximated | the template's words made from the name, its inputs appended | the vesting date for *an earn date* is *a date* | to be reviewed: the name does not say where its inputs go |
| vesting category | definition | encoded | func | the vesting category for *an earn date* is *a vesting category* |  |
| vesting date | definition | encoded | func | the vesting date for *an earn date* is *a date* |  |
| Tranche Is Vested | definition | encoded | pred | tranche is vested for *a tranche number* with *a current date* with *an earn date* |  |
| Immediate Vesting Applies | definition | encoded | pred | immediate vesting applies for *an award state* |  |
| Forfeiture Applies | definition | encoded | pred | forfeiture applies for *an award state* |  |
| Offset Amount For Tranche | definition | encoded | func | the offset amount for tranche for *a tranche number* is *a number* |  |
| holding period end | wording | approximated | the template's words made from the name, its inputs appended | the holding period end for *an earn date* is *a date* | to be reviewed: the name does not say where its inputs go |
| holding period end | definition | encoded | func | the holding period end for *an earn date* is *a date* |  |
| Holding Period Met | definition | encoded | pred | holding period met for *an earn date* with *a current date* |  |
| Elon Musk | record | encoded | an individual with one fact per field | elon_musk |  |
| Eligible Service Requirement | contract | residue | the contracts half (step 3) | Eligible Service Requirement |  |
| Milestone Achievement Requirement | contract | residue | the contracts half (step 3) | Milestone Achievement Requirement |  |
| Vesting Requirement | contract | residue | the contracts half (step 3) | Vesting Requirement |  |
| Tranche Is Earned | definition | encoded | pred | *a tranche* is earned for *an award state* |  |
| Get Earn Date For Tranche | definition | encoded | func | the get earn date for *a tranche* for *an award state* is *a date* |  |
| Get Index Of Tranche | definition | encoded | func | the get *an index* of *a tranche* for *a tranche list* is *a number* |  |
| Get Date At Index | definition | encoded | func | the get date at *an index* for *a date list* is *a date* |  |
| Million | definition | encoded | func | the million for *a number* is *a second number* |  |
| Billion | definition | encoded | func | the billion for *a number* is *a second number* |  |
| Trillion | definition | encoded | func | the trillion for *a number* is *a second number* |  |
| newYear | wording | approximated | the template's words made from the name, its inputs appended | the new year for *a date* with *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| fractionalDays | wording | approximated | the template's words made from the name, its inputs appended | the fractional days for *a date* with *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| newDay | wording | approximated | the template's words made from the name, its inputs appended | the new day for *a date* with *a number* is *a second number* | to be reviewed: the name does not say where its inputs go |
| newMonth | wording | approximated | the template's words made from the name, its inputs appended | the new month for *a date* is *a value* | to be reviewed: the name does not say where its inputs go |
| newYear | definition | encoded | func | the new year for *a date* with *a number* is *a second number* |  |
| fractionalDays | definition | residue | a value with no LE form | r1 |  |
| newDay | definition | encoded | func | the new day for *a date* with *a number* is *a second number* |  |
| newMonth | definition | encoded | func | the new month for *a date* is *a value* |  |
| years after | definition | encoded | func | the years after for *a number* with *a date* is *a second date* |  |
| Number In List | definition | encoded | pred | number in *a list* for *an item* |  |
| Any Earned Tranche Uses Same Product Goal | definition | encoded | pred | any earned tranche uses same product goal for *a tranche number* with *an earned tranches* |  |
| Product Goals Are Same | definition | encoded | pred | product goals are same for *a tranche1* with *a tranche2* |  |
| Forfeiture Reason | definition | encoded | func | the forfeiture reason for *an award state* is *a text* |  |
| Immediate Vesting Reason | definition | encoded | func | the immediate vesting reason for *an award state* is *a text* |  |
| Example Metrics High Performance | record | encoded | an individual with one fact per field | example_metrics_high_performance |  |
| Example Metrics Medium Performance | record | encoded | an individual with one fact per field | example_metrics_medium_performance |  |
| Example Metrics Low Performance | record | encoded | an individual with one fact per field | example_metrics_low_performance |  |
| Example Award State Active | record | encoded | an individual with one fact per field | example_award_state_active |  |
| Example Award State Terminated | record | encoded | an individual with one fact per field | example_award_state_terminated |  |
| Example Award State Change In Control | record | encoded | an individual with one fact per field | example_award_state_change_in_control |  |
| Example Award State Medium Performance | record | encoded | an individual with one fact per field | example_award_state_medium_performance |  |
| Example Award State Low Performance | record | encoded | an individual with one fact per field | example_award_state_low_performance |  |
| Example Award State With Earned Tranche | record | encoded | an individual with one fact per field | example_award_state_with_earned_tranche |  |
| #EVAL at line 665 | test | encoded | a query and the evaluator's answer | line_665 |  |
| #EVAL at line 666 | test | encoded | a query and the evaluator's answer | line_666 |  |
| #EVAL at line 667 | test | encoded | a query and the evaluator's answer | line_667 |  |
| #EVAL at line 668 | test | encoded | a query and the evaluator's answer | line_668 |  |
| #EVAL at line 669 | test | encoded | a query and the evaluator's answer | line_669 |  |
| #eval at line 672 | test | residue | a value that is not a constant: `Fifth Anniversary` |  |  |
| #eval at line 673 | test | residue | a value that is not a constant: `Performance End Date` |  |  |
| #EVAL at line 676 | test | encoded | a query and the evaluator's answer | line_676 |  |
| #EVAL at line 677 | test | encoded | a query and the evaluator's answer | line_677 |  |
| #EVAL at line 678 | test | encoded | a query and the evaluator's answer | line_678 |  |
| #EVAL at line 679 | test | encoded | a query and the evaluator's answer | line_679 |  |
| #EVAL at line 680 | test | encoded | a query and the evaluator's answer | line_680 |  |
| #EVAL at line 683 | test | encoded | a query and the evaluator's answer | line_683 |  |
| #EVAL at line 684 | test | encoded | a query and the evaluator's answer | line_684 |  |
| #EVAL at line 685 | test | encoded | a query and the evaluator's answer | line_685 |  |
| #EVAL at line 686 | test | encoded | a query and the evaluator's answer | line_686 |  |
| #EVAL at line 687 | test | encoded | a query and the evaluator's answer | line_687 |  |
| #EVAL at line 690 | test | encoded | a query and the evaluator's answer | line_690 |  |
| #EVAL at line 691 | test | encoded | a query and the evaluator's answer | line_691 |  |
| #EVAL at line 692 | test | encoded | a query and the evaluator's answer | line_692 |  |
| #EVAL at line 693 | test | encoded | a query and the evaluator's answer | line_693 |  |
| #EVAL at line 694 | test | encoded | a query and the evaluator's answer | line_694 |  |
| #EVAL at line 697 | test | encoded | a query and the evaluator's answer | line_697 |  |
| #EVAL at line 698 | test | encoded | a query and the evaluator's answer | line_698 |  |
| #eval at line 699 | test | residue | a value that is not a constant: `Grant Date` |  |  |
| Eligible Service Requirement | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Eligible Service Requirement |  |
| Milestone Achievement Requirement | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Milestone Achievement Requirement |  |
| Vesting Requirement | contract | encoded | a contract -> LE for LPS (LPS2) and a history view (step 3) | Vesting Requirement |  |

## Residue

- **Eligible Service Requirement** (contract) — the contracts half (step 3); in the program: Eligible Service Requirement. 
- **Milestone Achievement Requirement** (contract) — the contracts half (step 3); in the program: Milestone Achievement Requirement. 
- **Vesting Requirement** (contract) — the contracts half (step 3); in the program: Vesting Requirement. 
- **fractionalDays** (definition) — a value with no LE form; in the program: r1. 
- **#eval at line 672** (test) — a value that is not a constant: `Fifth Anniversary`; in the program: . 
- **#eval at line 673** (test) — a value that is not a constant: `Performance End Date`; in the program: . 
- **#eval at line 699** (test) — a value that is not a constant: `Grant Date`; in the program: . 

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| line_665 | line_665 | pass |  |
| line_666 | line_666 | pass |  |
| line_667 | line_667 | pass |  |
| line_668 | line_668 | pass |  |
| line_669 | line_669 | pass |  |
| line_678 | line_678 | pass |  |
| line_679 | line_679 | pass |  |
| line_680 | line_680 | pass |  |
| line_685 | line_685 | pass |  |
| line_686 | line_686 | pass |  |
| line_687 | line_687 | pass |  |
| line_692 | line_692 | pass |  |
| line_693 | line_693 | pass |  |
| line_694 | line_694 | pass |  |
| line_697 | line_697 | pass |  |

