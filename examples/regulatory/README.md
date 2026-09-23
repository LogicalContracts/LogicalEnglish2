# Regulatory decisions: provenance, tables, sections, views

The programs of the regulatory-decision constructs, docs/user/reference/language.md §17,
and of LE Views (docs/user/tutorials/views.md):

- `judged_damage.le` — provenance-bearing facts and judged templates (§17.1).
- `otherwise_table.le`, `loaded_table.le` (+ `shipping.csv`) — `otherwise` and decision tables (§17.2, §17.3).
- `scenario_table.le` — where a table may be written: among a knowledge base's rules, and a table per scenario (§17.3).
- `sections_benefit.le` — the decision skeleton as sections, with views (§17.4, §17.10).
- `scoped_notice.le` — source-scoped proof (§17.5).
- `semantic_match.le`, `semantic_llm.le` — services and semantic predicates (§17.6).
- `flip_housing.le` — flip queries (§17.7).
- `precedent.le`, `precedent_pattern.le` — factors and precedent (§17.8).
- `eu261_integration.le` — everything together: air passenger compensation.

Two large models apply those constructs to whole bodies of regulation, each
with its own README, its cited texts under `sources/`, and a disclaimer: they
are examples, provided "as is", and not advice.

- `customs/` — customs classification: the General Rules of Interpretation
  and Chapters 39 (plastics), 61 and 62 (clothing) of the US tariff in full,
  run on 225 published rulings of US Customs and Border Protection (CBP) and
  15 European Binding Tariff Information (EBTI) decisions.
- `medicare/` — Medicare coverage of durable medical equipment: the coverage
  criteria of all 58 Local Coverage Determinations (LCDs) of the four
  regional Medicare contractors for that equipment, with their claims, and 48
  decisions of the Medicare Appeals Council compared with the model.
