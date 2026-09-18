# LE Views: how they work

*Kind: reference · Audience: developers · Status: current (2026-09-16)*

How the server reads, checks and serves the views of a program, and how the
built design compares with the proposal it came from. The tutorial, and the
table of the view sentences, are in the user documentation:
[LE Views](../user/tutorials/views.md); the language reference is
[language.md](../user/reference/language.md) §17.10.

## 1. How it works

- **Parsing.** `the view <name> is:` opens a section, as `scenario` and `query`
  do. The parser keeps its lines; `le_views.pl` reads them after the whole
  program is loaded. It reads each sentence against the sentence forms (the
  `view` keywords of the program's language) and each instance against the
  templates of the program and of its includes. The result is a plain structure
  returned with the load (`views`): groups, result, widgets in order. Nothing
  reasons with it.
- **Checking.** The verifier's `view_*` issues come from the same reading, with
  a message and a fix in each language (`i18n/messages.csv`).
- **Four server operations**, all generic:
  - `answeringQuery` also returns the **checklist** of a program's sections,
    and, asked `whyNot`, the **unmet** conditions of a failed result
    (`le_why_not.pl`: only the alternatives that came closest; docs/user/reference/language.md
    §17.10);
  - **`openQuestions`** returns the case facts a failed proof looked for (the
    facts the closest alternatives lack, which the case could state), and the
    questions a proof touches, which the interview uses;
  - **`draftView`** returns the draft of *Generate LE view*;
  - **`automaticView`** returns that draft compiled, for a program that
    declares no view, when a screen opens it.

  The flip, the citations and the documents use what the executive view already
  had.
- **The widgets** are one module of the editor, `editor/src/le-views.ts`. The
  executive view loads it for a `?view=`. It reuses the Scenario Editor's fact
  rows (their pick lists, the values the rules read, the citation field) and the
  source viewer (a passage in its document).
- **Words.** Every string of the widgets is a row of `i18n/ui.csv`; every
  phrase of the sentences is a row of `i18n/keywords.csv`. Adding a language
  adds columns, not code.

## 2. Compared with the proposal, and limits

LE Views began as a proposal in a role-play review of the customs programs
(CustomsOfficerReport.md, in the lpsPlus repository): a JSON file of
widgets beside each program, followed by a section on writing views in Logical
English instead. The Logical English form was built, and the JSON form was not:

- **One language.** A view is part of the program, checked against it, and
  translated with it. There is no second notation.
- **Questions.** The proposal's Questions widget became two sentences. `the
  result asks what is missing` offers the facts a failed proof looked for, or
  the facts a result that holds *provided that* waits for. `the facts are asked
  one at a time` turns them into an interview, which asks only while the answer
  can still depend on them.
- **The case board** became `the cases are listed with their results`,
  compared with the program's own expectations.
- **The draft** fills five named placeholders.

The limits:

- **Layout.** There are three columns, or one for an interview, with the order
  of the sentences. Anything beyond that (placement, colours, sizes) is outside
  what sentences should carry, and the page's theme decides it.
- **The widgets are fixed.** The original proposal described a registry to which new widget types could be added; today the
  widgets are one module.
- **The case list compares with the program's own expectations**
  (`expects answers`). It does not compare with an office's recorded outcomes;
  that needs the corpus mode of the LE extensions proposal.
- **The draft is text to copy.** There is no export to a document.
- **Examples.** The other four languages have their keywords, but only
  English views are among the examples.
