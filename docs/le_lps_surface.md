# Logical English for LPS — the surface language

**M8b.** This is the language the fifteen programs in `examples/lps/` (of the
LE2 repository) are written in, and the language `le_lps.pl` implements. It is
duplicated verbatim in both repositories, like `le_lps_interface.md`.

Every construct here has a written mapping to the internal term set of
`le_lps_interface.md` §5, and a program in `examples/lps/` that exercises it.

---

## 0. Where this came from

Not from invention. The corpus contains a Logical-English-for-LPS prototype by
the same author, and its three specimens

```
legacy_lps1/examples/CLOUT_workshop/RockPaperScissors-Minimal-en.pl
legacy_lps1/examples/CLOUT_workshop/RockPaperScissorsBaseEN.pl
legacy_lps1/examples/CLOUT_workshop/RockPaperScissorsEthereumFEn.pl
```

settle empirically what `docs/LPSplusLLM.md` §I.9.3 left as an assumption. The
constructs below are theirs. What changed is the *notation*: the specimens are
LE1, where a template is an untagged word sequence and `known as f` binds it to
a functor. LE2 has `*variable*` slots, head-noun typing and `;`-introduced
template additions, so every specimen sentence is re-expressed in that idiom.

Two things the specimens establish that are worth stating outright, because
they were open questions:

- **Both temporal forms are used, and each has a job.** Time is elided where
  the rule is about "whenever this happens" (`when … then …`), and named where
  the rule needs to relate two moments (`… at a first time`). LPS's own surface
  syntax makes exactly the same distinction.
- **Ordinal determiners are the variable mechanism.** `a first time` /
  `the first time` / `a second time` are how two distinct time variables are
  written and then referred back to. LE2 already has this.

`at step 3` — option (b) of §I.9.3 — appears nowhere in the specimens and is
not in this language.

---

## 1. The shape of a document

```
the target language is: lps.

the maximum time is 5.

the events are:
    *a player* inputs *a choice* and *an amount*; known as inputs.

the actions are:
    *a player* gets *a prize*; known as pay.

the fluents are:
    *a player* has played *a choice*; known as played.
    the reward is *an amount*; known as reward.
    the game is over; known as gameOver.

the templates are:
    *a choice* beats *another choice*.

the knowledge base rock paper scissors includes:

    initially the reward is 0.

    scissors beats paper.
    …

scenario one is:
    miguel inputs rock and 1000 from 1 to 2.
```

`the target language is: lps.` is what makes a `.le` document an LPS program.
Without it the document is plain Logical English and none of §3 is available;
`the fluents are:` is then just a template section, as it is today.

The extension stays `.le`. The declaration already carries the distinction, and
one extension means one Monaco language id, one Monarch grammar, one LSP
worker; see `docs/le_lps_design.md` §2 for the argument in full, including the
stated test that would make `.leps` right instead.

---

## 2. Declarations

| LE | internal |
|---|---|
| `the maximum time is *N*.` | `maxTime(N).` |
| `the maximum real time is *N*.` | `maxRealTime(N).` |
| `the minimum cycle time is *N*.` | `minCycleTime(N).` |
| `the events are: …` | `events([…]).` |
| `the actions are: …` | `actions([…]).` |
| `the fluents are: …` | `fluents([…]).` |
| `the prolog events are: …` | `prolog_events([…]).` |
| `the templates are: …`, `the predicates are: …` | nothing — timeless vocabulary |

`the actions are:` and `the prolog events are:` are new sections. They are not
optional conveniences: LPS distinguishes *actions*, which the agent performs
and whose preconditions are checked, from *events*, which happen to it, and
that distinction is load-bearing in the engine and cannot be inferred from use.
The specimens declare both.

### `; known as f`

A template addition, in the same `;`-introduced family as `; opposite`,
`; synonym` and `; prepositional`:

```
    *a player* has played *a choice*; known as played.
```

binds the template to the LPS functor `played/2` instead of LE2's derived
`has_played/2`. It is optional. It exists for two reasons, both practical: the
generated internal syntax, the timeline lanes and the state-transitions diagram
are all labelled with the functor, and a companion `.lps` file (§7) has to name
the same predicate.

Argument order is the order the `*slots*` appear in the sentence.

---

## 3. Sentences

### 3.1 Temporal suffixes

Any template instance in a rule may carry one of

```
    … at <time>
    … from <time> to <time>
    … to <time>
```

where `<time>` is a term — usually an ordinal-determined variable (`a first
time`, `the second time`) and occasionally an integer.

- `at T` on a fluent → `holds(F, T)`
- `from T1 to T2` on an event or action → `happens(E, T1, T2)`
- `to T` on an event → `happens(E, _, T)`, the **prospective form** (§5)

A template instance with no suffix is timed by its context: inside a `when …
then …` the trigger's times are used, and inside `initially` there is no time
at all.

This is a *suffix on a sentence*, not a slot in a template — the specimens do
it this way, and it is why one fluent template serves both `the reward is 0`
(in `initially`) and `the reward is a number at the first time` (in a
condition).

### 3.2 `initially`

```
    initially the reward is 0.
    initially the goat is at the north bank and the wolf is at the north bank.
```

→ `initial_state([reward(0)]).`, `initial_state([loc(goat,north), loc(wolf,north)]).`

### 3.3 Timeless facts and rules

An ordinary LE fact or rule over templates declared in `the templates are:`:

```
    scissors beats paper.
    *a place* is across from *another place* if …
```

→ a Prolog clause, or `l_timeless(Head, Conditions)` when it has a body that
mentions no time.

### 3.4 `when … then …` — causal laws

**`when` says what an event does.** Its antecedent contains exactly one event
or action occurrence — the trigger — and any number of extra conditions; its
consequent says how the state changes.

```
    when a player inputs a choice and an amount
        and the amount > 0
    then the player has played the choice.
```
→ `initiated(happens(inputs(P,C,A), T1, T2), played(P,C), [A > 0]).`

```
    when a player inputs a choice and an amount
    then it is not the case that the player has played the choice.
```
→ `terminated(happens(inputs(P,C,A), T1, T2), played(P,C), []).`

```
    when a player inputs a choice and an amount
    then the reward that is a number becomes number + amount.
```
→ `updated(happens(inputs(P,C,A), T1, T2), reward(N), N-N2, [N2 is N + A]).`

Three consequent forms, then: a fluent (initiates), a negated fluent
(terminates), and `the <fluent> that is <var> becomes <expression>` (updates).
Several may be joined with `and`, giving several laws from one sentence.

### 3.5 `if … then …` — reactive rules

**`if` says what to do about it.**

```
    if a first player has played a first choice at a first time
        and a second player has played a second choice at the first time
        and the first player is different from the second player
        and the first choice beats the second choice
        and it is not the case that the game is over at the first time
    then initiate the game is over from the first time to a second time
        and the reward is a prize at the first time
        and the first player gets the prize from the first time to a third time.
```
→ `reactive_rule([holds(played(P1,C1),T1), holds(played(P2,C2),T1), P1 \== P2,
   beats(C1,C2), holds(not gameOver, T1)],
   [happens(initiate gameOver, T1, T2), holds(reward(Pz), T1),
    happens(pay(P1,Pz), T1, T3)]).`

`initiate <fluent>` and `terminate <fluent>` in a consequent are the immediate
effects `happens(initiate F, …)` / `happens(terminate F, …)`.

Whether a `then` conclusion is an action to perform or a condition to check is
decided by its declaration, not by its position: a declared action or event
becomes `happens/3`, a fluent becomes `holds/2`.

### 3.6 Intensional fluents and composite events

An LE rule whose head carries a temporal suffix:

```
    the players are a number at a time if
        the number at the time is the sum of each a value
            such that a player has played the value at the time.
```
→ `l_int(holds(num_players(N), T), [ … ]).`

```
    a player pays a prize from a first time to a second time if
        an account is credited with the prize at the first time
        and the account is settled from the first time to the second time.
```
→ `l_events(happens(pay(P,Pz), T1, T2), [ … ]).`

`at` gives `l_int`, `from … to …` gives `l_events`. Which one is *checked*
against the declarations: a head declared a fluent must use `at`, a head
declared an event or action must use `from … to …`.

### 3.7 `it must not be true that …` — integrity constraints

```
    it must not be true that
        a player inputs a choice and an amount from a first time to a second time
        and the amount <= 0.
```
→ `d_pre([happens(inputs(P,C,A), T1, T2), A =< 0]).`

### 3.8 `the goal is that …` — planning

```
    the goal is that the goat is at the south bank and the wolf is at the south bank.
```
→ `achieve(loc(goat,south) & loc(wolf,south)).`

A document with a goal also needs `:- lps_engine(planning).`, which
`le_lps.pl` emits automatically — a goal is exactly the declaration that the
program is a planning problem.

### 3.9 Observations

A scenario is a list of timed events:

```
scenario one is:
    miguel inputs rock and 1000 from 1 to 2.
    bob inputs paper and 1000 from 1 to 2.
```
→ `observe([inputs(miguel,rock,1000)], 2).` and one more.

`observe/2` takes the *end* time, which is why `from 1 to 2` produces `2`.
A scenario fact with no temporal suffix is an error, not a fact at time 0:
an untimed observation has no meaning in LPS and silently placing it would be
worse than saying so.

### 3.10 `display`

```
    the balance of a person that is an amount is drawn as
        a rectangle from [*x*, 0] to [*right*, *amount*] labelled the person if …
```

is **not** in this language. `display/2` is a Prolog term with a property list;
rendering it in English buys nothing, and a companion `.lps` file (§7) is the
right home for it. `examples/lps/badlight.le` therefore has a `badlight.lps`
beside it, and that is the documented answer.

---

## 4. Conditions

Everything LE2 already parses works unchanged inside an antecedent: `and`,
`or`, `it is not the case that`, `for all cases in which … it is the case that
…`, aggregates (`is the sum of each … such that …`), comparisons, arithmetic,
lists. What §3.1 adds is the temporal suffix, and what `le_lps.pl` adds is the
decision, per literal, between `holds/2`, `happens/3` and a plain Prolog goal:

| the literal's template was declared | becomes |
|---|---|
| a fluent | `holds(F, T)` — or `holds(not F, T)` under a negation |
| an event, action or prolog event | `happens(E, T1, T2)` |
| a timeless template, or an LE built-in | the goal itself, untimed |

An untimed fluent or event inside a rule inherits the rule's time: the
antecedent time for a condition, the trigger's times for a `when`.

---

## 5. The prospective form

`docs/le_lps_design.md` §6 called this the one genuinely open problem and made
it the acceptance test for the surface language. From `prospectiveGoat.pl`:

```prolog
false loc(goat,L) at T, loc(wolf,L) at T, not loc(farmer,L) at T, row(_,_) to T.
```

`row(_,_) to T` anchors `T` to the state *resulting from* a crossing, so the
constraint is about a state that does not exist yet and is defined by the
action under consideration.

**It is expressible, by §3.1's third suffix.** The English is:

```
    it must not be true that
        a crossing happens to a time
        and the goat is at a place at the time
        and the wolf is at the place at the time
        and it is not the case that the farmer is at the place at the time.
```

→ `d_pre([happens(row(_,_), _, T), holds(loc(goat,L), T), holds(loc(wolf,L), T),
   holds(not loc(farmer,L), T)]).`

`… to a time` with no `from` is exactly `row(_,_) to T`: an event whose end is
the moment being constrained and whose start is not mentioned. Reading it aloud
— "it must not be true that a crossing happens *to* a time and, *at* that time,
the goat and the wolf are together without the farmer" — says what the
constraint means.

So the acceptance test is met, and §I.9.6's scope limit is narrower than
`docs/le_lps_design.md` feared. What is *not* covered is listed in §7.

---

## 6. The fifteen programs

In the LE2 repository, `examples/lps/`. Each `NAME.le` has a `NAME.expected.lpsw`
beside it: the internal syntax `le_lps.pl` must produce, compared `variant/2`
term by term.

| program | what it is for |
|---|---|
| `rock_paper_scissors_minimal.le` | the first specimen: events, actions, fluents, updates, denials |
| `rock_paper_scissors_base.le` | the second specimen: aggregates, initiate, ordinals |
| `rock_paper_scissors_ethereum.le` | the third specimen: prolog events, composite events, `l_int` |
| `goat.le` | composite events, recursive decomposition |
| `prospective_goat.le` | the prospective form — the acceptance test (§5) |
| `goat_declarative.le` | `achieve`, planning mode |
| `badlight.le` | `display/2` via a companion `.lps` (§3.10, §7) |
| `bank_transfer.le` | the canonical "contract" shape |
| `dining_philosophers.le` | concurrent actions, preconditions over action sets |
| `fire_simple.le` | the smallest interesting reactive rule |
| `map_colouring.le` | timeless-heavy, little state |
| `loan_agreement.le` | real-time, dates, a legal text behind it |
| `escrow.le` | multi-party, obligations |
| `delivery_delay.le` | deadlines and elapsed time |
| `life.le` | intensional fluents over a grid — the stress case |

All fifteen translate, and their expectations are checked by
`testing/lps_test.pl`. Thirteen also survive the **round trip** —
`LE → internal → LE → internal`, with the two internal forms `variant/2`-equal
term by term (`testing/lps_roundtrip.pl`, and `le_lps_write.pl` for what that
does and does not claim). The two that do not are `delivery_delay.le` and
`loan_agreement.le`, both for the same reason and both listed in the test with
it: a calendar date appears as a *constant* (`2018-04-01`), and a date constant
has no LE surface form of its own, so the writer cannot put it back.
 Thirteen also *run* to `success` under LPS(2)
(`./lps run examples/lps/NAME.le` with `LPS_LE2_DIR` set). The two that do not:

- `prospective_goat.le` ends in `failure` — and so does the original
  `legacy_lps1/examples/forTesting/prospectiveGoat.pl` under the same engine.
  Agreeing with the source is the point.
- `rock_paper_scissors_minimal.le` ends in `failure` where the original ends in
  `terminated(unknown)`. The original has one rule this version does not —
  `If a number is sent to some body from T1 to T2 then lps_terminate from T2 to
  T3` — and `lps_terminate` is a system action with no English form. Rather
  than invent one, the difference is recorded here.

---

## 7. What is out of scope, and why

Stated rather than worked around, per §I.9.6.

- **`display/2`.** A property list of shapes, colours and coordinates. §3.10.
  Companion file.
- **Prolog escapes.** `findall/3` with a hand-written goal, `is/2` over a
  library predicate, anything reaching outside the templates. Companion file —
  which is `docs/le_lps_design.md` §5's recommendation (ii), taken.
- **Priorities.** `reactive_rule/3` has no English form. No corpus program uses
  one.
- **`unserializable/1`.** A tracing directive, not a statement about the
  domain.
- **Real-time settings other than the three in §2.** `simulatedRealTime*` are
  test-harness knobs.
- **`lps_terminate` and the other system actions.** They are instructions to
  the engine, not statements about the domain. See the note on
  `rock_paper_scissors_minimal.le` in §6.

Two further limits are LE2's, not LPS's, and are worth knowing before writing a
program:

- **Arithmetic operands must be bare variable names.** `a total = price + tax`,
  not `a total = the price + the tax` — which is how LE2's expression parser
  has always worked (`examples/moreExamples/numbers.le`). Comparisons are
  written symbolically (`the amount >= 10`); the spelled-out
  `is greater than or equal to` is ambiguous against `is greater than` in
  LE2's template matcher and matches the shorter one.
- **A template may not contain a section keyword** — `contract`, `knowledge`,
  `templates`, `fluents`, `events`, `actions`, `predicates`, `ontology`,
  `target` — because LE2 reads one as the start of a new section and reports
  the template as truncated. `the lender calls off the loan`, not `the lender
  cancels the contract`.

The companion-file rule is: `foo.le` and `foo.lps` compile together, `.le`
first, and the `.lps` half is ordinary LPS external syntax with an ordinary
`.lps` editor mode. Nothing is smuggled through the English.
