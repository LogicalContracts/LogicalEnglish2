# The Proof Game — A Teacher's Guide

The **Proof Game** turns a Logical English query into a hands-on puzzle. Instead of
reading a proof, students *build* one: they drag rules and facts together until they
have explained **why** an answer is true (or why something is **not** true). It is
designed to make the core ideas of logical reasoning — rules, facts, variables,
matching, negation, and "for all" — visible and tactile.

This guide explains the main concepts and how to run a lesson with it. No
programming background is needed.

---

## 1. What the game is for

When Logical English answers a query, it does so by **chaining rules and facts
together** into a proof. The Proof Game lets a student reconstruct that chain by
hand:

- The **query** (the question) sits at the top.
- Below it are the **rules** and **facts** of the knowledge base, as movable cards.
- The student **connects** cards together so that every condition of every rule is
  satisfied, all the way down to plain facts.

When the whole structure holds together, the proof is **complete** — the game
celebrates with colour and a sound. When two cards are joined in a way that
contradicts itself, the game shows a **clash**. Both are immediate, so students
learn by trying.

The game works for any query in any `.le` knowledge base. The examples in this
guide use `examples/moreExamples/happy_dragon.le`.

---

## 2. Launching the game

1. Open a knowledge base in the **editor** and press **Load**.
2. Choose a **scenario** (the set of facts to reason about) and a **query** from the
   dropdowns.
3. Press the **Proof Game** button. The game opens in a new window.

> A query only becomes playable if it actually has an answer in the chosen scenario
> — you can't build a proof of something that isn't true.

---

## 3. The board and the pieces

| Piece | What it is | How it behaves |
|-------|-----------|----------------|
| **Query card** (top) | The question to answer, e.g. *"which dragon is happy"* | Has one socket underneath, waiting for the rule or fact that answers it. |
| **Rule card** | A rule from the knowledge base: a **head** on top and one **condition** box per body condition underneath | Its head plugs **upward** into whatever it helps prove; each condition has a socket that must be filled. |
| **Fact card** | A plain fact from the scenario or knowledge base | Plugs upward to satisfy a condition. Facts have no conditions of their own — they are where a branch of the proof ends. |
| **FAIL card** (a red stop sign) | "This does not hold" | Used to satisfy a **negation** — an *"it is not the case that …"* condition. |

**Connections** are arrows. You make one by dragging from a card's **output**
(its top) to a **condition socket** (the bottom of a condition box). An arrow means
*"this card supplies that condition."*

### Colours and feedback

- Each **predicate** (e.g. *is a dragon*, *is happy*) has its own colour, shown in
  the **Predicates Legend**. Matching colours help students spot which cards can fit
  together.
- **Green** = part of a complete proof.
- **Red (clash)** = two connected cards disagree about who/what they are talking
  about (a variable can't be two things at once).
- **Dark red (failing)** = a card being used to show that something **fails** (see
  §6).

---

## 4. The central idea: matching and bindings

Most rules talk about *some* person, dragon, or thing using a **variable** —
shown as a phrase like *"a creature"* or *"a dragon"*. A fact talks about a
**specific** one, like *"alice"*.

When you connect a fact to a condition, the game **binds** the variable to the
fact's value, and the text on the cards updates to show it. Connect *"alice is a
dragon"* to a rule's *"a creature is a dragon"* condition, and that creature
becomes **alice** everywhere in the rule.

- If two connections try to bind the same variable to **different** values, you get
  a **clash** (red). This is the heart of unification, made visible.
- A branch of the proof is finished when it bottoms out in **facts** — things that
  are simply true in the scenario.

**Teaching point:** a proof is not a single step. It is a *tree* — the query at the
root, rules in the middle, and facts at the leaves. The student's job is to grow
that tree until every leaf is a fact.

---

## 5. "For all cases" conditions

Some rules use a universal: *"for all cases in which … it is the case that …"*.
On a rule card this condition shows **two sockets**:

- one for the **case** ("for all cases in which *a creature is a parent of a
  dragon*"), and
- one for the **consequence** ("it is the case that *the other creature is
  healthy*").

To satisfy it, the student supplies a card for the case (e.g. the fact *alice is a
parent of bob*) and a card proving the consequence (e.g. the rule that makes *bob*
healthy). This shows, concretely, that the universal claim holds for the case at
hand.

---

## 6. Negation and "failure mode" — proving that something is **not** true

This is the game's most powerful teaching idea.

A rule may contain a condition like *"it is not the case that the creature
smokes"*. To satisfy it, the student must show that the creature smoking **fails**.
There are two ways:

1. **The quick way — a FAIL card.** Drag a **FAIL** (red stop sign) onto the
   negation socket. It asserts "this doesn't hold," and the negation is satisfied.
   Good for younger students or a first pass.

2. **The thorough way — build the failure.** Connect the **rule that would prove
   it** to the negation socket. The link is drawn dashed with a **"not the case"**
   label, and that rule flips into **failing mode** (dark red): now it is being used
   to explain *why* the goal fails. The student then builds the failure underneath
   it, condition by condition, until they reach something that simply cannot be
   satisfied (a FAIL leaf).

**Worked failure (happy_dragon).** *bob smokes* is false. Why? No scenario fact stating that bob smokes. Alternatively, the smoking rule
needs someone who is a parent of bob, is a dragon, and smokes. The only parent of
bob is **alice**, who is a dragon — but **alice does not smoke**, because there is no fact stating it, and no one is
a parent of *alice*. The failure tree the student builds mirrors exactly that
chain of reasoning:

```
it is not the case that bob smokes
  bob smokes                         (fails)
    a creature is a parent of bob    (there is one — alice — a choice point)
    alice smokes                     (fails)
      a creature is a parent of alice  (fails — there is none)
```

**Teaching point:** "true" and "false" are proved differently. A positive proof
needs **one** way to succeed; a negation needs **every** way to **fail**. Failing
mode lets students experience that asymmetry instead of being told it.

---

## 7. Choosing which answer to prove

A query like *"which dragon is happy"* often has **several** answers, and they can
have very different proofs. When there is more than one answer, an **"Answer to
prove"** dropdown appears in the toolbar. Pick the answer you want the class to work
on.

For example, in `happy_dragon.le`:

- **"bob is happy"** is true *vacuously* — bob is a parent of no one, so the
  "for all cases" condition has nothing to check. A gentle first example.
- **"alice is happy"** requires the full failure argument about smoking from §6 —
  a rich, advanced example.

Switching answers keeps the same cards on the board and just changes the target.

---

## 8. Reusing a rule: the Clone Tool

Sometimes a proof needs the **same rule twice** — most often when building a failure
tree (in the example above, the smoking rule is applied once for *bob* and again
for *alice*). Because each card can only be wired into one place, you make a copy.

- The **Clone Tool** button appears **only when the selected answer's proof actually
  needs a duplicate** — so it stays out of the way until it's relevant.
- Click **Clone Tool** to turn it on (it highlights), then click a card to make a
  copy of it.
- To remove a copy, click it to select and press **Delete** (or **Backspace**). The
  game always keeps at least one original of each card.

---

## 9. The toolbar at a glance

| Control | What it does |
|---------|--------------|
| **Answer to prove** | (Appears only with several answers.) Chooses which answer to build a proof for. |
| **Child Mode (Hide Text)** | Hides all wording and shows only coloured shapes — students match by **colour and structure**, not reading. Great for younger learners or for emphasising the *shape* of a proof. Unchecked = full text. |
| **Clone Tool** | (Appears only when needed.) Click to enable, then click a card to duplicate it. |
| **Show Proof** | Builds the complete proof automatically — the "answer key". Use it to demo, to check a student's attempt, or to reveal a failure tree that is hard to find. |
| **Auto Layout** | Tidies the cards into a readable tree. |
| **Predicates Legend** | Lists each predicate with its colour. |
| **+ / − / ⛶** | Zoom in, zoom out, and fit-to-screen. |
| **Theme** | Dark, light, or high-contrast. |

Clicking any card also **highlights the matching text back in the editor**, so the
class can connect the puzzle piece to the rule or fact it came from.

---

## 10. A suggested lesson plan

A 30–40 minute session with `happy_dragon.le`:

1. **Warm up (positive proof).** Load the `smoky` scenario, query `happy`, and pick
   the answer **"bob is happy."** Ask the class to connect cards from the query down
   to facts. Introduce **matching/bindings** as they go, and let a **clash** happen
   on purpose to discuss why it's wrong.
2. **Universals.** Notice the *"for all cases"* condition and its two sockets. Talk
   about what it means to check a claim "for every case."
3. **Switch answers.** Change "Answer to prove" to **"alice is happy."** It looks
   similar — but now there's a *negation* to satisfy.
4. **Negation, the easy way.** Satisfy *"it is not the case that bob smokes"* with a
   **FAIL** card. Proof complete. Ask: *but why doesn't bob smoke?*
5. **Negation, the real way.** Remove the FAIL card. Connect the **smoking rule** to
   the negation (note the *"not the case"* label and the colour change to failing
   mode). Use the **Clone Tool** to apply the smoking rule again for *alice*, and
   reach a **FAIL leaf**. Discuss why proving *false* means **all** ways must fail.
6. **Reveal.** Press **Show Proof** to compare with the class's attempt.

---

## 11. Concept glossary for the classroom

- **Query** — the question we are trying to answer.
- **Rule** — "if these conditions hold, then this conclusion holds."
- **Fact** — something simply true in the chosen scenario.
- **Variable** — a placeholder like *"a creature"* that can stand for different
  individuals.
- **Binding / matching (unification)** — fixing a variable to a specific value when
  cards are joined; the basis of all the reasoning.
- **Clash** — a contradiction: a variable forced to be two different things.
- **Proof tree** — query at the top, rules in the middle, facts at the bottom.
- **Negation as failure** — something counts as "not true" precisely when every
  attempt to prove it **fails**.
- **Failing mode** — a rule shown in dark red because it is being used to explain a
  failure rather than a success.
- **Universal ("for all cases")** — a claim that must hold for every relevant case.

---

*Tip:* Start in **Child Mode** to focus on the *shape* of a proof, then turn the
text on to connect that shape to the actual Logical English sentences. The same
board supports both a first encounter with reasoning and a serious discussion of
negation and quantification.
