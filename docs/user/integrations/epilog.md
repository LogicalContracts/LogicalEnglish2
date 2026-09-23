# Epilog and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Epilog is the logic programming language of Stanford's course on Dynamic Logic
Programming. The course teaches Epilog through the Epilog web site and through
EpilogJS, which runs Epilog programs inside a web browser. An Epilog program
keeps three things apart. The *data* are the facts. The *view definitions* are
rules, such as `gp(X,Z) :- parent(X,Y) & parent(Y,Z)`. The *operation
definitions* say what an action changes, as in `mark(M,N) :: control(R) ==>
cell(M,N,R) & ~cell(M,N,b)`: when the action happens, change the data this way.

The translation goes one way only, into Logical English. A ruleset, which is a
file of rules with no actions in it, becomes an ordinary Logical English
program. A program that does
have operations, such as one of the games on the Epilog Games page, becomes a
program in Logical English for LPS (Logic Production System), which runs
forward through time. Open the Epilog file with **File ▸ Open…** or **File ▸
Import from Another System…**. Nothing writes an Epilog file back out. The
translator is part of the InsurLE extensions, so only installations that have
the extensions, such as the hosted service, offer it. Running a translated game
needs an LPS2 server beside the editor as well.

## Contents

- [At a glance](#at-a-glance)
- [How to use it](#how-to-use-it)
  - [Opening a ruleset](#opening-a-ruleset)
  - [Opening a game](#opening-a-game)
  - [The example twins](#the-example-twins)
- [How Epilog maps to Logical English](#how-epilog-maps-to-logical-english)
  - [Rulesets](#rulesets)
  - [Games and other programs with operations](#games-and-other-programs-with-operations)
- [Traps](#traps)
- [See also](#see-also)

## At a glance

| Direction | Where (menu item) | Files | What you get | Checked against |
|---|---|---|---|---|
| Epilog ruleset → Logical English | **File ▸ Open…**, **File ▸ Import from Another System…** | `.epilog`, `.epi`, `.txt` (rules, optionally with facts) | the views as rules, a query per view, a ledger | EpilogJS's answers to every view's query (example twins) |
| Epilog game or program with operations → Logical English for LPS | the same | `.hrf` (a game library of the Games page), `.epilog`, `.epi`, `.txt` | actions, causal laws, intensional fluents, the initial state, legality as constraints, a ledger | EpilogJS's final state after a recorded play (example twins) |
| Logical English → Epilog | none | — | — | — |

## How to use it

### Opening a ruleset

1. Save the rules as a text file whose name ends in `.epilog` (or `.epi`, or
   `.txt`). A rule sheet copied straight from the Epilog site is fine as it is.
   To bring the data across as well, put the facts from the data sheet in the
   same file: the editor reads one file only.
2. Choose **File ▸ Open…** (or **File ▸ Import from Another System…**) and
   pick the file. The program opens in a new tab.
3. The note under the menu bar names the translator and gives the counts from
   the ledger, the record of how each piece of the file was translated — for
   example *kinship: an Epilog ruleset, as Logical English (6 elements encoded,
   0 approximated, 0 residue), with a query per view.* Close the note with its
   `×`.
4. The program has one query for each view (`query gp is: which thing is the gp
   of which second thing.`). Pick a query and run it. The facts in the file are
   facts of the program.
5. **File ▸ Show the Original…** shows the Epilog file, which the editor keeps
   in the program's `sources/` folder. The ledger, `<name>.ledger.md`, is
   written beside the program.

A file you open this way arrives with no expected answers, because nothing in
the editor runs EpilogJS. If you know what the answers should be, write them
into a scenario with `expects answers`, and then use **Misc ▸ Run the
Program's Tests…**.

### Opening a game

1. Save the game's library — the text of a game on the Epilog Games page — as
   a `.hrf` file, and open that file with **File ▸ Open…**.
2. The new program declares `the target language is: lps.`. In place of the
   query buttons, the editor now shows **Run in LPS** and **Legal View**.
3. The note says how many pieces of the game were encoded, how many were
   approximated and how many were left as residue, and that the program has no
   scenario yet. Add one: a sequence of moves, one move to each step of time:

   ```le
   scenario play is:
       the move mark with 1 and 1 is made from 1 to 2.
       the move mark with 3 and 3 is made from 2 to 3.
   ```

   The words of a move are the words of its action declaration
   (`the move mark with *an index* and *a second index* is made`).
4. **Run in LPS** runs the program with the LPS2 engine, in a new window. The
   timeline there shows the moves, and shows each fluent — each fact that
   changes over time — as time passes. A move that is not legal is refused,
   and the timeline marks that move *refused by a constraint*.
5. A program that opens without a play in it says `the maximum time is 20.`
   Raise that number for a longer play.

The **Open…** item of the LPS2 IDE — the integrated development environment,
or editor, for LPS — reads the same `.epilog`, `.epi` and `.hrf` files,
whenever the Logical English installation beside that editor has the
translators.

### The example twins

The translator has been run over the Epilog site's own programs. The
translations, called *twins*, sit among the lpsPlus examples, under
`lpsPlus/migration/epilog/`. The twins are visible only on installations that
have the lpsPlus examples, and only to users with access to them; open a twin
with **File ▸ Open example from server…**.

- Rulesets from the Examples page: `lpsPlus/migration/epilog/kinship`,
  `…/blocks`, `…/graphs`. In each of them the data sheet has become the
  scenario `dataset`, and each view's query expects the answers EpilogJS gives
  on those same rules and that same data. **Misc ▸ Run the Program's Tests…**
  shows that the answers all pass.
- Games from the Games page: `…/tictactoe`, `…/buttonsandlights`,
  `…/bridgecrossing`, `…/hunter`, `…/missionaries`, `…/knightstour`,
  `…/lightboard`, `…/connectfour`, `…/cram`, `…/hamilton`. The scenario
  `play` holds a play that EpilogJS made. The comment just before the scenario
  lists the state EpilogJS finished in, and running the twin in LPS finishes in
  that same state.

**File ▸ Show the Original…** on a twin lists the rule sheet and the data
sheet (`.rules`, `.data`). For a game it lists the game library (`.hrf`) and
EpilogJS's record of the play (`<name>.epilog.json`), which holds the state and
the legal moves after every single move.

## How Epilog maps to Logical English

### Rulesets

| Epilog | Logical English |
|---|---|
| a fact `parent(art,bob)` | a fact, `art is the parent of bob.` (in a twin, in the scenario `dataset`) |
| a view definition `h :- b1 & b2` | a rule, `… if … and …` |
| `~p(X)` | `it is not the case that …` |
| `b1 \| b2` | `either … or …` |
| a relation name | a template worded from the name: `*a thing* is the gp of *a second thing*` |
| a unary relation that types a place (`node(X)`) | the place's name: `*a node* is the p of *a second node*` |
| `same`, `distinct`, `leq`, `less` | `=`, `\=`, `=<`, `<` |
| `evaluate(plus(X,times(Y,2)),Z)` | `Z = X + Y * 2` (`plus`, `times`, `minus`, `quotient`) |
| `mutex(X1,…,Xn)` | the values pairwise different |
| `countofall(X, p(X) & q(X), N)` | an aggregate: the number of each X such that … |
| `max(A,B)`, `min(A,B)` in an evaluation | two rules, one for `A >= B` and one for `A < B` |
| `symless`, `symleq` | dropped; the ledger marks the view *approximated* |
| a sentence with a functional term, a function definition `f(X) := …`, or a list pattern | a residue block (below) |
| each view | a query `which thing is …` |

From the kinship twin:

```le
a thing is childless if
    the thing is a person
    and it is not the case that the thing is isparent.

query childless is:
    which thing is childless.
```

Epilog's `~` and Logical English's `it is not the case that` mean the same
thing: the condition holds when the fact cannot be proved from the rules and
the data. Both languages ask that the rules be layered, so that each layer only
negates a layer below. A view and the rule it becomes therefore give the same
answers on the same data.

### Games and other programs with operations

The editor reads a file as a game when the file holds at least one operation
definition (`… :: … ==> …`). A file with no operation definition in it is read
as a ruleset.

| Epilog | Logical English for LPS |
|---|---|
| a relation that `init` sets or an operation changes (`cell`, `control`) | a fluent |
| a move: an operation no other operation calls, or declared by `action(…)` | an action, worded as a move: `the move mark with *an index* and *a second index* is made; known as mark.` |
| `init(…)` | `initially …`, evaluated: `initially 1 cell 1 with b and … and x is a control.` |
| `a :: cond ==> e & ~f` | a causal law, one per operation rule: `when … is made and cond then e and it is not the case that f.` |
| an operation a move calls (`tick(X)`) | inlined: its conditions and effects join the move's law |
| a view over the state (`line`, `open`, `goal`, `terminal`) | an intensional fluent, `… at a time if … at the time` |
| a view over static relations only (`index`, `succ`) | a timeless template with its facts and rules |
| `legal(mark(M,N)) :- …` | an intensional fluent per move, `the move mark with *an index* and *a second index* is legal`, and a constraint that refuses a move that is not legal |
| `goal(R, N)` | `the goal of *a role* is *a number*` |
| `terminal` | `the game is terminal` |
| `max(A,B)`, `min(A,B)` in an operation's or a view's arithmetic | two cases, one for `A >= B` and one for `A < B` |
| `role(R)`, `base(…)`, `action(…)` | no sentence of their own: they type the places of the fluents and moves |

Here, from the tic-tac-toe twin, are the three operation rules of `mark` and
the constraint that keeps a move legal:

```le
when the move mark with an index and a second index is made
    and x is a control
then o is a control
    and it is not the case that x is a control.

it must not be true that
    the move mark with an index and a second index is made
    and it is not the case that the move mark with the index and the second index is legal.
```

A causal law reads its conditions in the state as it was before the move, which
is how Epilog reads them too. Epilog deletes before it adds, so a fluent that
one operation both deletes and adds still holds after the move, and LPS gives
that same result.

A game manager refuses a move that is not legal, and so does the translated
program: the constraint stops the move from happening at all. Legality is not
something the program sets out to achieve. Nor does the program choose the
moves. Every move comes from the scenario.

Across the whole Games page, 74 games have libraries EpilogJS can play. Of
those 74, 70 finish under LPS2 in the state EpilogJS finishes in after the same
play.

## Traps

- **The wording is naive.** The translator builds each template out of the
  relation's name rather than out of English, so `isparent(X)` becomes `*a
  thing* is isparent`, and `cell(M,N,Z)` becomes `*an index* cell *a second
  index* with *a thing*`. The words follow the order of the arguments, so a
  sentence can come out backwards: `value(p,true)` becomes `p is the value of
  true`. Rename the templates, by hand or with help from the assistants, before
  you show the program to anyone.
- **A file you open has no expected answers.** Only the example twins were
  checked against EpilogJS. After opening a ruleset of your own, compare a few
  of its answers with Epilog's before you trust the program.
- **One file only.** Rules in one file and data in another cannot be opened
  together. Put the facts in the file that holds the rules. A file holding
  nothing but facts, with no `:-` and no `::` in it, is not recognised as
  Epilog at all: such a file opens as a program whose text sits inside a `TODO`
  comment.
- **A line that ends with a full stop** makes the file look like Prolog, and
  the Epilog translator then leaves the file alone. Epilog itself writes no
  full stops.
- **A game opens without a play.** You have to write the scenario yourself, and
  `the maximum time is 20.` sets how far the play may run.
- **The final state is not a checked expectation.** In a game twin the final
  state is a comment. Compare that comment with the last state of the run
  yourself; **Misc ▸ Run the Program's Tests…** does not compare them for
  you.
- **A value built out of parts is left as residue.** A place in a Logical
  English sentence holds a plain constant, not a value built out of other
  values, such as `and(p,q)`, `not(X)` or `location(cell(a,1),
  piece(white,rook,1))`. The translator writes each sentence holding such a
  value as a `% RESIDUE functional_term_… BEGIN … END` block, keeping the
  Epilog sentence inside it, and counts the sentence as *residue* in the ledger
  and in the note. A relation that only such sentences state keeps its template
  and its query, and the query finds nothing until someone translates the
  block. The rulesets called boolean, satisfiability, schedule and zebra, and
  games that keep such values in their state, such as skirmish, come out mostly
  as residue.
- **Functions.** A function definition (`f(X) := …`) becomes a residue block,
  and so does every sentence whose `evaluate(…)` calls that function, or calls
  any Epilog function other than `plus`, `times`, `minus`, `quotient`, `max`
  and `min`.
- **Lists.** A clause that takes a list apart (`mem(X,X!Y)`) becomes a residue
  block holding the Epilog clause, and the ledger counts it. A query left open
  over a relation with no end to it, such as the lists or the sets, has no
  finite answer.
- **`symless` and `symleq` are dropped**, in rulesets and in games alike.
  Epilog uses them to list a pair once and once only, where the translated
  program lists the pair in both orders. The ledger marks each view that used
  them *approximated*.
- **Symbols that are also Logical English words.** In a game, a constant such
  as `a` — a column of a board, or one of the people in Bridge crossing — is
  written as the piece of text `"a"`, so that Logical English does not read it
  as the article *a*. Write such a constant the same way in your own scenario:
  `the move right with "a" is made from 1 to 2.`
- **One name used with two numbers of arguments.** A relation used once with
  one argument and once with two becomes two separate templates, which LPS
  knows as `left_1` and `left_2`.
- **An operation that calls another operation** has the called operation's
  conditions and effects folded into its own, down to a depth of five. Where a
  move's chain of operations calling operations runs deeper than that, or where
  an operation calls itself, the effects further down get no law of their own.
  The program then holds a residue block naming the operations concerned, and
  the ledger marks the move *approximated*.
- **Rules with no variables in them** (`reflexive if it is not the case that
  nonreflexive.`) are faithful to Epilog, but the verifier warns about every
  one of them.
- **Differences found on the Games page.** Two games, reversum and ttcc4,
  finish in a different state from the one EpilogJS finishes in, and nobody has
  yet explained why. Games whose state holds values built out of other values,
  such as skirmish, are out of reach altogether.

## See also

- In this documentation:
  - [Other systems: importing and exporting](index.md): [opening another system's file](index.md#opening-another-systems-file), [what could not be translated](index.md#what-could-not-be-translated), [Show the Original](index.md#show-the-original), [the migration twins](index.md#the-migration-twins-among-the-examples)
  - [Logical English for LPS](../reference/lps-target.md)
  - [The editor: advanced features](../guide/editor.md#advanced-features) (Run in LPS, Legal View)
  - [The Contract Assistant](../guide/assistants.md#the-contract-assistant), whose migration residue mode translates residue blocks
  - [Logical operators](../reference/language.md#4-logical-operators) and [aggregates](../reference/language.md#5-aggregates) in the language reference
- In LPS2:
  - [Logical English for LPS, the surface language](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps): [intensional fluents](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps#36-intensional-fluents-and-composite-events), [`initially`](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps#32-initially)
  - [The LPS2 IDE](https://lps2.logicalcontracts.com/docs/user/guide/ide): the timeline, and running a program
  - [LPS glossary](https://lps2.logicalcontracts.com/docs/user/reference/glossary)
- Epilog's own documentation:
  - [Epilog](http://epilog.stanford.edu/homepage/index.php), the language's site
  - [Examples](http://epilog.stanford.edu/homepage/examples.php) and [Games](http://epilog.stanford.edu/homepage/games.php)
  - [Vocabulary](http://epilog.stanford.edu/homepage/vocabulary.php): the predefined relations and functions
  - [Sierra](http://epilog.stanford.edu/homepage/sierra.php), the Epilog IDE, and [EpilogJS](http://epilog.stanford.edu/homepage/epilogjs.php)
