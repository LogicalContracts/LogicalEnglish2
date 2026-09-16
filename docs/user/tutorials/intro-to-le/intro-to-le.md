# A Gentle Introduction to Logical English 2

*Kind: tutorial · Audience: users · Status: current (2026-09-16; screenshots of September 2026, those of s(CASP) of July)*

Logical English (LE) lets you write rules, facts and queries in a controlled subset
of English — and then *run* them. No brackets, no `:-`, no semicolons hiding in the
dark. You write something that reads like a contract or a regulation, and the system
turns it into logic it can reason about, complete with human‑readable explanations of
*why* each answer is (or isn't) true.

This tutorial walks through three small programs, from a whimsical tea party to a
(slightly) serious slice of British nationality law, and introduces the web editor's
tools as we go. Then a fourth program, the Mad Hatter's tea shop, tours the newer
parts of the language — numbers, cascades, tables, dates, constraints, citations —
and the tools around it: tests, the debugger, and screens for the people who use a
program. By the end you will be able to write LE, query it, poke at "what‑if"
scenarios, and interrogate the reasoner until it confesses.

> **Follow along.** Everything here runs in your browser at
> **<https://le2.logicalcontracts.com>** — a public copy of the system. Open the
> editor, then **File → Open copy from server…** and pick the example named in each
> section (`tea_party`, `happy_dragon`, `citizenship`). The tea shop is not on the
> server: you paste it in yourself (§16). No install required.

**Reference material** (you won't need it to follow along, but it's there):

- Language reference: [Logical English syntax summary](../../reference/language.md)
- Editor manual: [How to use the LE2 web application](../../guide/editor.md)
- All examples: [`examples/moreExamples/`](https://github.com/LogicalContracts/LogicalEnglish2/tree/main/examples/moreExamples)

---

## Contents

- [A Gentle Introduction to Logical English 2](#a-gentle-introduction-to-logical-english-2)
  - [Contents](#contents)
  - [1. The editor at a glance](#1-the-editor-at-a-glance)
  - [2. Example 1 — `tea_party`: language basics](#2-example-1--tea_party-language-basics)
    - [Templates — teaching LE your vocabulary](#templates--teaching-le-your-vocabulary)
    - [Facts](#facts)
    - [Rules](#rules)
    - [Negation, and sentences about sentences](#negation-and-sentences-about-sentences)
    - [Scenarios and queries](#scenarios-and-queries)
  - [3. Running a query](#3-running-a-query)
  - [4. Reading explanations](#4-reading-explanations)
  - [5. Example 2 — `happy_dragon`: "for all cases"](#5-example-2--happy_dragon-for-all-cases)
  - [6. Example 3 — `citizenship`: a real little rulebook](#6-example-3--citizenship-a-real-little-rulebook)
  - [7. Scenario Variations: playing "what if"](#7-scenario-variations-playing-what-if)
  - [8. Unknowns: assuming your way to an answer](#8-unknowns-assuming-your-way-to-an-answer)
  - [9. Why *not*? Failure explanations](#9-why-not-failure-explanations)
  - [10. Explanation preferences and the Explanation Drill](#10-explanation-preferences-and-the-explanation-drill)
    - [Preferences](#preferences)
    - [The Explanation Drill](#the-explanation-drill)
  - [11. The important reason of an explanation](#11-the-important-reason-of-an-explanation)
  - [12. Bento Box: an explanation as nested boxes](#12-bento-box-an-explanation-as-nested-boxes)
  - [13. Flip: what would change the answer?](#13-flip-what-would-change-the-answer)
  - [14. Tests: saying what you expect](#14-tests-saying-what-you-expect)
  - [15. When the editor complains: warnings and "?"](#15-when-the-editor-complains-warnings-and-)
  - [16. Example 4 — the tea shop: numbers, cascades, tables, dates](#16-example-4--the-tea-shop-numbers-cascades-tables-dates)
    - [Named constants and arithmetic](#named-constants-and-arithmetic)
    - [`otherwise`: the first alternative that applies](#otherwise-the-first-alternative-that-applies)
    - [A decision table](#a-decision-table)
    - [Calendar months](#calendar-months)
    - [A rule that must never be broken](#a-rule-that-must-never-be-broken)
  - [17. Citing your sources](#17-citing-your-sources)
  - [18. The debugger: breakpoints and steps](#18-the-debugger-breakpoints-and-steps)
  - [19. A screen for the program's users: views](#19-a-screen-for-the-programs-users-views)
  - [20. The LE Assistant: drafting with a language model](#20-the-le-assistant-drafting-with-a-language-model)
  - [21. A second engine: s(CASP)](#21-a-second-engine-scasp)
    - [Seeing the generated s(CASP)](#seeing-the-generated-scasp)
    - [Answers that are *constraints*](#answers-that-are-constraints)
    - [Several possible worlds, and what each assumes](#several-possible-worlds-and-what-each-assumes)
    - [Which engine, when](#which-engine-when)
  - [22. Sharing a program: links and QR codes](#22-sharing-a-program-links-and-qr-codes)
  - [23. Where to go next](#23-where-to-go-next)

---

## 1. The editor at a glance

Open the editor and load `tea_party` (**File → Open copy from server… → tea_party**).

![The LE editor with tea_party.le loaded](01-editor-overview.png)

Five regions matter:

- **Header (top):** the filename, the knowledge‑base name (`KB: tea party`) and a
  **Session** id. The session is the live copy of your program on the server; the
  editor loads it for you when you need it (as soon as you reach for the query
  pickers, for instance). **Home** goes back to the list of examples.
- **Menu bar:** `File`, `Edit`, `Misc` and `Help`. Every menu item has a tooltip
  saying what it does; **Help** lists the documentation, this tutorial included.
- **File tabs:** one tab per open document, as in a browser. `+` opens a new, empty
  document; a dot on a tab means unsaved changes. Each tab keeps its own queries,
  answers and assistant conversation.
- **Code editor (middle):** a Monaco editor with LE syntax highlighting. Keywords
  are coloured, and problems get squiggles with hover‑to‑fix suggestions (§15).
- **Bottom panel:** tabbed **Query** and **LE Assistant**. This is where you run
  things. The small **?** buttons open the part of the documentation about the
  panel they sit in.

This tutorial's screenshots use the **Light** theme. You'll find it — along with
other settings we'll meet later — under **Misc**:

![The Misc menu open: Theme, Font size, Hierarchical Numbering, the engine picker, tests, the executive view and explanation preferences](02-theme-menu.png)

Besides the theme and font size, note **Hierarchical Numbering**, **Run the
Program's Tests…** (§14), **Open Executive View** (§19) and the **EXPLANATIONS →
Preferences…** entry (§10). (**View Source Graph** draws the program as a graph of
templates, rules and facts, in a tab of its own.)

---

## 2. Example 1 — `tea_party`: language basics

Every LE program is built from a few kinds of section. Here is `tea_party` in full:

```le
the target language is: prolog.

the templates are:
*a creature* attends *an event*.
it is prohibited that *an eventuality*.
it is approved that *an eventuality*.
*a creature* is punished with *a sanction*.
*a creature* is a lofty creature.
*a creature* is a lowly creature.

the knowledge base tea party includes:

it is prohibited that a creature attends a tea party if
	it is not the case that
	it is approved that the creature attends the tea party.

a creature is punished with banishment if
	the creature attends a party
	and it is prohibited that the creature attends the party
	and the creature is a lowly creature.

a creature is punished with scolding if
	the creature attends a party
	and it is prohibited that the creature attends the party
	and the creature is a lofty creature.

mad hatter is a lofty creature.
doormouse is a lowly creature.

scenario attendees is:
alice attends the tea party.
mad hatter attends the tea party.
doormouse attends the tea party.
it is approved that alice attends the tea party.
punishment expects answers ["doormouse is punished with banishment","mad hatter is punished with scolding"].

query punishment is:
    which creature is punished with which sanction.
```

Let's take it piece by piece. (The `expects answers` line is a test; we come back to
it in §14.)

### Templates — teaching LE your vocabulary

Before you can *say* anything, you declare the sentence patterns you'll use, under
`the templates are:`. Each template is a sentence with its variable slots wrapped in
asterisks:

```le
*a creature* attends *an event*.
*a creature* is punished with *a sanction*.
```

The **head noun** of a starred phrase is its **type** — `creature`, `event`,
`sanction`. The fixed words in between (`attends`, `is punished with`) are what LE
matches against. Think of a template as the schema for a whole family of sentences:
once `*a creature* attends *an event*` exists, `alice attends the tea party` is a
legal fact and `which creature attends which event` is a legal question.

> Filler words like *a*, *an*, *is*, *are* are ignored when a sentence is matched
> against a template, so you can write naturally. But the articles still matter for
> *meaning*: `a creature` introduces a variable, `the creature` refers back to it, and
> a `the` phrase that nothing introduced — `the tea party` in a scenario — names one
> fixed individual (see [definite descriptions](../../reference/language.md#60-definite-descriptions-back-reference-or-global-constant)).

### Facts

A **fact** is a template instance ending in a period:

```le
mad hatter is a lofty creature.
doormouse is a lowly creature.
```

`mad hatter` and `doormouse` are constants (lowercase names are fine as constants too).

### Rules

A **rule** is `Head if Body.` The body is a list of conditions joined by `and`
(a new line at the same indentation also means "and") and other connectives. Indentation carries meaning
in LE, so line things up:

```le
a creature is punished with banishment if
	the creature attends a party
	and it is prohibited that the creature attends the party
	and the creature is a lowly creature.
```

Note that `the creature` reuses the variable
introduced by `a creature`: same words ⇒ same individual, throughout a rule.

### Negation, and sentences about sentences

LE does negation‑as‑failure with **`it is not the case that`**. The negated goal
goes on its own indented line beneath it:

```le
it is prohibited that a creature attends a tea party if
	it is not the case that
	it is approved that the creature attends the tea party.
```

In English: attending the tea party is prohibited *unless* it was approved.

Now look closely at the two templates this rule leans on:

```le
it is prohibited that *an eventuality*.
it is approved that *an eventuality*.
```

The starred slot `*an eventuality*` is not a creature or a date — its value is *another
whole sentence*. The little word **`that`** is what lets one sentence be *about*
another: `it is approved that (the creature attends the tea party)` embeds the sentence
`the creature attends the tea party` as the argument of `it is approved that …`.
Templates that take a sentence where you would otherwise expect a thing are called
**meta‑templates**, and `that` is the join. They are how LE expresses *propositional
attitudes* — prohibition, approval, belief, saying: all the "someone holds that
⟨sentence⟩" constructions of ordinary legal and everyday language. We'll meet another
one (`… says that …`) in the citizenship example.

### Scenarios and queries

A **scenario** is a named bundle of facts to reason over — your test case or your
"situation." A **query** is the question:

```le
scenario attendees is:
alice attends the tea party.
mad hatter attends the tea party.
doormouse attends the tea party.
it is approved that alice attends the tea party.

query punishment is:
    which creature is punished with which sanction.
```

`which creature` / `which sanction` are the things we want filled in. Alice is safe
(her attendance was approved). The Mad Hatter is lofty, the Doormouse lowly — so we
expect a scolding and a banishment respectively. Let's confirm it.

---

## 3. Running a query

In the **Query** tab at the bottom:

1. Pick a **Scenario** — `attendees`.
2. Pick a **Query** — `which creature is punished with which sanction (punishment)`.
3. Click **Query**.

![Query tab with answers for the tea party punishment query](03-query-panel.png)

Two answers appear on the left:

- *doormouse is punished with banishment*
- *mad hatter is punished with scolding*

Alice is absent from the list — exactly right, since her attendance was approved and
so nothing about her is prohibited. (Justice at the tea party is swift but fair.)

The address bar now names the example, the scenario and the query: copy it to give
someone the same run. The other buttons in the row — **Scenario Variations**,
**Flip…**, **Trace** and **Proof Game** — each get their turn below. (The **Engine**
picker is §21's business; leave it on Prolog.)

> The **Query** button is disabled while your program has errors. If it's greyed out,
> check the editor for red squiggles first. A query still running after a couple of
> seconds shows an **Interrupt** button.

---

## 4. Reading explanations

Click an answer — say *doormouse is punished with banishment* — and the **EXPLANATION**
panel on the right draws the reasoning as a tree:

![Explanation tree for 'doormouse is punished with banishment', fully expanded](04-explanation-tree.png)

Each tree node is one condition, colour‑coded by status:

- **green** — proven true;
- **red** — could not be proven;
- **amber** — *unknown*: neither proved nor refuted, but assumed true (more on this
  in §8).

Here the doormouse attends the tea party, it is prohibited, and the doormouse is a
lowly creature. Open the prohibition all the way down and you find the one red node:
*it is approved that doormouse attends the tea party*. Red inside a negation is what
the rule wanted — the prohibition holds precisely *because* approval could not be
found, so *it is not the case that …* above it is green.

Two handy moves:

- **Click any node** and the editor scrolls to — and highlights — the exact rule or
  fact that produced it. Great for "where did *that* come from?"
- **Expand/collapse** with the `−`/`+` toggles. The top two levels open by default.

Right‑click in the tree for **Copy Explanation** (as text and HTML) and **Copy as
Mermaid diagram**, to paste a proof into a document.

---

## 5. Example 2 — `happy_dragon`: "for all cases"

Load `happy_dragon`. It's short, and its job is to introduce one genuinely new
idea — **`forall` conditions** (universal quantification) — while giving the negation
we met at the tea party a second airing in a fresh setting.

![happy_dragon.le in the editor](05-happy-dragon-editor.png)

```le
A creature is healthy
    if the creature is a dragon
    and it is not the case that
	the creature smokes.

A creature is happy
    if the creature is a dragon
    and for all cases in which
	    the creature is a parent of an other creature
		it is the case that
		the other creature is healthy.
```

- **Healthy** reuses the negation from §2 (`it is not the case that`): a dragon is
  healthy if it does *not* smoke — nothing new here, just the same construct feeding a
  different conclusion.
- **Happy** is where the new idea lives: **`for all cases in which … it is the case
  that …`**. A dragon is happy when *every* one of its children is healthy. A dragon
  with no children is happy vacuously — the universal is satisfied when there's nothing
  to check.

Also note `an other creature`: the qualifier **other** makes it a *distinct*
`creature` variable from `the creature`, so a dragon isn't accidentally required to
be its own parent. (Small word, big consequence.)

Run scenario `smoky` with query `which dragon is happy (happy)`, then click
*alice is happy*:

![happy_dragon answers with a 'for all cases' explanation node](06-happy-dragon-answers.png)

Both `bob` and `alice` are happy. Alice's explanation contains a **for all cases in
which alice is a parent of a dragon** tree node, expanding to the one case that matters
(*for case alice is a parent of bob*) and confirming that bob is healthy — because
*bob smokes* could not be proven (bob would smoke only if a parent of his smoked, and
nobody is a parent of alice). The universal became a concrete, checkable list — which
is exactly what makes LE explanations pleasant to read.

---

## 6. Example 3 — `citizenship`: a real little rulebook

Time for something with the flavour of actual law. `citizenship` is a miniature
homage to the classic British Nationality Act formalisation. Load it:

![citizenship.le in the editor](07-citizenship-editor.png)

The central rule:

```le
a person acquires British citizenship on a date
if the person is born in the UK on the date
	and the date is after commencement
	and an other person is the mother of the person
    	or the other person is the father of the person
	and the other person is a British citizen on the date
    	or the other person is settled in the UK on the date.
```

In words: you acquire citizenship if you were born in the UK after commencement and a
parent (mother *or* father) was, at the time, a British citizen *or* settled in the
UK. This one rule mixes `and`/`or` and shares the variable `an other person` across
the parent conditions — the same parent must satisfy both the "is a parent" and the
"citizen/settled" parts.

The program uses another **meta‑template** — the same "sentence about a sentence"
idea we met with `it is approved that …` back at the tea party (§2). This time the
propositional attitude is *saying*:

```le
a person is the father of an other person
if a third person says
    that the person is the father of the other person
    and the third person is qualified to determine fatherhood.
```

`… says that …` again uses `that` to let one fact be *about* another sentence: a third
person's *saying* that someone is the father — together with their being qualified to
determine fatherhood — is what makes the fatherhood hold. And dates (`2021-10-09`) are
first‑class values you can compare with `after`/`before`.

Run scenario `alice` with query `one` and click the answer:

![citizenship query 'one' answered for scenario alice](08-citizenship-query.png)

*John acquires British citizenship on 2021‑10‑09* — proven green all the way down:
John was born in the UK after commencement, Alice is his mother, and Alice is a
British citizen. So far, so lawful. Now let's start meddling.

---

## 7. Scenario Variations: playing "what if"

Scenarios in the file are fixed. But real questions are usually *"…and what if they
weren't?"* The **Scenario Variations** window lets you take a scenario, change the
facts, and re‑run queries against the altered version — **without touching your
program**.

With scenario `alice` and query `one` selected in the Query tab, click **Scenario
Variations** (the button beside **Query**). A new window opens, pre‑seeded with that
scenario:

![The Scenario Variations window, seeded with the alice scenario](09-variations-window.png)

The facts are shown as **fill‑in‑the‑blank forms**, not raw text — so you never have
to remember a template's exact wording. The fixed words are labels; only the
placeholder fields are editable:

> `[John]` is born in `[the UK]` on `[2021-10-09]`

You can edit fields, **✕**‑delete a fact, **Add fact** from a template menu, tick
**Assume** (next section), or use **❝** to note the passage of a document that states
the fact (§17). The selected query appears as a card below. Hit **Query** at the
bottom to run every listed query against the current facts:

![Scenario Variations after running: John acquires citizenship, all green](10-variations-answer.png)

Same green success as before — but now on facts *you* control. The **Query** button
disables itself after a run and re‑enables the moment you change anything, so you
always know whether the results below are current. And because the whole variation is
encoded in the window's URL, you can copy that URL to **share exactly what you're
exploring** with a colleague. (**Copy Scenario** also drops the edited `scenario … is:`
block on your clipboard, ready to paste back into the program.)

> The same forms edit the program's *own* scenarios: **Edit → Edit Scenarios…** opens
> the Scenario Editor, and **Edit → Edit Queries…** builds queries from your templates
> the same way. Both write their result back into the editor. See the
> [Scenario Editor](../../guide/editor.md#the-scenario-editor) and the
> [Query Editor](../../guide/editor.md#the-query-editor).

---

## 8. Unknowns: assuming your way to an answer

Here's the interesting bit. What if we're *not sure* Alice is a British citizen — we
just want to explore the consequence of assuming she is?

Tick the **Assume** checkbox on the *"Alice is a British citizen on 2021‑10‑09"* row
and re‑run:

![An assumed fact produces an amber 'unknown' node and an answer flagged with '?'](11-variations-assume.png)

Three things changed:

1. The assumed fact's fields become **non editable** — it's no longer a plain fact but an
   *assumption*. Behind the scenes this rewrites it as
   *"it is unknown whether Alice is a British citizen on 2021‑10‑09."*
2. The answer is still there, but now carries a **`?`** marker — it holds *only under
   an assumption*. Hover the answer to see the list of unknowns it rests on.
3. In the explanation tree, the *"Alice is a British citizen…"* node is **amber**
   instead of green: it wasn't proven, it was **assumed true because it's unknown**.

This is LE's way of reasoning with incomplete information: *"John would acquire
citizenship — provided Alice is indeed a citizen, which we're currently assuming."*
The amber nodes are precisely the open questions your conclusion still depends on.

**Assuming a whole predicate, not just a fact.** Ticking **Assume** turns one
*particular* fact into an unknown. Sometimes, though, an entire *kind* of fact is
inherently uncertain, and you want every goal of that shape to be assumable whenever it
can't be proven. For that you mark the **template** itself, adding `; assumable`
(equivalently `; unknown` or `; assumed`) after its declaration:

```le
the templates are:
*a person* is a British citizen on *a date*; assumable.
```

Now *any* "… is a British citizen on …" goal the reasoner cannot prove is
automatically treated as unknown and assumed true — no per‑fact ticking needed — and
every answer that relied on it comes back with the same `?` marker and amber node we
saw above. It's the difference between "assume *this* fact" (the checkbox) and "treat
*this whole predicate* as open" (the template addition). You can still pin a single
instance, in the knowledge base or a scenario, with `it is unknown whether …`:

```le
it is unknown whether Alice is a British citizen on 2021-10-09.
```

(See the [template additions](../../reference/language.md#template-additions-after-)
in the language reference for the full story.)

---

## 9. Why *not*? Failure explanations

Assumptions make things true; deletions make them false. Delete the *"Alice is a
British citizen…"* fact entirely (its **✕**) and re‑run:

![A failure explanation: 'No answers (false)', with the unmet conditions in red](12-variations-fail.png)

Now the answer is **No answers (false)** — and the explanation turns into a
**why‑not** tree. LE doesn't just shrug; it shows which condition broke. The
sub‑goal *"Alice is a British citizen … or Alice is settled in the UK …"* is **red**,
because neither disjunct could be established once we removed the citizenship fact.
The parts that still hold (John is born in the UK, Alice is the mother of John) stay
green, so you can see exactly how far the proof got before it stalled. (The father
branch is red too: nobody says who John's father is.)

Failure explanations are often *more* useful than success ones: they tell you the one
fact you'd need to add — or assume — to flip the result. In this window a right‑click
on a red node even offers **Patch scenario — add this fact** and **Assume fact**. And
§13 shows how to ask for the flip directly.

---

## 10. Explanation preferences and the Explanation Drill

Real rulebooks produce big trees. Two features keep them manageable.

### Preferences

Open **Misc → EXPLANATIONS → Preferences…**:

![The Explanations Preferences dialog](13-explanation-preferences.png)

- **Prefix for failed nodes:** text prepended to failed nodes when you **Copy
  Explanation** (handy when pasting into somewhere that loses the colours).
- **Detailed failure explanations (per‑rule nodes):** when on, a failed goal trying
   several rules shows one node per rule. Thorough, but slower — off by default.
- **Hide repeated explanations** (*on by default, keep it on*): large trees — failure
  trees especially — repeat the same sub‑proof many times. This collapses each repeat
  to a single italic line tagged with its occurrence count, so you see the *shape* of
  the reasoning instead of a wall of duplicates.
- **Larger important reasons** — see §11.

Also worth a mention from the **Misc** menu: **Hierarchical Numbering** prefixes each
node with its position (`1.2.3`) — invaluable when discussing a specific step with
someone else.

### The Explanation Drill

For "there are forty nodes and I only care about *the* reason," use the
**Explanation Drill**. Right‑click the **EXPLANATION** title and choose **Explanation
Drill…**. A separate window opens and walks you through the proof as a sequence of
yes/no questions. Here it is on `happy_dragon`'s *alice is happy*, after one answer:

![The Explanation Drill window: a question answered 'Not yet' and the next one](14-explanation-drill.png)

At each step it shows the **most important reason** of what's left and asks
**Accept?**:

- **Yes** — "I get that part"; it's set aside and the drill moves to the next most
  important reason.
- **Not yet** — "dig deeper"; the drill descends into that reason and asks about *its*
  most important part. (Why is bob not a smoker? Because alice, his parent, is not
  one either.)

A progress bar fills as you accept parts, each question highlights its source in the
editor, and you can revise any earlier answer (or **✕** a question) at any time. Once
you have accepted every part of a reason you answered *Not yet*, that reason counts as
accepted and the drill goes back to what is left around it. When everything is
accepted, the bar is full and it says *"Nothing else to show."* It's a systematic
way to narrow a big proof down to the single intermediate fact that explains it.

---

## 11. The important reason of an explanation

A big proof has many true nodes, but usually *one* of them is the crux — the
intermediate fact that most explains why the answer holds (or, for a failure, the
condition whose absence sank it). LE computes this **important reason** for every
answer and offers two ways to see it.

Run `citizenship` with scenario `alice`, query `one`, and click the answer. The
**EXPLANATION** title now carries the reason as a tooltip (its dotted underline is
the hint) — and **right‑click the title** for the action:

![The EXPLANATION title menu with 'Show important reason'](15-important-reason.png)

Choose **Show important reason** and the tree expands straight to that node, opens
it one level, and flashes it — no hunting through forty green lines. This is the
same notion the **Explanation Drill** (§10) walks you through step by step; here it
is a single jump to the headline.

Two things shape it:

- **Larger important reasons** (a preference, *on by default*): for a *failed* query,
  instead of a single deepest culprit it lists all the equally‑deep dead ends as
  *"it is not the case that X, nor that Y, nor that Z"* (truncated after the third).
  One glance at everything you'd need to fix.
- The reason is deliberately **invariant** to the "Detailed failure explanations"
  setting — turning per‑rule nodes on or off never changes *which* fact is called
  the important one.

---

## 12. Bento Box: an explanation as nested boxes

The tree is not the only way to read a proof. **Bento Box** draws the same
explanation as a set of *nested compartments*: the outer box is the rule that
proved the answer, the boxes inside it are that rule's conditions, and the
innermost leaves are the facts. It turns "how does this proof decompose?" into a
picture you take in at a glance.

Load `happy_dragon` (scenario `smoky`, query `happy`), run it, then **right‑click
the answer *alice is happy* → Bento Box…**. A new window opens:

![The Bento Box view of 'alice is happy', with a colour legend](16-bento-box.png)

- Each compartment has its own colour, keyed to the **Legend** on the right (with
  the same hierarchical numbers as §10's numbering).
- **Hover** a box for its sentence; **click** it to highlight the source rule/fact
  back in the editor — exactly like clicking a tree node.
- A **failed** branch is an empty dark compartment. Here the dark box is *bob
  smokes*, which could not be proven — and that failure is exactly what makes *it is
  not the case that bob smokes* hold.

Bento Box is especially good for showing *shape* — how much of an answer rests on
one fat rule versus many small ones.

---

## 13. Flip: what would change the answer?

Scenario Variations lets *you* try one change at a time. A **flip** asks the program
itself: *which smallest changes to the scenario would change this answer?*

Back in the editor, with `citizenship`, scenario `alice` and query `one`, run the
query, select the answer and click **Flip…**:

![The Flip dialog, proposing to make John's citizenship not the case](17-flip-dialog.png)

The dialog proposes the question *which minimal change to the scenario makes it the
case that it is not the case that John acquires British citizenship on 2021‑10‑09*.
Untick **it is not the case that** to ask what would make a sentence *true* instead,
or edit the sentence. Click **Flip**:

![The flip's answers: four single-fact removals, each with its proof](18-flip-answers.png)

Each answer is one minimal change — here, removing any one of the four facts of the
scenario — and selecting it shows the proof the changed scenario gives. The flip ran
as a *custom query* (the **Query** picker now says **Another…**), so you can edit and
rerun it. A program can also keep a flip as a query of its own:

```le
query flip is:
    which minimal change to the scenario makes it the case that
        it is not the case that John acquires British citizenship on 2021-10-09.
```

Flips only add or remove *case* facts — facts of templates marked `; undefined`
(§16), or, in a program that marks none, of templates no rule concludes. More in
[flip queries](../../reference/language.md#177-flip-queries-which-minimal-change-flips-the-outcome)
and in the tutorial [Querying a program](../querying-a-program.md#5-flip-what-would-change-the-answer).

---

## 14. Tests: saying what you expect

Remember the extra line in the tea party's scenario?

```le
punishment expects answers ["doormouse is punished with banishment","mad hatter is punished with scolding"].
```

It is a **test**: it names a query (`punishment`, without the word `query`) and the
answers it should give on this scenario. You can also say which unknowns an answer
may rest on — `… expects answers [...] and unknowns ["Alice is a British citizen on
2021-10-09"]` — and a flip query says `expects changes [[...]]`.

The editor runs the tests whenever it checks the program (as far as a few seconds
allow), and a failing one shows up as a warning. To run them all and see the
outcome, open `citizenship` — each of its four scenarios has a test — and choose
**Misc → Run the Program's Tests…**:

![The test report of citizenship.le: four tests passed](19-test-report.png)

A test that fails lists what was expected and what came instead; a click on a row
selects its scenario and query, ready to run. Write a test as soon as an answer is
right: it will tell you the day a change to the rules breaks it. See
[testing and expectations](../../reference/language.md#12-testing-and-expectations).

---

## 15. When the editor complains: warnings and "?"

The editor checks your program as you work. Errors (red) stop the program from
running; **warnings** (yellow) say something looks suspicious. Back in
`happy_dragon`, line 9 is underlined. Hover it:

![A warning's hover: 'This template is never used', with a link to the warnings guide](20-verifier-warning.png)

*This template is never used* — `*a collection* is a bag of *a thing* that *a
condition*` is declared but nothing mentions it. The hover ends with a link (here
**warnings guide**) to the section of the documentation that explains the warning
and how to fix it, and **Quick Fix…** offers the fixes the editor knows (adding a
missing template, for instance). Other warnings you will meet early: a *missing
template* for a sentence that matches none, a predicate *not tested by any query*,
and a *test failed* (§14). They are all in [the verifier's warnings](../../guide/warnings.md).

More ways to get help without leaving the editor: the **?** beside each panel opens
its part of the manual, a right‑click on a word of the program offers
**Documentation for this**, and **Help → Search the documentation…** searches all of
it.

---

## 16. Example 4 — the tea shop: numbers, cascades, tables, dates

The Mad Hatter has opened a tea shop, and its prices need rules. This program is not
on the server: click **+** on the tab strip for a new, empty document, paste the
program in, and open the **Scenario** picker: the program loads, and its scenarios
and queries appear.

```le
the target language is: prolog.

the templates are:
    *a guest* orders *a number* cups of tea; undefined.
    *a guest* is a member; undefined.
    *a guest* has an unbirthday today; undefined.
    *a guest* is banished; undefined.
    *a party* has *a number* guests; undefined.
    the membership of *a guest* started on *a date*; undefined.
    the discount of *a guest* is *a percentage*.
    the bill of *a guest* is *an amount*.
    *a guest* is one cup away from a free cup.
    the cake for *a number* guests is *a cake* under table cakes.
    the cake of *a party* is *a cake*.
    the membership of *a guest* expires on *a date*.

the constants are:
    the price of a cup is 3.

the table cakes is, with first match:
    size   | guests        | cake
    small  | <= 2          | cupcake
    medium | > 2 and <= 6  | sponge cake
    large  | > 6           | three tier cake

the knowledge base tea shop includes:

the bill of a guest is an amount A
    if the guest orders a number N cups of tea
    and the value of the price of a cup is a price P
    and the discount of the guest is a percentage D
    and A = (N - N // 3) * P * (100 - D) / 100.

a guest is one cup away from a free cup
    if the guest orders a number N cups of tea
    and R = N mod 3
    and R = 2.

the discount of a guest is a percentage
    if the guest is a member
        and the percentage is 20
    otherwise the guest has an unbirthday today
        and the percentage is 10
    otherwise the percentage is 0.

the cake of a party is a cake
    if the party has a number guests
    and the cake for the number guests is the cake under table cakes.

the membership of a guest expires on a date
    if the membership of the guest started on a start date
    and the date is 6 months after the start date.

it must not be true that
    a guest is a member
    and the guest is banished.

scenario saturday is:
    alice orders 5 cups of tea.
    alice is a member.
    the hatter orders 7 cups of tea.
    the hatter has an unbirthday today.
    the dormouse orders 2 cups of tea.
    the membership of alice started on 2026-08-31.
    the garden party has 5 guests.
    bills expects answers ["the bill of alice is 9.6", "the bill of the hatter is 13.5", "the bill of the dormouse is 6"].
    nearly expects answers ["alice is one cup away from a free cup", "the dormouse is one cup away from a free cup"].
    cake expects answers ["the cake of the garden party is sponge cake"].
    expiry expects answers ["the membership of alice expires on 2027-02-28"].

scenario trouble is:
    the knave orders 2 cups of tea.
    the knave is a member.
    the knave is banished.
    bills expects answers [].

query bills is:
    the bill of which guest is which amount.

query nearly is:
    which guest is one cup away from a free cup.

query cake is:
    the cake of which party is which cake.

query expiry is:
    the membership of which guest expires on which date.
```

Two things first. The templates marked **`; undefined`** are the *case facts*: they
are stated in scenarios, never concluded by rules (the flip of §13 and the views of
§19 use this). And every query has a test, so **Misc → Run the Program's Tests…**
should report five passes before you change anything.

### Named constants and arithmetic

`the constants are:` gives a value a name, one per line. A rule reads it with
`the value of the price of a cup is a price P` — and an explanation shows it as a
reason (*the price of a cup is 3*). Change the price in one place and every bill
follows.

The bill is arithmetic: `+`, `-`, `*`, `/`, brackets, and the integer operations
`//` (division, rounded down) and `mod` (the remainder). Every third cup is free, so a
guest pays for `N - N // 3` cups. Variables in a formula are short capital names
(`N`, `P`, `D`), introduced by a condition first (`a number N`). Run `bills` on
`saturday` and select the hatter's bill:

![The hatter's bill: 7 cups, the price of a cup, a 10 percent discount, and the formula](21-tea-shop-bill.png)

`nearly` finds the guests one cup away from a free one: `R = N mod 3` computes the
remainder, then `R = 2` tests it. (`N mod 3 = 2` in one condition does the same: a
formula is evaluated on either side of `=`.) See [arithmetic and comparisons](../../reference/language.md#7-arithmetic-and-comparisons).

### `otherwise`: the first alternative that applies

The discount is a **cascade**. A line that starts with `otherwise` begins a new
alternative, which applies only when all the earlier ones fail: 20 for members,
otherwise 10 on an unbirthday, otherwise nothing: Alice, a member, gets 20; the
hatter, not a member but on his unbirthday, gets 10; the dormouse gets 0. In the
hatter's explanation the cascade shows as *it is
not the case that the hatter is a member* — the alternative that did not apply —
followed by the one that did. Each alternative's conditions may also share its line
(`otherwise the guest has an unbirthday today and the percentage is 10`); on their own
lines, as above, they are easier to read. See [`otherwise` cascades](../../reference/language.md#172-otherwise-cascades).

### A decision table

`the table cakes is, with first match:` is a small **decision table**, bound to the
one template whose words name it (`… under table cakes`). Its columns are the
template's places in order — here, with one extra column in front, the row's name —
and the last column is the result. A cell may be a value, a comparison
(`> 2 and <= 6`), or `any`. *First match* means the first row that fits answers. Run
`cake`: the garden party has 5 guests, so it gets *sponge cake*, and the explanation
cites *row medium of table cakes*. See [decision tables](../../reference/language.md#173-decision-tables).

### Calendar months

`the date is 6 months after the start date` counts **calendar months**, keeping the
day where the month has it and otherwise taking the month's last day. Run `expiry`:
Alice's membership, started on 31 August 2026, expires on **2027‑02‑28** — there is no
31 February. (Days work the same way: `… is 30 days after …`.)

### A rule that must never be broken

```le
it must not be true that
    a guest is a member
    and the guest is banished.
```

An **integrity constraint** says that some conditions must never hold together. A
scenario whose facts break it is inconsistent, and nothing follows from it. Run
`bills` on the scenario `trouble`, where the knave is both:

![No answers: the case breaks a constraint, and the explanation shows it](22-tea-shop-constraint.png)

No bill, and the explanation says why: *the case breaks a constraint … its conditions
hold*, with the two facts beneath. Constraints matter most with unknowns (§8): an
answer that would need to *assume* something the constraint forbids is not given. See
[integrity constraints](../../reference/language.md#33-integrity-constraints-it-must-not-be-true-that-).

---

## 17. Citing your sources

Rules come from somewhere — a statute, a policy, a notice on the tea shop's wall —
and facts come from someone. LE can say so, without changing what the rules prove.
Make three changes to the tea shop. Label the bill rule with the document it
encodes:

```le
rule every_third_cup with provenance the tea shop notice,
        confer "Every third cup is on the house":
the bill of a guest is an amount A
    if the guest orders a number N cups of tea
    ...
```

Say, in the scenario's header, which document its facts come from (and quote a
passage with `confer`):

```le
scenario saturday is, as stated in the order book at page 12:
    alice orders 5 cups of tea, confer "Alice, five cups".
```

And say who asserts a fact, and why:

```le
    the hatter has an unbirthday today,
        according to the March Hare, because "he says so every day".
```

These **trailers** — `according to`, `as stated in … at …`, `because`, `confer` —
come after a comma. Run `bills` again and select the hatter:

![The explanation with its citations, each with a § badge](23-cited-explanation.png)

Every cited step now reads with its source, and carries a **§** badge. Click the §
of *the bill of the hatter is 13.5*:

![The source viewer for the tea shop notice, which has no text yet](24-source-viewer.png)

The **source viewer** names the document, the rule and the passage. It would show the
document itself, with the passage highlighted, if the program said where its text is
— which is what the message suggests:

```le
the tea shop notice is published at "https://example.org/notice.html".
the text of the tea shop notice is at "notice.txt".
```

(A text file lives beside a saved program.) With those, a right‑click on a citing
line of the program and **View Original Text** opens the passage, and the verifier checks that each
quoted passage really is in the text. See
[provenance trailers](../../reference/language.md#171-provenance-trailers-and-judged-templates)
and [rule labels and provenance](../../reference/language.md#155-rule-labels-and-provenance).

---

## 18. The debugger: breakpoints and steps

When an answer is missing and the explanation doesn't make it obvious why, watch the
program run. Load `tea_party`, pick scenario `attendees` and query `punishment`, and
click in the margin left of line 20's number (`and the creature is a lowly
creature`) to set a **breakpoint**. Then click **Trace**, and in the **LE Debugger**
panel click **Continue**:

![The LE Debugger stopped at a breakpoint on line 20, with the call stack and variables](25-debugger.png)

The run stops at line 20, highlighted. The **call stack** shows how it got there —
it is trying *mad hatter is punished with banishment* and now asks whether *mad
hatter is a lowly creature* (he is not, so this rule will fail for him) — and
**VARIABLES** shows the bindings: *a creature = mad hatter*. From here:

- **Step** (F11) goes to the next goal, into the rules it calls;
- **Step over** (F10) goes to the next goal at this level, without stopping inside;
- **Continue** (F5) runs to the next breakpoint or answer;
- **Stop** ends the query.

Right‑click in the editor → **See PROLOG** shows the Prolog the program became. More
in the [editor manual](../../guide/editor.md#advanced-features).

---

## 19. A screen for the program's users: views

The editor is for the person who *writes* a program. The people it decides for — a
shop assistant, a caseworker, a citizen — need a simpler screen. **Misc → Open
Executive View** opens one: the program without its text, a scenario picker, a query
picker, and the answers as cards that open onto their explanations. It works on the
program as it is in the editor, unsaved changes included.

A **view** says how that screen should look for one kind of decision — in LE, at the
end of the program. You don't have to start from nothing: with the tea shop open,
choose the **LE Assistant** tab and press **Generate LE view** (no language model
needed):

![Generate LE view: a first view of the tea shop, appended to the program](26-generate-view.png)

The draft lists the case facts, takes the first query as the result, and adds what
the program can show. Edit it into this — a title, the orders grouped, the amount as
the headline:

```le
the view till is:
    the title is "The Mad Tea Shop".
    the case is a scenario.
    the facts about "the orders" are
        a guest orders a number cups of tea,
        a guest is a member,
        a guest has an unbirthday today.
    the result is the answer to query bills, headed by the amount.
    the result shows its reasons.
```

Then **Misc → Open Executive View** and choose the view **The Mad Tea Shop** at the
top:

![The view 'The Mad Tea Shop': the orders as editable rows, the bills in large type, the reasons](27-view-till.png)

The orders are rows to edit (the other case facts are below them), each bill is in
large type, and the reasons are listed. Change Alice's 5 cups to 7 and press
**Re‑evaluate**: her bill becomes 12. A view changes nothing in how the program reasons, and the verifier
checks every sentence of it against the program's templates and queries. Views can
also run an interview, one question at a time, or show what would flip the result:
the tutorial [Introducing LE Views](../views.md) builds them step by step, and
[the executive view](../../guide/executive-view.md) describes the screen.

---

## 20. The LE Assistant: drafting with a language model

You don't have to write every template and rule by hand. The **LE Assistant** tab
(next to **Query**) is a chat panel where you ask, in plain English, for the change
you want — *"add a rule…", "fix this warning", "why does scenario saturday fail?"* —
and a language model edits the program for you, **running the LE verifier and queries
in the loop** so what it hands back actually parses and runs.

The **Light Mode** checkbox chooses how: **Light** (the default) is a fast loop on the
server that only edits your program and calls the verifier and queries; unticked,
**Deep** mode runs a full coding agent. Pick a model and enter your provider's key in
**Misc → API Keys & Assistant Settings…** (a server may supply keys of its own, in
which case you need none). Then type a request — say, *"add a rule that a guest is
thirsty if the guest orders more than 6 cups of tea, with its template and a query"*
— and **Send**. The assistant edits, verifies, runs, and applies the result to the
editor; **Edit → Undo** reverts anything you don't like.

The same models power **Write it in English** in the Scenario Editor and Scenario
Variations: describe a case in a sentence, and it becomes facts of *your* templates.

> The Assistant is an accelerator, not an oracle — always read what it wrote. But for
> boilerplate (templates, scaffolding a scenario, echoing a rule in a new shape) it
> removes most of the typing. See [the assistants](../../guide/assistants.md).

---

## 21. A second engine: s(CASP)

Everything so far ran on LE's **Prolog** engine. LE can also execute the *same
program* under **s(CASP)** — a goal‑directed Answer Set Programming engine — which
brings three things Prolog can't: answers that are **constraints**, **several
stable models** ("possible worlds") for one query, and **abduction** ("what would
have to be true?"). A program says which engine it prefers in its first line
(`the target language is: scasp.`), and the **Engine** picker in the Query tab lets
you switch by hand. (For Prolog‑only programs the picker can be hidden: **Misc →
ENGINE PICKER → Show engine choice only for non‑Prolog**.) The s(CASP) engine must be
installed on the server that runs the program; where it is not, both a query and See
s(CASP) say so.

### Seeing the generated s(CASP)

LE compiles a *separate* s(CASP) program from your rules. **Right‑click the editor →
See s(CASP)** shows it:

![The generated s(CASP) program for clp_coverage](28-scasp-program.png)

Two things to notice in the output: each LE template becomes a **`#pred`** directive
carrying its English sentence (so s(CASP)'s own explanations read in your domain
language), and the comparison `the amount is greater than 25000` is lowered to the
**constraint** `#>(A, 25000)` — not a test on a fixed number. That last point is the
key to the next feature.

### Answers that are *constraints*

Because comparisons become constraints, s(CASP) can answer a query **with no concrete
scenario at all**. Load `language/scasp/clp_coverage` (it declares `scasp`, so the
engine pre‑selects), pick the `covered` query — no scenario — and hit **Query**:

![A symbolic s(CASP) answer: any amount greater than 25000](29-scasp-constraint.png)

The answer is not a value but a *phrase*: **"a claim of any amount greater than
25000 is covered."** You asked "which amounts are covered?" and got the condition
itself, rendered through the template. This is how you ask *"under what circumstances
would this hold?"* directly.

### Several possible worlds, and what each assumes

When a program has *assumable* facts (§8's `; assumable`), one query can be true in
**several different ways**. s(CASP) enumerates them as distinct **models**. Here
`language/abduction/loan_approval` (several assumable applicant attributes) is
queried under s(CASP):

![Multiple s(CASP) models labelled 'world 1 of 4', with assumption tooltips](30-scasp-worlds.png)

- The answers pane groups results as **"world 1 of 4", "world 2 of 4", …** — one card
  per genuinely distinct world.
- Each carries the familiar **`?`** marker: it holds *under assumptions*. Hover it (or
  read the amber nodes in the tree) to see the **assumption set** — e.g. *"2 unknown
  goals: the applicant owns property, the applicant has a good credit score."* That is
  abduction: the engine tells you what it *had to assume* to make the loan approve, and
  a different world assumes something different.

Negation is richer too: where Prolog shows a failed `not` as a red absence, s(CASP)
*proves* the negation and shows why the inner goal fails, rule by rule.

### Which engine, when

Keep **Prolog** as the default — it is faster and handles aggregates, dates, `prolog`
goals and large fact sets. Reach for **s(CASP)** when you want constraint answers,
"what must be assumed" questions, multiple possible worlds, or a program that loops
through negation (where Prolog may misbehave and the editor will warn you). A program
s(CASP) cannot state faithfully is refused, with the list of problems and their lines,
rather than run wrongly (and it points you back to Prolog). The full story is in [s(CASP) on Logical English](../../reference/scasp.md).

---

## 22. Sharing a program: links and QR codes

We've already met two ways to share: the editor's address (`?example=…&scenario=…&query=…`,
§3) and a Scenario Variations link (§7). For handing a program to someone on a phone —
in a talk, a classroom, across a desk — there's **File → QR code…**:

![The QR code dialog for happy_dragon](31-qr-code.png)

Scanning it opens the exact program, scenario and query in the recipient's browser;
**Copy URL** puts the same link on the clipboard. A server example travels as its
short URL; an **edited, unsaved** document is compressed straight into the link (a
`#lzp=` fragment the editor inflates on load), so even a program that lives nowhere
but your editor is shareable. If a document is too big for a scannable code, the
dialog says so rather than producing an unreadable one. To keep a program, **File →
Save As…** saves it to your computer, and **File → Open…** brings it back.

---

## 23. Where to go next

You now know enough to be dangerous:

- **Templates** declare your vocabulary; **facts** and **rules** (`Head if Body`) say
  what's true; **`and` / `or` / `it is not the case that` / `for all cases in which`**
  build the logic; **scenarios** supply situations; **queries** ask questions; **tests**
  (`expects answers`) keep answers right.
- **Constants**, **arithmetic** (with `//` and `mod`), **`otherwise`** cascades,
  **decision tables**, **calendar months** and **integrity constraints** cover most of
  what rulebooks need; **provenance trailers** say where each rule and fact comes from.
- The **Query** tab runs them; **explanations** show why (as a tree, as the
  **important reason**, as a **Bento Box**, or through the **Drill**); **Scenario
  Variations** and **Flip…** explore "what if"; **Assume** reasons under uncertainty
  (amber = unknown); failure trees tell you what's missing; the **debugger** shows the
  run itself.
- **Views** and the **executive view** give a program's users a screen of their own;
  the **LE Assistant** drafts and fixes LE for you; the **s(CASP)** engine adds
  constraint answers and possible worlds; **QR codes** hand a program to a phone.

From here:

- Work through [Querying a program](../querying-a-program.md), which runs a real
  regulatory program (EU flight compensation) through queries, why not, flips and the
  Drill, and [Introducing LE Views](../views.md).
- Skim the [language reference](../../reference/language.md) for the parts we skipped:
  aggregates (`sum`, `count`, …), the taxonomy / `is a` hierarchy, synonyms,
  prepositional templates, included resources and shipped libraries, and the rest of
  the [regulatory‑decision constructs](../../reference/language.md#17-regulatory-decision-constructs)
  (judged templates, the applicability / question / remedy skeleton, `according to` in
  a rule).
- Read the [editor manual](../../guide/editor.md) for the Scenario and Query Editors,
  file tabs, the Source Graph and the rest; play the [Proof Game](../../guide/proof-game.md),
  which has you build a proof yourself.
- Coming from another rules system? [Other systems: importing and exporting](../../integrations/index.md)
  says which systems' files the editor can open as LE, and write back.
- Browse the [examples](https://github.com/LogicalContracts/LogicalEnglish2/tree/main/examples/moreExamples)
  — `language/includes/citizenship_including`, `royal_family`, `language/templates/subset`,
  the `domains/tax/` set, and the programs of
  [`examples/regulatory/`](https://github.com/LogicalContracts/LogicalEnglish2/tree/main/examples/regulatory)
  — and open any of them straight from the running system at
  **<https://le2.logicalcontracts.com>**.

Now go write a rule. The tea party awaits, and someone has to decide who gets
banished.
