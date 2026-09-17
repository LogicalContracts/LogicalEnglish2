# Bitcoin Miniscript and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Miniscript is a structured way of writing Bitcoin Script. It is specified in
BIP 379 and used by wallets such as Bitcoin Core and Liana. A *spending policy*
says who can spend a coin and when. It is written in the policy language
(`and(pk(key_user),or(pk(key_service),older(12960)))`), in Miniscript itself
(`and_v(v:pk(…),or_d(…))`), or inside an output descriptor (`wsh(…)`). The
integration works both ways. **File ▸ Open…** (or **File ▸ Import from Another
System…**) turns a file of policies into a Logical English program. The program
has one cited rule per spending path, the policy's own analysis as scenarios,
flip queries for lost keys, and a *custody explainer* view. **File ▸ Export to
Another System…** writes a program in that vocabulary back as a policy. You get
the Miniscript sipa's compiler makes of it, the descriptor when the program
states the keys, and a link that opens the policy in the Minsc playground. The
translators are part of the InsurLE extensions, so they are available only on
installations that have them, such as the hosted service. The example twins are
in every installation.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a policy file](#opening-a-policy-file)
  - [Reading the program](#reading-the-program)
  - [The custody explainer and the flips](#the-custody-explainer-and-the-flips)
  - [The example twins and their chain runs](#the-example-twins-and-their-chain-runs)
  - [Exporting a program as a policy](#exporting-a-program-as-a-policy)
  - [Writing a policy in Logical English](#writing-a-policy-in-logical-english)
- [How Miniscript maps to Logical English](#how-miniscript-maps-to-logical-english)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Miniscript → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.miniscript`, `.ms`, `.policy`, `.desc`, `.txt`: policies, Miniscript expressions or descriptors, one per line | one rule per spending path, each citing its line; the satisfaction analysis as scenarios; key-loss flips; a custody explainer view; a ledger | an independent evaluator of the policy (BIP 379's semantics), and for the twins a recorded run of every spending attempt on the Tape test network |
| Logical English → Miniscript | **File ▸ Export to Another System…** | writes `<program>.policy` | the policy, sipa's Miniscript, the descriptor when the keys are stated, a **Try it in Minsc** button | the round trip: every twin exports to its source's policy, and the exported file opens back into the same policy |

The LPS2 IDE's **File ▸ Open…** and **Misc ▸ Export to another system…** use
the same translators, when the Logical English installation beside it has them.

## How to use it

### Opening a policy file

1. Write the policies in a text file, one per line. Lines starting with `#`
   are comments, and the comment just above a policy becomes its title. A
   line `name = role` gives a key or hash a role, and holds for every policy
   in the file. Here is a file that File ▸ Open reads:

   ```
   key_user = the user
   key_service = the cosigning service

   # A user and a co-signing service, the user alone after 90 days
   and(pk(key_user),or(99@pk(key_service),older(12960)))
   ```

   A policy may be a descriptor with real keys and a checksum
   (`wsh(…)#checksum`, `tr(…)`, key origins such as `[a5c6b76e/48'/1'/0'/2']tpub…/<0;1>/*`).
2. Choose **File ▸ Open…** and pick the file. The program opens in a new tab.
3. The note under the menu bar gives, for each policy, the ledger counts and
   the result of the policy's own tests, for example *wallet: 5 ledger
   elements encoded, 1 approximated, 0 residue; 0 writer errors; the policy's
   own analysis: 12 tests pass, 0 fail, 0 errors.* It starts with a
   **WARNING** when consensus reads the policy differently from how it is
   written (see [Traps](#traps)).
4. The first policy of the file is the program opened. Each further policy
   becomes a program of its own beside it (`<name>_2`, `<name>_3`, …). The note
   names them, and so does a comment at the top of the first program.
5. A line that is not a policy (a bare word, say) is not dropped. It becomes a
   `% TODO` residue block in the first program, with the parser's complaint.
   A file with no policy at all is not treated as Miniscript.
6. **Misc ▸ Run the Program's Tests…** runs the scenarios. **File ▸ Show the
   Original…** shows the uploaded file, kept in the program's `sources/`
   folder. The ledger, `<name>.ledger.md`, is written beside the program.

### Reading the program

The comment at the top of the program shows the source four ways, so you need
not decode a descriptor:

- as written;
- laid out as an indented tree, with keys and hashes by role (`pk(<the user>)`);
- the legend, which says which key or hash plays each role;
- what the policy says, in words, with delays in blocks and in approximate
  time (`the coin at least 12960 blocks old (about 90 days; older(12960))`).

Then come the rules, one per spending path, each labelled and citing its source:

```le
rule user_and_service with provenance the Miniscript page,
        confer "A user and a 2FA service need to sign off, but after 90 days the user alone is enough":
the coin can be spent if
    the witness contains a signature by the user
    and the witness contains a signature by the cosigning service
        or the coin has been confirmed for a number N blocks
            and N >= 12960.
```

The scenarios are the policy's *satisfaction analysis*. Each spending path gets
a scenario that meets exactly its requirements, named after the rule it
satisfies (`revocation` for rule `revocation`; `family_1`, `family_2` when rule
`family` can be met in several ways, through an `or` or a `thresh` inside it).
Each path also gets its *near misses*, with one requirement removed
(`revocation_without_1`): a
signature or a preimage missing, a delay one block short, a lock time one
below. There is also an empty witness (`no_witness`). Every expected answer
comes from the policy, computed by an evaluator that follows BIP 379, and never
from the Logical English program. The queries are `spendable` (`the coin can
be spent`), `flip_spend` and `flip_block`.

### The custody explainer and the flips

Each program ends with a view, `custody explainer`. Open it with **Misc ▸ Open
Executive View** and pick it from the **Views:** strip. It shows the witness
(the signatures and preimages) and the timelocks (the block of the coin and of
the spending transaction) as the facts of the case. It shows whether the coin
can be spent, with the reasons and the citations. Its flip button, **What
would let this coin be spent?**, keeps the block heights, so it answers in
keys and preimages.

The flip scenarios hold the key-loss analysis
([flip queries](../reference/language.md#177-flip-queries-which-minimal-change-flips-the-outcome)):

- `flip_now` and `flip_after_delays` ask, with nothing signed, which minimal
  sets of signatures and preimages let the coin be spent: now, and once every
  delay has passed;
- `lost_the_<role>` gives everything except that key's signature, after the
  delays. It says whether the coin can still be spent, and if so, which
  smallest removals would then block it. Those are the keys (and timelock
  facts) that become indispensable once that key is gone.

For example, in `cosigning_service` the user's key is indispensable. Losing
the cosigning service leaves the coin spendable by the user alone, after the
delay.

### The example twins and their chain runs

Twelve published policies have been translated. The results, *twins*, are
among the examples under `migration/miniscript/`. Open them with **File ▸ Open
example from server…**:

| Twin | Source |
|---|---|
| `core_2of3_multisig` | Bitcoin Core's descriptor documentation: a 2-of-3 multisig |
| `liana_recovery`, `liana_inheritance` | Liana's recovery descriptor, and the inheritance wallet its README describes |
| `cosigning_service`, `decaying_multisig` | sipa's Miniscript page: a 2FA service; a 3-of-3 that becomes 2-of-3 after 90 days |
| `bolt3_to_local`, `bolt3_offered_htlc`, `bolt3_received_htlc` | sipa's page: the Lightning outputs of BOLT #3, with hash locks |
| `halving_decay`, `hash_threshold`, `liquid_federation`, `revault_unvault` | Bitcoin Core's test policies: a decaying 4-of-4, a threshold of hashes, a federation with a time-based lock, Revault's unvault output with `after` |

**File ▸ Show the Original…** on a twin lists what it was translated from. You
get the cited excerpt as plain text, the page or files it comes from in full
(`originals/`), `<id>.policy` (the policy in the format File ▸ Open reads, with
sipa's compilation and the Minsc link), and `<id>.chain.json`.

Every twin except `hash_threshold` has also been *run*. Each spending attempt
of its satisfaction analysis (every path, every near miss, the empty witness)
was built as a real transaction and broadcast. The network was **Tape**, Rewind
Bitcoin's public regtest network, which runs Bitcoin Core's consensus and
mempool rules. The node's verdicts are in the twins as the scenarios
`chain_…`:

```le
scenario chain_user_and_service_1 is, as stated in the Tape run of 2026-09-14 at the refusal of attempt path_1:
    % the chain refused the spend: non-BIP68-final
    the witness contains a signature by the user.
    the coin was confirmed in block 122322.
    the spending transaction is in block 122322.
    spendable expects answers [].
```

An accepted spend cites its transaction, and the document `the Tape run of …`
links to the address on Tape's explorer. In the run of 14 September 2026, 90
attempts on eleven twins gave 16 accepted spends and 74 refusals. The refusals
came from missing signatures, wrong preimages, coins too young for `older`
(BIP 68) and lock times not yet past (BIP 65/113). Every verdict agrees with
its twin. The same attempts were also run on a private regtest node, where
the coins are buried under enough blocks for the long relative locks, so the
`older` paths are accepted too. That run is a check, and it is not recorded
in the twins.

The signatures in these runs are made with *test keys* derived from the role
names. Nobody holds the sources' private keys. The policy's structure is the
source's. The editor does not broadcast anything: the chain runs are
recorded material, not a feature you run.

### Exporting a program as a policy

1. Open a twin, or any program in the same vocabulary (below).
2. Choose **File ▸ Export to Another System…**. It offers *Bitcoin Miniscript
   policy (with its Miniscript and a Minsc link)*. It also offers LegalRuleML,
   which refuses programs with a threshold (see
   [LegalRuleML](legalruleml.md#traps)).
3. The window shows the `.policy` text, with **Copy**, **Save…** and **Try it in
   Minsc**. The text has:
   - the Miniscript sipa's compiler makes of the policy (P2WSH);
   - the descriptor, `wsh(…)`, when the program states every key;
   - the Minsc link;
   - the legend lines and the policy itself.

   The notes count the keys and hashes and the spending paths.
4. **Try it in Minsc** opens the policy in the Minsc playground, which compiles
   it to Miniscript, Script and a testnet address in the browser.

The exported file opens again with **File ▸ Open…**. Every twin comes back with
the same policy (the same paths, keys and hashes by role, locks and hash
functions).

If a rule concluding `the coin can be spent` has a condition outside the
vocabulary, the export is refused and nothing is written
([refusals](index.md#when-an-export-is-refused)). The window lists each such
condition with its line:
*a condition Miniscript has no form for (a policy says only: signatures, hash
preimages, relative and absolute time locks, and thresholds of them)*. An
integrity constraint (`it must not be true that …`) is refused the same way.
Rules the policy does not read, such as the rule for the coin's age, are not a
problem.

### Writing a policy in Logical English

The program need not come from a policy. Any program that uses the twins'
templates exports, so a spending policy can be written, tested and explained
in Logical English first. Here is a minimal one:

```le
the target language is: prolog.

the templates are:
    the coin can be spent.
    the witness contains a signature by *a key*.
    the witness reveals the preimage of *a hash*.

the knowledge base mine includes:

the coin can be spent if
    the witness contains a signature by alice
    and the witness reveals the preimage of the secret.

the coin can be spent if
    the witness contains a signature by bob.
```

It exports as `or(and(pk(alice),sha256(secret)),pk(bob))`, which sipa's
compiler makes `andor(pk(alice),sha256(secret),pk(bob))`. The templates must
be worded exactly as in the table below. To use real keys, and get a
descriptor, state them: `the public key of the primary key is "[a5c6b76e/…]tpub…/<0;1>/*".`
For a hash other than SHA-256, state its function: `the hash function of the
payment hash is hash160.`

## How Miniscript maps to Logical English

| Miniscript or policy | Logical English |
|---|---|
| `pk(K)`, `pkh(K)`, `pk_k`, `pk_h`, `c:` | `the witness contains a signature by <role>`: the role from the legend, else `key A`, `key B`, … |
| `sha256(H)`, `hash256`, `ripemd160`, `hash160` | `the witness reveals the preimage of <role>`, with `the hash function of <role> is hash160` (and so on) as a fact |
| `older(n)`, in blocks | `the coin has been confirmed for a number N blocks and N >= n`, the age computed from `the coin was confirmed in block …` and `the spending transaction is in block …` |
| `older(n)` with BIP 68's time flag | the same, in seconds (512 × the low 16 bits) |
| `after(t)` | `the spending transaction has the lock time a number N and the lock time N is a block height` (or `is a time`) `and N >= t`, and the lock time past: `the spending transaction is in block a height H and N < H` |
| `and`, `and_v`, `and_b`, `and_n` | `and` |
| `or`, `or_b`, `or_c`, `or_d`, `or_i` | `or`; a top-level `or` is one rule per spending path, labelled |
| `andor(X, Y, Z)` | (X and Y) or Z |
| `thresh(k, keys)`, `multi`, `multi_a`, `sortedmulti` | a count: `a number N is the count of each K such that a key K is in [cosigner A, cosigner B, cosigner C] and the witness contains a signature by K` and `N >= 2` |
| `thresh(k, conditions)` | the same count over named conditions (`the condition … is met`), each with a rule of its own |
| `tr(K, {leaves})` | K's signature, or any leaf |
| a real key in a descriptor | `the public key of <role> is "…"` |
| wrappers (`a s c d v j n t l u`), `wsh`, `sh`, weights like `99@` | nothing in the rules: they do not change who can spend (BIP 379); the ledger records them |
| witness sizes, fees, malleability, the choice of fragments | not in the program: one *approximated* ledger entry, *the Script encoding* |

The templates `the witness contains a signature by *a key*`, `the coin was
confirmed in block *a height*`, `the spending transaction is in block *a
height*` and `the spending transaction has the lock time *a number*` are
`scenario element`s. Those are the facts a case states, and the facts a flip
may add or remove.

## Traps

- **The program is the policy, not the Script.** Witness sizes, fees,
  malleability and the choice between equivalent fragments are not in it. Two
  Miniscripts with the same policy give the same program.
- **Weights disappear.** `99@` and `9@` guide sipa's compiler towards the
  likelier path. They do not change who can spend, and the header says the
  program leaves them out.
- **`older(n)` reads only 16 bits.** BIP 68 ignores the higher bits, so
  `older(65664)` is 128 blocks to consensus. File ▸ Open says so in a WARNING
  (in the note, the header and the ledger), and the program states what
  consensus reads (`N >= 128`). The export gives the policy back as written.
  The longest relative lock is 65535 blocks, about 455 days. "One year and
  three months" cannot be written in blocks.
- **Mixed lock kinds.** A spending path that needs a lock by block height and a
  lock by time cannot be met by any transaction. File ▸ Open warns about it
  (BIP 379, timelock mixing). The parser does not otherwise re-check
  Miniscript's type system.
- **`after(t)` needs the lock time to be past.** BIP 379 reads `after(t)` as
  "the lock time is at least t". Consensus also refuses a transaction whose
  lock time is not below its block's height or median time. The programs state
  both. This was found when the Tape run refused spends the first programs
  allowed.
- **The block heights in the analysis are illustrative.** The scenarios place
  the coin at block 850000 and the spend just after the delays. The chain
  scenarios use the heights of the Tape run.
- **Chain runs recorded before 16 September 2026 number their attempts.** The
  scenario names follow the rules (`chain_revocation`), but the citation keeps
  the run's own attempt id (`at the refusal of attempt path_1`), which counts
  the analysis's paths in the order it found them.
- **The program's flip queries may propose removing block facts.** `flip_block`
  answers include `remove: the coin was confirmed in block 850000`: true, but
  not something a key holder can do. The view's flip keeps the timelock facts.
  Use the view for questions about keys.
- **Bounds.** A policy with more than 12 spending paths is sampled (the first,
  the last and some in between). Key-loss scenarios are written for policies
  of up to six keys. A flip looks at most three changes deep.
- **Minsc links use test keys when the source names none.** A link or a
  descriptor built from role names holds keys derived from those names. The
  comment in the link says *a test key: the source names no key*. Never send
  funds to an address made from them. The export writes a descriptor only when
  the program states every key with `the public key of …`.
- **An unstated hash function is SHA-256.** An exported program with
  `the witness reveals the preimage of …` and no `the hash function of … is …`
  fact writes `sha256`.
- **sipa's compiler may decline.** When it cannot compile the policy to sane
  Miniscript, the export writes the policy without Miniscript or descriptor,
  and a note says why. `hash_threshold` is such a policy: two preimages spend
  it with no signature. Minsc answers *"Top Level script is not safe on some
  spendpath"*, and wallet libraries will not build its transactions, so it
  has no chain run.
- **Wording must match.** The exporter reads rules by their templates. A
  program that says `the transaction is signed by alice` instead of `the
  witness contains a signature by alice` is not offered the Miniscript export,
  or is refused at that condition.
- **`.txt` is shared.** Several translators read `.txt`. A `.txt` file is
  treated as Miniscript only when at least one of its lines parses as a policy.
  Use `.policy` to be sure.
- **Expected warnings.** Single-signature paths have no variables. The
  verifier's `rule_without_variables` warning on them is expected.
- **Not covered:** Simplicity, and Script that is not Miniscript (decompile it
  to Miniscript first).

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): opening files, [what could not be translated](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [refused exports](index.md#when-an-export-is-refused), [the twins](index.md#the-migration-twins-among-the-examples);
  - [LegalRuleML](legalruleml.md), the other exporter these programs are offered;
  - [flip queries](../reference/language.md#177-flip-queries-which-minimal-change-flips-the-outcome), [views](../reference/language.md#1710-views-how-a-screen-shows-a-program), [aggregates](../reference/language.md#5-aggregates), [integrity constraints](../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-), [rule labels and provenance](../reference/language.md#155-rule-labels-and-provenance);
  - [the executive view](../guide/executive-view.md#views), [LE Views](../tutorials/views.md), [Querying a program](../tutorials/querying-a-program.md#5-flip-what-would-change-the-answer);
  - [the Contract Assistant](../guide/assistants.md#the-contract-assistant), whose residue mode translates TODO blocks.
- In the LPS2 IDE: [the IDE guide](https://lps2.logicalcontracts.com/docs/user/guide/ide), [integrations](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- Miniscript's own documentation:
  - [Miniscript](https://bitcoin.sipa.be/miniscript/), by Pieter Wuille, Andrew Poelstra and Sanket Kanjalkar, with the policy compiler;
  - [BIP 379: Miniscript](https://github.com/bitcoin/bips/blob/master/bip-0379.md);
  - [Bitcoin Core's descriptors](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md);
  - [Minsc](https://min.sc/), the playground;
  - [the Tape network](https://tape.rewindbitcoin.com/).
