# The Proof Game — A Teacher's Guide

*Kind: guide · Audience: teachers · Status: current (2026-09-20)*

The **Proof Game** turns a Logical English query into a hands-on puzzle. Instead of
reading a proof, students *build* one: they drag rules and facts together until they
have explained **why** an answer is true, or why something is **not** true. The game
is built to make the central ideas of logical reasoning — rules, facts, variables,
matching, negation, and "for all" — something a student can see and handle.

This guide explains the main ideas and how to run a lesson with the game. You
need no programming background to read it.

---

## 1. What the game is for

When Logical English answers a query, it does so by **chaining rules and facts
together** into a proof. The Proof Game lets a student reconstruct that chain by
hand:

- The **query** (the question) sits at the top.
- Below it are the **rules** and **facts** of the knowledge base, as movable cards.
- The student **connects** cards together so that every condition of every rule is
  satisfied, all the way down to plain facts.

When the whole structure holds together, the proof is **complete**, and the game
celebrates with colour and a sound. When two cards are joined in a way that
contradicts itself, the game shows a **clash**. Both answers come at once, so
students learn by trying things out.

The game works for any query in any `.le` knowledge base. The examples in this
guide use `examples/moreExamples/happy_dragon.le`.

---

## 2. Launching the game

1. Open a knowledge base in the **editor** and press **Load**.
2. Choose a **scenario** — the set of facts to reason about — and a **query**, each
   from its own list.
3. Press the **Proof Game** button. The game opens in a new window.

> A query with **no** answer in the chosen scenario is playable too: the game then
> builds the proof that it **fails** (see §6.1).

---

## 3. The board and the pieces

| Piece | What it is | How it behaves |
|-------|-----------|----------------|
| **Query card** (top) | The question to answer, e.g. *"which dragon is happy"* | Has one socket underneath, waiting for the rule or fact that answers it. |
| **Rule card** | A rule from the knowledge base: a **head** on top and one **condition** box per body condition underneath | Its head plugs **upward** into whatever it helps prove; each condition has a socket that must be filled. |
| **Fact card** | A plain fact from the scenario or knowledge base | Plugs upward to satisfy a condition. Facts have no conditions of their own — they are where a branch of the proof ends. |
| **Assumption card** (dashed amber border) | An **assumable** statement — a template declared `; assumable`, or an *"it is unknown whether …"* line in a scenario | Plays like a fact, but nothing *proves* it: connecting the card **assumes** the statement is true. Assumption cards are how the game handles **abduction**, which means explaining something you have observed by assuming a cause that would account for it — *"the grass is wet"* because, we assume, *"it rained"*. |
| **FAIL card** (a red stop sign) | "This does not hold" | Used to satisfy a **negation** — an *"it is not the case that …"* condition — and, in a game of a query that has no answer (§6.1), to say that nothing could prove a goal. |

**Connections** are arrows. You make one by dragging from a card's **output**
(its top) to a **condition socket** (the bottom of a condition box). An arrow means
*"this card supplies that condition."*

### Colours and feedback

- Each **predicate** — each kind of statement the program can make, such as *is a
  dragon* or *is happy* — has its own colour, listed in the **Predicates Legend**.
  Matching colours help students spot which cards can fit together.
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
  a **clash**, shown in red. A clash shows unification at work: unification is the
  matching of variables to values that every proof rests on.
- A branch of the proof is finished when it bottoms out in **facts** — things that
  are simply true in the scenario.
- Some conditions are **computed, not proved**: arithmetic (*"the amount is the
  rent / 2"*), comparisons (*"the rent =< 1000"*), date calculations. No card
  supplies them, so their boxes have no socket; the game works them out as soon
  as the cards you connect give them their inputs. Connect *"the rent of ann is
  800"* and the rule's head becomes *"the help for ann is 400"*. If the result
  is false — a rent of 1200 under *"the rent =< 1000"* — the connection clashes.
  A condition with alternatives (*"N >= 3 or N = 2 and the patient is
  flagged"*) keeps its socket, for the alternative a card proves; when the
  computed one holds (a class of 3), it needs nothing connected.

**Teaching point:** a proof is not a single step. A proof is a *tree* — the query at
the root, rules in the middle, and facts at the leaves. The student's job is to grow
that tree until every leaf is a fact.

---

## 5. "For all cases" conditions

Some rules use a "forall" claim: *"for all cases in which … it is the case that …"*.
On a rule card this condition shows **two sockets**:

- one for the **case** ("for all cases in which *a creature is a parent of a
  dragon*"), and
- one for the **consequence** ("it is the case that *the other creature is
  healthy*").

To satisfy the condition, the student supplies a card for the case — the fact
*alice is a parent of bob*, say — and a card proving the consequence, such as the
rule that makes *bob* healthy. Supplying both cards shows, in the plainest way,
that the claim holds for the case at hand.

---

## 6. Negation and "failure mode" — proving that something is **not** true

Negation is the game's most powerful teaching idea.

A rule may contain a condition like *"it is not the case that the creature
smokes"*. To satisfy that condition, the student must show that every attempt to
prove the creature smoking **fails**. There are two ways to do so:

1. **The quick way — a FAIL card.** Drag a **FAIL** card, the red stop sign, onto
   the negation socket. The FAIL card simply says "this doesn't hold", and the
   negation is satisfied. The quick way suits younger students, or a first pass.

2. **The thorough way — build the failure.** Connect the **rule that would have
   proved the statement** to the negation socket. The game draws that link as a
   dashed arrow labelled **"not the case"**, and the rule turns to **failing mode**,
   shown in dark red: the rule now serves to explain *why* the statement fails. The
   student then builds the failure underneath the rule, condition by condition,
   until reaching something that simply cannot be satisfied — a FAIL card at the
   end of a branch.

**Worked failure (happy_dragon).** *bob smokes* is false. Why? First, no fact in the
scenario states that bob smokes. Second, the smoking rule needs someone who is a
parent of bob, is a dragon, and smokes. The only parent of bob is **alice**, and
alice is a dragon — but **alice does not smoke**, because no fact states that she
does, and because no one is a parent of *alice*. The failure tree the student
builds follows exactly that chain of reasoning:

```
it is not the case that bob smokes
  bob smokes                         (fails)
    a creature is a parent of bob    (there is one — alice — a choice point)
    alice smokes                     (fails)
      a creature is a parent of alice  (fails — there is none)
```

A failure can itself contain a proof. In
`examples/moreExamples/collections/logical-thinking-talk/heart_failure.le` (scenario
`high_creatinine`, query `withheld`), "the guideline recommends aldosterone
antagonists for Frank" fails because its condition *"it is not the case that
Frank has a contraindication to aldosterone antagonists"* fails — and that
negation fails because the contraindication **holds**. So under that condition
of the failing card goes the ordinary, green proof of Frank's contraindication.
Each negation turns the work around: what was a failure to build becomes a
success to build, and the other way about.

**Teaching point:** "true" and "false" are proved differently. A positive proof
needs **one** way to succeed; a negation needs **every** way to **fail**. Failing
mode lets students experience that asymmetry instead of being told it.

### 6.1 A query with no answer: playing the failure

The same idea covers a **whole query that has no answer**. Choose such a scenario
and query, and open the game as usual. The toolbar then says *"No answer: build the
proof that this query FAILS"*, and the **query card itself** is in failing mode,
dark red. What goes under the query card is a failure, exactly as under a negation:
a **FAIL** card wherever nothing could prove a goal, and **one failing-mode card for
each rule that was tried**, each with the condition it failed on built underneath in
turn. The proof is complete when every way the query could have succeeded has been
shown to fail. **Show Proof** builds that answer key here as it does elsewhere.

Playing a failed query is the game's counterpart of *Why not* in the editor, which
lists the conditions a failed query did not meet. In the editor the reasons are read
out; in the game the class builds them.

**Worked example.** A claim is payable if it is for an item with code "A1",
furnished to a person, and that person is hypoxemic; a person is hypoxemic if their
saturation is at most 88. The record states the item and the person, but no
saturation. Query *"which claim is payable"* — no answer:

```
which claim is payable                 (fails)
  a claim is payable                   (the rule that tried; its first three
                                        conditions hold, the fourth does not)
    Ann is hypoxemic                   (fails)
      a person is hypoxemic            (the rule that tried)
        the saturation of Ann is a number   (FAIL — the record is silent)
```

**Teaching point:** a query that fails is not an error and not a "no"; it is a
conclusion with a proof of its own, and the proof names exactly what the case
lacks.

---

## 7. Choosing which answer to prove

A query like *"which dragon is happy"* often has **several** answers, and the
answers can have very different proofs. When there is more than one answer, an
**"Answer to prove"** list appears in the toolbar. Pick the answer you want the
class to work on.

An answer that holds only because something is **assumed** (see the Assumption
card) is labelled with what it assumes. In
`examples/moreExamples/language/abduction/grass_is_wet.le`, for instance, the list
offers *"the grass is wet, assuming it rained"* and *"the grass is wet, assuming the
sprinkler was on"*. Those are two competing **explanations** of the same
observation, and each has its own proof to build.

For example, in `happy_dragon.le`:

- **"bob is happy"** is true *vacuously* — bob is a parent of no one, so the
  "for all cases" condition has nothing to check. A gentle first example.
- **"alice is happy"** requires the full failure argument about smoking from §6 —
  a rich, advanced example.

Switching answers keeps the same cards on the board and just changes the target.

---

## 8. Reusing a rule: the Clone Tool

Sometimes a proof needs the **same rule twice**, most often when building a failure
tree: in the example above, the smoking rule is used once for *bob* and again for
*alice*. Each card can be connected in one place only, so you make a copy of it.

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
| **No answer: build the proof that this query FAILS** | (Appears only for a query with no answer.) A reminder that the whole board is in failing mode — see §6.1. |
| **Child Mode (Hide Text)** | Hides all the wording and leaves only coloured shapes, so that students match cards by **colour and structure** rather than by reading. Good for younger learners, and for drawing attention to the *shape* of a proof. Leave the box unticked to keep the full wording. |
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
2. **"forall" conditions.** Notice the *"for all cases"* condition and its two sockets. Talk
   about what it means to check a claim "for every case."
3. **Switch answers.** Change "Answer to prove" to **"alice is happy."** The board
   looks much the same, but now there is a *negation* to satisfy.
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
  attempt to prove it **fails**. A query with no answer is played this way, whole
  (§6.1).
- **Assumption / abduction** — an assumable statement cannot be proved, only
  **assumed**; using one explains an observation by a hypothesis ("the grass is
  wet **if we assume** it rained").
- **Failing mode** — a rule shown in dark red because it is being used to explain a
  failure rather than a success.
- **"for all cases"** — a claim that must hold for every relevant case.

---

*Tip:* Start in **Child Mode** to focus on the *shape* of a proof, then turn the
text on to connect that shape to the actual Logical English sentences. The same
board supports both a first encounter with reasoning and a serious discussion of
negation and quantification.
