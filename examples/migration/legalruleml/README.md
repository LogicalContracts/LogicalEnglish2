# LegalRuleML twins

The examples of the LegalRuleML Core Specification (OASIS, 2021), an XML
standard for legal rules, rewritten in Logical English by a translator.
Such a rewrite is a **twin**. Obligations, permissions and prohibitions come
from a small deontic library, `deontic.le`, beside each twin. The expected
answers are those of SPINdle, a reasoner for defeasible deontic logic, on the
original; the scenarios were drafted from the examples and the law they
encode, since LegalRuleML ships no tests.

## Start here
- [US copyright damages, 17 U.S.C. §504](ex12_usc_17_504_context/ex12_usc_17_504_context.le?scenario=statutory_damages&query=obligations) — what an infringer must pay.
- [Obligations and permissions](ex3_deontic/ex3_deontic.le?scenario=permitted_and_obliged&query=obligations) — the smallest deontic example.
- [Maternity leave, two readings](ex11_maternity_alternatives/ex11_maternity_alternatives.le) — alternative interpretations of one rule.

## Try this
1. Open [§504 on statutory damages](ex12_usc_17_504_context/ex12_usc_17_504_context.le?scenario=statutory_damages&query=obligations) and click **Query**: ben is obliged to pay statutory damages, in three ranges.
2. Change the query to `breaches`: "ben is in breach".
3. Open [the same law on wilful infringement](ex12_usc_17_504_context/ex12_usc_17_504_context.le?scenario=wilful_infringement&query=obligations): the increased damages appear.
4. Put the cursor inside `rule ps2_tblock1` and choose **File > View Original Text**: the LegalRuleML statement it came from.
5. Open [the ledger](ex12_usc_17_504_context/ex12_usc_17_504_context.ledger.md): each statement of the original, encoded, approximated or left for a person to translate.

## More
- [LegalRuleML in Logical English](/docs/user/integrations/legalruleml): how the translation works, and the way back.
- LegalRuleML Core Specification: https://docs.oasis-open.org/legalruleml/legalruleml-core-spec/v1.0/legalruleml-core-spec-v1.0.html
- Written by `lpsPlus/migration/legalruleml/build.pl`; do not edit by hand.
- The few warnings the editor still shows on these twins come from the originals, and the ledger says why. The schematic examples' rules are about one individual, x, as the specification writes them. In ex3, the statements depend on one another through negation. In ex12, a rule makes everyone an infringer.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.
