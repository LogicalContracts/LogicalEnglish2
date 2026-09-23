# Twins of other systems' programs

A **twin** is a program of another rule system rewritten in Logical English
by a translator, a program that reads the other system's files. Each twin
keeps the original beside it, in its `sources/` folder, and a **migration
ledger**: the record of what each part of the twin was translated from. Its
scenarios (named sets of facts) expect the answers the other system itself
gives, so running them checks the translation.

## Start here
- [Blawx](blawx/) — Acts encoded in Blawx, a visual tool for legal rules.
- [LegalRuleML](legalruleml/) — the examples of the OASIS LegalRuleML standard: duties, permissions, prohibitions.
- [Miniscript](miniscript/) — Bitcoin spending policies: who can spend a coin, and when.
- [OIPA](oipa/) — insurance transactions of Oracle Insurance Policy Administration, on two plans we wrote.
- [s(CASP)](scasp/) — logic programs of the s(CASP) reasoner, including Logical English 1's own.

## Try this
1. Open [the Rock Paper Scissors Act](blawx/rps/rps.le?scenario=bobjane&query=bobjane) and click **Query**: the answer is "the winner of testgame is jane".
2. Click the answer: the explanation cites section 4 of the Act.
3. Choose **File > Show the Original…**: the Blawx project the twin was translated from.
4. Open [its ledger](blawx/rps/rps.ledger.md) to see what was translated from what.
5. Open any folder above for its own short tour.

## More
- How translation works, for each system: [the integrations guide](/docs/user/integrations/index).
- The twins are written by the translators of `lpsPlus/migration` (not public); do not edit them by hand.
- The twins in Logical English for LPS (Daml, Drools, Solidity) are among LPS2's examples, in its `examples/migration/`.

## Disclaimer
A twin is written by a translator, and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment; the translators write it there
themselves (`twin_disclaimer` in `i18n/writer_words.csv`).
