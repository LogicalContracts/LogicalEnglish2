# Migration ledger: core_2of3_multisig

Source: A 2-of-3 multisig (P2WSH) — https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-15

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 7 |
| approximated | 1 |
| residue | 0 |
| **total** | 8 |

Fidelity: **25 of 25** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigner A |  |
| pk(03774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigner B |  |
| pk(03d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a) | key | encoded | pk(key) -> the witness contains a signature by <role> | cosigner C |  |
| thresh(2,pk(03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7),pk(03774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb),pk(03d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | two_of_three |  |
| thresh(2,pk(03a0434d9e47f3c86235477c7b1ae6ae5d3442d49b1943c2b752a68e2a47e247c7),pk(03774ae7f858a9411e5ef4246b70c65aac5649980be5c17891bbec17895da008cb),pk(03d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a)) | threshold | encoded | thresh(k, keys) -> the count of the keys in the list that signed is at least k | a count aggregate |  |
| multi | fragment | encoded | multi(k, keys) -> thresh(k) of the keys' signatures | the rules |  |
| wsh | fragment | encoded | the P2WSH wrapper: no effect on the policy | the rules |  |
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
| path_3_without_2 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_cosigner_A | spendable | pass |  |
| lost_cosigner_B | spendable | pass |  |
| lost_cosigner_C | spendable | pass |  |
| chain_path_1 | spendable | pass |  |
| chain_path_1_without_1 | spendable | pass |  |
| chain_path_1_without_2 | spendable | pass |  |
| chain_path_2 | spendable | pass |  |
| chain_path_2_without_1 | spendable | pass |  |
| chain_path_3 | spendable | pass |  |
| chain_no_witness | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_cosigner_A | flip_block | pass |  |
| lost_cosigner_B | flip_block | pass |  |
| lost_cosigner_C | flip_block | pass |  |

