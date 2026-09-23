# How to use the Logical English 2 web application

*Kind: guide · Audience: users · Status: current (2026-09-20)*

The Logical English (LE) web application is a simple IDE — an integrated development environment, meaning one screen where you write a program, run it and look for mistakes. You use it to write, test and correct Logical English programs.

## Contents

- [How to use the Logical English 2 web application](#how-to-use-the-logical-english-2-web-application)
  - [Contents](#contents)
  - [Getting Started](#getting-started)
  - [Executive Mode (run a program without editing)](#executive-mode-run-a-program-without-editing)
  - [File Operations](#file-operations)
    - [Opening and Saving](#opening-and-saving)
    - [Other systems' files: import and export](#other-systems-files-import-and-export)
    - [Example names, and the names they used to have](#example-names-and-the-names-they-used-to-have)
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

The landing page (`/`) lists all the example programs, grouped in folders you
can open and close. You can add two optional settings to the page's URL (its
web address), which is handy when you want to share a link:
*   `?dir=<subdirectory>` narrows the list to one example subdirectory (for
    example `/?dir=abduction`, or a folder inside a folder,
    `/?dir=insureLE2/testing`), with a "[show all]" link back to the full list.
*   `?expand=all` opens all the folders.

1.  **Open the editor:** go to the editor's address (for example, `http://localhost:3050/editor/`).
2.  **What is on the screen:**
    *   **Top:** a header naming the file you are editing and the program the server has loaded.
    *   **Middle:** the writing area, built on the Monaco editor. The writing area colours the words of the language and marks mistakes.
    *   **Bottom:** a panel with tabs, one for Queries and one for the LE Assistant.

## Executive Mode (run a program without editing)

Some people only want to **use** an existing program: to ask it questions and
try different scenarios, rather than write or change rules. For them there is a
plain screen, made to work well on a phone, at **`/executive`** (for example
`http://localhost:3050/executive`). The full guide is
[The executive view](executive-view.md). In short:

- **Choose a program.** Opening `/executive` with nothing added to the address
  shows a list of the available example programs, which you can narrow by
  typing; tap one to open it.
- **Pick a scenario and a question.** The program screen has two pickers —
  **Scenario** (the named scenarios in the program, or *(no scenario)*) and
  **Query** (the program's queries). There is no "run" button. The query runs
  when the program opens, on its first scenario, and again whenever you change
  either picker. The answers appear below.
- **See why.** Each answer is a card. Tap the card to open its explanation as an
  indented tree, green for what held, with any assumed *unknowns* noted. A
  step that held only because what it denies failed ("it is not the case
  that …") keeps those failures folded away.
- **Citations first.** A program can cite its sources: rules and tables
  `with provenance`, facts `as stated in …, confer "…"`. For such a program, an
  opened answer lists its **cited steps** in the order of the proof, each with
  the rule, the document and the passage. Where the text of the document is
  known, a **§** button opens the passage in that text. **Copy** puts the
  list on the clipboard. **Full explanation** unfolds the whole tree, and a link
  beside the list's heading jumps straight down to it, past a long list of
  citations.
- **Why not.** A query with no answer lists the conditions the case did not
  meet, each marked *not stated* (the case is silent) or *not met* (the case
  says otherwise), with the rule that asks for it, its citation, and the facts
  it compared.
- **Explore variations.** A **Scenario Variations** button between the two
  pickers opens the full [Scenario Variations](#scenario-variations) window on
  the same program, for altering facts and comparing outcomes.
- **Views.** A program can declare views ([the language reference](../reference/language.md) §17.10),
  and a program that declares them lists them at the top. Choosing a view
  replaces the two pickers with the screen the view's author described: the
  case's facts in groups, the result in large type, its citations, the stage it
  reaches, what is missing, what would change it, the documents beside it,
  every case with its result, or an interview asking one question at a time.
  Adding `&view=<name>` to the address opens one view directly. A program with
  no views of its own offers an **Automatic view**, which the executive view
  draws from the program as it opens it (`&view=*`). How to write a view:
  [Introducing LE Views](../tutorials/views.md).
- **Login.** The top right shows **Login** (or the user and **Logout**); a
  logged-in user with the right role also sees the restricted programs.

The web address holds everything the screen is showing, so you can share a
result or keep it as a bookmark: `/executive?program=<name>`, and, if you want
them, `&scenario=<name>`, `&query=<name>` and `&view=<name>`. A link that names
a program, a scenario and a query runs the query as soon as the page opens. The
executive view only reads the program; the executive view never changes it.

## File Operations

### Opening and Saving
New and Open each put the document in a tab of its own. Save and Save As act on the tab in front (see [file tabs](#several-documents-file-tabs) below).

Every menu item has a tooltip saying what it does (hover over it).

*   **New File:** `File > New` opens a new, empty document.
*   **Open Local File:** `File > Open...` loads a `.le` file from your computer. `File > Open...` also opens files written for other systems, whenever the server knows how to translate them. The server translates such a file as it opens it, into a new tab, and adds a note saying what it did; the same file always gives the same translation. A piece the server could not translate stays in the program as a `% TODO` comment holding that piece word for word. The server keeps the translation, and whatever the translation includes or cites, for one day. See [Other systems' files](#other-systems-files-import-and-export) below.
*   **Import from Another System:** `File > Import from Another System…` does the same translation, and in the same reliable way, but offers only the other systems' files. Its tooltip lists the systems this server translates from, and the menu item is hidden when there are none.
*   **Show the Original:** `File > Show the Original…` shows, in the source viewer, the files a program was converted from. Those files live by convention in the `sources/` folder beside the program. `File > Open` puts what you uploaded there when it translates an upload, and the translated twins of other systems' programs keep their own originals there too: a Solidity twin's contract, a Socotra product's configuration files, an OIA project's rule documents and rulebase. A single file opens directly; where there are several, they are listed first. A program with no `sources/` folder says so.
*   **View Original Text:** `File > View Original Text` shows, in the source viewer, where the line under the cursor came from. The editor's own menu offers the same item when you right-click on any line of a program. The editor tries four things, in this order.
    (a) If the cursor is on a citation — a fact or rule with provenance, a scenario "as stated in" a document, or `the text of … is at …` — the viewer shows the cited passage. Where the program gives only the address at which the document is published, the viewer shows that address.
    (b) Otherwise the editor takes the rule, fact, decision table, template, scenario or query under the cursor, and looks for it among the program's originals: the `sources/` folder and the documents the program says the text of is at. It follows the program's own links to find the passage, and then highlights the passage it found. Those links are: the element's label (`rule ps1:` finds the element whose key is `ps1`, compared without regard to capitals, `_` and `-`); the entries about it in the program's migration ledger, the file `<program>.ledger.json` that records what each piece was translated from; and whatever the element cites.
    (c) If the editor finds no passage but the program does keep originals, the viewer shows the originals, with a note saying that no passage was located.
    (d) If the program keeps no original text at all, the viewer says so.
    For example, in `migration/legalruleml/ex12_usc_17_504_context`, View Original Text inside `rule ps2_tblock1` shows the LegalRuleML statement `ps2-tblock1` of the source.
*   **New from URL:** `File > New from URL...` opens a copy of a Logical English program published at a web address. Where that program's `includes these resources:` names a file by a path relative to itself, and where it cites documents, the editor looks for them beside that address.
*   **Tests:** `Misc > Run the Program's Tests…` runs every expectation the program states and lists each one with its outcome: what was expected, and what came instead. Clicking a row opens that expectation's scenario and query.
*   **Open example from server:** `File > Open example from server...` shows the server's examples as a tree of folders. Each folder says how many examples it holds and what they are about — `citizenship` at the top, for instance, or `domains/tax/` or `migration/`. A click opens a folder, and the editor remembers which folders you left open. Typing in the box above searches the whole tree by name; the arrow keys move through the matches, showing the first lines of the one selected, and Enter opens it. What opens is a copy, so your changes never touch the server's own file.
*   **Save:** `File > Save` or `Save As...` saves your work back to your own computer.
*   **Export to Another System:** `File > Export to Another System…` writes the program out in another system's format, whenever the server has a writer for a system the program suits (see below).
*   **QR code:** `File > QR code…` shows a QR code that opens this document with the scenario and query you have chosen — so that you can carry on with it on a phone, for instance. **Copy URL** copies the same address as plain text.

> **⚠️ Browser Compatibility:** Saving straight back to the file you opened needs a recent browser: one that lets a web page write to a file on your computer, through the arrangement called the *File System Access API*. Chrome and Edge do this. In other browsers, such as Safari and Firefox, "Save" downloads the file instead.

### Other systems' files: import and export

A server with the InsurLE extensions installed — the hosted service has them —
translates the files of eleven other systems into Logical English, and writes
Logical English programs out in three other systems' formats. A server without
the extensions hides `Import from Another System…`, and its `File > Open...`
offers only `.le` files.
Full guide: [Other systems: importing and exporting](../integrations/index.md), with a document for each system.

*   **What the server reads in** (`File > Open...` and `File > Import from Another System…`, whose tooltip lists the systems this server translates from): a Bitcoin Miniscript policy or descriptor; an Oracle Intelligent Advisor project or rulebase; a Socotra product configuration; a Solidity contract (read in as LE for LPS — Logic Production System, the companion system for rules that act over time); an s(CASP) or Prolog program (including LE1's s(CASP) translations); a Blawx project; a Drools rule base (DRL); an Epilog program; a LegalRuleML document; an Oracle Insurance Policy Administration transaction (Rules Palette XML); a Daml source (read in as LE for LPS).
*   **What the server writes out** (`File > Export to Another System…`, which offers only the formats the program can be written in): a Bitcoin Miniscript policy, with a link to the Minsc playground; LegalRuleML; and Daml, for an LE for LPS program. The result is shown with its notes, and with **Copy** and **Save…** buttons.
*   **Refusals.** When the server cannot write the program faithfully in the chosen format, it writes nothing at all. A dialog then lists each problem with the line it is on — the line number is a link — and the program's words there. **See s(CASP)** and the s(CASP) engine refuse in the same way.
*   **The twins.** The examples include the translators' results on published programs, under `migration/`: programs from Blawx, LegalRuleML, Miniscript and s(CASP). Each twin comes with its migration ledger (the record of what was translated from what) and its `sources/` folder, which **Show the Original** opens.

### Example names, and the names they used to have

An example is opened by **name**: `/editor/index.html?example=<name>`, and the
same name names it to the executive view (`/executive?program=<name>`), the QR
code, the landing page and the web API. The name is the example's path inside
the example tree, without the `.le` — `citizenship`, `domains/tax/payg`,
`collections/kowalski-book/underground_emergency`,
`regulatory/eu261_integration`.

**An example that moves keeps its old name.** The example folders were
regrouped by purpose, and every link, QR code, paper and video written before
the regrouping still works, because the server sends an old name on to the
current one. So `?example=rkBook/underground_emergency` opens
`collections/kowalski-book/underground_emergency`. The old names are listed in a
table in the server: `example_alias/2` for a single example and
`example_dir_alias/2` for a whole directory, both in `le_kbs.pl`. The test
`testing/test_example_alias.pl` checks that every row of the table still leads
to a file that exists.

The directory renamings are these — each applies to everything under it:

| Old name | Opens today |
|---|---|
| `abduction/…` | `language/abduction/…` |
| `prolog_resources/…` | `language/includes/prolog_resources/…` |
| `tax/…` | `domains/tax/…` |
| `rkBook/…` | `collections/kowalski-book/…` |
| `LogicalThinkingInAgeOfAI/…` | `collections/logical-thinking-talk/…` |
| `RulesRus/…` | `regulatory/…` |
| `testing/…` | `fixtures/…` (the test fixtures, listed to logged-in users) |
| `insureLE2/customs/…` | `lpsPlus/customs/…` |
| `insureLE2/medicare/…` | `lpsPlus/medicare/…` |
| `insureLE2/migration/…` | `lpsPlus/migration/…` |

Individual programs that moved on their own — `sums`, `citizenship_including`,
`white_rabbit` and about thirty others — have one `example_alias/2` row each,
and that table is the full list. You need do nothing to use an old name: the
old name simply opens the example.

### Saving via URL (Quick Save)
The editor keeps a copy of the program you are editing in the browser's own address, in a part of the address called `text`. 
*   **To "save" where you are:** copy the current address from your browser's address bar.
*   **To "load" it again:** paste that address into a new tab. Pasting the address back is a handy way to share a short piece of a program, or to bookmark one particular version of your rules.

### Several documents: file tabs
The strip above the editor has one tab per open document, much as a browser has one tab per page. A tab shows the document's name, and a dot while the document has changes you have not saved. To close a tab, click that dot, or the `×` that takes its place when the mouse is over it; a middle click closes the tab too. The `+` at the end of the strip opens a new, empty document in a tab of its own, just as `File > New` does. A document opened with `File > Open...`, `Open example from server...` or `New from URL...` also goes into a new tab — unless the document is open already, in which case its tab simply comes forward. The empty document the editor starts with is replaced rather than left behind as an empty tab, as long as you have not typed in it. `Save` and `Save As...` act on the tab in front.

Each tab's program has panels of its own. Clicking a tab brings that document into the editor, and at the same time brings its program into the **Query** panel — scenarios, queries, answers and explanation, just as you left them — into the **LE Assistant**, which keeps a conversation of its own per program, and into the Source Graph. The address bar follows along: the address names the example now in the panels, or carries its text, together with its scenario and query.

A rule of an **included resource** may prove a step of an explanation. Clicking that step opens the resource in a tab of its own, at the rule, or brings its tab forward if the resource is already open. The panels stay on the program being explained, so that you can keep following the explanation, and the tab of that program is marked with a dotted underline. Clicking one of the program's own steps brings its tab back. If you choose the resource's tab yourself, the resource becomes the program in the panels.

While the server is loading a program, the scenario and query pickers show a busy cursor. If you click one of them, the whole window shows a waiting cursor until the program has loaded, and the menu then opens.

## Writing Logic and Issue Reporting

The editor checks the document as you type:
*   **Colours:** the editor colours keywords, variables and templates, so that they are easy to tell apart.
*   **Mistakes:** a red wavy underline marks a sentence the editor cannot read, or a template that is missing.
*   **Quick fixes:** rest the mouse on a mistake to see the repairs the editor offers, such as adding the missing template for you.
*   **When you can run:** while the document still has mistakes, the editor switches off the "Query" button in the bottom panel.
*   **Show definition (F12):** right-click a word and choose **Show definition** to go to the rule or template that defines that word. On the name of an included resource (`… includes these resources: deontic.`) or of a base (`… extends token:`), **Show definition** opens the resource itself: a Logical English resource in a tab of its own, a Prolog one in the source viewer. **Go back** returns you to where you were.
*   **Where it is explained:** when you rest the mouse on a warning or an error, the note that appears ends with a link. The link goes either to the section of the language reference the message cites, or to the message's entry in the [warnings guide](warnings.md).

A **?** beside the query controls, the answers, the explanation, the LE Assistant, and at the top of the Scenario Editor, Query Editor, Scenario Variations, Explanation Drill, Proof Game and executive view opens the section of the documentation about that part.

![Editor Selection](images/an_editor_selection.png)

## Running Queries

1.  **The program goes to the server:** the editor sends your program to the server without being asked. The header at the top shows the session identifier, the name the server gives to your working session.
2.  **Choose a scenario:** in the **Query** tab, choose one of the scenarios your program defines (`scenario alice is:`, for example). You can also choose "Another..." and type facts of your own.
3.  **Choose a query:** choose one of the queries your program defines (`query one is:`, for example).
4.  **Run it:** click the **Query** button. A query still running after a couple of seconds offers **Interrupt**. A query that has not finished after 4 minutes is stopped by the server, which says so among the answers; either a rule is going round in circles, or the search is simply too large.
5.  **Flip the outcome:** **Flip…** asks what smallest change to the scenario would change the answer. Choose an answer first. The dialog then proposes the question *which minimal change to the scenario makes it the case that it is not the case that* the answer. Untick **it is not the case that** to ask for the answer itself, or edit the sentence — to aim at a different answer, for instance. If you have chosen no answer, the dialog proposes the query instead. **Flip** then runs the proposed question as a query of your own on the chosen scenario. Each answer is a set of facts to add or remove (`add: …`, `remove: …`), explained by the proof that the changed scenario gives. See the language summary, §17.7.

## The Scenario Editor

A scenario is a named set of facts that your queries run against. The **Scenario Editor** lets you build and change a scenario as a **fill-in-the-blank form**, instead of typing its facts by hand, so you never have to remember a template's exact wording. Open the Scenario Editor from **Edit → Edit Scenarios…**; it opens in a window of its own.

### Layout

*   **Top:** a **Scenario** picker — choose **New…** to start a fresh scenario, or pick an existing one to load it for editing — and a **Name** field (the scenario's name in your program).
*   **Middle:** a vertical list of the scenario's facts, one per row.
*   **Bottom:** an **Add fact** picker, and the **Copy** / **Insert into Editor** buttons.

### Editing facts

Each fact is shown as one row built from a template: the template's fixed words are plain **labels**, and each placeholder is an editable **field**. For the template `*a person* is born in *a place* on *a date*` a fact reads:

> `[a person]` is born in `[a place]` on `[a date]`

You can change the fields but not the words around them, so you cannot break the wording by accident. Each field shows, in pale text, the template variable it stands for (*a person*, for instance), and each field grows to fit what you type into it. Sometimes the program's rules expect particular values in one place — *knitted*, *woven* and so on, for a fabric construction. The field then **suggests** those values as you type, and lists them when you rest the mouse on it. When you load a scenario that already exists, the Scenario Editor recognises which template each of its facts uses, and fills the fields in for you.

*   **Cite the passage.** The **❝** button on a row opens a field for the place in the document where the fact is stated. Type the passage, and the Scenario Editor writes it as `confer "…"`; the scenario's **Provenance** names the document itself. You can also type a phrase of your own after the fact, such as `according to …` or `as stated in … at …`. A fact that already carries a citation shows it, and you can change it.

*   **Add a fact:** pick a template from the **Add fact** menu, click **+ Add**, and fill in the fields. The menu lists only the templates that make sense as scenario facts: those declared **`; undefined`** (also called a *scenario element*) and those some scenario already uses. Plain "*X* is a *type*" statements work too.
*   **Delete a fact:** click the **✕** on its row.
*   **Assume (unknown):** each row has an **Assume** checkbox on the right. Tick the box to mark the fact *unknown*. The fact is then written back with `it is unknown whether …` in front of it, and its fields cannot be changed while it is assumed. A fact the program already declares unknown arrives with **Assume** already ticked; untick the box to turn the fact back into an ordinary one.
*   **Test lines** (`… expects answers …`) are too involved for this form, so the form does not show them. The Scenario Editor keeps them aside and writes them back as comments, so that the scenario you save is still valid. Look them over and turn them back on in the main editor.
*   **Other lines that match no template** appear greyed out, and you cannot change them there; the Scenario Editor shows them so that nothing is lost. Edit those lines in the main editor. Comments (lines beginning with `%`) are left out.

### Write it in English (LLM-assisted)

Instead of picking a template, you can choose **Write it in English**, the last entry in the **Add fact** menu, and describe the facts in ordinary language. A dialog opens. Type one or more sentences stating precise facts, and an LLM (a large language model: a program trained to read and write ordinary language) turns them into Logical English facts that use **the templates your program already has**. The new facts arrive as ordinary rows you can edit.

*   **Your templates are respected.** The model only fills in templates you already have; the model will not invent sentence patterns of its own. It also settles the wording and the tense — "Miguel *was* born in Portugal" becomes `Miguel is born in Portugal on a date` — and where your sentence says nothing about one of the blanks, the model leaves the blank's own words (`a date`, for instance) for you to fill in. If you need new templates first, add them in the main editor or with the **LE Assistant**.
*   **You need a language model set up** — the same model and keys as the LE Assistant. Set them in the main editor under **Misc → API Keys & Assistant Settings…**. The dialog names the model it will use, or tells you that none is set. More in [The assistants](assistants.md#write-it-in-english).
*   **The facts are checked before they are added.** The editor checks the proposed facts against your program, and compares the result with the problems the program had beforehand, so that only *new* problems count. If nothing new goes wrong, the facts are added straight away. If new problems do appear, the editor **warns** you; you can still choose **Insert anyway**, or reword your sentences and **Regenerate**.

### Saving your work

*   **Copy:** copies the whole scenario block (`scenario <name> is:` followed by its facts) to the clipboard, ready to paste anywhere.
*   **Insert into Editor:** writes the scenario back into the main editor and closes the Scenario Editor window. If you loaded an existing scenario, the new text **replaces** it; a new scenario is **added at the end**.

The Scenario Editor does not check your Logical English itself. As with any edit, the **server has the last word**: it checks the program the next time the editor loads it, and reports any problems in the usual way. If you try to close the Scenario Editor window while it holds changes you have neither copied nor inserted, it asks you to confirm first.

## The Query Editor

The **Query Editor** builds and changes queries in the same way as the Scenario Editor builds scenarios: as fill-in-the-blank rows, rather than lines you type out yourself. Open the Query Editor from **Edit → Edit Queries…**; it opens in a window of its own. Pick **New…** to start a fresh query, or pick an existing query to load it, and give the query a **Name**.

A query is a list of **conditions**. Each condition uses one of your templates: fill in its blanks, or type something like `which person` to ask the query to report a value. You decide how the conditions go together:

*   **Add condition:** pick a template, click **+ Add**, and fill in the fields. Every condition after the first has an **and / or** chooser in front of it, set to **and** unless you change it, so that a sequence such as *A and B or C* reads from top to bottom.
*   **Negate** a condition by ticking its **not** box. The condition is then written as `it is not the case that …`.
*   **Indent** a condition (⇥ to move it right, ⇤ to move it left) to put it *inside* the condition above. Indenting shows how the **and**s and **or**s group: the further right a condition sits, the more tightly it binds. Logical English itself uses indentation in exactly this way.
*   **Write it in English:** the last entry in the **Add condition** menu opens the same language-model dialog as the Scenario Editor. Describe the query in ordinary language; its conditions are written from your templates, checked, and added at the end. See [Write it in English](#write-it-in-english-llm-assisted).
*   **Copy** puts the `query <name> is:` block on the clipboard. **Insert into Editor** writes the query back: **replacing** the query you loaded, or **adding** a new one at the end.

The Query Editor stays deliberately simple, and does not offer everything a Logical English query may contain — conditions grouped inside other conditions, sums and counts over many facts, and so on. Write those in the main editor. As with the Scenario Editor, the **server has the last word** and checks the program the next time it loads.

## Scenario Variations

The **Scenario Variations** window lets you take a scenario, **change it**, and run one or more queries against the changed version straight away, without touching your program. The window suits questions of the "what if" kind: what if Alice were *not* a citizen? Open the window with the **Scenario Variations** button in the **Query** tab, between **Query** and **Trace**. The window opens on its own, already set to whichever scenario was chosen in the Query tab.

### Layout

*   **Scenario picker** (top): choose which scenario to start from, or `(empty)` to build one from nothing.
*   **Scenario facts:** the same fill-in-the-blank form as the [Scenario Editor](#the-scenario-editor). Change the fields, delete facts, **Add fact** from a template, or tick **Assume** to run a fact as *unknown*. **Copy Scenario** puts the resulting `scenario … is:` block on the clipboard.
*   **Queries:** a list of the queries to run. **Add Query** adds one of your program's queries, and each query in the list has a ✕ that removes it.
*   **Query** button (bottom): runs **all** the listed queries against the facts as you have now changed them. Under each query you get the familiar answers and explanation. You get the notes that appear when you rest the mouse on an assumed step, too, and you can click a step of an explanation to **show the rule or fact behind it in the main editor window**.

### Running and sharing

Click **Query** to run everything. The button then switches itself off, and comes back on only when you change something — a fact, or the list of queries. So you can always tell whether the results below are still the current ones.

As you work, the window keeps its **web address up to date**: the changed scenario, the list of queries and the program are all written into the address. Copy that address to **share exactly what you are looking at** with someone else, just as you would share a program from the editor.

## Generate LE view (LE Assistant)

The **Generate LE view** button in the LE Assistant's header drafts a view for
the program ([the language reference](../reference/language.md) §17.10) and adds the draft at the end of
the program. The draft puts the facts a case can state in one group, keeps the
judged facts apart, takes the first query as the result, and lists what the
program is able to show: citations, the stage, documents, a flip. Drafting a
view needs no language model. Edit the draft — group the facts under titles,
head the result by the value that matters, add questions for an interview — or
send the improvement that the assistant's input box then proposes. The verifier
checks that everything the view names really exists. The reply's **Open the
view** link opens the view in the executive view, exactly as the program stands
in the editor, without saving anything. If the program's knowledge base has no
name, the view takes the name of the file. Templates whose wording contains a
comma or a full stop are left out, because the lists in a view cannot hold
them. Tutorial: [Introducing LE Views](../tutorials/views.md).

## Explanations and Navigation

Once a query has run:
*   **Answers:** the answers appear on the left of the bottom panel.
*   **Explanation tree:** click an answer and the reasons behind it appear on the right, written in ordinary English and laid out as a tree of steps. When a query has *no* answer, the tree explains *why* the query failed.
*   **Going to the rule:**
    *   Click any step in the explanation tree and the editor scrolls to the rule or fact behind that step. If the rule lives in an included resource, the editor goes to the tab holding that resource (see [file tabs](#several-documents-file-tabs)).
    *   The editor highlights those lines, so that you can check the reasoning quickly.

### Reading the Explanation Tree

*   **Colours** tell you how each step fared: **green** for a condition that *held*, **red** for one that *failed*, and **amber** for an *unknown* condition — one the program could prove neither true nor false, but took to be true because its template is declared "unknown".
*   **Notes on each step:** rest the mouse on a step to read how it fared, for example "Succeeded: this condition was proven" or "Failed: this condition could not be proven". A negated condition that holds reads "Succeeded: this negative condition holds (the inner statement could not be proven)".
*   **Open and close:** a step with steps beneath it carries a `-`/`+` button. The top two levels are open to begin with. The editor remembers, for each answer, which steps you left open, so you can move between answers freely.
*   **Numbering the steps:** turn on **Misc → Hierarchical Numbering** to put each step's position in the tree in front of it, such as `1.2.3`.
*   **Important reason:** rest the mouse on the **EXPLANATION** title, which is underlined when a summary is available, for a one-line summary of the answer you have chosen. The summary describes the tree as you see it, so it follows your setting for repeated sub-explanations. Right-click the title and choose **Show important reason** to open the tree down to that step and flash it.

### The Explanation Drill

The **Explanation Drill** is a window of its own that walks you through an answer's explanation as a series of yes-or-no questions, so that you can find, and understand, the reason that matters to you. You can keep working in the editor while the drill is open. Open the drill by right-clicking the **EXPLANATION** title and choosing **Explanation Drill…**.

The drill treats the explanation as a tree of suspects. At each step it shows the **important reason** for the part of the tree you are in, and asks **"Accept?"**:

*   **Yes** — you understand that part. The drill sets the part aside and moves on to the next most important reason among those left.
*   **Not yet** — you want to dig deeper. The drill goes into that reason and asks about *its* most important part.

At the top of the window are the words *"Understanding why …:"*, naming the statement being explained, and a bar that fills up as you mark parts understood. Every question keeps your answer — Yes, Not yet, or still unanswered — so you can go back and change an earlier answer at any time, and the drill then asks again from that point on. Each question also has a **✕** that deletes it: your answer to that question is dropped, the others stay, and the drill works out afresh what to ask next. Whenever the drill puts a new question to you, it **highlights the rule behind it** in the main editor, without taking your attention away from the drill; clicking any question card highlights its rule again. Once every part of a reason you answered *Not yet* has been accepted, the reason itself counts as accepted, and the drill goes back to the reasons still open around it — the answer's other conditions, for instance. When you have accepted everything, the bar is full and the drill says *"Nothing else to show."*

### Repeated Sub-explanations

A large tree often contains the same piece of explanation many times over, and a tree explaining a failure especially so. Unless you say otherwise, the editor folds the repeats away:

*   A piece of explanation that occurs several times is shown **once, in italics**, in its usual green, red or amber. Rest the mouse on it to see how many times it occurred: "N repeated sub-explanations", or "N repeated occurrences" for a condition with no steps beneath it.
*   **Go to full sub-explanation:** some of the repeats stand for a copy that *is* shown in full somewhere else in the tree. Those repeats carry a small `↩` mark. **Right-click → "Go to full sub-explanation"** scrolls to the full copy, opens any closed steps above it, and highlights it for a moment. A repeat with no fuller copy anywhere — a plain repeated condition, for example — has neither the mark nor the menu item.
*   The **Hide repeated explanations** setting controls the folding, and is on unless you turn it off. Turn it off to see every occurrence in full.

### The Explanation Context Menu

Right-click in the explanation tree for:

*   **Copy Explanation:** copies the whole tree, every branch of it, to the clipboard, both as plain text and as formatted text, ready to paste into a document.
*   **Copy as Mermaid diagram:** copies the whole tree as a [Mermaid](https://mermaid.js.org) flowchart — Mermaid being a way of writing a diagram as text. Paste it anywhere Mermaid diagrams are drawn: GitHub, Obsidian, Notion, mermaid.live. The steps that held, failed and were assumed keep the tree's green, red and amber. The Scenario Variations explanation menu offers the same item.
*   **Go to full sub-explanation:** appears only on a repeated step that has a full copy elsewhere (see above).

### Explanation Preferences

Open **Misc → EXPLANATIONS → Preferences...** to set:

*   **Prefix for failed nodes:** text the editor puts in front of every failed step when you copy an explanation. The prefix helps when you paste the explanation somewhere that loses the colours.
*   **Detailed failure explanations (per-rule nodes):** several rules may be able to prove the same statement. When this setting is on and such a statement fails, the tree shows one step per rule that was tried, each leading to that rule, with the conditions that rule failed on beneath it. The extra detail makes explaining slower, so the setting is off unless you turn it on.
*   **Hide repeated explanations:** as described above; on unless you turn it off.
*   **Larger important reasons:** when a query fails, its important reason can name just the first of the conditions that failed at the deepest level, or all of them. With this setting on, which it is unless you turn it off, the reason names all of them — "it is not the case that X, nor that Y, nor that Z" — stopping after the third.

### Why not: a query with no answer

In the editor, a query with no answer shows **No answers (false)** and an explanation of the failure: the conditions that were tried, with the failed ones in red. Some programs divide their rules into the sections *applicability*, *question* and *remedy* ([the language reference](../reference/language.md) §17.4). For such a program, the first step of the tree is a checklist of those sections: "applicability passed, question failed, remedy not reached". The **Detailed failure explanations** setting described above adds one step per rule tried.

The [executive view](executive-view.md#when-there-is-no-answer-why-not), and any view that `shows its reasons`, put the same thing more briefly, under the heading **Why not**. They list only the conditions the case did not meet, drawn from the ways of reaching the answer that came closest — the ways in which the most conditions held. Each condition is marked either **not stated**, meaning a fact the case could have stated but does not, or **not met**, meaning a test that is false on the case's values, a fact the case states otherwise, or a denial whose subject does hold. Beside each condition stand the rule that asks for it, the rule's citation, and the facts the rule compared. To see all this for the program you have open, use **Misc → Open Executive View**. The tutorial [Querying a program](../tutorials/querying-a-program.md) works through failed queries on an example.

## Advanced Features

*   **Executive view:** ([guide](executive-view.md)) **Misc → Open Executive View** opens the executive view of the program in a new tab, on the scenario and query you picked in the editor, with the program's views listed at the top. The executive view shows the program as it stands in the editor, changes you have not saved included. The editor passes the text to the new tab through the browser's own store, so if you copy a link out of that tab and open it in another browser, the other browser shows the saved program instead.
*   **LPS programs:** a document that declares `the target language is: lps.` plays out over time rather than answering queries, so the query bar shows two buttons instead of the usual ones.
    **Run in LPS** (also at **Misc → Run in LPS**) opens the Logical English → LPS page with the document as it stands in the editor, and runs it with the LPS engine: the timeline, the changes of state, the explanations. The LPS engine is the LPS2 program, and it has to be running already — start it with `LPS_LE2_LIB=<this checkout> ./lps ide` in your copy of LPS2, where `<this checkout>` is the folder holding this copy of Logical English 2.
    **Legal View** (also at **Misc → Legal View of This LPS Program**) opens the program's *legal view* (built by `le_lps_legal.pl`) in a new tab. The legal view is an ordinary Logical English program, worked out afresh each time and never stored, in which the timed program is restated as rules about what is allowed: each action's integrity constraints become one rule saying who may perform that action; each causal law becomes a rule about effects (`… transferring … results in the balance of … being …`); and the fluents — the facts that change as time passes — become scenario elements. The program's own calls become its queries: may this happen? what does it change? and a flip query, what would have to change for it to be allowed?
    When the LPS server is running, the legal view is drawn from an actual run of the program. There is then one scenario per call the program's scenario makes, each holding the state of affairs just before that call, and the call's questions become expectations: whether it may happen — true exactly when the run accepted it — and what it changes. So **Misc → Run the Program's Tests…** on the legal view checks the view against the program. Without the LPS server, the legal view has only one scenario, the program's starting state. Constraints that speak of two actions at once, and actions no rule in the program governs, are written out as comments rather than turned into permissions.
*   **Source Graph:** **Misc → View Source Graph** opens a picture of the program in a new browser tab, a picture you can move around in. Templates, rules, facts, scenarios, types and queries appear as boxes, and lines join them to show which uses which, which depends on which, which denies which, and which is a kind of which. A panel at the side chooses how the boxes are laid out, which way the picture runs, and which kinds of box and line to show; the editor remembers those choices for next time. Click a box and the editor highlights the text behind it, and moving the cursor in the editor picks out the matching box. Right-click a box for **Copy Node**, which copies its text to the clipboard, **Copy URL**, a link you can share that opens the picture on that box, and **Redraw from here**. The **Copy Mermaid** button copies the picture *as you can see it* — the kinds of box and line now shown, the scenarios now chosen, running the way you have set — as a [Mermaid](https://mermaid.js.org) flowchart, which is a way of writing a diagram as text. Scenarios become boxed groups around their facts. Paste the result into GitHub, Obsidian, or anywhere else that draws Mermaid diagrams.
*   **LE Assistant:** use the **LE Assistant** tab to ask questions about your program, or for help in drafting new rules. The **Light Mode** box in the tab's header chooses between two assistants: a quick one that runs on the server (Light, the one you get unless you change it) and a full coding assistant (Deep). Either needs a model and an API key — the pass phrase that lets this program use that model — which you set in **Misc → API Keys & Assistant Settings…**. See [The assistants](assistants.md), which also covers the Contract Assistant web page.
*   **s(CASP) engine:** the **Engine** picker beside the query answers a query with s(CASP) rather than with Prolog. Whether the picker appears at all is up to **Misc → ENGINE PICKER**. To see how your program reads in s(CASP), right-click in the editor and choose **See s(CASP)**. Where s(CASP) cannot state the program faithfully, the translation is refused and the problems are listed. See [s(CASP)](../reference/scasp.md).
*   **Proof Game:** the **Proof Game** button in the Query tab opens a game in which you build the proof of the chosen query yourself. See [the Proof Game](proof-game.md).
*   **Debugger:** the debugger lets you follow a query one step at a time. Right-click in the editor and choose **See PROLOG** to see what your rules become in Prolog, or press the **Trace** button in the Query tab to walk through the query. Clicking in the margin to the left of a line number sets a breakpoint there, shown as a red dot: a place where the query will stop and wait for you. In the debug panel, **Step** (F11) moves to the next goal, **Step over** (F10) to the next goal at the same level or above, **Continue** (F5) to the next breakpoint or the next answer, and **Stop** ends the query. Each time the query stops, the panel shows which goals are still open and what the current goal's variables stand for.

## Finding documentation

*   **Search:** three boxes search the text of every user document — **Help ▸ Search the documentation…**, the box at the top of every document, and the one under *Documentation* on the landing page. A section counts as a match only if all your words occur in it, and a phrase in quotation marks must occur exactly as you wrote it. The results are sections, grouped by document, the best first; a word in a heading counts most. The same words always give the results in the same order. A link at the foot of the results repeats the search in the LPS2 documentation.
*   **Documentation for this:** right-click on a word of the program and choose **Documentation for this**. The search looks for what the word *is*, not for its letters. A variable such as `X` or `a person` finds the documentation about variables; a date finds the documentation about dates; a word belonging to a template finds the documentation about templates; and a keyword such as `if`, `it is not the case that` or `the templates are:` finds the documentation about that keyword. If you select more than one word, the search looks for the selection as written. The results page also offers the word itself as a search of its own.
*   **Other systems:** **Help ▸ Other systems: import and export** opens the [map of the integrations](../integrations/index.md), with a document for each system.

## More guides

*   [The executive view](executive-view.md): running a program without its text, citations, why not, views, links.
*   [Other systems](../integrations/index.md): a map of the integrations, a document per system, other systems' files, exports and refusals, the migration twins.
*   [The assistants](assistants.md): the LE Assistant, Write it in English, the Contract Assistant.
*   [Querying a program](../tutorials/querying-a-program.md): a tutorial on queries, explanations, variations, flips and the Explanation Drill.
*   [The Proof Game](proof-game.md) and [the verifier's warnings](warnings.md).
