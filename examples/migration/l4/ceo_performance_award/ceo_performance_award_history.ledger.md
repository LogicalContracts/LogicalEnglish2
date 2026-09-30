# Migration ledger: ceo_performance_award_history

Source: an L4 file (smucclaw/l4-ide) — ceo-performance-award.l4
Translator: the L4 translator
Date: 2026-09-30

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 0 |
| approximated | 0 |
| residue | 10 |
| **total** | 10 |

Fidelity: 0 source test(s) translated to scenarios; not run.

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| contract Eligible Service Requirement | contract | residue | outside what the translator covers: "a function applied to fewer or more inputs than it takes" | Eligible Service Requirement |  |
| contract Milestone Achievement Requirement | contract | residue | outside what the translator covers: field_of_unknown('Six Month Avg Market Cap') | Milestone Achievement Requirement |  |
| contract Vesting Requirement | contract | residue | outside what the translator covers: pcons(papp(head,[]),papp(tail,[])) | Vesting Requirement |  |
| #TRACE (`Eligible Service Requirement` OF `Example Award State Active`) (line 702) | trace | residue | not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes" | trace_702 |  |
| #TRACE (`Milestone Achievement Requirement` OF 1, `Example Award State Active`) (line 705) | trace | residue | not translated: outside what the translator covers: field_of_unknown('Six Month Avg Market Cap') | trace_705 |  |
| #TRACE (`Milestone Achievement Requirement` OF 1, `Example Award State Medium Performance`) (line 710) | trace | residue | not translated: outside what the translator covers: field_of_unknown('Six Month Avg Market Cap') | trace_710 |  |
| #TRACE (`Milestone Achievement Requirement` OF 1, `Example Award State Low Performance`) (line 714) | trace | residue | not translated: outside what the translator covers: field_of_unknown('Six Month Avg Market Cap') | trace_714 |  |
| #TRACE (`Vesting Requirement` OF 1, `Example Award State With Earned Tranche`) (line 731) | trace | residue | not translated: outside what the translator covers: pcons(papp(head,[]),papp(tail,[])) | trace_731 |  |
| #TRACE (`Eligible Service Requirement` OF `Example Award State Terminated`) (line 736) | trace | residue | not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes" | trace_736 |  |
| #TRACE (`Eligible Service Requirement` OF `Example Award State Change In Control`) (line 739) | trace | residue | not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes" | trace_739 |  |

## Residue

- **contract Eligible Service Requirement** (contract) — outside what the translator covers: "a function applied to fewer or more inputs than it takes"; in the program: Eligible Service Requirement. 
- **contract Milestone Achievement Requirement** (contract) — outside what the translator covers: field_of_unknown('Six Month Avg Market Cap'); in the program: Milestone Achievement Requirement. 
- **contract Vesting Requirement** (contract) — outside what the translator covers: pcons(papp(head,[]),papp(tail,[])); in the program: Vesting Requirement. 
- **#TRACE (`Eligible Service Requirement` OF `Example Award State Active`) (line 702)** (trace) — not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes"; in the program: trace_702. 
- **#TRACE (`Milestone Achievement Requirement` OF 1, `Example Award State Active`) (line 705)** (trace) — not translated: outside what the translator covers: field_of_unknown('Six Month Avg Market Cap'); in the program: trace_705. 
- **#TRACE (`Milestone Achievement Requirement` OF 1, `Example Award State Medium Performance`) (line 710)** (trace) — not translated: outside what the translator covers: field_of_unknown('Six Month Avg Market Cap'); in the program: trace_710. 
- **#TRACE (`Milestone Achievement Requirement` OF 1, `Example Award State Low Performance`) (line 714)** (trace) — not translated: outside what the translator covers: field_of_unknown('Six Month Avg Market Cap'); in the program: trace_714. 
- **#TRACE (`Vesting Requirement` OF 1, `Example Award State With Earned Tranche`) (line 731)** (trace) — not translated: outside what the translator covers: pcons(papp(head,[]),papp(tail,[])); in the program: trace_731. 
- **#TRACE (`Eligible Service Requirement` OF `Example Award State Terminated`) (line 736)** (trace) — not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes"; in the program: trace_736. 
- **#TRACE (`Eligible Service Requirement` OF `Example Award State Change In Control`) (line 739)** (trace) — not translated: outside what the translator covers: "a function applied to fewer or more inputs than it takes"; in the program: trace_739. 

