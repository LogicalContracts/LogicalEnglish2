# Twins of other systems' programs

Logical English programs written by the translators of other rule systems
(lpsPlus/migration), one directory per source system and one per program,
each with its migration ledger and its sources (docs/dev/migration.md):

- `blawx/` — Blawx (s(CASP)-based legal encodings);
- `legalruleml/` — the OASIS LegalRuleML specification's examples;
- `miniscript/` — Bitcoin spending policies;
- `oipa/` — Oracle Insurance Policy Administration (OIPA) transactions of two
  synthetic plans, an annuity and a term life policy;
- `scasp/` — s(CASP) programs, including LE1's.

The LE-for-LPS twins (Daml, Drools, Solidity) are in lps2's examples/migration.

**Disclaimer.** A twin is written by a translator (a program that rewrites
another system's program in Logical English), and it is provided **"as is",
without warranty of any kind**, express or implied, including any warranty
that it is accurate, complete or fit for a particular purpose. A translation
may be wrong: check a twin against its source before relying on it. A twin
is not legal, tax, insurance, financial or other professional advice. Its
authors accept no liability for any loss or damage arising from its use.
Every twin repeats this notice in its opening comment; the translators write
it there themselves (`twin_disclaimer` in `i18n/writer_words.csv`).
