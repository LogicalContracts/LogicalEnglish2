# The executive view

*Kind: guide · Audience: users · Status: current (2026-09-16)*

The executive view runs an existing Logical English program for the people who
use the program rather than write it. They put questions to the program, try
cases on it, and read why it answered as it did. The executive view never
shows the program's text, and never changes it. The page works on a phone as
well as on a desktop computer. You will find the page at **`/executive`** on
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

Opening `/executive` with nothing added to its address lists the example
programs the server holds. Type in **Filter…** to narrow the list, and tap a
name to open that program. The **←** at the top left of a program takes you
back to the list.

## Asking a question

A program's screen has two pickers: **Scenario**, holding the program's named
scenarios and *(no scenario)*, and **Query**, holding the program's queries,
each shown by its text. There is no Run button. The program opens on its first
scenario and runs the chosen query at once. Changing either picker runs the
query again, and the answers appear below.

If anything went wrong while the program was loading, the screen lists the
first few problems at the top. A program with no queries says so.

## Reading an answer

Each answer is a card. Tap the card to open its explanation. Some answers hold
only because something was assumed — a fact the scenario marks as *unknown*.
Such a card lists those assumptions after the answer, as *(assuming: …)*.

The explanation is a tree of steps, each indented under the step it serves:

- green marks what was proved, red what failed, and amber what was assumed;
- a step may hold precisely because something else failed (*it is not the case
  that …*, *for all …*). Such a step keeps those failures folded away behind a
  small triangle, because the failures record the search rather than the
  reasons;
- a piece of explanation that occurs more than once is shown once, with the
  number of times it occurred (*×3*) or the words *(shown above)*.

### Citations first

When a program cites its sources, an opened answer begins with its
**Citations**: those steps of the proof that cite a document, listed in the
order of the proof. A rule or a table cites its source with `with provenance`,
and a fact cites its source with `as stated in …`, `according to …` or
`confer "…"` (see [the language reference](../reference/language.md) §17.1).
Each step shows the sentence that was proved, and one line saying where the
sentence comes from: the rule, the document, and either the quoted passage or
the place in the document, such as *page 1* or *paragraph 25*.

- **Copy** puts the numbered list of cited steps on the clipboard, each with
  its citation.
- **Full explanation ↓** jumps to the whole tree, which is folded below the
  list.

An answer whose proof cites nothing shows the tree directly.

### The source viewer

A cited step carries a **§** button in two cases: when the server can reach
the text of the document, because the program says where the text is with
`the text of <document> is at "…"`, and when the document has an address at
which it is published. The **§** button opens the document in the source
viewer, with the cited passage marked. Where all the program gives is a web
address, the document opens in a new tab instead.

### When there is no answer: why not

When a query has no answer, the card says *No — no answers for this query.*
and lists, under **Why not**, the conditions the case did not meet. A program
may have several ways of reaching the answer. Only the ways that came closest
are listed: those in which the most conditions held before one of them failed.
Each condition carries one of two marks:

- **not stated**: a fact the case could have stated but does not. The record
  is silent about it;
- **not met**: a test that is false on the case's values, a fact the case
  states otherwise, or a denial whose subject does hold.

Beside each condition stand the rule that asks for it and that rule's
citation, and, after the word *given:*, the facts the rule compared. A **§**
opens the passage, as described above. The full explanation of the failure is
folded away below.

## Scenario Variations

The **Scenario Variations** button between the two pickers opens the editor's
Scenario Variations window on the same program, in a new tab, starting from
the scenario and query you have chosen. In that window you can change, delete,
add or assume facts, and run queries on the case as you have altered it. The
program itself is left as it was. See
[Scenario Variations](editor.md#scenario-variations) in the editor guide.

## Views

A program can say how its screen should look, in a *view* section at the end
of the program (see [the language reference](../reference/language.md) §17.10,
and the tutorial [LE Views](../tutorials/views.md)). A program that has views
lists them in a **Views:** strip at the top. Tap a view to open it. The view
then takes the place of the two pickers, and shows the title and the screen
its author described. What that screen holds depends on the view:

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

A program that declares no view of its own offers an **Automatic view**. The
server draws the automatic view from the program as you open it — the same
draft that the editor's *Generate LE view* button produces — and a note on the
screen says as much.

Opening a view takes a few seconds: the program has to load, and then the
first result has to be worked out. Meanwhile the page says *Opening the view…*
and shows a waiting cursor.

## Links: the address of a result

The address holds everything the screen is showing, so you can bookmark a
result or share it. These are the parts you can add to the address:

| Parameter | Meaning |
|---|---|
| `program=<name>` | the example program, as it is named in the list (e.g. `citizenship`, `regulatory/eu261_integration`) |
| `scenario=<name>` | the scenario to select |
| `query=<name>` | the query to select |
| `view=<name>` | a view of the program to open; `view=*` opens the automatic view |

The pickers keep the address up to date as you change them, and so does a
view's own case picker, which sets `scenario=`. A link that names a program, a
scenario and a query runs that query as soon as it opens, for example:

```
/executive?program=citizenship&scenario=alice&query=one
/executive?program=regulatory/eu261_integration&view=claim%20desk
```

If the address names a scenario or a query the program does not have, the page
passes over the name and selects the first scenario instead.

## From the editor

**Misc ▸ Open Executive View** in the editor opens the program in the
executive view, in a new tab, on the scenario and query chosen in the editor.
The new tab shows the program *as it stands in the editor*, changes you have
not saved included, and the views it lists come from that same text. The
**Open the view** link of *Generate LE view* works in the same way. The editor
hands the text over through the browser's own store, and the address carries a
`text=` key naming where the text was put. If you open such a link in another
browser, the page tells you that the editor's copy is not in that browser, and
shows the program as it was last saved.

## Logging in

The top right of the page shows **Login**, or, once you are logged in, your
email address and **Logout**, just as the landing page does. Either one brings
you back to the page you were on. Some example programs are open only to users
who hold a particular role. If you log in with such a role, the list includes
those programs, and you can open them and the documents they cite.

## Language

The page's own words — buttons, labels and messages — follow the language
chosen on the multilingual landing page (`/multilingual`). The program's own
sentences stay in the language the program is written in.
