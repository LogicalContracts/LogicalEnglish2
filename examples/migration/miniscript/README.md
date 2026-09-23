# Bitcoin Miniscript twins

Twelve Bitcoin spending policies, written in Miniscript (a language for the
conditions under which a coin can be spent), rewritten in Logical English by
a translator. Such a rewrite is a **twin**: each rule is one way of spending
the coin. Each twin's opening comment shows the policy as written, laid out,
and in words. Its scenarios are the policy's satisfaction analysis, the loss
of each key, and recorded spending attempts on the public Tape test network.

## Start here
- [Two of three](core_2of3_multisig/core_2of3_multisig.le?scenario=two_of_three_1&query=spendable) — any two of three cosigners.
- [Liana inheritance](liana_inheritance/liana_inheritance.le?scenario=family_1&query=spendable) — the manager, or two of the family after a year, or a third party later.
- [Revault unvault](revault_unvault/revault_unvault.le) — a vault with a delay and an emergency path.

## Try this
1. Open [two of three](core_2of3_multisig/core_2of3_multisig.le?scenario=two_of_three_1&query=spendable) and click **Query**: "the coin can be spent", with the signatures of cosigners A and B.
2. Open [the Liana wallet, family path](liana_inheritance/liana_inheritance.le?scenario=family_1&query=spendable): the two children can spend, 52,560 blocks after the coin was confirmed.
3. Open it [one block too early](liana_inheritance/liana_inheritance.le?scenario=family_1_without_1&query=spendable): no answer; the explanation shows the condition that fails, the age of the coin.
4. Open [what would let the coin be spent](liana_inheritance/liana_inheritance.le?scenario=flip_after_delays&query=flip_spend), with nothing signed and every delay passed: the smallest changes are the manager's signature, or the third party's.
5. Open [the custody explainer](liana_inheritance/liana_inheritance.le?view=custody%20explainer&scenario=lost_the_spouse): the view a wallet's owner reads.

## More
- [Miniscript in Logical English](/docs/user/integrations/miniscript): how the translation works, and the way back.
- Miniscript: https://bitcoin.sipa.be/miniscript/ and BIP 379, https://github.com/bitcoin/bips/blob/master/bip-0379.md
- Each twin cites "the policy in Minsc", which opens the policy in the Minsc playground, https://min.sc
- `sources/` holds the cited excerpt, the originals, the policy as File > Open takes it back, and the recorded run on the chain (`<id>.chain.json`).
- Written by `lpsPlus/migration/miniscript/build.pl`; do not edit by hand.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.
