# Migration ledger: halving_decay

Source: A 4-of-4 that decays to 3, 2 and 1 of 4 at each of the next halvings — https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 13 |
| approximated | 1 |
| residue | 0 |
| **total** | 14 |

Fidelity: **92 of 92** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk([7258e4f9/44h/1h/0h]tpubDCZrkQoEU3845aFKUu9VQBYWZtrTwxMzcxnBwKFCYXHD6gEXvtFcxddCCLFsEwmxQaG15izcHxj48SXg1QS5FQGMBx5Ak6deXKPAL7wauBU/<0;1>/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 1 |  |
| pk([c80b1469/44h/1h/0h]tpubDD3UwwHoNUF4F3Vi5PiUVTc3ji1uThuRfFyBexTSHoAcHuWW2z8qEE2YujegcLtgthr3wMp3ZauvNG9eT9xfJyxXCfNty8h6rDBYU8UU1qq/<0;1>/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 2 |  |
| pk([4e5024fe/44h/1h/0h]tpubDDLrpPymPLSCJyCMLQdmcWxrAWwsqqssm5NdxT2WSdEBPSXNXxwbeKtsHAyXPpLkhUyKovtZgCi47QxVpw9iVkg95UUgeevyAqtJ9dqBqa1/<0;1>/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 3 |  |
| pk([3b1d1ee9/44h/1h/0h]tpubDCmDTANBWPzf6d8Ap1J5Ku7J1Ay92MpHMrEV7M5muWxCrTBN1g5f1NPcjMEL6dJHxbvEKNZtYCdowaSTN81DAyLsmv6w6xjJHCQNkxrsrfu/<0;1>/*) | key | encoded | pk(key) -> the witness contains a signature by <role> | key 4 |  |
| thresh(4,pk([7258e4f9/44h/1h/0h]tpubDCZrkQoEU3845aFKUu9VQBYWZtrTwxMzcxnBwKFCYXHD6gEXvtFcxddCCLFsEwmxQaG15izcHxj48SXg1QS5FQGMBx5Ak6deXKPAL7wauBU/<0;1>/*),pk([c80b1469/44h/1h/0h]tpubDD3UwwHoNUF4F3Vi5PiUVTc3ji1uThuRfFyBexTSHoAcHuWW2z8qEE2YujegcLtgthr3wMp3ZauvNG9eT9xfJyxXCfNty8h6rDBYU8UU1qq/<0;1>/*),pk([4e5024fe/44h/1h/0h]tpubDDLrpPymPLSCJyCMLQdmcWxrAWwsqqssm5NdxT2WSdEBPSXNXxwbeKtsHAyXPpLkhUyKovtZgCi47QxVpw9iVkg95UUgeevyAqtJ9dqBqa1/<0;1>/*),pk([3b1d1ee9/44h/1h/0h]tpubDCmDTANBWPzf6d8Ap1J5Ku7J1Ay92MpHMrEV7M5muWxCrTBN1g5f1NPcjMEL6dJHxbvEKNZtYCdowaSTN81DAyLsmv6w6xjJHCQNkxrsrfu/<0;1>/*),after(840000),after(1050000),after(1260000)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | decaying_threshold |  |
| after(840000) | timelock | encoded | after(t) -> the lock time L is a block height and L >= t (lib/temporal) | the lock time 840000 |  |
| after(1050000) | timelock | encoded | after(t) -> the lock time L is a block height and L >= t (lib/temporal) | the lock time 1050000 |  |
| after(1260000) | timelock | encoded | after(t) -> the lock time L is a block height and L >= t (lib/temporal) | the lock time 1260000 |  |
| thresh(4,pk([7258e4f9/44h/1h/0h]tpubDCZrkQoEU3845aFKUu9VQBYWZtrTwxMzcxnBwKFCYXHD6gEXvtFcxddCCLFsEwmxQaG15izcHxj48SXg1QS5FQGMBx5Ak6deXKPAL7wauBU/<0;1>/*),pk([c80b1469/44h/1h/0h]tpubDD3UwwHoNUF4F3Vi5PiUVTc3ji1uThuRfFyBexTSHoAcHuWW2z8qEE2YujegcLtgthr3wMp3ZauvNG9eT9xfJyxXCfNty8h6rDBYU8UU1qq/<0;1>/*),pk([4e5024fe/44h/1h/0h]tpubDDLrpPymPLSCJyCMLQdmcWxrAWwsqqssm5NdxT2WSdEBPSXNXxwbeKtsHAyXPpLkhUyKovtZgCi47QxVpw9iVkg95UUgeevyAqtJ9dqBqa1/<0;1>/*),pk([3b1d1ee9/44h/1h/0h]tpubDCmDTANBWPzf6d8Ap1J5Ku7J1Ay92MpHMrEV7M5muWxCrTBN1g5f1NPcjMEL6dJHxbvEKNZtYCdowaSTN81DAyLsmv6w6xjJHCQNkxrsrfu/<0;1>/*),after(840000),after(1050000),after(1260000)) | threshold | encoded | thresh(k, conditions) -> the count of the named conditions that are met is at least k | a count aggregate |  |
| l: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| n: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| s: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| wsh | fragment | encoded | the P2WSH wrapper: no effect on the policy | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| path_1 | spendable | pass |  |
| path_1_without_1 | spendable | pass |  |
| path_1_without_2 | spendable | pass |  |
| path_1_without_3 | spendable | pass |  |
| path_1_without_4 | spendable | pass |  |
| path_2 | spendable | pass |  |
| path_2_without_1 | spendable | pass |  |
| path_2_without_2 | spendable | pass |  |
| path_2_without_3 | spendable | pass |  |
| path_2_without_4 | spendable | pass |  |
| path_3 | spendable | pass |  |
| path_3_without_1 | spendable | pass |  |
| path_3_without_2 | spendable | pass |  |
| path_3_without_3 | spendable | pass |  |
| path_3_without_4 | spendable | pass |  |
| path_4 | spendable | pass |  |
| path_4_without_1 | spendable | pass |  |
| path_4_without_2 | spendable | pass |  |
| path_4_without_3 | spendable | pass |  |
| path_4_without_4 | spendable | pass |  |
| path_5 | spendable | pass |  |
| path_5_without_1 | spendable | pass |  |
| path_5_without_2 | spendable | pass |  |
| path_5_without_3 | spendable | pass |  |
| path_5_without_4 | spendable | pass |  |
| path_6 | spendable | pass |  |
| path_6_without_1 | spendable | pass |  |
| path_6_without_2 | spendable | pass |  |
| path_6_without_3 | spendable | pass |  |
| path_6_without_4 | spendable | pass |  |
| path_7 | spendable | pass |  |
| path_7_without_1 | spendable | pass |  |
| path_7_without_2 | spendable | pass |  |
| path_7_without_3 | spendable | pass |  |
| path_7_without_4 | spendable | pass |  |
| path_8 | spendable | pass |  |
| path_8_without_1 | spendable | pass |  |
| path_8_without_2 | spendable | pass |  |
| path_8_without_3 | spendable | pass |  |
| path_8_without_4 | spendable | pass |  |
| path_9 | spendable | pass |  |
| path_9_without_1 | spendable | pass |  |
| path_9_without_2 | spendable | pass |  |
| path_9_without_3 | spendable | pass |  |
| path_9_without_4 | spendable | pass |  |
| path_10 | spendable | pass |  |
| path_10_without_1 | spendable | pass |  |
| path_10_without_2 | spendable | pass |  |
| path_10_without_3 | spendable | pass |  |
| path_10_without_4 | spendable | pass |  |
| path_11 | spendable | pass |  |
| path_11_without_1 | spendable | pass |  |
| path_11_without_2 | spendable | pass |  |
| path_11_without_3 | spendable | pass |  |
| path_11_without_4 | spendable | pass |  |
| path_12 | spendable | pass |  |
| path_12_without_1 | spendable | pass |  |
| path_12_without_2 | spendable | pass |  |
| path_12_without_3 | spendable | pass |  |
| path_12_without_4 | spendable | pass |  |
| path_13 | spendable | pass |  |
| path_13_without_1 | spendable | pass |  |
| path_13_without_2 | spendable | pass |  |
| path_13_without_3 | spendable | pass |  |
| path_13_without_4 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_key_1 | spendable | pass |  |
| lost_key_2 | spendable | pass |  |
| lost_key_3 | spendable | pass |  |
| lost_key_4 | spendable | pass |  |
| chain_path_1 | spendable | pass |  |
| chain_path_1_without_1 | spendable | pass |  |
| chain_path_2 | spendable | pass |  |
| chain_path_3 | spendable | pass |  |
| chain_path_4 | spendable | pass |  |
| chain_path_4_without_1 | spendable | pass |  |
| chain_path_4_without_2 | spendable | pass |  |
| chain_path_7 | spendable | pass |  |
| chain_path_7_without_2 | spendable | pass |  |
| chain_path_7_without_3 | spendable | pass |  |
| chain_path_9 | spendable | pass |  |
| chain_path_10 | spendable | pass |  |
| chain_path_11 | spendable | pass |  |
| chain_path_11_without_1 | spendable | pass |  |
| chain_path_12 | spendable | pass |  |
| chain_path_13 | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_key_1 | flip_block | pass |  |
| lost_key_2 | flip_block | pass |  |
| lost_key_3 | flip_block | pass |  |
| lost_key_4 | flip_block | pass |  |

