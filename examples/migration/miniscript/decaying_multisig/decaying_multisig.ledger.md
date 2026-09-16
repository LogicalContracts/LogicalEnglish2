# Migration ledger: decaying_multisig

Source: A 3-of-3 multisig that turns into a 2-of-3 after 90 days — https://bitcoin.sipa.be/miniscript/
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 1 |
| residue | 0 |
| **total** | 7 |

Fidelity: **33 of 33** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(key_1) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 1 |  |
| pk(key_2) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 2 |  |
| pk(key_3) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 3 |  |
| thresh(3,pk(key_1),pk(key_2),pk(key_3),older(12960)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | decaying_threshold |  |
| older(12960) | timelock | encoded | older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction) | the delay of 12960 blocks |  |
| thresh(3,pk(key_1),pk(key_2),pk(key_3),older(12960)) | threshold | encoded | thresh(k, conditions) -> the count of the named conditions that are met is at least k | a count aggregate |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| decaying_threshold_1 | spendable | pass |  |
| decaying_threshold_1_without_1 | spendable | pass |  |
| decaying_threshold_1_without_2 | spendable | pass |  |
| decaying_threshold_1_without_3 | spendable | pass |  |
| decaying_threshold_2 | spendable | pass |  |
| decaying_threshold_2_without_1 | spendable | pass |  |
| decaying_threshold_2_without_2 | spendable | pass |  |
| decaying_threshold_2_without_3 | spendable | pass |  |
| decaying_threshold_3 | spendable | pass |  |
| decaying_threshold_3_without_1 | spendable | pass |  |
| decaying_threshold_3_without_2 | spendable | pass |  |
| decaying_threshold_3_without_3 | spendable | pass |  |
| decaying_threshold_4 | spendable | pass |  |
| decaying_threshold_4_without_1 | spendable | pass |  |
| decaying_threshold_4_without_2 | spendable | pass |  |
| decaying_threshold_4_without_3 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_key_1 | spendable | pass |  |
| lost_key_2 | spendable | pass |  |
| lost_key_3 | spendable | pass |  |
| chain_decaying_threshold_1 | spendable | pass |  |
| chain_decaying_threshold_1_without_1 | spendable | pass |  |
| chain_decaying_threshold_1_without_2 | spendable | pass |  |
| chain_decaying_threshold_2 | spendable | pass |  |
| chain_decaying_threshold_2_without_1 | spendable | pass |  |
| chain_decaying_threshold_3 | spendable | pass |  |
| chain_decaying_threshold_4 | spendable | pass |  |
| chain_no_witness | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_key_1 | flip_block | pass |  |
| lost_key_2 | flip_block | pass |  |
| lost_key_3 | flip_block | pass |  |

