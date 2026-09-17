# How to use the Logical English 2 web application

*Kind: guide · Audience: users · Status: current (2026-09-16)*

The Logical English (LE) web application is a simple IDE designed for developing, testing, and debugging Logical English programs.

## Contents

- [How to use the Logical English 2 web application](#how-to-use-the-logical-english-2-web-application)
  - [Contents](#contents)
  - [Getting Started](#getting-started)
  - [Executive Mode (run a program without editing)](#executive-mode-run-a-program-without-editing)
  - [File Operations](#file-operations)
    - [Opening and Saving](#opening-and-saving)
    - [Other systems' files: import and export](#other-systems-files-import-and-export)
    - [Saving via URL (Quick Save)](#saving-via-url-quick-save)
    - [Several documents: file tabs](#several-documents-file-tabs)
  - [Writing Logic and Issue Reporting](#writing-logic-and-issue-reporting)
  - [Running Queries](#running-queries)
  - [The Scenario Editor](#the-scenario-editor)
    - [Layout](#layout)
    - [Editing facts](#editing-facts)
    - [Write it in English (LLM-assisted)](#write-it-in-english-llm-assisted)
    - [Saving your work](#saving-your-work)
  - [The Query Editor](#the-query-editor)
  - [Scenario Variations](#scenario-variations)
    - [Layout](#layout-1)
    - [Running and sharing](#running-and-sharing)
  - [Generate LE view (LE Assistant)](#generate-le-view-le-assistant)
  - [Explanations and Navigation](#explanations-and-navigation)
    - [Reading the Explanation Tree](#reading-the-explanation-tree)
    - [The Explanation Drill](#the-explanation-drill)
    - [Repeated Sub-explanations](#repeated-sub-explanations)
    - [The Explanation Context Menu](#the-explanation-context-menu)
    - [Explanation Preferences](#explanation-preferences)
    - [Why not: a query with no answer](#why-not-a-query-with-no-answer)
  - [Advanced Features](#advanced-features)
  - [Finding documentation](#finding-documentation)
  - [More guides](#more-guides)

## Getting Started

The landing page (`/`) lists all the example programs, grouped in collapsible
folders. Its URL takes two optional parameters, handy for sharable links:
*   `?dir=<subdirectory>` focuses the list on one example subdirectory (e.g.
    `/?dir=abduction`, or nested, `/?dir=insureLE2/testing`), with a
    "[show all]" link back to the full list.
*   `?expand=all` opens all the folders.

1.  **Open the Editor:** Navigate to the editor URL (e.g., `http://localhost:3050/editor/`).
2.  **The Interface:**
    *   **Top:** Header with filename and module information.
    *   **Middle:** Monaco-based code editor with syntax highlighting and error reporting.
    *   **Bottom:** Multi-tab panel for Queries and the LE Assistant.

## Executive Mode (run a program without editing)

For people who just want to **use** an existing program — ask questions of it and
try different scenarios — rather than write or edit rules, there is a minimalist,
mobile-friendly entry point at **`/executive`** (e.g.
`http://localhost:3050/executive`). The full guide is
[The executive view](executive-view.md); in short:

- **Choose a program.** Opening `/executive` with no parameters shows a filterable
  list of the available example programs; tap one to open it.
- **Pick a scenario and a question.** The program screen has two pickers —
  **Scenario** (the named scenarios in the program, or *(no scenario)*) and
  **Query** (the program's queries). There is no "run" button: the query runs
  when the program opens (on its first scenario) and whenever you change either
  picker, and the answers appear below.
- **See why.** Each answer is a card; tap it to expand its explanation as an
  indented tree (green for what held, with any assumed *unknowns* noted). A
  step that held only because what it denies failed ("it is not the case
  that …") keeps those failures folded.
- **Citations first.** When the program cites its sources (rules and tables
  `with provenance`, facts `as stated in …, confer "…"`), an opened answer
  lists its **cited steps** in the order of the proof — each with the rule,
  the document and the passage — and, where the document's text is known, a
  **§** button that opens the passage in the document's text. **Copy** puts the
  list on the clipboard; **Full explanation** unfolds the whole tree (a link
  beside the list's heading jumps to it, past a long list of citations).
- **Why not.** A query with no answer lists the conditions the case did not
  meet, each marked *not stated* (the case is silent) or *not met* (the case
  says otherwise), with the rule that asks for it, its citation, and the facts
  it compared.
- **Explore variations.** A **Scenario Variations** button between the two
  pickers opens the full [Scenario Variations](#scenario-variations) window on
  the same program, for altering facts and comparing outcomes.
- **Views.** A program that declares views ([the language reference](../reference/language.md) §17.10) lists
  them at the top; a view replaces the two pickers with the screen its author
  described — the case's facts in groups, the result in large type, its
  citations, the stage it reaches, what is missing, what would change it, the
  documents beside it, every case with its result, or an interview asking one
  question at a time. `&view=<name>` opens one directly. A program without
  views of its own offers an **Automatic view**, drawn from the program when
  opened (`&view=*`). How to write one:
  [Introducing LE Views](../tutorials/views.md).
- **Login.** The top right shows **Login** (or the user and **Logout**); a
  logged-in user with the right role also sees the restricted programs.

Everything is driven by the URL, so results are shareable and bookmarkable:
`/executive?program=<name>`, optionally with `&scenario=<name>`,
`&query=<name>` and `&view=<name>`. A link that names a program, a scenario and
a query runs the query immediately on load. The view is read-only — it never
edits the program.

## File Operations

### Opening and Saving
New and the Open operations put the document in a tab of its own; Save and Save As act on the tab in front (see [file tabs](#several-documents-file-tabs) below).

Every menu item has a tooltip saying what it does (hover over it).

*   **New File:** `File > New` opens a new, empty document.
*   **Open Local File:** `File > Open...` allows you to load a `.le` file from your computer. It also opens the files of other systems the server has a translator for: the file is translated on opening, deterministically, into a new tab, with a note saying what was done; a fragment that could not be translated is kept in the program as a `% TODO` comment holding the fragment verbatim. The translation and what it includes or cites are kept on the server for a day. See [Other systems' files](#other-systems-files-import-and-export) below.
*   **Import from Another System:** `File > Import from Another System…` is the same deterministic translation, offering only the other systems' files (its tooltip lists the systems this server translates from; the item is hidden when there are none).
*   **Show the Original:** `File > Show the Original…` shows the files a program was converted from, in the source viewer: by convention the `sources/` folder beside the program, which File > Open keeps for a translated upload (what was uploaded) and the migrations' twins keep for theirs (a Solidity twin's contract, a Socotra product's configuration files, an OIA project's rule documents and rulebase). One file opens directly; several are listed first. A program with no `sources/` folder says so.
*   **View Original Text:** `File > View Original Text`, and the same item of the editor's context menu (right-click on any line of a program), shows where what is under the cursor comes from, in the source viewer, in this order: (a) on a citation (a fact or rule with provenance, a scenario "as stated in" a document, `the text of … is at …`), the cited passage — or the published address, when that is all the program gives; (b) otherwise the rule, fact, decision table, template, scenario or query under the cursor, looked for in the program's originals (its `sources/` folder and the documents it says the text of is at) by the program's own links: its label (`rule ps1:` finds the element whose key is `ps1`, compared without case, `_` and `-`), the entries of its migration ledger (`<program>.ledger.json`) about it, and what it cites — the passage highlighted; (c) otherwise, when the program keeps originals, those, with a note that no passage was located; (d) otherwise a message that the program keeps no original text. For example, in `migration/legalruleml/ex12_usc_17_504_context`, View Original Text inside `rule ps2_tblock1` shows the LegalRuleML statement `ps2-tblock1` of the source.
*   **New from URL:** `File > New from URL...` opens a copy of a Logical English program published at a web address; its `includes these resources:` with relative paths, and the documents it cites, resolve against that address.
*   **Tests:** `Misc > Run the Program's Tests…` runs every expectation of the program and lists each with its outcome (what was expected and what came instead); a row opens its scenario and query.
*   **Open example from server:** `File > Open example from server...` shows the server's examples as a tree of folders, each with its count and what it holds (like `citizenship` at the top, `domains/tax/` or `migration/`); a folder opens with a click, and the editor remembers which are open. Typing in the filter above searches the whole tree by name; the arrow keys walk the matches, showing the first lines of the selected one, and Enter opens it. What opens is a copy: your changes do not touch the server's file.
*   **Save:** `File > Save` or `Save As...` allows you to save your work back to your local filesystem.
*   **Export to Another System:** `File > Export to Another System…` writes the program in another system's format, when the server has an exporter that applies to it (see below).
*   **QR code:** `File > QR code…` shows a QR code, and its URL with **Copy URL**, that opens this document with its selected scenario and query — to continue on a phone, for instance.

> **⚠️ Browser Compatibility:** Direct file saving (writing back to the same file) requires a modern browser that supports the *File System Access API* (e.g., Chrome, Edge). In other browsers (e.g., Safari, Firefox), the "Save" action will instead trigger a **Download** of the file.

### Other systems' files: import and export

With the InsurLE extensions installed (the hosted service has them), the server
translates the files of eleven other systems into Logical English, and writes
Logical English programs in three other systems' formats. Without them, `Import
from Another System…` is hidden and `File > Open...` offers only `.le` files.
Full guide: [Other systems: importing and exporting](../integrations/index.md), with a document for each system.

*   **Importers** (`File > Open...` and `File > Import from Another System…`, whose tooltip lists the systems this server translates from): a Bitcoin Miniscript policy or descriptor; an Oracle Intelligent Advisor project or rulebase; a Socotra product configuration; a Solidity contract (as LE for LPS); an s(CASP) or Prolog program (LE1's s(CASP) translations too); a Blawx project; a Drools rule base (DRL); an Epilog program; a LegalRuleML document; an Oracle Insurance Policy Administration transaction (Rules Palette XML); a Daml source (as LE for LPS).
*   **Exporters** (`File > Export to Another System…`, which offers only those that apply to the program): a Bitcoin Miniscript policy (with a link to the Minsc playground); LegalRuleML; Daml, for an LE for LPS program. The result is shown with its notes, **Copy** and **Save…**.
*   **Refusals.** An exporter that cannot write the program faithfully writes nothing: a dialog lists each problem with its line (a link to it) and the program's words there. **See s(CASP)** and the s(CASP) engine refuse the same way.
*   **The twins.** The translators' results on published programs are among the examples, under `migration/` (Blawx, LegalRuleML, Miniscript, s(CASP)), each with its migration ledger and its `sources/` folder, which **Show the Original** opens.

### Saving via URL (Quick Save)
The editor automatically synchronizes the current code into the browser's URL using a `text` parameter. 
*   **To "Save" a state:** Simply copy the current URL from your browser's address bar.
*   **To "Load" a state:** Paste that URL into a new tab. This is useful for sharing snippets or bookmarking a specific version of your logic.

### Several documents: file tabs
The strip above the editor has one tab per open document, as in a browser: its name, a dot while it has unsaved changes (click the dot, or the `×` that replaces it on hover, to close the tab; a middle click closes it too), and `+` to open a new, empty document in a tab of its own, like `File > New`. A document opened with `File > Open...`, `Open example from server...` or `New from URL...` goes into a new tab too — unless it is open already, in which case its tab comes forward; and the untouched empty document the editor starts with is replaced rather than left behind as an empty tab. `Save` and `Save As...` act on the tab in front.

Each tab's program has panels of its own: clicking a tab brings its document into the editor *and* its program into the **Query** panel (scenarios, queries, answers and explanation, as you left them), the **LE Assistant** (its own conversation) and the Source Graph. The address bar follows: it names the example (or carries the text) of the program in the panels, with its scenario and query.

Clicking an explanation node proved by a rule of an **included resource** opens that resource in a tab of its own (or brings its tab forward) at the rule — but the panels stay on the program being explained, so you can keep following the explanation; the tab of that program is then marked with a dotted underline. A click on one of the program's own nodes brings its tab back. Choosing the resource's tab yourself makes it the program in the panels.

While a program is loading on the server the scenario and query pickers show a busy cursor; a click on one of them waits for the load (the whole window shows a waiting cursor) and then opens the menu.

## Writing Logic and Issue Reporting

As you type, the editor performs real-time verification:
*   **Syntax Highlighting:** Keywords, variables, and templates are colored for readability.
*   **Error Reporting:** Red squiggly lines indicate syntax errors or missing templates.
*   **Quick Fixes:** Hover over an error to see suggested fixes (e.g., automatically adding a missing template).
*   **Status:** The "Query" button in the bottom panel is disabled if the document contains errors.
*   **Show definition (F12):** right-click a word and choose **Show definition** to go to the rule or template that defines it; on the name of an included resource (`… includes these resources: deontic.`) or of a base (`… extends token:`) it opens that resource — a Logical English one in a tab of its own, a Prolog one in the source viewer. **Go back** returns.
*   **Where it is explained:** the hover of a warning or error ends with a link — to the section of the language reference its message cites, or to its entry in the [warnings guide](warnings.md).

A **?** beside the query controls, the answers, the explanation, the LE Assistant, and at the top of the Scenario Editor, Query Editor, Scenario Variations, Explanation Drill, Proof Game and executive view opens the section of the documentation about that part.

![Editor Selection](images/an_editor_selection.png)

## Running Queries

1.  **Load the Module:** The editor proactively loads your code onto the server. You can see the session ID in the top header.
2.  **Select Scenario:** In the **Query** tab, select a scenario defined in your code (e.g., `scenario alice is:`). You can also select "Another..." to type custom facts.
3.  **Select Query:** Select a query defined in your code (e.g., `query one is:`).
4.  **Execute:** Click the **Query** button. A query still running after a couple of seconds shows **Interrupt**; one that has not finished after 4 minutes is stopped by the server, which says so in the answers (a rule may loop, or the search may be too large).
5.  **Flip the outcome:** **Flip…** asks which minimal change to the scenario would change the answer. Select an answer first: the dialog proposes *which minimal change to the scenario makes it the case that it is not the case that* the answer (untick **it is not the case that** to ask for the answer itself, or edit the sentence — to aim at a different answer, say). With no answer, it proposes the query. **Flip** runs it as a custom query on the selected scenario: each answer is a set of facts to add or remove (`add: …`, `remove: …`), explained by the proof the changed scenario then gives. See the language summary, §17.7.

## The Scenario Editor

A scenario is a named set of facts your queries run against. The **Scenario Editor** lets you build and edit these scenarios as **fill-in-the-blank forms** instead of typing the facts by hand, so you never have to remember a template's exact wording. Open it from **Edit → Edit Scenarios…**; it opens in a separate window.

### Layout

*   **Top:** a **Scenario** picker — choose **New…** to start a fresh scenario, or pick an existing one to load it for editing — and a **Name** field (the scenario's name in your program).
*   **Middle:** a vertical list of the scenario's facts, one per row.
*   **Bottom:** an **Add fact** picker, and the **Copy** / **Insert into Editor** buttons.

### Editing facts

Each fact is shown as one row built from a template: the template's fixed words are plain **labels**, and each placeholder is an editable **field**. For the template `*a person* is born in *a place* on *a date*` a fact reads:

> `[a person]` is born in `[a place]` on `[a date]`

Only the placeholders are editable — you can't accidentally break the surrounding wording. Each field's **hint text** is the template variable it stands for (e.g. *a person*), and fields grow to fit their contents. Where the program's rules read particular values in a place (*knitted*, *woven*, … for a fabric construction), the field **suggests** them as you type, and its tooltip lists them. Loading an existing scenario fills the fields in automatically by recognising each fact's template.

*   **Cite the passage.** The **❝** button on a row opens a field for where the document states the fact: type the passage and it is written as `confer "…"` (the scenario's **Provenance** names the document), or type trailers of your own (`according to …`, `as stated in … at …`). A fact that already has a citation shows it, editable.

*   **Add a fact:** pick a template from the **Add fact** menu and click **+ Add**, then fill in the fields. The menu lists only templates that make sense as scenario facts: those declared **`; undefined`** (a.k.a. *scenario element*) and those already used by some scenario. Plain "*X* is a *type*" assertions are also supported.
*   **Delete a fact:** click the **✕** on its row.
*   **Assume (unknown):** each row has an **Assume** checkbox on the right. Tick it to mark the fact *unknown* — the fact is written back with the `it is unknown whether …` prefix and its fields become read-only while assumed. A fact the program already declares unknown loads with **Assume** pre-checked; untick it to turn it back into an ordinary fact.
*   **Test lines** (`… expects answers …`) are too complex for this form, so they are not shown. They are kept aside and written back **commented out** (so your saved scenario is valid); review and re-enable them in the main editor.
*   **Other lines that match no template** are shown greyed-out and read-only so they are preserved; edit those in the main editor. Comments (`%`) are ignored.

### Write it in English (LLM-assisted)

Instead of picking a template, choose **Write it in English** (the last entry in the **Add fact** menu) to add facts by describing them in plain language. A dialog opens; type one or more sentences describing precise facts, and an LLM turns them into Logical English facts that use **your program's existing templates**, adding them as ordinary editable rows.

*   **Respects your templates.** The model only fills in the templates you already have — it won't invent predicates. It also normalises wording and tense (e.g. "Miguel *was* born in Portugal" → `Miguel is born in Portugal on a date`) and, where the sentence leaves a placeholder unspecified, keeps the placeholder's own words (like `a date`) for you to fill in. If you need new predicates first, add them in the main editor or with the **LE Assistant**.
*   **You need an LLM configured** — the same model and API keys as the LE Assistant. Set them in the main editor under **Misc → API Keys & Assistant Settings…**; the dialog shows which model it will use, or a hint if none is set. More in [The assistants](assistants.md#write-it-in-english).
*   **Verified before it's added.** The proposed facts are checked against your program (baseline-diffed, so only *new* problems count). If the result verifies clean it is added straight away; if it introduces new issues you are **warned** but can still **Insert anyway**, or rephrase and **Regenerate**.

### Saving your work

*   **Copy:** copies the whole scenario block (`scenario <name> is:` followed by its facts) to the clipboard, ready to paste anywhere.
*   **Insert into Editor:** writes the scenario back into the main editor — **replacing** the scenario you loaded, or **appending** a new one — and closes the Scenario Editor window.

The Scenario Editor does not itself check your Logical English: as with any edit, the **final syntax check happens on the server** the next time the editor loads the module, and any problems are reported as usual. If you try to close the window with unsaved changes (not yet copied or inserted), it asks you to confirm first.

## The Query Editor

The **Query Editor** builds and edits queries the same way the Scenario Editor builds scenarios — as fill-in-the-blank rows instead of hand-typed syntax. Open it from **Edit → Edit Queries…**; it opens in a separate window. Pick **New…** to start a fresh query or an existing query to load it, and give it a **Name**.

A query is a list of **conditions**, each an instance of one of your templates (fill in its placeholder fields, or type `which person` to ask for a value to return). You control how they combine:

*   **Add condition:** pick a template and click **+ Add**, then fill in the fields. Each condition after the first has an **and / or** selector before it (**and** by default), so a sequence like *A and B or C* reads top to bottom.
*   **Negate** a condition with its **not** checkbox — it is written as `it is not the case that …`.
*   **Indent** (⇥ / ⇤) a condition to **nest** it, which reflects the intended **and/or scoping** (a more-indented condition binds tighter), exactly as Logical English uses indentation.
*   **Write it in English:** the last entry in the **Add condition** menu opens the same LLM-assisted dialog as the Scenario Editor — describe the query in plain language and its conditions are generated (and verified) from your templates and appended. See [Write it in English](#write-it-in-english-llm-assisted).
*   **Copy** puts the `query <name> is:` block on the clipboard; **Insert into Editor** writes it back — **replacing** the query you loaded or **appending** a new one.

The Query Editor keeps things simple and does not cover the full LE body-condition syntax (nested groups, aggregates, etc.); use the main editor for those. As with the Scenario Editor, the **final syntax check happens on the server** when the module next loads.

## Scenario Variations

The **Scenario Variations** window lets you take a scenario, **alter it**, and immediately run one or more queries against the variation — without touching your program. It is ideal for "what-if" exploration ("what if Alice were *not* a citizen?"). Open it with the **Scenario Variations** button in the **Query** tab (between **Query** and **Trace**); it opens in a separate window, preselected with whatever scenario was chosen in the Query tab.

### Layout

*   **Scenario picker** (top): choose which scenario to start from, or `(empty)` to build one from scratch.
*   **Scenario facts:** the same fill-in-the-blank form as the [Scenario Editor](#the-scenario-editor) — edit the placeholder fields, delete facts, **Add fact** from a template, or tick **Assume** to run a fact as *unknown*. **Copy Scenario** puts the resulting `scenario … is:` block on the clipboard.
*   **Queries:** a list of the queries to run. Use **Add Query** to add one of your program's queries; each query has a close box (✕) to remove it.
*   **Query** button (bottom): runs **all** the listed queries against the current (altered) facts. Under each query you get the familiar **answers + explanation** view — including unknown-goal tooltips and clickable explanation nodes, which **reveal the matching source in the main editor window**.

### Running and sharing

Click **Query** to run everything. The button then disables itself and re-enables only when you change something (an edit to the facts, or to the query list), so you always know whether the results below are current.

As you edit, the window keeps its **URL in sync** — the altered scenario, the query list and the program are all encoded in the address. Copy that URL to **share exactly what you are exploring** with someone else, just like sharing a program from the editor.

## Generate LE view (LE Assistant)

The **Generate LE view** button in the LE Assistant's header drafts a view for
the program ([the language reference](../reference/language.md) §17.10) and appends it: the facts a case can
state as one group, the judged facts apart, the first query as the result,
and what the program can show (citations, the stage, documents, a flip). It
needs no language model. Edit it — group the facts under titles, head the
result by the value that matters, add questions for an interview — or send
the refinement the assistant's input then proposes. The verifier checks what
a view names. The reply's **Open the view** link opens it in the executive
view as it is in the editor, without saving. A program whose knowledge base
has no name takes its file's name for the view. Templates worded with a comma
or full stop are left out, since a view's lists cannot hold them. Tutorial:
[Introducing LE Views](../tutorials/views.md).

## Explanations and Navigation

Once a query is executed:
*   **Answers:** A list of results appears in the left side of the bottom panel.
*   **Explanation Tree:** Clicking an answer displays a natural language justification tree on the right. When a query has *no* answer, the tree explains *why* it failed.
*   **Navigation to Source:**
    *   Clicking any node in the explanation tree will automatically scroll the editor to the corresponding rule or fact in your source code — in the tab of an included resource when the rule is there (see [file tabs](#several-documents-file-tabs)).
    *   The selected range will be highlighted in the editor, allowing you to quickly verify the logic.

### Reading the Explanation Tree

*   **Node colours** show each node's status: **green** for a condition that *succeeded*, **red** for one that *failed*, and **amber** for an *unknown* condition (one that could not be proven true or false, but was assumed true because it matches an "unknown" template).
*   **Type tooltips:** Hover over any node to see a description of its status (e.g. "Succeeded: this condition was proven", "Failed: this condition could not be proven"). A negated condition that holds reads "Succeeded: this negative condition holds (the inner statement could not be proven)".
*   **Expand / collapse:** Nodes with sub-steps show a `-`/`+` toggle; the top two levels are expanded by default. Expansion state is remembered per answer while you switch between answers.
*   **Hierarchical numbering:** Turn on **Misc → Hierarchical Numbering** to prefix each node with its position in the tree (e.g. `1.2.3`).
*   **Important reason:** hover the **EXPLANATION** title (shown underlined when available) for a one-line summary of the selected answer. It reflects the tree as displayed (so it honours your repeated-sub-explanations preference). Right-click the title and choose **Show important reason** to expand the tree to that node and flash it.

### The Explanation Drill

The **Explanation Drill** is a separate, non-modal window that walks you through an answer's explanation as a guided sequence of yes/no questions — to help you find, and understand, the reason that matters to you. Open it by right-clicking the **EXPLANATION** title and choosing **Explanation Drill…**.

It treats the explanation as a "suspects tree" and, at each step, shows the **important reason** of the current region and asks **"Accept?"**:

*   **Yes** — you understand that part; it is set aside and the drill moves on to the next most important reason of what remains.
*   **Not yet** — you want to dig deeper; the drill descends into that reason and asks about *its* most important part.

The window is headed by *"Understanding why …:"* (the goal being explained) and a **progress bar** that fills as you mark parts understood. Every question keeps its answer (Yes / Not yet / unanswered), so you can revise an earlier one at any time — the drill re-questions from there. Each question also has a **✕** to delete it: that answer is dropped, the others are kept, and the drill re-derives what to ask next. Each new question **highlights its source** in the main editor (without taking focus away from the drill), and clicking any question card re-selects its source there. Once every part of a reason answered *Not yet* is accepted, that reason counts as accepted and the drill returns to the reasons still open around it (the answer's other conditions, for instance). When everything is accepted, the bar is full and it says *"Nothing else to show."*

### Repeated Sub-explanations

Large success — and especially failure — trees often contain the same sub-explanation many times. By default these are collapsed:

*   A sub-explanation that occurs several times is shown **once, in italics**, keeping its normal green/red/amber colour. Its tooltip reports how many times it occurred ("N repeated sub-explanations", or "N repeated occurrences" for a leaf condition that has no sub-steps).
*   **Go to full sub-explanation:** Some repeats stand in for a copy that *is* shown in full elsewhere in the tree. These carry a small `↩` marker; **right-click → "Go to full sub-explanation"** scrolls to that full copy, expanding any collapsed ancestors and briefly highlighting it. Repeats with no fuller copy anywhere (e.g. a plain repeated leaf) have no marker and no such menu item.
*   This collapsing is controlled by the **Hide repeated explanations** preference (on by default); turn it off to see every occurrence in full.

### The Explanation Context Menu

Right-click in the explanation tree for:

*   **Copy Explanation:** Copies the whole tree (all sibling subtrees) to the clipboard as both plain text and HTML, ready to paste into a document.
*   **Copy as Mermaid diagram:** Copies the whole tree as a [Mermaid](https://mermaid.js.org) flowchart (text), ready to paste anywhere Mermaid is rendered — GitHub, Obsidian, Notion, mermaid.live — with succeeded, failed and assumed (unknown) nodes in the tree's green/red/amber. Also available in the Scenario Variations explanation menu.
*   **Go to full sub-explanation:** Shown only on a repeated node that has a full copy elsewhere (see above).

### Explanation Preferences

Open **Misc → EXPLANATIONS → Preferences...** to configure:

*   **Prefix for failed nodes:** Text prepended to failed nodes when copying an explanation (handy when pasting into a context that loses colour).
*   **Detailed failure explanations (per-rule nodes):** When on, a failed predicate proven by several rules shows an intermediate node per rule (each navigable to that rule), with each rule's failed sub-goals beneath it. Slower; off by default.
*   **Hide repeated explanations:** As described above; on by default.
*   **Larger important reasons:** When on (the default), the important reason of a failed query lists all of its deepest failed conditions ("it is not the case that X, nor that Y, nor that Z", cut after the third) instead of the first only.

### Why not: a query with no answer

In the editor, a query with no answer shows **No answers (false)** and its failure explanation: the conditions that were tried, the failed ones in red. When the program's rules are in the sections *applicability*, *question* and *remedy* ([the language reference](../reference/language.md) §17.4), the first node is the section checklist ("applicability passed, question failed, remedy not reached"). **Detailed failure explanations** (above) adds a node per rule attempted.

The [executive view](executive-view.md#when-there-is-no-answer-why-not), and a view that `shows its reasons`, say it shorter, as **Why not**: only the conditions the case did not meet, taken from the ways of reaching the answer that came closest (those in which the most conditions held). Each is marked **not stated** (a fact the case could state but does not) or **not met** (a test false on the case's values, a fact the case states otherwise, a negation whose subject holds), with the rule that asks for it, the rule's citation, and the facts it compared. To see it for the program in the editor, use **Misc → Open Executive View**. The tutorial [Querying a program](../tutorials/querying-a-program.md) works through failed queries on an example.

## Advanced Features

*   **Executive view:** ([guide](executive-view.md)) **Misc → Open Executive View** opens the executive view of the program in a new tab, on the scenario and query picked in the editor, with the program's views listed at the top. It shows the program as it is in the editor, unsaved changes included (the text goes to the new tab through the browser's storage, so a link copied from it shows the saved program in another browser).
*   **LPS programs:** a document that declares `the target language is: lps.` runs in time rather than answering queries, so the query bar shows two buttons instead. **Run in LPS** (also **Misc → Run in LPS**) opens the Logical English → LPS page with the document as it is in the editor and runs it with the LPS engine (LPS2, which must be running: `LPS_LE2_LIB=<this checkout> ./lps ide` in the LPS2 checkout) — timeline, state changes, explanations. **Legal View** (also **Misc → Legal View of This LPS Program**) opens, in a new tab, the program's *legal view* (`le_lps_legal.pl`): each action's integrity constraints as one rule saying who may perform it, each causal law as an effect rule (`… transferring … results in the balance of … being …`), the fluents as scenario elements — an ordinary Logical English program, with the program's own calls as queries (may it happen? what does it change? a flip query: what would have to change for it to be allowed?). It is computed each time, never stored. When the LPS server is running, it draws the view from the program's run: one scenario per call of the program's scenario, holding the state just before that call, with the call's questions as expectations (may it happen — exactly when the run accepted it; what it changes) — so **Misc → Run the Program's Tests…** on the view checks it against the program. Without the LPS server, the view has the program's initial state as its one scenario. Constraints on two actions at once, and actions nothing in the program governs, are stated as comments rather than turned into permissions.
*   **Source Graph:** **Misc → View Source Graph** opens, in a new browser tab, an interactive graph of the program: templates, rules, facts, scenarios, types and queries as nodes, with their uses/depends-on/negates/is-a relationships as edges. A sidebar selects the layout algorithm, its direction, and which layers (node and edge types) to show — these preferences persist across sessions. Clicking a node highlights its source text back in the editor (and the editor caret focuses the corresponding node); right-clicking a node offers **Copy Node** (copies its text to the clipboard), **Copy URL** (a shareable link focusing that node) and **Redraw from here**. The **Copy Mermaid** toolbar button copies the *visible* graph (the current layers and scenario filter, in the selected direction) as a [Mermaid](https://mermaid.js.org) flowchart — scenarios become subgraphs around their facts — ready to paste into GitHub, Obsidian, or any Mermaid renderer.
*   **LE Assistant:** Use the **LE Assistant** tab to ask questions about your code or request help with drafting new rules. The **Light Mode** checkbox in its header chooses between a fast assistant that runs on the server (Light, the default) and a full coding agent (Deep). It needs a model and an API key, set in **Misc → API Keys & Assistant Settings…**. See [The assistants](assistants.md), which also covers the Contract Assistant web page.
*   **s(CASP) engine:** the **Engine** picker beside the query (shown according to **Misc → ENGINE PICKER**) runs a query with s(CASP) instead of Prolog; right-click in the editor and select **See s(CASP)** to view the translation. A program s(CASP) cannot state faithfully is refused, with the list of problems. See [s(CASP)](../reference/scasp.md).
*   **Proof Game:** the **Proof Game** button in the Query tab opens a game in which you build the proof of the selected query yourself. See [the Proof Game](proof-game.md).
*   **Debugger:** Right-click in the editor and select **See PROLOG** to view the translated logic, or use the **Trace** button in the Query tab for step-by-step execution. Click in the margin left of a line number to set a breakpoint (a red dot). In the debug panel, **Step** (F11) goes to the next goal, **Step over** (F10) to the next one at the same level or above, **Continue** (F5) to the next breakpoint or answer, and **Stop** ends the query. The call stack and the current goal's variables follow each stop.

## Finding documentation

*   **Search:** **Help ▸ Search the documentation…**, the search box at the top of every document, and the one under *Documentation* on the landing page search the text of every user document. All the words must occur in a section, and a phrase in quotes must occur as written; the results are the sections, grouped by document, best first (a word in a heading counts most), always in the same order for the same words. A link at the foot repeats the search in the LPS2 documentation.
*   **Documentation for this:** right-click on a word of the program and choose **Documentation for this**. It searches for what the word *is*, not for its letters: a variable (`X`, `a person`) finds the documentation about variables, a date the one about dates, a word of a template the one about templates, a keyword (`if`, `it is not the case that`, `the templates are:`) that keyword. With a selection wider than one word, it searches for the selection as written. The results page offers the word itself as a search of its own.
*   **Other systems:** **Help ▸ Other systems: import and export** opens the [map of the integrations](../integrations/index.md), with a document for each system.

## More guides

*   [The executive view](executive-view.md): running a program without its text, citations, why not, views, links.
*   [Other systems](../integrations/index.md): a map of the integrations, a document per system, other systems' files, exports and refusals, the migration twins.
*   [The assistants](assistants.md): the LE Assistant, Write it in English, the Contract Assistant.
*   [Querying a program](../tutorials/querying-a-program.md): a tutorial on queries, explanations, variations, flips and the Explanation Drill.
*   [The Proof Game](proof-game.md) and [the verifier's warnings](warnings.md).
