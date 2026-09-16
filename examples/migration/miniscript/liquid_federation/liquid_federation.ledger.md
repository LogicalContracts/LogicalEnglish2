# Migration ledger: liquid_federation

Source: A Liquid-like federated peg-in: five functionaries, or two of three emergency keys after about 90 days — https://github.com/bitcoin/bitcoin/blob/master/test/functional/wallet_miniscript.py
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 1 |
| residue | 0 |
| **total** | 21 |

Fidelity: **34 of 34** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(02aebf2d10b040eb936a6f02f44ee82f8b34f5c1ccb20ff3949c2b28206b7c1068) | key | encoded | pk(key) -> the witness contains a signature by <role> | functionary 1 |  |
| pk(030f64b922aee2fd597f104bc6cb3b670f1ca2c6c49b1071a1a6c010575d94fe5a) | key | encoded | pk(key) -> the witness contains a signature by <role> | functionary 2 |  |
| pk(02abe475b199ec3d62fa576faee16a334fdb86ffb26dce75becebaaedf328ac3fe) | key | encoded | pk(key) -> the witness contains a signature by <role> | functionary 3 |  |
| pk(0314f3dc33595b0d016bb522f6fe3a67680723d842c1b9b8ae6b59fdd8ab5cccb4) | key | encoded | pk(key) -> the witness contains a signature by <role> | functionary 4 |  |
| pk(025eba3305bd3c829e4e1551aac7358e4178832c739e4fc4729effe428de0398ab) | key | encoded | pk(key) -> the witness contains a signature by <role> | functionary 5 |  |
| pk(tpubD6NzVbkrYhZ4YPAbyf6urxqqnmJF79PzQtyERAmvkSVS9fweCTjxjDh22Z5St9fGb1a5DUCv8G27nYupKP1Ctr1pkamJossoetzws1moNRn/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | emergency key 1 |  |
| pk(029ffbe722b147f3035c87cb1c60b9a5947dd49c774cc31e94773478711a929ac0) | key | encoded | pk(key) -> the witness contains a signature by <role> | emergency key 2 |  |
| pk(0211c7b2e18b6fd330f322de087da62da92ae2ae3d0b7cec7e616479cce175f183) | key | encoded | pk(key) -> the witness contains a signature by <role> | emergency key 3 |  |
| and(pk(02aebf2d10b040eb936a6f02f44ee82f8b34f5c1ccb20ff3949c2b28206b7c1068),and(pk(030f64b922aee2fd597f104bc6cb3b670f1ca2c6c49b1071a1a6c010575d94fe5a),and(pk(02abe475b199ec3d62fa576faee16a334fdb86ffb26dce75becebaaedf328ac3fe),and(pk(0314f3dc33595b0d016bb522f6fe3a67680723d842c1b9b8ae6b59fdd8ab5cccb4),pk(025eba3305bd3c829e4e1551aac7358e4178832c739e4fc4729effe428de0398ab))))) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | federation |  |
| and(thresh(2,pk(tpubD6NzVbkrYhZ4YPAbyf6urxqqnmJF79PzQtyERAmvkSVS9fweCTjxjDh22Z5St9fGb1a5DUCv8G27nYupKP1Ctr1pkamJossoetzws1moNRn/*),pk(029ffbe722b147f3035c87cb1c60b9a5947dd49c774cc31e94773478711a929ac0),pk(0211c7b2e18b6fd330f322de087da62da92ae2ae3d0b7cec7e616479cce175f183)),older(4209713)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | emergency |  |
| older(4209713) | timelock | encoded | older(n) with the BIP 68 time flag -> the coin has been confirmed for N seconds and N >= 512 x (n and 0xffff) | the delay of 7889408 seconds |  |
| thresh(2,pk(tpubD6NzVbkrYhZ4YPAbyf6urxqqnmJF79PzQtyERAmvkSVS9fweCTjxjDh22Z5St9fGb1a5DUCv8G27nYupKP1Ctr1pkamJossoetzws1moNRn/*),pk(029ffbe722b147f3035c87cb1c60b9a5947dd49c774cc31e94773478711a929ac0),pk(0211c7b2e18b6fd330f322de087da62da92ae2ae3d0b7cec7e616479cce175f183)) | threshold | encoded | thresh(k, keys) -> the count of the keys in the list that signed is at least k | a count aggregate |  |
| a: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| and_b | fragment | encoded | X and Y (BIP 379) -> and | the rules |  |
| and_v | fragment | encoded | X and Y (BIP 379) -> and | the rules |  |
| or_i | fragment | encoded | X or Z (BIP 379) -> or | the rules |  |
| pkh | fragment | encoded | a key check -> a signature | the rules |  |
| s: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| v: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| wsh | fragment | encoded | the P2WSH wrapper: no effect on the policy | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| emergency_1 | spendable | pass |  |
| emergency_1_without_1 | spendable | pass |  |
| emergency_1_without_2 | spendable | pass |  |
| emergency_1_without_3 | spendable | pass |  |
| emergency_2 | spendable | pass |  |
| emergency_2_without_1 | spendable | pass |  |
| emergency_2_without_2 | spendable | pass |  |
| emergency_2_without_3 | spendable | pass |  |
| emergency_3 | spendable | pass |  |
| emergency_3_without_1 | spendable | pass |  |
| emergency_3_without_2 | spendable | pass |  |
| emergency_3_without_3 | spendable | pass |  |
| federation | spendable | pass |  |
| federation_without_1 | spendable | pass |  |
| federation_without_2 | spendable | pass |  |
| federation_without_3 | spendable | pass |  |
| federation_without_4 | spendable | pass |  |
| federation_without_5 | spendable | pass |  |
| no_witness | spendable | pass |  |
| chain_emergency_1 | spendable | pass |  |
| chain_emergency_1_without_1 | spendable | pass |  |
| chain_emergency_1_without_2 | spendable | pass |  |
| chain_emergency_2 | spendable | pass |  |
| chain_emergency_2_without_1 | spendable | pass |  |
| chain_emergency_3 | spendable | pass |  |
| chain_federation | spendable | pass |  |
| chain_federation_without_1 | spendable | pass |  |
| chain_federation_without_2 | spendable | pass |  |
| chain_federation_without_3 | spendable | pass |  |
| chain_federation_without_4 | spendable | pass |  |
| chain_federation_without_5 | spendable | pass |  |
| chain_no_witness | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |

