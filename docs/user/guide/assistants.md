# The assistants: language models in the editor

*Kind: guide · Audience: users · Status: current (2026-09-16)*

Three features of Logical English 2 (LE2) use a large language model — an LLM,
a program trained on great quantities of text so that it can read and write
ordinary language — to write Logical English for you:

- the **LE Assistant**, a chat panel in the editor that reads, writes and
  checks the program in front of you;
- **Write it in English**, in the Scenario Editor and the Query Editor, which
  turns sentences into facts or a query that use your program's templates;
- the **Contract Assistant**, a separate web page that turns a contract
  (wording, schedule, cases) into a tested program, or writes one scenario or
  one query for a program you already have, as a background job.

In all three, the Logical English verifier checks what the model has written
before the text reaches you, and tells you about any problem it finds. The
model never decides the answers; your program decides them, when you run it.

Two things in the editor need no model: **Generate LE view** in the LE
Assistant's header, which drafts a view from the program itself (see
[the editor guide](editor.md#generate-le-view-le-assistant)), and the
translators of other systems' files ([importing and exporting](../integrations/index.md)).

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
- One **API key** field per provider. An API key is the pass phrase that lets
  the editor use that provider's models. Where the server already has a key
  for a provider, the field reads *Provided by server* and you cannot change
  it. You need a key of your own only for a provider the server has no key for.
- **Assistant Max Steps (1–50)**: how many turns the LE Assistant's Light
  mode may take over one request. It takes up to 10 unless you change the
  number.

Your browser keeps the keys and the settings in a store of its own, and the
editor sends them with each request that needs them. The same model and keys
serve the LE Assistant and Write it in English. The Contract Assistant page
reads the same stored keys, so a key you set in one place works in both.

If you have selected no model, or the selected model's provider has no key,
the LE Assistant answers with a warning pointing back to this dialog, and
Write it in English switches off its **Generate** button.

## The LE Assistant

The **LE Assistant** tab of the editor's bottom panel is a chat about the
program in the tab in front. Type a request and press **Send** (or Enter),
for example:

- *Fix the errors in this program.*
- *Why does scenario alice give no answer to query one?*
- *Add a rule: a person is a citizen if a parent is a citizen.*
- *Draft a program for the following regulation: …*

While the assistant works, a line under the input box says what it is doing at
that moment, and **Interrupt** stops it. When the assistant has finished, the
panel shows its explanation, laid out with headings and lists. If the
assistant changed the program, the new version replaces the text in the
editor, and the panel says *I have updated the editor content with the
changes.* The whole replacement counts as one edit, so **Undo** in the editor
brings the previous text straight back. A reply may also carry a folded
*System Logs (stderr)* section, which holds the technical record of the run.

Each open tab has a conversation of its own, and a reply comes back to the
program that asked for it, even if you have moved to another tab meanwhile.

You can also ask the assistant about Logical English or about the editor —
*How do I write a decision table?*, *What does "otherwise" do?* The assistant
searches this documentation for what you asked, answers briefly, and ends with
up to three links to the sections that say more. A link opens in a new browser
tab. A request to change the program gets no links.

### Light and Deep modes

The **Light Mode** box in the panel's header chooses how the assistant works.
Your browser remembers the choice.

- **Light** is what you get unless you change it, and it runs on the server
  itself. The server gives the model the Logical English reference and a set
  of example programs. The model can do two things to the program it is
  editing: **verify** it, which loads the program and checks it, and **query**
  it, which runs one query on one scenario. The model then goes round again,
  mending whatever the verifier reported and checking the tests, until either
  it is done or it has used up its allowance of steps. Every request starts
  afresh from the program as it stands in the editor; the earlier messages in
  the panel are not sent again.
- **Deep** runs a full coding assistant on the server, the program
  `opencode`. Deep mode works on a file, with the same two Logical English
  tools, and can also look through files, fetch web pages and run commands.
  Deep mode is slower to start and suits larger pieces of work, such as
  drafting a program from a regulation that has to be researched first. Deep
  mode also remembers the whole conversation of a tab from one request to the
  next. The server must have `opencode` installed for Deep mode to work.

## Write it in English

In the **Scenario Editor** (Edit ▸ Edit Scenarios…) the last entry of the
**Add fact** menu is **Write it in English**. In the **Query Editor** (Edit ▸
Edit Queries…) the same item is the last entry of **Add condition**. Choosing
it opens a dialog:

1. Type one or more sentences, such as *Alice is the mother of John, and John
   was born in the UK on 2021-10-09.* for facts, or a question for a query.
2. Press **Generate** (or Ctrl/Cmd+Enter). The dialog shows which model it
   uses.
3. The model writes facts, or query conditions, using **only the templates
   your program already has**. The model settles the wording and the tense,
   and where your sentence supplies no value it keeps the blank's own words,
   such as `a date`. The editor then checks the result against your program.
   Only problems your program did not already have are counted, and where
   there are such problems the model is asked to correct them, for a few
   rounds.
4. If nothing new is wrong, the result is added straight away as ordinary
   rows, which you can edit. If problems remain, the dialog shows the text
   and the list of problems, errors first. You can then **Insert anyway**, or
   reword your sentence and **Regenerate**. An *[error]* means the text would
   not do what it says, so rewording is usually the better choice.

If your sentence needs a kind of statement the program does not have, add the
template for it first, in the editor or with the LE Assistant.

**From a document.** In the Scenario Editor, the dialog has a folded **From a
document** section. Give the document's name there. You may also give the
address of its text — a web address, or a file beside the program — and press
**Fetch text** to bring the text into the box. Each fact the model then writes
cites the passage that states it, as `confer "…"`, and the scenario names the
document.

## The Contract Assistant

The Contract Assistant is a web page of its own, at
**`/web_extras/contract_assistant/index.html`** on the server. The Contract
Assistant runs longer pieces of work on the server, each within a budget you
set. One run may call the model many times and take anything from minutes to
hours, and what it costs depends on the models and on the effort you choose.

The Contract Assistant needs a model and a key for it (**3. Model**). A key
field appears only for the provider of the model you picked, and only when the
server has no key of its own for that provider. The **Judge model** does just
two things — it merges the vocabulary samples and writes the coverage ledger —
so a cheaper model usually serves. **Additional instructions** and the
**Effort budget** described below apply whichever of the modes you use.

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
  still has `RESIDUE` blocks ([importing and exporting](../integrations/index.md#what-could-not-be-translated)).
  The assistant translates those blocks and nothing else, then runs the
  program's tests. A test that passed before and gives different answers
  afterwards counts as damage the assistant must repair. A test whose answers
  still hold, but now rest on different unknowns, does not count: translating
  a block changes what an answer rests on. You may add background text, such
  as the other system's own documentation, but you need not.
  A program with many blocks is translated about twenty blocks at a time, so
  that each request stays small. A block left as it was, or translated into
  rules that only repeat what the rule using it already checks, counts as not
  done. Where a block names its source (a `% provenance:` line), each rule
  written for it cites that source, as the other rules of the program cite
  theirs. Where a block is translated into a single rule, that rule's
  conditions are then moved into the rules that use the block, and the block
  is removed; this is called folding. The block's text stays as a comment
  above each of those rules, and the program before folding is kept too.
  A block that a scenario mentions by name is not folded.

In the scenario, query and residue modes, the assistant only reads the program
you paste; it never changes it. The assistant does not invent templates.
Where your text needs words the program does not declare, the assistant writes
what it can and notes on the block, in a `%` comment, what it could not
express. You may give the block a **Name**, but you need not.

These three modes do the same work as *Write it in English*, with a budget
behind them: *Write it in English* is a single call to the model and a few
seconds' wait. Use the Contract Assistant when the block matters enough to pay
for more checking.

### A whole program

1. **Documents.** The **contract wording** is required. **Schedule** and
   **cases / claims** are optional and may be several files each. Markdown or
   plain text works best. The server can also convert a Word file (`.docx`,
   using the pandoc tool) and a PDF (using pdftotext), where those tools are
   installed. Schedules and cases may also arrive as JSON or CSV, two common
   ways of writing structured data as text. A JSON list of claims gives one
   case, and so one scenario, for each item in the list.
2. **Target section** (optional, strongly recommended): a section title (that
   section with its subsections, plus the general terms), or a span such as
   `from Employers' liability until Property definitions`, with `(inclusive)`
   to keep the closing section. Leave it empty for the whole wording.
3. **Existing LE code** (optional): templates, scenarios with the answers you
   expect of them, and rules you have already written. The program the
   assistant writes must contain your code and must agree with it. The result
   reports how much of your code came through word for word.
4. **Additional instructions** (optional): anything you care to write, added
   to every request to draft and to every request to repair. Where your
   instructions disagree with the assistant's usual conventions, your
   instructions win. The assistant writes scenarios only for the cases you
   supply, unless your instructions ask for more.
5. **Effort budget**: **Draft** takes about 15 minutes, **Standard** about 45
   minutes and **Thorough** about 2 hours. The three differ in how many
   vocabulary samples are drawn, how many competing drafts are written, and
   how many awkward test cases the winning draft has to face. **Advanced**
   shows each of those numbers and settings, for you to choose yourself. Once
   you have chosen a wording file, the page shows an **estimate of the cost**
   before you start.

Press **Generate Logical English**. The assistant then writes several drafts,
checks each one, and repairs it against the cases, keeping the best draft of
them all. In judging the drafts, the assistant prefers a program that has
tests; among those, one with fewer errors; and among those, one that passes
more of its tests. If you supplied two or more cases, the assistant keeps some
of them back while drafting and scores the result on those unseen cases.

### Running, leaving, coming back

The run screen shows which stage the work has reached, one card per draft with
its errors, warnings and tests, a running record of what is happening, the
time elapsed, and a **Cancel** button. The work goes on inside the server, not
inside the page, so you may close the tab. The page's address carries the run's
identifying name, after the `#`, so opening that address again — or giving it
to someone else — joins the run once more. If you have no such address, the
setup screen lists **Your recent runs** from this browser. The server forgets
its runs when it restarts, though a finished result can still be recovered
from the files it left behind.

### The result

- the Logical English the assistant wrote, with **Copy**, **Download .le** and
  **Open in editor**. For a scenario or a query, **Open in editor** opens the
  new block at the end of the program it was written for, exactly as it was
  checked. A program too large to travel in a web address has to be downloaded
  and opened from the file instead;
- the score of the delivered program, and of each draft;
- for a whole program, the **coverage ledger**: what was encoded, what was
  deliberately skipped, and what is missing;
- reports, where they apply: the test cases that agree with the program and
  those that disagree with it — a disagreement means that either the program
  or the reading of the contract is wrong; how much of your existing code was
  kept; what a new scenario or query answers when it is run against the
  program; and the score for how steadily the program behaves when the same
  question is put in different words.

Read the result as you would read a colleague's draft. The tests show that the
program decides the cases you supplied as you expected, and the ledger shows
what the program does not cover.
