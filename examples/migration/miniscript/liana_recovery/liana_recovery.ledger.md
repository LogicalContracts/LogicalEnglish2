# Migration ledger: liana_recovery

Source: A Liana wallet: a primary key, or a recovery key after a delay — https://github.com/wizardsardine/liana/blob/master/doc/RECOVER.md
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 10 |
| approximated | 1 |
| residue | 0 |
| **total** | 11 |

Fidelity: **15 of 15** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk([a5c6b76e/48'/1'/0'/2']tpubDF5861hj6vR3iJr3aPjGJz4rNbqDCRujQ21mczzKT5SiedaQqNVgHC8HT9ceyxvMFRoPMx4P6HAcL3NZrUPhRUbwCyj3TKSa64bAfnE3sLh/<0;1>/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | the primary key |  |
| pk([c477fd13/48'/1'/0'/2']tpubDFn7iPbFqGrTQ2aRACNsUK1MXQR4Z6dYfU2nD1WA9ifSaia642j3Wah4n5pBUEpERNWGJsyv3Dv5qwBabC9TLQrwSboKzukw9wmurGu7XVH/<0;1>/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | the recovery key |  |
| pk([a5c6b76e/48'/1'/0'/2']tpubDF5861hj6vR3iJr3aPjGJz4rNbqDCRujQ21mczzKT5SiedaQqNVgHC8HT9ceyxvMFRoPMx4P6HAcL3NZrUPhRUbwCyj3TKSa64bAfnE3sLh/<0;1>/*) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | primary |  |
| and(pk([c477fd13/48'/1'/0'/2']tpubDFn7iPbFqGrTQ2aRACNsUK1MXQR4Z6dYfU2nD1WA9ifSaia642j3Wah4n5pBUEpERNWGJsyv3Dv5qwBabC9TLQrwSboKzukw9wmurGu7XVH/<0;1>/*),older(3)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | recovery |  |
| older(3) | timelock | encoded | older(n) -> the coin has been confirmed for N blocks and N >= n (N from the blocks of the coin and of the spending transaction) | the delay of 3 blocks |  |
| and_v | fragment | encoded | X and Y (BIP 379) -> and | the rules |  |
| or_d | fragment | encoded | X or Z (BIP 379) -> or | the rules |  |
| pkh | fragment | encoded | a key check -> a signature | the rules |  |
| v: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| wsh | fragment | encoded | the P2WSH wrapper: no effect on the policy | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| recovery | spendable | pass |  |
| recovery_without_1 | spendable | pass |  |
| recovery_without_2 | spendable | pass |  |
| primary | spendable | pass |  |
| primary_without_1 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_the_primary_key | spendable | pass |  |
| lost_the_recovery_key | spendable | pass |  |
| chain_recovery | spendable | pass |  |
| chain_recovery_without_1 | spendable | pass |  |
| chain_primary | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_the_primary_key | flip_block | pass |  |
| lost_the_recovery_key | flip_block | pass |  |

