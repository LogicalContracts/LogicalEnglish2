# Migration ledger: hash_threshold

Source: Two of a signature, a SHA-256 preimage and a HASH160 preimage — https://github.com/bitcoin/bitcoin/blob/master/src/test/miniscript_tests.cpp
Translator: InsurLE2/migration/miniscript (ms_twin.pl)
Date: 2026-09-16

## Summary

| Verdict | Source elements |
|---|---|
| encoded | 9 |
| approximated | 1 |
| residue | 0 |
| **total** | 10 |

Fidelity: **14 of 14** source test expectation(s) reproduced (100%).

A source element is **encoded** when a documented mapping rule translated it with its meaning unchanged, **approximated** when the mapping changes its meaning in a documented way (see the note), and **residue** when it was not translated: it is marked in the program (`% RESIDUE <id> BEGIN ... END`) for the LE Contract Assistant or a person.

## Source elements

| Source element | Kind | Verdict | Mapping | In the program | Note |
|---|---|---|---|---|---|
| pk(025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc) | key | encoded | pk(key) -> the witness contains a signature by <role> | the key holder |  |
| sha256(e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f) | hash | encoded | hash lock -> the witness reveals the preimage of <name> | the payment secret |  |
| hash160(dd69735817e0e3f6f826a9238dc2e291184f0131) | hash | encoded | hash lock -> the witness reveals the preimage of <name> | the release secret |  |
| thresh(2,pk(025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc),sha256(e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f),hash160(dd69735817e0e3f6f826a9238dc2e291184f0131)) | spending path | encoded | a branch of the top-level or -> a rule concluding the coin can be spent | two_of_three |  |
| thresh(2,pk(025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc),sha256(e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f),hash160(dd69735817e0e3f6f826a9238dc2e291184f0131)) | threshold | encoded | thresh(k, conditions) -> the count of the named conditions that are met is at least k | a count aggregate |  |
| a: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| c: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| pk_h | fragment | encoded | a key check -> a signature | the rules |  |
| s: | fragment | encoded | a wrapper: no effect on the policy (BIP 379) | the rules |  |
| the Script encoding | script | approximated | the twin is the spending policy (BIP 379, the semantics column), not the Script | the whole program | witness sizes, fees, malleability and the choice of fragments (or_d / or_i, wrappers) do not change who can spend, and are not in the twin |

## Source tests

| Source test | Query | Result | Detail |
|---|---|---|---|
| two_of_three_1 | spendable | pass |  |
| two_of_three_1_without_1 | spendable | pass |  |
| two_of_three_1_without_2 | spendable | pass |  |
| two_of_three_2 | spendable | pass |  |
| two_of_three_2_without_1 | spendable | pass |  |
| two_of_three_2_without_2 | spendable | pass |  |
| two_of_three_3 | spendable | pass |  |
| two_of_three_3_without_1 | spendable | pass |  |
| two_of_three_3_without_2 | spendable | pass |  |
| no_witness | spendable | pass |  |
| lost_the_key_holder | spendable | pass |  |
| flip_now | flip_spend | pass |  |
| flip_after_delays | flip_spend | pass |  |
| lost_the_key_holder | flip_block | pass |  |

