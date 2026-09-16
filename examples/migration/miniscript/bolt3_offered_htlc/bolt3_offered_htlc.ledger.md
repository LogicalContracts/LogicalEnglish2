# Migration ledger: bolt3_offered_htlc

Source: A Lightning offered HTLC (BOLT #3) — https://bitcoin.sipa.be/miniscript/
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 6 |
| approximated | 1 |
| residue | 0 |
| **total** | 7 |

Fidelity: **24 of 24** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(key_revocation) | key | encoded | pk(key) -> the witness contains a signature by <role> | the revocation key |  |
| pk(key_remote) | key | encoded | pk(key) -> the witness contains a signature by <role> | the remote node |  |
| pk(key_local) | key | encoded | pk(key) -> the witness contains a signature by <role> | the local node |  |
| hash160(H) | hash | encoded | hash lock -> the witness reveals the preimage of <name> | the payment hash |  |
| pk(key_revocation) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | revocation |  |
| and(pk(key_remote),or(pk(key_local),hash160(H))) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | remote_with_local_or_preimage |  |
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
| path_3 | spendable | pass |  |
| path_3_without_1 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_the_revocation_key | spendable | pass |  |
| lost_the_remote_node | spendable | pass |  |
| lost_the_local_node | spendable | pass |  |
| chain_path_1 | spendable | pass |  |
| chain_path_1_without_1 | spendable | pass |  |
| chain_path_1_without_2 | spendable | pass |  |
| chain_path_2 | spendable | pass |  |
| chain_path_2_without_2 | spendable | pass |  |
| chain_path_3 | spendable | pass |  |
| chain_path_3_without_1 | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_the_revocation_key | flip_block | pass |  |
| lost_the_remote_node | flip_block | pass |  |
| lost_the_local_node | flip_block | pass |  |

