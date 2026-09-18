# Epilog and Logical English

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

Epilog is the logic programming language of Stanford's Dynamic Logic
Programming, taught with the Epilog web site and its browser interpreter,
EpilogJS. An Epilog program separates *data* (facts), *view definitions*
(rules such as `gp(X,Z) :- parent(X,Y) & parent(Y,Z)`) and *operation
definitions* (`mark(M,N) :: control(R) ==> cell(M,N,R) & ~cell(M,N,b)`: when
the action happens, change the data). The translation goes one way, into
Logical English: a ruleset becomes an ordinary Logical English program, and a
program with operations, such as a game of the Epilog Games page, becomes a
program in Logical English for LPS, which runs in time. You open the Epilog
file with **File ▸ Open…** or **File ▸ Import from Another System…**. There
is no export to Epilog. The translator is part of the InsurLE extensions, so
it is available only on installations that have them, such as the hosted
service. Running a translated game needs an LPS2 server as well.

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

1. Save the rules as a text file with the extension `.epilog` (or `.epi`, or
   `.txt`). A rule sheet copied from the Epilog site is fine as it is. To get
   the data too, put the data sheet's facts in the same file: the importer
   reads one file.
2. Choose **File ▸ Open…** (or **File ▸ Import from Another System…**) and
   pick the file. The program opens in a new tab.
3. The note under the menu bar names the translator and gives the ledger's
   counts, for example *kinship: an Epilog ruleset, as Logical English (6
   elements encoded, 0 approximated, 0 residue), with a query per view.*
   Close it with its `×`.
4. The program has one query per view (`query gp is: which thing is the gp of
   which second thing.`). Pick one and run it. The facts of the file are facts
   of the program.
5. **File ▸ Show the Original…** shows the Epilog file, which is kept in the
   program's `sources/` folder. The ledger, `<name>.ledger.md`, is written
   beside the program.

A file opened this way has no expected answers: nothing in the editor runs
EpilogJS. If you know the answers, add them to a scenario with `expects
answers` and use **Misc ▸ Run the Program's Tests…**.

### Opening a game

1. Save the game's library (the text of a game on the Epilog Games page) as a
   `.hrf` file, and open it with **File ▸ Open…**.
2. The program declares `the target language is: lps.`. The editor shows
   **Run in LPS** and **Legal View** instead of the query buttons.
3. The note says how many elements were encoded, approximated or left as
   residue, and that the program has no scenario yet. Add one, a sequence of
   moves, one per time step:

   ```le
   scenario play is:
       the move mark with 1 and 1 is made from 1 to 2.
       the move mark with 3 and 3 is made from 2 to 3.
   ```

   The words of a move are those of its action declaration
   (`the move mark with *an index* and *a second index* is made`).
4. **Run in LPS** runs the program with the LPS2 engine, in a new window:
   the timeline shows the fluents over time and the moves. A move that is not
   legal is refused, and the timeline marks it *refused by a constraint*.
5. The program opened without a play has `the maximum time is 20.` Raise it
   for a longer play.

The LPS2 IDE's **Open…** reads the same `.epilog`, `.epi` and `.hrf` files
when the Logical English installation beside it has the translators.

### The example twins

The translator has been run on the Epilog site's own programs. The results,
*twins*, are among the lpsPlus examples, under `lpsPlus/migration/epilog/`.
They are visible only on installations with the lpsPlus examples, to users
with access; open them with **File ▸ Open example from server…**.

- Rulesets of the Examples page: `lpsPlus/migration/epilog/kinship`,
  `…/blocks`, `…/graphs`. Each has the data sheet as the scenario `dataset`,
  and each view's query expects EpilogJS's own answers on the same rules and
  data. **Misc ▸ Run the Program's Tests…** shows that they pass.
- Games of the Games page: `…/tictactoe`, `…/buttonsandlights`,
  `…/bridgecrossing`, `…/hunter`, `…/missionaries`, `…/knightstour`,
  `…/lightboard`, `…/connectfour`, `…/cram`, `…/hamilton`. The scenario
  `play` is a play EpilogJS made. The last comment before it lists the state
  EpilogJS ended in; running the twin in LPS ends in the same state.

**File ▸ Show the Original…** on a twin lists the rule and data sheets
(`.rules`, `.data`), or the game library (`.hrf`) and EpilogJS's record of the
play (`<name>.epilog.json`: the state and the legal moves after every move).

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

Epilog's negation is negation as failure over a stratified program, and so is
Logical English's `it is not the case that`: a view and its rule give the
same answers on the same data.

### Games and other programs with operations

A file is read as a game when it has at least one operation definition
(`… :: … ==> …`). Otherwise it is a ruleset.

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

From the tic-tac-toe twin, the three operation rules of `mark` and the
legality constraint:

```le
when the move mark with an index and a second index is made
    and x is a control
then o is a control
    and it is not the case that x is a control.

it must not be true that
    the move mark with an index and a second index is made
    and it is not the case that the move mark with the index and the second index is legal.
```

The conditions of a law are read in the state before the move, as Epilog
reads them. Epilog deletes before it adds, so a fluent that one operation both
deletes and adds still holds after the move; LPS gives the same result.

A game manager refuses an illegal move, and so does the program: the
constraint stops the move from happening. Legality is not a goal the program
pursues. The program does not choose moves either: the moves come from the
scenario.

Across the Games page, 70 of the 74 games whose libraries EpilogJS plays end,
under LPS2, in the state EpilogJS ends in after the same play.

## Traps

- **The wording is naive.** Templates are made from relation names, not from
  English: `isparent(X)` becomes `*a thing* is isparent`, `cell(M,N,Z)`
  becomes `*an index* cell *a second index* with *a thing*`. The order of the
  words follows the order of the arguments, so a sentence can read backwards:
  `value(p,true)` becomes `p is the value of true`. Rename the templates
  (by hand, or with the assistants) before showing the program to anyone.
- **Opened files have no expected answers.** Only the example twins were
  checked against EpilogJS. After opening your own ruleset, compare a few
  answers with Epilog's before trusting the program.
- **One file.** Rules and data in two files cannot be opened together. Put the
  facts in the rules file. A file with facts only (no `:-` and no `::`) is not
  recognised as Epilog, and opens as a program holding its text in a `TODO`
  comment.
- **A line ending with a full stop** makes the file look like Prolog, and the
  Epilog importer does not take it. Epilog writes no full stops.
- **A game opens without a play.** Its scenario has to be written, and
  `the maximum time is 20.` bounds it.
- **The final state is not a checked expectation.** In a game twin it is a
  comment. Compare it with the run's last state yourself; **Misc ▸ Run the
  Program's Tests…** does not check it.
- **Functional terms are residue.** A Logical English place holds a
  constant, not a term such as `and(p,q)`, `not(X)` or
  `location(cell(a,1), piece(white,rook,1))`. Each sentence that holds one is
  written as a `% RESIDUE functional_term_… BEGIN … END` block with the
  Epilog sentence, and counted as *residue* in the ledger and the note. A
  relation stated only by such sentences keeps its template and its query,
  which finds nothing until the block is translated. Rulesets such as
  boolean, satisfiability, schedule and zebra, and games that keep terms in
  the state (skirmish), come out mostly as residue.
- **Functions.** A function definition (`f(X) := …`) is a residue block, and
  so is every sentence whose `evaluate(…)` calls it, or calls an Epilog
  function other than `plus`, `times`, `minus`, `quotient`, `max` and `min`.
- **Lists.** A clause that takes a list apart (`mem(X,X!Y)`) is a residue
  block with the Epilog clause, counted in the ledger. Open queries over
  infinite relations (lists, sets) have no finite answer.
- **`symless` and `symleq`** are dropped, in rulesets and in games. They list
  a pair once in Epilog; the program lists it in both orders. The ledger
  marks each such view *approximated*.
- **Symbols that are Logical English words.** A constant `a` (a board column,
  a person in Bridge crossing) is written as the text `"a"` in a game, so that
  it is not read as an article. Write it the same way in your scenario:
  `the move right with "a" is made from 1 to 2.`
- **One name, two arities.** A relation used with one and with two arguments
  is two templates, known as `left_1` and `left_2` in LPS.
- **Sub-operations are inlined** to a depth of five. When a move's chain of
  operations calling operations goes deeper (or an operation calls itself),
  the effects beyond have no law: the program has a residue block with the
  operations involved, and the ledger marks the move *approximated*.
- **Rules without variables** (`reflexive if it is not the case that
  nonreflexive.`) are faithful to Epilog, but the verifier warns about each
  one.
- **Differences found on the Games page.** Two games, reversum and ttcc4, end
  in a different state from EpilogJS's, not yet explained. Games whose state
  holds functional terms (skirmish) are out of reach.

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
