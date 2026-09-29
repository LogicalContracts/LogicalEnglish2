# Signing in, and what a licence adds

*Kind: guide · Audience: everyone who uses the hosted editor · Status: current (2026-09-28)*

You do not need an account to use Logical English. Everything described in
this documentation works without signing in, except the few things listed
below under *The two licences*.

## One sign-in for Logical English and LPS

The hosted Logical English editor (`le2.logicalcontracts.com`) and the hosted
LPS editor (`lps2.logicalcontracts.com`) share one sign-in. LPS, short for
Logic Production Systems, is the sister language for programs that act over
time. If you sign in on one site, you are signed in on the other as well.
If you sign out on one site, you are signed out on both.

To sign in, choose **Login** at the top right of the start page or of the
executive view, or open the page `/login`. There are three ways:

- **Sign in with Google**, with any Google account.
- **Sign in with GitHub**, with any GitHub account.
- **An email address and a password** that Logical Contracts created for
  you. You cannot create one of these yourself; use Google or GitHub instead.

Google and GitHub tell us your email address and nothing else. We do not see
your password for either of them.

A sign-in lasts 14 days, or until you choose **Logout**.

## The two licences

Signing in by itself changes nothing that you can do. What it does is tell the
site your email address, so that the site can look up the licences that are
attached to that address. Each licence has an expiry date. It works until the
end of that day.

| Licence | What it adds |
|---|---|
| **With extensions** | The translators of other systems: **File ▸ Open** of a file written for another rules system (for example Oracle Intelligent Advisor, Socotra, Blawx or Drools), and **File ▸ Export** of a program to such a system. The private example programs, including the programs these translators wrote from sources that may not be published. In the LPS editor, it also adds **Deploy as Solidity** and the Drools reader. |
| **InsurLE** | The InsurLE language extensions: a *which* in the conclusion of a rule, conditions introduced by *unless*, groups of conditions under *either*, *any of* or *all of*, and conditions numbered 1., 2., 3. It also adds InsurLE's own example programs. |

A person may hold one licence, the other, or both. To obtain a licence,
contact Logical Contracts.

## What you see without a licence

- **File ▸ Open** accepts Logical English files only, and **File ▸ Export**
  offers no other systems.
- The private examples are not listed. A link to one of them sends you to the
  sign-in page, and then back to the example if your account holds the
  licence.
- A program that numbers its conditions (`if:` followed by `1.`, `2.`, ...)
  shows an error on each such rule. The error says that numbered conditions
  belong to the InsurLE licence. Until then the rule is read as never true,
  so the program never gives a wrong answer because of a construct it could
  not read. You can write the same conditions one after the other, joined by
  *and* and *or*, and the rule works for everyone.
- Other InsurLE constructs, such as a *which* in a conclusion, are not
  recognised, and the editor reports the sentence as one it cannot match to a
  template. A template is the pattern, declared at the start of a program,
  that each sentence of the program must follow.

## What the sites keep about you

- In your browser: a small file called a cookie, named `lc_session`. It holds
  your email address and the way you signed in, for 14 days. It is what lets
  the two sites recognise you. While you sign in with Google or GitHub, a
  second cookie, `lc_oauth`, lives for ten minutes at most.
- On the sites: nothing, if you have no licence. If you have a licence, the
  licences table holds your email address, the licence, and its expiry date.

The programs you write are not stored with your account.
