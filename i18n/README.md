# Multilingual Logical English — the `i18n/` dictionaries

This directory is the **single source of truth** for every natural-language
surface of Logical English. The Prolog backend (`le_i18n.pl`) loads these CSVs
at start-up; the editor build generates its keyword tables and UI catalog from
the same files (`editor/scripts/gen-i18n.cjs` → `editor/src/generated/i18nData.ts`).

A Logical English program declares its language with its **first statement**
(the `opener` column of `languages.csv`):

| Language | Opener |
|---|---|
| English | `the target language is: prolog.` |
| Português Lógico | `a linguagem alvo é: prolog.` |

When no opener matches, the program is parsed as English (decision O-1).

## Files

- **`languages.csv`** — language registry: code, autonym, opener phrase, and
  number locale (`decimal_sep`, `thousands_sep`, `list_sep`). `status` is
  informational (`core`, `pilot`, `draft`).
- **`keywords.csv`** — grammar keywords and word classes. One row per keyword
  `key` (grouped by `category`), one column per language. A cell holds one or
  more **synonyms separated by `|`**; each synonym is a space-separated word
  phrase. The first/longest synonym is the *principal* form, used when LE text
  is generated (answers, explanations); all synonyms are accepted when parsing.
- **`system_templates.csv`** — surface phrases of the built-in predicates
  (`is equal to` / `é igual a`, …). `{1}`, `{2}`, … mark the argument slots;
  synonyms with `|` as above. Symbolic operators (`>=`, `=` …) are
  language-neutral and are not listed here.
- **`messages.csv`** — diagnostics and other generated messages, with
  **named placeholders** `{name}` that translations may reorder ( `{newline}`
  is predefined). An empty cell falls back to English.
- **`ui.csv`** — editor/UI chrome strings, keyed by the canonical English
  string. An empty cell falls back to English.

## Adding or revising a language

1. Add/adjust the row in `languages.csv` (opener + number separators).
2. Fill the language's column in `keywords.csv`, `system_templates.csv` and
   `messages.csv`. Machine-translated first drafts are fine — mark work in
   progress via the `status` column of `languages.csv` and review keyword rows
   especially (they define the grammar!).
3. Run the tests: `testing/run_tests.sh --no-e2e`. Example programs for the
   language live under `examples/<code>/` (decision O-7) and are picked up by
   the runner automatically.
4. Rebuild the editor (`cd editor && npm run build`) to regenerate its tables.

### Notes and caveats for translators

- **Number locale (decision O-3, option B).** In comma-decimal languages a
  comma **directly between digits** is read as the decimal separator
  (`o custo é 1,5`). Write list/argument commas with a following space:
  `[1, 5]`. The thousands separator groups exactly three digits
  (`1.234.567`); dates stay ISO (`2026-07-15`).
- **Meta markers (decision O-14).** The words of the `meta_marker` class
  (`that`/`says`; `que`/`diz`, …) give templates containing
  `<marker> *a variable*` priority as meta-templates. In Romance languages
  `que` is ubiquitous — built-in templates are exempt from this priority, and
  comparison phrasings in `system_templates.csv` should avoid a bare
  `que` before a slot (Portuguese uses `é superior a`, not `é maior que`).
- **Determiners.** The `article` class introduces variables ("uma pessoa");
  the `definite_article` class marks constants in scenarios ("o pão");
  `determiner_definite` ("this"/"este|esta") anchors prepositional chains.
  Capitalised variants ('The', 'Uma') are accepted automatically.
- **Gender/number agreement (decision O-8).** Generation is minimal: programs
  are echoed with their own words; only connective words are inserted. Where a
  class needs both genders (qualifiers, additions), list both forms as
  synonyms (`desconhecido|desconhecida`).
- Keys are **stable identifiers** — never rename them; only edit language
  cells. New grammar features must add rows here rather than hardcoding words.
