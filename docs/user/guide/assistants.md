# The assistants: language models in the editor

*Kind: guide · Audience: users · Status: current (2026-09-16)*

Three features of LE2 use a large language model (LLM) to write Logical
English for you:

- the **LE Assistant**, a chat panel in the editor that reads, writes and
  checks the program in front of you;
- **Write it in English**, in the Scenario Editor and the Query Editor, which
  turns sentences into facts or a query that use your program's templates;
- the **Contract Assistant**, a separate web page that turns a contract
  (wording, schedule, cases) into a tested program, or writes one scenario or
  one query for a program you already have, as a background job.

In all three, what the model writes is checked by the Logical English
verifier before you get it, and the verifier's problems are reported to you.
The model never decides answers: the program does, when you run it.

Two things in the editor need no model: **Generate LE view** in the LE
Assistant's header, which drafts a view from the program itself (see
[the editor guide](editor.md#generate-le-view-le-assistant)), and the
translators of other systems' files ([import and export](import-export.md)).

## Contents

- [Setting up: models and API keys](#setting-up-models-and-api-keys)
- [The LE Assistant](#the-le-assistant)
  - [Light and Deep modes](#light-and-deep-modes)
- [Write it in English](#write-it-in-english)
- [The Contract Assistant](#the-contract-assistant)
  - [What to generate](#what-to-generate)
  - [A whole program](#a-whole-program)
  - [Running, leaving, coming back](#running-leaving-coming-back)
  - [The result](#the-result)

## Setting up: models and API keys

Open **Misc ▸ API Keys & Assistant Settings…** in the editor:

- **Assistant Model** lists the models this server knows, each with its
  provider (OpenAI, Anthropic, Google, Groq, Together).
- One **API key** field per provider. A key the server already has for a
  provider is shown as *Provided by server* and cannot be edited. You need a
  key of your own only for a provider the server has no key for.
- **Assistant Max Steps (1–50)**: how many turns the LE Assistant's Light
  mode may take on one request (10 by default).

Keys and settings are stored in your browser's local storage and sent with
each request that needs them. The same model and keys serve the LE Assistant
and Write it in English. The Contract Assistant page reads the same stored
keys, so a key set in one place works in both.

If no model is selected, or the selected model's provider has no key, the LE
Assistant replies with a warning that points to this dialog, and Write it in
English disables its **Generate** button.

## The LE Assistant

The **LE Assistant** tab of the editor's bottom panel is a chat about the
program in the tab in front. Type a request and press **Send** (or Enter),
for example:

- *Fix the errors in this program.*
- *Why does scenario alice give no answer to query one?*
- *Add a rule: a person is a citizen if a parent is a citizen.*
- *Draft a program for the following regulation: …*

While it works, a line under the input shows its latest activity, and
**Interrupt** stops it. When it finishes, the panel shows its explanation in
Markdown. If it changed the program, the editor's text is replaced with the
new version, and the panel says *I have updated the editor content with the
changes.* The replacement is a single edit, so **Undo** in the editor brings
back the previous text. A reply may have a *System Logs (stderr)* section,
folded, with the technical log of the run.

Each open tab has its own conversation, and a reply goes to the program that
asked for it even if you have switched tabs meanwhile.

### Light and Deep modes

The **Light Mode** checkbox in the panel's header chooses how the assistant
works. The choice is kept in your browser.

- **Light** (the default) runs on the server itself. The model is given the
  Logical English reference and a set of example programs, and it can use two
  tools on the program it is editing: **verify** (load and check it) and
  **query** (run a query on a scenario). It repeats, fixing what the verifier
  reports and checking the tests, until it is done or reaches the maximum
  number of steps. Each request starts from the program as it is in the
  editor; earlier messages in the panel are not sent again.
- **Deep** runs a full coding agent (`opencode`) on the server. It works on a
  file with the same Logical English tools, and can also search files, fetch
  web pages and run commands. It is slower to start and suits larger tasks,
  such as a program from a regulation that needs research. It keeps its own
  session across the requests of a tab. Deep mode needs `opencode` installed
  on the server.

## Write it in English

In the **Scenario Editor** (Edit ▸ Edit Scenarios…) the last entry of the
**Add fact** menu is **Write it in English**. In the **Query Editor** (Edit ▸
Edit Queries…) it is the last entry of **Add condition**. It opens a dialog:

1. Type one or more sentences, such as *Alice is the mother of John, and John
   was born in the UK on 2021-10-09.* for facts, or a question for a query.
2. Press **Generate** (or Ctrl/Cmd+Enter). The dialog shows which model it
   uses.
3. The model writes facts (or query conditions) using **only the templates
   your program already has**. It normalises wording and tense and keeps a
   placeholder's own words (such as `a date`) where your sentence gives no
   value. The result is checked against your program. Only problems that your
   program did not already have count, and when there are some, the model is
   given them to correct, for a few rounds.
4. If the result checks clean, it is added straight away as ordinary rows,
   which you can edit. If problems remain, the dialog shows the text and the
   list of problems, errors first. You can then **Insert anyway**, or rephrase
   and **Regenerate**. An *[error]* means the text would not do what it says,
   so rephrasing is usually the better choice.

If your sentence needs a predicate the program does not have, add the
template first, in the editor or with the LE Assistant.

**From a document.** In the Scenario Editor, the dialog has a folded **From a
document** section. Give the document's name, and optionally the address of
its text (a URL, or a file beside the program) with **Fetch text** to load it
into the text area. Each generated fact then cites the passage that states it
(`confer "…"`), and the scenario names the document.

## The Contract Assistant

The Contract Assistant is a web page of its own, at
**`/web_extras/contract_assistant/index.html`** on the server. It runs longer,
budgeted jobs on the server. A run may make many model calls and take from
minutes to hours, and its cost depends on the models and the effort you choose.

It needs a model with a key (**3. Model**). A key field appears only for the
provider of the model you picked, and only when the server has no key of its
own for that provider. The **Judge model** is used only to merge the
vocabulary samples and to write the coverage ledger, so a cheaper model
usually does. **Additional instructions** and the **Effort budget** (below)
apply to every mode.

### What to generate

- **A whole program**: a contract wording, with its schedule and any concrete
  cases, becomes a complete program (templates, rules, scenarios, queries)
  with a clause-by-clause coverage ledger. See [A whole program](#a-whole-program).
- **One scenario**: paste a Logical English program you consider correct and
  describe a situation in English. You get one `scenario … is:` block for it.
  **Expected answers** chooses whether the scenario gets `expects answers`
  lines: *auto* only when your text states the outcome, *always* where a query
  fits, or *never*.
- **One query**: the same, for a question; you get one `query … is:` block.
- **Migration residue**: paste a program translated from another system that
  still has `RESIDUE` blocks ([import and export](import-export.md#what-could-not-be-translated)).
  The assistant translates those blocks only, never the rest, then runs the
  program's tests. A test that passed before and fails afterwards counts as a
  regression to repair. Background text, such as the source system's
  documentation, is optional.

In the scenario, query and residue modes, the program you paste is **input
only**: it is never modified. The assistant does not invent templates. If
the text needs vocabulary the program does not declare, it writes what it
can and says in a `%` comment on the block what it could not express. A
**Name** for the block is optional.

These modes are the budgeted counterpart of *Write it in English*, which is
one call and a few seconds. Use the Contract Assistant when the block matters
enough to pay for more checking.

### A whole program

1. **Documents.** The **contract wording** is required. **Schedule** and
   **cases / claims** are optional and may be several files each. Markdown or
   plain text works best. The server converts Word (`.docx`, with pandoc) and
   PDF (with pdftotext) if those tools are installed. Schedules and cases may
   also be JSON or CSV; a JSON array of claims becomes one case, and one
   scenario, per element.
2. **Target section** (optional, strongly recommended): a section title (that
   section with its subsections, plus the general terms), or a span such as
   `from Employers' liability until Property definitions`, with `(inclusive)`
   to keep the closing section. Leave it empty for the whole wording.
3. **Existing LE code** (optional): templates, scenarios with their expected
   answers, and rules you have already written. The generated program must
   contain this code and stay consistent with it. The result reports how much
   of it survived verbatim.
4. **Additional instructions** (optional): free text added to every drafting
   and repair request, which overrides the default conventions where they
   conflict. Scenarios are written only for the cases you supply, unless your
   instructions ask for more.
5. **Effort budget**: **Draft** (about 15 minutes), **Standard** (about 45
   minutes) or **Thorough** (about 2 hours). The presets differ in how many
   vocabulary samples are drawn, how many alternative drafts compete, and how
   many edge-case probes test the winner. **Advanced** exposes each number and
   feature. A **cost estimate** is shown before you start, once a wording file
   is chosen.

Press **Generate Logical English**. What the assistant does: several drafts
are written, verified and repaired against the cases, and the best one is
kept. The ranking favours a program with tests, then fewer errors, then more
tests passed. With two or more cases, some are held back from drafting and
used for a blind score.

### Running, leaving, coming back

The run screen shows the stage, one card per draft with its errors, warnings
and tests, a log, the elapsed time and **Cancel**. The job runs on the server,
not in the page: you can close the tab. The job's identifier is in the page's
address (after `#`), so reopening that address, or sharing it, reattaches to
the job. Without an address, the setup screen lists **Your recent runs** from
this browser. The server forgets jobs when it restarts, although a finished
result can still be recovered from its files.

### The result

- the generated Logical English, with **Copy**, **Download .le** and **Open in
  editor**. For a scenario or a query, Open in editor opens the block appended
  to the program it was written for, as it was verified. A program too large
  for an address must be downloaded and opened instead;
- the score of the delivered program, and of each draft;
- for a whole program, the **coverage ledger**: what was encoded, what was
  deliberately skipped, and what is missing;
- reports, where they apply: probes that agree or disagree with the program
  (a disagreement means either the program or the contract's reading is
  wrong), how much of the existing code was kept, what a new scenario or query
  answers when run against the program, and the paraphrase-stability score.

Review the result as you would a colleague's draft. The tests show that the
program decides the supplied cases as expected, and the ledger shows what it
does not cover.
