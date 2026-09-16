# Migration ledger: cosigning_service

Source: A user and a co-signing service, the user alone after 90 days — https://bitcoin.sipa.be/miniscript/
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 1 |
| residue | 0 |
| **total** | 6 |

Fidelity: **16 of 16** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(key_user) | key | encoded | pk(key) -> the witness contains a signature by <role> | the user |  |
| pk(key_service) | key | encoded | pk(key) -> the witness contains a signature by <role> | the cosigning service |  |
| and(pk(key_user),or(pk(key_service),older(12960))) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | user_and_service |  |
| older(12960) | timelock | encoded | older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction) | the delay of 12960 blocks |  |
| 99@ | fragment | encoded | a branch probability: guides the compiler, no effect on who can spend | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| path_1 | spendable | pass |  |
| path_1_without_1 | spendable | pass |  |
| path_1_without_2 | spendable | pass |  |
| path_2 | spendable | pass |  |
| path_2_without_1 | spendable | pass |  |
| path_2_without_2 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_the_user | spendable | pass |  |
| lost_the_cosigning_service | spendable | pass |  |
| chain_path_1 | spendable | pass |  |
| chain_path_1_without_1 | spendable | pass |  |
| chain_path_2 | spendable | pass |  |
| chain_path_2_without_2 | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_the_cosigning_service | flip_block | pass |  |

