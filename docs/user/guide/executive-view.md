# The executive view

*Kind: guide · Audience: users · Status: current (2026-09-16)*

The executive view runs an existing Logical English program for people who
use it rather than write it. They ask it questions, try cases, and read why
it answered as it did. The program's text is never shown and never changed.
The page works on a phone as well as on a desk. It is at **`/executive`** on
the server (for example `http://localhost:3050/executive`), and the landing
page links to it.

## Contents

- [Choosing a program](#choosing-a-program)
- [Asking a question](#asking-a-question)
- [Reading an answer](#reading-an-answer)
  - [Citations first](#citations-first)
  - [The source viewer](#the-source-viewer)
  - [When there is no answer: why not](#when-there-is-no-answer-why-not)
- [Scenario Variations](#scenario-variations)
- [Views](#views)
- [Links: the address of a result](#links-the-address-of-a-result)
- [From the editor](#from-the-editor)
- [Logging in](#logging-in)
- [Language](#language)

## Choosing a program

Opening `/executive` with no parameters lists the example programs of the
server. Type in **Filter…** to narrow the list, and tap a name to open that
program. The **←** at the top left of a program returns to the list.

## Asking a question

A program's screen has two pickers: **Scenario** (the program's named
scenarios, or *(no scenario)*) and **Query** (the program's queries, each
shown by its text). There is no Run button. The program opens on its first
scenario and the selected query runs at once. Changing either picker runs the
query again, and the answers appear below.

If the program has load errors, the first few are listed at the top of the
screen. A program with no queries says so.

## Reading an answer

Each answer is a card. Tap it to open its explanation. When the answer holds
only on assumptions (facts the scenario marks as *unknown*), the card lists
them after the answer, as *(assuming: …)*.

The explanation is an indented tree:

- green for what was proved, red for what failed, amber for what was assumed;
- a step that held because something failed (*it is not the case that …*,
  *for all …*) keeps those failures folded behind a disclosure triangle, since
  they record the search rather than the reasons;
- a repeated sub-explanation is shown once, with its count (*×3*) or *(shown
  above)*.

### Citations first

When the program cites its sources, an opened answer starts with its
**Citations**: the steps of the proof that cite a document, in the order of
the proof. Rules and tables cite with `with provenance`, and facts with
`as stated in …`, `according to …` or `confer "…"`
(see [the language reference](../reference/language.md) §17.1). Each step shows
the sentence proved and one line saying where it comes from: the rule, the
document, and the quoted passage or the place in the document (*page 1*,
*paragraph 25*).

- **Copy** puts the numbered list of cited steps on the clipboard, each with
  its citation.
- **Full explanation ↓** jumps to the whole tree, which is folded below the
  list.

An answer whose proof cites nothing shows the tree directly.

### The source viewer

A cited step whose document has a text the server can reach (the program
says where, with `the text of <document> is at "…"`) or a published address
has a **§** button. It opens the document in the source viewer, with the
cited passage marked. When the document has only a web address, it opens in a
new tab.

### When there is no answer: why not

When a query has no answer, the card says *No — no answers for this query.*
and lists **Why not**: the conditions the case did not meet. Where the
program has several ways to reach the answer, only the ones that came closest
count: those in which the most conditions held before one failed. Each
condition is marked:

- **not stated**: a fact the case could state but does not (the record is
  silent);
- **not met**: a test that is false on the case's values, a fact the case
  states otherwise, or a negation whose subject holds.

Each condition also shows the rule that asks for it and that rule's citation,
and after *given:* the facts that rule compared. A **§** opens the passage, as
above. The full failure explanation is folded below.

## Scenario Variations

The **Scenario Variations** button between the two pickers opens the editor's
Scenario Variations window on the same program, in a new tab, starting from
the selected scenario and query. There you can edit, delete, add or assume
facts and run queries on the altered case. The program is not changed. See
[Scenario Variations](editor.md#scenario-variations) in the editor guide.

## Views

A program can say how its screen should look, in a *view* section at its end
(see [the language reference](../reference/language.md) §17.10, and the
tutorial [LE Views](../tutorials/views.md)). A program with views lists them in
a **Views:** strip at the top. Tap one to open it: the view takes the place of
the two pickers, with the title and the screen its author described. Depending
on the view, that is:

- the case's facts in groups, editable;
- the result in large type;
- its citations or its reasons (*Why not* when it fails);
- the stage it reaches;
- what is missing;
- the smallest changes that would change it;
- other questions' answers as tables;
- a comparison with another scenario;
- the documents beside the facts;
- every case with its result;
- a draft text;
- or an interview, one question at a time.

**Without a view** returns to the pickers.

A program that declares no view offers an **Automatic view**. The server draws
it from the program when you open it (the same draft as the editor's
*Generate LE view*), and a note says so.

Opening a view takes a few seconds (the program loads, then the first result
runs). The page says *Opening the view…* and shows a waiting cursor meanwhile.

## Links: the address of a result

Everything is in the address, so a result can be bookmarked or shared:

| Parameter | Meaning |
|---|---|
| `program=<name>` | the example program, as it is named in the list (e.g. `citizenship`, `regulatory/eu261_integration`) |
| `scenario=<name>` | the scenario to select |
| `query=<name>` | the query to select |
| `view=<name>` | a view of the program to open; `view=*` opens the automatic view |

The pickers keep the address up to date as you change them, and so does a
view's case picker (`scenario=`). A link that
names a program, a scenario and a query runs that query when it opens, for
example:

```
/executive?program=citizenship&scenario=alice&query=one
/executive?program=regulatory/eu261_integration&view=claim%20desk
```

An unknown scenario or query name is ignored: the first scenario is selected
instead.

## From the editor

**Misc ▸ Open Executive View** in the editor opens the program in the
executive view, in a new tab, on the scenario and query selected in the
editor. It shows the program *as it is in the editor*, unsaved changes
included, and the views it lists come from that text. The **Open the view**
link of *Generate LE view* works the same way. The text is handed over through
the browser's storage, and the address carries a `text=` key that names it. If
you open such a link in another browser, the page says that the editor's copy
is not in that browser, and shows the program as saved.

## Logging in

The top right of the page shows **Login**, or the email of the user logged in
and **Logout**, as on the landing page. Both return to the same page. Some
example programs are restricted to users with a given role. Logging in with
such a role lists them and lets them be opened, together with the documents
they cite.

## Language

The page's own words (buttons, labels, messages) follow the interface
language chosen on the multilingual landing page (`/multilingual`). The
program's sentences are in the program's language.
