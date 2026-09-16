# Querying a program: answers, explanations and what-ifs

*Kind: tutorial · Audience: users · Status: current (2026-09-16)*

This tutorial is about *running* a Logical English program, not writing one.
We take a program that is already written and question it: we run its
queries, read its explanations, try "what if" variations, ask what would
change an answer, and walk through an explanation one reason at a time.

The program is `examples/regulatory/eu261_integration.le`. It decides
compensation for a cancelled flight under EU Regulation 261/2004. Its rules
say when a passenger is owed compensation, and how much, by the distance of
the flight. The interesting part is *extraordinary circumstances*: a carrier
owes nothing if it establishes that the cancellation was due to such
circumstances. The program decides that with two judgments of the Court of
Justice:

- *Wallentin-Hermann* (C-549/07): technical problems found during maintenance
  are inherent in a carrier's activity, so they are not extraordinary;
- *Peskova* (C-315/15): a bird strike is not inherent.

Everything below happens in the LE editor. Open the program with **File ▸
Open copy from server…**, choosing `regulatory/eu261_integration`, or directly
at `/editor/index.html?example=regulatory/eu261_integration`. The program is
in the code area, with the **Query** panel along the bottom.

## Contents

1. [Running a query](#1-running-a-query)
2. [Reading the explanation](#2-reading-the-explanation)
3. [When there is no answer](#3-when-there-is-no-answer)
4. [Scenario Variations: what if?](#4-scenario-variations-what-if)
5. [Flip: what would change the answer?](#5-flip-what-would-change-the-answer)
6. [The Explanation Drill](#6-the-explanation-drill)
7. [The same program for its users](#7-the-same-program-for-its-users)
8. [Quick reference](#8-quick-reference)

## 1. Running a query

A run needs two things from the program: a **scenario** (the facts of one
case) and a **query** (the question). Pick both in the Query panel.

The program has four scenarios:

| Scenario | The case |
|---|---|
| `new_claim` | anna's flight AZ123 from Vienna (800 km) is cancelled; Alitalia says the cause was a technical problem found during maintenance |
| `notified` | the same flight, but anna was told of the cancellation 20 days before |
| `bird_strike` | the same flight, cancelled after a bird strike that Alitalia says was beyond its control |
| `outside_the_eu` | a flight from Istanbul |

Every fact of a scenario says where it comes from, for example:

```le
the cancellation of flight AZ123 is caused by the inspection defect,
    according to Alitalia, as stated in the carrier letter at paragraph 3.
```

The main query is `claim`:

```le
query claim is:
    which passenger is entitled to compensation of which amount for which flight.
```

To run it:

1. In **Scenario**, choose `new_claim`.
2. In **Query**, choose `claim`. The picker shows the query's text followed
   by its name.
3. Click **Query**.

The answer appears on the left:

> anna is entitled to compensation of 250 for flight AZ123

The flight is 800 km, and the program's decision table `article_7` gives
250 for distances up to 1500 km.

The address bar now names the program, the scenario and the query. Copy it
to give someone the same run.

## 2. Reading the explanation

The **explanation** on the right shows how the program reached the answer.
It is a tree of the program's own sentences: each condition of the rule that
concluded the answer, and under each, what proved it. The top two levels are
open. The `+` / `-` toggles open and close the rest.

For `new_claim`, the conditions under the answer are:

- anna is booked on flight AZ123, *as stated in the booking at page 1*;
- flight AZ123 is within scope (it departs from Vienna, and Vienna is in the
  EU);
- flight AZ123 is cancelled;
- it is not the case that anna is notified of the cancellation with a number
  days of notice and the number is at least 14;
- the carrier of flight AZ123 is Alitalia;
- it is not the case that the cancellation of flight AZ123 is due to
  extraordinary circumstances according to Alitalia;
- 250 is the compensation due for flight AZ123 (the distance is 800 km, and
  row `a` of table `article_7` gives 250).

Things to notice:

- **Green** is a condition that was proved. **Red** is one that could not be.
- **Red inside a negation is what the rule wanted.** Open *it is not the case
  that the cancellation of flight AZ123 is due to extraordinary
  circumstances…*. Under it, *the cancellation … is due to extraordinary
  circumstances* is red: it could not be proved, so the negation holds.
  Opening further shows why. The inspection defect *counts as inherent in the
  normal exercise of the activity of Alitalia*, because it is *forced for
  inherent by wallentin hermann*: that case decided for *inherent* (C-549/07,
  paragraph 25) on a factor, *maintenance problem*, which this defect also
  has.
- **Click a node to see its source.** The editor scrolls to the rule or fact
  that proved it and highlights it.

### The important reason

The **EXPLANATION** title is underlined when an answer is selected. Hover over
it to see the one reason the answer rests on most. For `new_claim` that is:

> the inspection defect counts as inherent in the normal exercise of the
> activity of Alitalia

Right-click the title for **Show important reason**, which opens the tree at
that node and flashes it, and **Explanation Drill…** (section 6).

Right-clicking in the tree offers **Copy Explanation** (as text and HTML) and
**Copy as Mermaid diagram**. **Misc ▸ EXPLANATIONS ▸ Preferences…** controls how
trees are shown. Keep **Hide repeated explanations** on for large programs: a
sub-explanation that occurs several times is then shown in full once. The
[editor guide](../guide/editor.md#explanations-and-navigation) describes each
preference.

## 3. When there is no answer

Choose the scenario `notified` and run `claim` again. The answers list says
**No answers (false)**, and the explanation now says why the query failed.

The program's rules are in three sections: *applicability*, *question* and
*remedy* (see [the language reference](../reference/language.md) §17.4). The
first node of a failure explanation is a checklist:

> section checklist: applicability passed, question failed, remedy not reached

Under the rule's node, the red condition is the one that stopped it:

> it is not the case that anna is notified of the cancellation of flight
> AZ123 with a number days of notice and a number is greater than or equal to 14

It failed because both parts under it hold: anna *is* notified with 20 days
of notice (according to Alitalia, as stated in the notice email), and 20 is
at least 14.

Now try the other two scenarios:

- `outside_the_eu`: *applicability failed*. The flight is not within scope,
  because *Istanbul is in the EU* cannot be proved.
- `bird_strike`: *question failed*. Here *the cancellation … is due to
  extraordinary circumstances according to Alitalia* holds. The bird
  collision has the factor *bird strike*, so *peskova* forces it against
  *inherent*, and Alitalia states that it was beyond its control (the incident
  report, page 2). So the negation fails.

The program also has a query for the stage alone:

```le
query stage is:
    the query fails at which section.
```

Its answer is *the query fails at question* for `notified`, *the query fails
at applicability* for `outside_the_eu`, and no answer for `new_claim`, whose
claim does not fail.

## 4. Scenario Variations: what if?

The **Scenario Variations** window takes a scenario, lets you change it, and
runs queries on the changed case. Your program is not modified.

Choose `new_claim` and `claim`, then click **Scenario Variations**. A window
opens with the scenario's facts as rows: each template's words are fixed, and
its values are fields you can edit. The `claim` query is listed below the
facts. **Query** at the bottom runs every listed query on the facts as they
now are, and turns grey until you change something.

### Change a value

In the row *the distance of flight AZ123 is 800 km*, change `800` to `2000`
and click **Query**. The answer becomes:

> anna is entitled to compensation of 400 for flight AZ123

and the explanation now cites row `b` of table `article_7`.

### Remove a fact

Put the distance back to 800, then delete that row with its **✕** and click
**Query**. The result is **No answers (false)**. In the explanation, *an amount
is the compensation due for flight AZ123* is red, and under it *the distance of
flight AZ123 is a number km*, the fact that is now missing. Remove a fact and
run the query again: that is how you find which facts an answer depends on.

A right-click on a node of this explanation can change the case for you. A
green node that is a fact of the scenario offers **Patch scenario — delete
this fact**. A red node that matches a template offers **Patch scenario — add
this fact** and **Assume fact**. Each runs the queries again.

### Assume a fact

Sometimes a fact is not established yet, and you want the answer *if* it
holds. Add the distance row back with **Add fact**, fill in `AZ123` and
`800`, and tick its **Assume** box. The fact
becomes *it is unknown whether the distance of flight AZ123 is 800 km*. Run
again:

> anna is entitled to compensation of 250 for flight AZ123

The answer carries a **?** marker. Hovering over the answer shows:

> Unknown goal: the distance of flight AZ123 is 800 km

and in the explanation the assumed condition is **amber**. This is the answer
*provided that* the assumption holds. The unknowns of an answer list what is
still to be checked.

The window keeps the changed facts and the query list in its address. Copy
the address to share this what-if, or use **Copy Scenario** to get the changed
facts as a `scenario … is:` block.

## 5. Flip: what would change the answer?

Scenario Variations tries one change at a time. A *flip* asks the program
for the smallest changes to the case that would change the answer.

Back in the editor, with `new_claim` and `claim`, run the query and select
the answer. Click **Flip…**. The dialog proposes:

> which minimal change to the scenario makes it the case that it is not the
> case that anna is entitled to compensation of 250 for flight AZ123

Click **Flip**. Each answer is one change:

- remove: flight AZ123 is cancelled
- remove: flight AZ123 departs from Vienna
- remove: anna is booked on flight AZ123
- remove: the carrier of flight AZ123 is Alitalia
- remove: the distance of flight AZ123 is 800 km

Each comes with the proof that the changed case gives.

Some facts are missing from this list. Removing the maintenance log's
statement, or the cause of the cancellation, does not change the answer. The
carrier must *establish* extraordinary circumstances, and without those facts
it establishes nothing. The program has the same question as a query of its
own, `flip`. See [the language reference](../reference/language.md) §17.7 for
flip queries.

## 6. The Explanation Drill

The Explanation Drill walks you through an explanation as a series of
questions, starting with the reasons that matter most.

Select the answer of `claim` on `new_claim`, right-click **EXPLANATION**, and
choose **Explanation Drill…**. A window opens, headed *Understanding why anna
is entitled to compensation of 250 for flight AZ123:*, with a progress bar. It
shows the most important reason and asks **Accept?**:

- **Yes**: you accept this part. It is set aside, and the drill asks about
  the next reason.
- **Not yet**: you want to know more. The drill breaks the reason into the
  reasons under it and asks about the most important of those.

Each question highlights its source in the editor. You can change an earlier
answer at any time, or delete a question with its **✕**, and the drill
recomputes its questions from that point. When nothing is left, it says
*Nothing else to show*.

Answer *Not yet* where a step is not obvious to you. On this program, the
reasons under the extraordinary-circumstances condition lead down to the
precedent, its factor, and the maintenance log entry that gives the defect
that factor, as in the tree of section 2.

## 7. The same program for its users

A passenger or a claims handler does not need the program's text. **Misc ▸
Open Executive View** opens the same program in the
[executive view](../guide/executive-view.md). It has two pickers, the answers
below them, and each answer opens on its **Citations**: the steps of the
proof that cite a document, such as *the booking · page 1* or *C-549/07 ·
paragraph 25*.

With `notified`, the executive view says *No — no answers for this query.*
and lists **Why not**: *it is not the case that anna is notified of the
cancellation … with a number days of notice and a number is greater than or
equal to 14*, marked **not met**, with the facts it compared. With
`outside_the_eu` it lists *Istanbul is in the EU*.

The program also declares a view, **Passenger claim desk**, at its end. Open
it at `/executive?program=regulatory/eu261_integration&view=claim%20desk`. It
shows the case's facts in groups, the result in euros, the stage, the
citations, the precedents, a comparison with `bird_strike`, a flip, and the
documents. How views are written is the subject of the
[LE Views](views.md) tutorial.

## 8. Quick reference

| To… | Do this |
|---|---|
| Ask a question | Pick a **Scenario** and a **Query**, click **Query** |
| Read the reasoning | The explanation tree: green proved, red not proved, amber assumed |
| Find the source of a step | Click the node |
| Find the main reason | Hover **EXPLANATION**; right-click it for **Show important reason** |
| See why there is no answer | The failure explanation: the section checklist, then the red condition |
| Try a what-if | **Scenario Variations**: edit, delete, add or **Assume** facts, then **Query** |
| Find the smallest change that flips an answer | Select the answer, **Flip…** |
| Be walked through an explanation | Right-click **EXPLANATION**, **Explanation Drill…** |
| Show the program to its users | **Misc ▸ Open Executive View** |

The [editor guide](../guide/editor.md) describes each of these in full. The
[Proof Game](../guide/proof-game.md) is another way in: building the proof of
an answer yourself.
