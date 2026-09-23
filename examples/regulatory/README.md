# Regulatory decisions: provenance, tables, sections, views

Programs that apply written rules to recorded cases, as an office decides
them: every fact cites the document that states it, someone decides the
contested question, and the answer can be shown on a screen made for the
person who uses it (a *view*). Each small program shows one construct of the
language reference, §17; two large models apply them all to real regulation.

## Start here

- [eu261_integration.le](eu261_integration.le?scenario=new_claim&query=claim) — everything together: compensation for a cancelled flight under EU Regulation 261/2004, decided by precedent.
- [sections_benefit.le, the rent decision](sections_benefit.le?view=rent%20decision&scenario=not_eligible) — a decision in three sections (does the rule apply, the question, the remedy), shown as a view with a draft letter.
- [customs/](customs/) — customs classification of goods under the US tariff, on published rulings.
- [medicare/](medicare/) — Medicare coverage of medical equipment, on claims and appeal decisions.

## Try this

1. Open [eu261_integration.le](eu261_integration.le?scenario=new_claim&query=claim) and press **Query**. The answer is *anna is entitled to compensation of 250 for flight AZ123*.
2. Click the answer. The explanation shows why the technical problem is not an extraordinary circumstance: it is like the problem in the Wallentin-Hermann judgment, a precedent the program cites.
3. Choose the scenario **bird_strike** and run **claim** again. There is no answer: a bird strike is beyond the carrier's control, so it owes nothing.
4. Choose **outside_the_eu** and run the query **stage**. The answer, *the query fails at applicability*, says the regulation does not apply at all.
5. Back on **new_claim**, run the query **flip**. Each answer is a smallest change to the facts that would take the compensation away.
6. Open [the claim desk](eu261_integration.le?view=claim%20desk&scenario=new_claim): the same decision as a claims handler's screen, with who states each fact.

## The other programs

- [judged_damage.le](judged_damage.le) — facts with their sources, and questions someone must decide (§17.1).
- [otherwise_table.le](otherwise_table.le), [loaded_table.le](loaded_table.le), [scenario_table.le](scenario_table.le) — `otherwise` and decision tables (§17.2, §17.3).
- [scoped_notice.le](scoped_notice.le) — a proof that may use only one party's evidence (§17.5).
- [semantic_match.le](semantic_match.le), [semantic_llm.le](semantic_llm.le) — services and semantic matching (§17.6).
- [flip_housing.le](flip_housing.le?scenario=bob&query=flip_bob) — flip queries: what would change the answer (§17.7).
- [precedent.le](precedent.le), [precedent_pattern.le](precedent_pattern.le) — factors and precedent (§17.8).

## More

- The manual: [the language reference, §17](/docs/user/reference/language), [LE Views](/docs/user/tutorials/views) and [the executive view](/docs/user/guide/executive-view).
- The regulation: [EU Regulation 261/2004](https://eur-lex.europa.eu/eli/reg/2004/261/oj) and the [Wallentin-Hermann judgment (C-549/07)](https://curia.europa.eu/juris/liste.jsf?num=C-549/07).
- The two large models are examples provided "as is", without warranty, and are not advice: each folder's README says so in full.
