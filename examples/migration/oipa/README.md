# OIPA twins

OIPA is Oracle Insurance Policy Administration, a system that keeps
insurance policies and computes their transactions from an XML (Extensible
Markup Language) configuration. Here are six transactions of two plans, a
deferred annuity and a level term life policy, rewritten in Logical English
by a translator. Such a rewrite is a **twin**. The configuration is
synthetic, written by us from the forms of Oracle's public OIPA XML
Configuration Guide 9.7; it is not Oracle's. The expected values come from an
independent interpreter of OIPA's arithmetic, never from the twin.

## Start here
- [Annuity withdrawal](annuity_withdrawal/annuity_withdrawal.le?scenario=drained_w1&query=net_amount) — free amount, surrender charge, net amount.
- [Term life issue](termlife_issue/termlife_issue.le?scenario=too_old_i1&query=checks) — issue age, premium rates, the checks at issue.
- [Grace check](termlife_grace_check/termlife_grace_check.le) — days past due, and lapse.

## Try this
1. Open [the withdrawal that drains the account](annuity_withdrawal/annuity_withdrawal.le?scenario=drained_w1&query=net_amount) and click **Query**: "the net amount of w1 is 8050".
2. Click the answer: the explanation shows the surrender charge of 450 on a chargeable 7,500, each step citing its MathVariable.
3. Change the query to `spawns`: "w1 spawns FullSurrender", the transaction it starts.
4. Put the cursor in a rule and choose **File > View Original Text**: the MathVariable in the transaction's XML.
5. Open [the withdrawal screen](annuity_withdrawal/annuity_withdrawal.le?view=withdrawal&scenario=drained_w1): the view "withdrawal", with its citations.
6. Open [an applicant who is too old](termlife_issue/termlife_issue.le?scenario=too_old_i1&query=checks): "i1 fails the check I001" and "I002".

## More
- [OIPA in Logical English](/docs/user/integrations/oipa): how the translation works.
- Oracle's OIPA documentation: https://docs.oracle.com/en/industries/insurance/policy-administration/
- Each twin loads its rate tables (`*.csv`) and the date library beside it; its ledger and the configuration (`sources/`) sit there too.
- Written by `lpsPlus/migration/oipa/build.pl`; do not edit by hand.

## Disclaimer
A twin is written by a translator (a program that rewrites another
system's program in Logical English), and it is provided **"as is", without
warranty of any kind**, express or implied, including any warranty that it
is accurate, complete or fit for a particular purpose. A translation may be
wrong: check a twin against its source before relying on it. A twin is not
legal, tax, insurance, financial or other professional advice. Its authors
accept no liability for any loss or damage arising from its use. Every twin
repeats this notice in its opening comment.
