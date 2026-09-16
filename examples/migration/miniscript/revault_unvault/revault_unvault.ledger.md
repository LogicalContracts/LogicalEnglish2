# Migration ledger: revault_unvault

Source: A Revault unvault output: the managers with the cosigning servers after a lock time, or all four stakeholders — https://github.com/bitcoin/bitcoin/blob/master/test/functional/wallet_miniscript.py
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 20 |
| approximated | 1 |
| residue | 0 |
| **total** | 21 |

Fidelity: **29 of 29** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(tpubD6NzVbkrYhZ4YPAbyf6urxqqnmJF79PzQtyERAmvkSVS9fweCTjxjDh22Z5St9fGb1a5DUCv8G27nYupKP1Ctr1pkamJossoetzws1moNRn/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | manager 1 |  |
| pk(tpubD6NzVbkrYhZ4YMQC15JS7QcrsAyfGrGiykweqMmPxTkEVScu7vCZLNpPXW1XphHwzsgmqdHWDQAfucbM72EEB1ZEyfgZxYvkZjYVXx1xS9p/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | manager 2 |  |
| pk(02aebf2d10b040eb936a6f02f44ee82f8b34f5c1ccb20ff3949c2b28206b7c1068) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigning server 1 |  |
| pk(030f64b922aee2fd597f104bc6cb3b670f1ca2c6c49b1071a1a6c010575d94fe5a) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigning server 2 |  |
| pk(02abe475b199ec3d62fa576faee16a334fdb86ffb26dce75becebaaedf328ac3fe) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigning server 3 |  |
| pk(0314f3dc33595b0d016bb522f6fe3a67680723d842c1b9b8ae6b59fdd8ab5cccb4) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigning server 4 |  |
| pk(tpubD6NzVbkrYhZ4YU9vM1s53UhD75UyJatx8EMzMZ3VUjR2FciNfLLkAw6a4pWACChzobTseNqdWk4G7ZdBqRDLtLSACKykTScmqibb1ZrCvJu/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | stakeholder 1 |  |
| pk(tpubD6NzVbkrYhZ4XRMcMFMMFvzVt6jaDAtjZhD7JLwdPdMm9xa76DnxYYP7w9TZGJDVFkek3ArwVsuacheqqPog8TH5iBCX1wuig8PLXim4n9a/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | stakeholder 2 |  |
| pk(tpubD6NzVbkrYhZ4WsqRzDmkL82SWcu42JzUvKWzrJHQ8EC2vEHRHkXj1De93sD3biLrKd8XGnamXURGjMbYavbszVDXpjXV2cGUERucLJkE6cy/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | stakeholder 3 |  |
| pk(tpubDEFLeBkKTm8aiYkySz8hXAXPVnPSfxMi7Fxhg9sejUrkwJuRWvPdLEiXjTDbhGbjLKCZUDUUibLxTnK5UP1q7qYrSnPqnNe7M8mvAW1STcc/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | stakeholder 4 |  |
| and(and(pk(tpubD6NzVbkrYhZ4YPAbyf6urxqqnmJF79PzQtyERAmvkSVS9fweCTjxjDh22Z5St9fGb1a5DUCv8G27nYupKP1Ctr1pkamJossoetzws1moNRn/*),pk(tpubD6NzVbkrYhZ4YMQC15JS7QcrsAyfGrGiykweqMmPxTkEVScu7vCZLNpPXW1XphHwzsgmqdHWDQAfucbM72EEB1ZEyfgZxYvkZjYVXx1xS9p/*)),and(and(and(and(pk(02aebf2d10b040eb936a6f02f44ee82f8b34f5c1ccb20ff3949c2b28206b7c1068),pk(030f64b922aee2fd597f104bc6cb3b670f1ca2c6c49b1071a1a6c010575d94fe5a)),pk(02abe475b199ec3d62fa576faee16a334fdb86ffb26dce75becebaaedf328ac3fe)),pk(0314f3dc33595b0d016bb522f6fe3a67680723d842c1b9b8ae6b59fdd8ab5cccb4)),after(424242))) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | managers |  |
| and(and(and(pk(tpubD6NzVbkrYhZ4YU9vM1s53UhD75UyJatx8EMzMZ3VUjR2FciNfLLkAw6a4pWACChzobTseNqdWk4G7ZdBqRDLtLSACKykTScmqibb1ZrCvJu/*),pk(tpubD6NzVbkrYhZ4XRMcMFMMFvzVt6jaDAtjZhD7JLwdPdMm9xa76DnxYYP7w9TZGJDVFkek3ArwVsuacheqqPog8TH5iBCX1wuig8PLXim4n9a/*)),pk(tpubD6NzVbkrYhZ4WsqRzDmkL82SWcu42JzUvKWzrJHQ8EC2vEHRHkXj1De93sD3biLrKd8XGnamXURGjMbYavbszVDXpjXV2cGUERucLJkE6cy/*)),pk(tpubDEFLeBkKTm8aiYkySz8hXAXPVnPSfxMi7Fxhg9sejUrkwJuRWvPdLEiXjTDbhGbjLKCZUDUUibLxTnK5UP1q7qYrSnPqnNe7M8mvAW1STcc/*)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | stakeholders |  |
| after(424242) | timelock | encoded | after(t) -> the lock time L is a block height and L >= t (lib/temporal) | the lock time 424242 |  |
| a: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| and_v | fragment | encoded | X and Y (BIP 379) -> and | the rules |  |
| andor | fragment | encoded | andor(X,Y,Z) = (X and Y) or Z -> or of two branches | the rules |  |
| multi | fragment | encoded | multi(k, keys) -> thresh(k) of the keys' signatures | the rules |  |
| pkh | fragment | encoded | a key check -> a signature | the rules |  |
| v: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| wsh | fragment | encoded | the P2WSH wrapper: no effect on the policy | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| managers | spendable | pass |  |
| managers_without_1 | spendable | pass |  |
| managers_without_2 | spendable | pass |  |
| managers_without_3 | spendable | pass |  |
| managers_without_4 | spendable | pass |  |
| managers_without_5 | spendable | pass |  |
| managers_without_6 | spendable | pass |  |
| managers_without_7 | spendable | pass |  |
| stakeholders | spendable | pass |  |
| stakeholders_without_1 | spendable | pass |  |
| stakeholders_without_2 | spendable | pass |  |
| stakeholders_without_3 | spendable | pass |  |
| stakeholders_without_4 | spendable | pass |  |
| no_witness | spendable | pass |  |
| chain_managers | spendable | pass |  |
| chain_managers_without_1 | spendable | pass |  |
| chain_managers_without_2 | spendable | pass |  |
| chain_managers_without_3 | spendable | pass |  |
| chain_managers_without_4 | spendable | pass |  |
| chain_managers_without_5 | spendable | pass |  |
| chain_managers_without_6 | spendable | pass |  |
| chain_stakeholders | spendable | pass |  |
| chain_stakeholders_without_1 | spendable | pass |  |
| chain_stakeholders_without_2 | spendable | pass |  |
| chain_stakeholders_without_3 | spendable | pass |  |
| chain_stakeholders_without_4 | spendable | pass |  |
| chain_no_witness | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |

