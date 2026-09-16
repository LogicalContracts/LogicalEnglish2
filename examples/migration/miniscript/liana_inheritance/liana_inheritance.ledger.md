# Migration ledger: liana_inheritance

Source: A Liana inheritance wallet: the wallet manager, or two of the family after a year, or a third party after fifteen months — https://github.com/wizardsardine/liana#about
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 5 |
| residue | 0 |
| **total** | 14 |

Fidelity: **39 of 39** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(manager) | key | encoded | pk(key) -> the witness contains a signature by <role> | the wallet manager |  |
| pk(spouse) | key | encoded | pk(key) -> the witness contains a signature by <role> | the spouse |  |
| pk(first_child) | key | encoded | pk(key) -> the witness contains a signature by <role> | the elder child |  |
| pk(second_child) | key | encoded | pk(key) -> the witness contains a signature by <role> | the younger child |  |
| pk(third_party) | key | encoded | pk(key) -> the witness contains a signature by <role> | the third party | the README says: a third party (after 1 year and 3 months); taken as 65535 blocks, the longest relative lock BIP 68 allows (about 455 days: one day short of 1 year and 3 months at 144 blocks a day; 65664 blocks, the literal reading, is not a relative lock — consensus would read it as 128 blocks) |
| pk(manager) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | manager |  |
| and(thresh(2,pk(spouse),pk(first_child),pk(second_child)),older(52560)) | spending path | approximated | a branch of the top-level or -> a rule concluding the coin can be spent | family | the README says: any 2 keys from the owner's spouse and two kids (after 1 year); the policy is our reading of that sentence, the year taken as 52560 blocks (144 a day) |
| and(pk(third_party),older(65535)) | spending path | approximated | a branch of the top-level or -> a rule concluding the coin can be spent | third_party | the README says: a third party (after 1 year and 3 months); taken as 65535 blocks, the longest relative lock BIP 68 allows (about 455 days: one day short of 1 year and 3 months at 144 blocks a day; 65664 blocks, the literal reading, is not a relative lock — consensus would read it as 128 blocks) |
| older(52560) | timelock | approximated | older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction) | the delay of 52560 blocks | 1 year at 144 blocks a day: the network's average, not a calendar year |
| older(65535) | timelock | approximated | older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction) | the delay of 65535 blocks | the longest relative lock in blocks (BIP 68), about 455 days |
| thresh(2,pk(spouse),pk(first_child),pk(second_child)) | threshold | encoded | thresh(k, keys) -> the count of the keys in the list that signed is at least k | a count aggregate |  |
| 99@ | fragment | encoded | a branch probability: guides the compiler, no effect on who can spend | the rules |  |
| 9@ | fragment | encoded | a branch probability: guides the compiler, no effect on who can spend | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| family_1 | spendable | pass |  |
| family_1_without_1 | spendable | pass |  |
| family_1_without_2 | spendable | pass |  |
| family_1_without_3 | spendable | pass |  |
| family_2 | spendable | pass |  |
| family_2_without_1 | spendable | pass |  |
| family_2_without_2 | spendable | pass |  |
| family_2_without_3 | spendable | pass |  |
| family_3 | spendable | pass |  |
| family_3_without_1 | spendable | pass |  |
| family_3_without_2 | spendable | pass |  |
| family_3_without_3 | spendable | pass |  |
| third_party | spendable | pass |  |
| third_party_without_1 | spendable | pass |  |
| third_party_without_2 | spendable | pass |  |
| manager | spendable | pass |  |
| manager_without_1 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_the_wallet_manager | spendable | pass |  |
| lost_the_spouse | spendable | pass |  |
| lost_the_elder_child | spendable | pass |  |
| lost_the_younger_child | spendable | pass |  |
| lost_the_third_party | spendable | pass |  |
| chain_family_1 | spendable | pass |  |
| chain_family_1_without_1 | spendable | pass |  |
| chain_family_1_without_2 | spendable | pass |  |
| chain_family_2 | spendable | pass |  |
| chain_family_2_without_1 | spendable | pass |  |
| chain_family_3 | spendable | pass |  |
| chain_third_party | spendable | pass |  |
| chain_third_party_without_1 | spendable | pass |  |
| chain_manager | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_the_wallet_manager | flip_block | pass |  |
| lost_the_spouse | flip_block | pass |  |
| lost_the_elder_child | flip_block | pass |  |
| lost_the_younger_child | flip_block | pass |  |
| lost_the_third_party | flip_block | pass |  |

