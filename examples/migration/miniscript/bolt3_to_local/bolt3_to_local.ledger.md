# Migration ledger: bolt3_to_local

Source: A Lightning to_local output (BOLT #3) — https://bitcoin.sipa.be/miniscript/
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 5 |
| approximated | 1 |
| residue | 0 |
| **total** | 6 |

Fidelity: **15 of 15** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(key_revocation) | key | encoded | pk(key) -> the witness contains a signature by <role> | the revocation key |  |
| pk(key_local) | key | encoded | pk(key) -> the witness contains a signature by <role> | the local node |  |
| pk(key_revocation) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | revocation |  |
| and(pk(key_local),older(1008)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | local_after_delay |  |
| older(1008) | timelock | encoded | older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction) | the delay of 1008 blocks |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| local_after_delay | spendable | pass |  |
| local_after_delay_without_1 | spendable | pass |  |
| local_after_delay_without_2 | spendable | pass |  |
| revocation | spendable | pass |  |
| revocation_without_1 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_the_revocation_key | spendable | pass |  |
| lost_the_local_node | spendable | pass |  |
| chain_local_after_delay | spendable | pass |  |
| chain_local_after_delay_without_1 | spendable | pass |  |
| chain_revocation | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_the_revocation_key | flip_block | pass |  |
| lost_the_local_node | flip_block | pass |  |

