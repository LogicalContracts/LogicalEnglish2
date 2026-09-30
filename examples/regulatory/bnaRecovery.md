# Recovering the British Nationality Act program from the 1980s floppy disk

This note records what was found in `DISK IMAGE.txt`, how the program in it was
recovered and converted to SWI-Prolog, which files were built, and what is left
to do. It was written on 30 September 2026.

## 1. What the disk image turned out to be

`DISK IMAGE.txt` is not a text file. It is a raw copy of a whole floppy disk
formatted for CP/M 2.2, the operating system most small business computers ran
around 1980. The label at the start of the image says "NORTH STAR" and
"QUAD.CAP": a North Star quad-capacity disk of about 350 KB.

The disk's directory (at byte 16550 of the image) lists 53 files:

| Files | What they are |
|---|---|
| `B11` … `B16`, `B1U`, `B51U`, `B5GEN`, `BGEN`, `BDATE`, `BMENU` | the British Nationality Act (BNA) program, split into modules |
| `BX11` … `BX16`, `BX1U`, `BX51U`, `BX5GEN`, `BXGEN`, `BXDATE`, `BXMENU` | a second series of the same modules |
| the same names ending `.BAK` | the previous version of each module, kept by the editor as a backup |
| `INTERACT`, `HOWEXP`, `CHAIN`, `MENTION`, `CONDITIO`, `LISTER`, `SYNCHECK` | the shell around the program: it asks the user questions and explains answers |
| `PROLOG.COM` | micro-PROLOG itself |

A `.LOG` file is a program saved by micro-PROLOG. Several deleted files (older
backups) are still readable in the directory too. So the disk holds **several
versions of the same program**, not one.

The program is written in micro-PROLOG's own list syntax, where a clause is a
list whose first element is the conclusion:

```
((b-c X (by birth) (1 1 1 a) Y)
  (born-in X UK)
  (born-on X Z)
  (after-or-on Y Z)
  ...)
```

The numbers such as `(1 1 1 a)` are section numbers of the Act: here section
1(1)(a). In micro-PROLOG the letters `X Y Z x y z`, alone or followed by a
digit, are variables; every other word is a constant.

## 2. Why the text is noisy

The recovery tool damaged the image in three ways:

1. **Bytes were removed.** Every `^Z` byte (the character CP/M uses to pad the
   end of a text file) was deleted, and every null byte was turned into a
   space. About 2 KB are missing in all, so every position after a deletion is
   shifted.
2. **Sectors are out of order.** A disk sector holds 512 bytes. On most tracks
   the disk stores consecutive sectors of a file five places apart
   (interleaving), but some stretches of the image are stored in plain order,
   and the recovery inserted blank sectors where it could not read one. As a
   result, the text of one file breaks off every 512 bytes or so and continues
   with the text of another. This is why the file shows words such as
   `parent-ofployed` or `(alive (both pbsent-from-UK`: two pieces of different
   clauses glued at a sector boundary.
3. **Some sectors are blank.** They could not be read and came back as spaces.

## 3. How the program was recovered

The first attempt was to rebuild each file exactly, from the directory's list
of blocks and a model of the disk's layout. It worked for the first tracks and
failed further on, because the layout changes from track to track and the
deleted bytes move every boundary. That attempt was abandoned.

Instead the program was recovered **one clause at a time**, relying on the fact
that the disk holds several copies of most of the text:

- **confirmed** — the exact text of the clause occurs in two or more places on
  the disk with different text around it, that is, in two independent copies.
  Damage at a sector boundary cannot produce the same text twice.
- **single** — only one copy exists, but it lies wholly inside one disk sector
  (or in a stretch whose sectors are in order), contains only plain characters,
  and has no word that is made of two cut-off words.
- **damaged** — everything else. Such a clause is not in the program.

After a first pass, a second pass removed clauses that still showed signs of a
splice:

- a call to a garbled name (`aeg`, `apies`, `was-in-UK-oinor-at`, …);
- a built-in with the wrong number of arguments (`SUM` with 1, 4 or 7);
- a predicate called with a number of arguments seen nowhere else, while its
  usual number is well attested;
- bare words in a clause body (part of a sentence spliced in);
- several clause bodies glued into one goal;
- a conclusion whose name is a fragment of other text.

About 60 clauses with rare words were then checked by eye and kept or dropped
one by one. Names that look misspelt but occur in several copies, such as
`registeration`, `assiciation` and `entittled-to-register-as-brit-cit`, were
kept: they are the original author's spelling. Names cut off at 60 characters
(`…-otherwise-than-by-descent-at-`) are micro-PROLOG's limit on name length,
not damage, and were kept.

## 4. Conversion to SWI-Prolog

Only the syntax was changed:

| micro-PROLOG | SWI-Prolog |
|---|---|
| `((head a b) (goal c) ...)` | `head(a, b) :- goal(c), ... .` |
| predicate and constant names | kept letter for letter, quoted: `'b-c'`, `'born-in'` |
| variables `X Y Z X1` | unchanged |
| variables `x y z x1` | `X_ Y_ Z_ X_1` |
| `(a b|X)`, `()` | `[a, b|X]`, `[]` |
| `(NOT p a)` | `\+ p(a)` |
| `(NOT ? ((g1) (g2)))` | `\+ (g1, g2)` |
| `/` | `!` (cut) |
| `(PP word ...)` | `'PP'([word, ...])` (micro-PROLOG's print takes any number of arguments) |

Two settings were added so that the program runs as it did in micro-PROLOG:

- **Every relation is dynamic.** In micro-PROLOG any relation could be given
  new clauses at any time, and the facts of a case were added next to the
  rules. SWI-Prolog normally forbids this for relations loaded from a file.
- **The facts of the case are declared.** The program uses 134 relations that
  it never defines, such as `born-in`, `father-of` and `female`. The original
  system asked the user for these. They are declared so that a question without
  them fails instead of raising an error.

## 5. The files built

| File | What it does |
|---|---|
| `bna.pl` | The recovered BNA program: 440 clauses (155 confirmed, 285 single) over 123 predicates. Each clause is preceded by a comment giving its status and its byte offset in `DISK IMAGE.txt`. Load it with `swipl bna.pl`. |
| `bna_compat.pl` | The micro-PROLOG built-in relations the program uses, written for SWI-Prolog: `SUM`, `TIMES` (and `PROD`), `LESS`, `EQ`, `FAIL`, `PP`, `P`, `R`, and `mp_call` for a goal given as a list. `CL` and `ADDCL` (reading and adding clauses as lists) are not reproduced. `bna.pl` loads this file. |
| `bna_shell.pl` | The explanation and question-asking shell found on the same disk (the `rel*` and `xr*` relations, the sentence parser, the lister): 258 clauses, converted the same way. It is **not loaded**: it relies on parts of micro-PROLOG that `bna_compat.pl` does not reproduce. The 8 clauses whose conclusions take a variable number of arguments are kept verbatim in a comment at the end. |
| `bna_damaged.txt` | Every clause left out of the program, verbatim, with each byte offset where it occurs and the reason it was left out: 274 damaged and 161 unverified (a clause that crosses a spliced sector boundary with no second copy to check it against, often two clauses glued together). This is the starting point for any repair by hand. |
| `bna.le` | The program in Logical English: one chosen version of each rule, the six questions of the original system as queries, and 14 test cases. Section 10 describes it. |
| `bna_compare/` | `cases.py` holds the 14 test cases, each fact written both as a Logical English sentence and as the facts `bna.pl` needs; `compare.py` runs every case on both programs and lists, question by question, the persons each one names. |

The scripts that did the recovery were temporary and are not kept. The method
above and the offsets in each file are enough to repeat or check any decision.

## 6. What the program contains

The system's own `askabout` facts list the questions it offered the user:

| Question | State in `bna.pl` |
|---|---|
| `brit-cit` — is this person a British citizen on this date? | defined |
| `brit-cit-by-descent` | defined |
| `brit-cit-by-annulment-of-renunciation` | defined |
| `entitled-to-naturalise-as-brit-cit` | defined |
| `entitled-to-register-as-brit-cit` | only a misspelt fact `'entittled-to-register-as-brit-cit'` with no arguments survives |
| `entitled-to-renunce-brit-citship` | not recovered |

Under these questions are the main relations:

- `'b-c'/4` — how a person is a British citizen, under which section of the
  Act, on which date (by birth, by descent, by adoption, by acquisition at
  Commencement, by naturalisation);
- `'entitled-to-register-as-b-c'/4` — entitlement to register, with its
  section;
- `satisfies/2` — whether a person meets the conditions of a given section;
- date arithmetic: `sumdate`, `after`, `after-or-on`, `earliest-of`,
  `age-of`, `within-years-after`, `days-in-month`.

There are also 134 `dict` facts (the vocabulary of the shell), a few facts
listing countries and territories, and one fact about a test person that was
saved on the disk: `'born-on'('F', [5, 12, 1956])`.

In this version of the program, Commencement is 30 October 1981,
`on('Commencement', [30, 10, 1981])`. That is the date the Act received Royal
Assent. Dates are lists of day, month and year.

## 7. It runs

A test case: Peter was born in the UK on 1 January 1985, and his father John
was a Citizen of the UK and Colonies with the right of abode.

```prolog
?- consult(bna),
   maplist(assertz, [
       'born-in'(peter, 'UK'),
       'born-on'(peter, [1, 1, 1985]),
       'father-of'(john, peter),
       'was-c-of-UK-and-colonies-on'(john, _),
       'had-right-of-abode-in-UK'(john, [under, im, '.', act, 1971], [on, _]),
       'born-on'(john, [5, 6, 1950]),
       uncertain(_, a, 'british-citizen', on, _)]).

?- 'b-c'(john, How, Section, [1, 1, 1985]).
How = [by, acquisition, at, 'Commencement', for, c, '`', s, of, 'UK', &, colonies],
Section = [1, 11, 1].

?- 'b-c'(peter, How, Section, [1, 1, 1990]).
How = [by, birth], Section = [1, 1, 1, a].

?- 'brit-cit'(peter, [on, [1, 1, 1990]]).
true.
```

John became a British citizen at Commencement under section 11(1); Peter is
one by birth under section 1(1)(a). A person about whom nothing is known is
not.

The fact `uncertain(...)` is needed because the original rule for
`british-citizen` first asks the user whether it is uncertain that the person
is a British citizen, and only then works it out.

Calling every predicate with open arguments raises no errors. Two calls do not
finish: `duplicate/1` waits for keyboard input, and `satisfies/2` searches
without end when all its arguments are open, as it would have in micro-PROLOG.

## 8. Limitations

- **Versions are mixed.** Because the disk held several versions of each
  module, one predicate may have clauses from more than one version. For
  example, both `days-absent-from-UK` and `whole-days-absent-from-UK` appear,
  and `b-c` by birth under section 1(1)(a) has three different forms. Clause
  order is the order of first appearance on the disk, which is not necessarily
  the order of any original file.
- **Clauses are missing.** 435 clauses are not in the program, so some rules
  are incomplete. For example, `dependent-territory` lost its list of
  territories, and some rules call a name that only another version defines.
- **"Single" is not proof.** A single-copy clause passed every check, but a
  splice that falls exactly between two words, and that produces a clause that
  still looks sensible, cannot be detected. Such cases should be rare.
- **The shell is not running.** The question-asking and explanation parts of
  the original system are converted but not loaded.

## 9. What is left to do

1. **Choose one version.** Decide which version counts as "the original" —
   probably the live `.LOG` files of the `B` series — and rebuild it alone.
   The disk's directory gives each file's blocks and size; the missing piece is
   a reliable map from blocks to positions in the image, track by track. Where
   the files of that version cannot be read, the confirmed clauses of
   `bna.pl` can fill the gaps.
2. **Repair damaged clauses by hand.** Many entries in `bna_damaged.txt` are
   two clauses glued at a sector boundary, and each half usually exists
   elsewhere. Rebuilding them would restore missing rules, starting with the
   top-level questions `entitled-to-register-as-brit-cit` and
   `entitled-to-renunce-brit-citship`.
3. **Check against the published program.** The BNA program was described by
   Sergot, Sadri, Kowalski, Kriwaczek, Hammond and Cory in "The British
   Nationality Act as a logic program" (Communications of the ACM, 1986).
   Comparing its clauses with the recovered ones would confirm many rules and
   show which version is on the disk.
4. **Run the shell.** Reproducing micro-PROLOG's clause-access built-ins (`CL`,
   `ADDCL`, `DELCL`) and its relations with a variable number of arguments
   would let `bna_shell.pl` ask the user questions and explain answers as the
   original did.
5. **Finish the Logical English version.** `bna.le` (section 10) covers every
   question of the original, but section 10.5 lists what it lacks: the rules
   lost from the disk, the list of dependent territories, and rules that were
   reconstructed. Each rule recovered by steps 1 to 3 should be added to it,
   with a test case, and checked with `bna_compare/compare.py`.

## 10. The Logical English version: `bna.le`

`bna.le` states the recovered program in Logical English, a language whose rules
read as English sentences. It is a translation of `bna.pl` made by hand, rule by
rule, and it is not a syntax conversion: where the recovered program held
several versions of a rule, `bna.le` holds one.

### 10.1 What it contains

- **The six questions of the original system**, one query each. The original
  listed them in its `askabout` facts:

  | Query | The question |
  |---|---|
  | `british_citizen` | Is this person a British citizen on this date? |
  | `british_citizen_by_descent` | … a British citizen by descent? |
  | `british_citizen_by_annulment_of_renunciation` | … a British citizen again because a renunciation was annulled? |
  | `entitled_to_register` | … entitled to register as a British citizen? |
  | `entitled_to_naturalise` | … entitled to naturalise as a British citizen? |
  | `entitled_to_renounce` | … entitled to renounce British citizenship? |

  A seventh query, `how`, asks by which way (birth, descent, adoption,
  naturalisation, acquisition at commencement) and under which section a person
  is a British citizen.

  The original system asked the user for the date the question was about. A
  scenario states it instead: `the question is asked on 1990-01-01.`
- **166 labelled rules**, grouped by the section of the Act: sections 1 to 4, 6, 8
  to 14, section 48 and Part 5 (interpretation), and the rules about
  commencement.
- **14 test cases** (scenarios), each stating what every one of the six
  questions should answer.

### 10.2 How the original's features were carried over

- **Sections become provenance.** Every rule has a label naming the section it
  comes from, for example
  `rule s1_1_a with provenance the British Nationality Act 1981 at "section 1(1)(a)":`.
  An explanation of an answer shows that section beside each step. A comment
  above each rule gives the byte offset, in `DISK IMAGE.txt`, of the clause it
  was translated from.
- **Section numbers that the rules use stay as values.** The original also
  passed sections around as data, for example "a british citizen by birth under
  section 1(1)(a)". These are written as quoted values, `"1(1)(a)"`, and appear
  in the answers.
- **Dates are Logical English dates.** The original wrote a date as a list
  `(day month year)` and did its own arithmetic (`sumdate`, `days-in-month`,
  `valid-dated-to`, and `after` defined on lists). `bna.le` writes
  `1985-01-01` and uses the date comparisons and the `months after` template
  of Logical English, so none of that arithmetic is needed. "3 years after" is
  36 months after, and an age is the number of whole months divided by 12.
- **Messages become unknowns.** Some conditions of the original always
  succeeded and printed advice, for instance "On making an application ... X
  will be entitled to register as b-c", or "Formal consent to the registeration
  ... is required of both parents". In `bna.le` each such condition holds
  either because the case says so (an application was made, the Secretary of
  State approved the case, both parents consented) or by assumption. The
  assumption is a template marked `; unknown`, such as `a person makes an
  application`, and an answer that rests on it lists it among its unknowns. So
  the answer "peter is entitled to register ..." comes with the unknowns
  "peter makes an application" and "the secretary of state approves the case
  of peter", which is what the original printed.
- **Facts of the case are declared.** A template the rules use but never
  conclude, such as `*a person* is born on *a date*`, is marked `; undefined`:
  its sentences belong in a scenario. The original asked the user for them.

### 10.3 Which clauses were chosen

Where `bna.pl` has several versions of a rule, `bna.le` keeps the one that is
most complete and most consistent with the rules around it. The main choices:

- **Section 1(1)(a)** — the version in which a parent who has died counts as a
  citizen up to the date of death (section 48), rather than the two shorter
  versions.
- **Section 2(1)(a)** — the same fuller version; the version that consisted of
  a single unrelated condition is a splice and is dropped.
- **Section 2(1)(b)** — both versions: one for a parent alive at the child's
  birth, one for a parent who died before commencement.
- **Section 2(2)** — two of the three definitions of a suitable employer; the
  third is the end of a section 14(1)(h) rule spliced onto it.
- **Section 3(5)** — the version counting days of absence and asking for the
  formal consent "as a British citizen", for both parents alive and for the
  mother dead.
- **Section 8(3)** — the version using the date of the application.
- **Section 10(4)** — nine ways of having an appropriate qualifying connection
  with the UK: being born in the UK, being naturalised before commencement, or
  being registered in the UK — each for the person, the father or the paternal
  grandfather. The copy with the garbled condition `(befor 1)` is dropped.
- **Sections 11(1) and 11(2)** — all versions, which cover different cases
  (registered or not, with or without the right of abode under section
  2(1)(c)).
- **Section 12(3)** — the version without a "present date".
- **Section 14(1)** — paragraphs (a) to (g); paragraph (h) depends on a
  relation (`b-c X (par . 2 of sch . 2)`) defined nowhere, and is left out.
- **Earliest of two dates** — the version using "is dead" and "died on", which
  has four copies, rather than the one using `is-true-of`.

Several names that the versions spell differently for one idea are one
template in `bna.le`: `born-outside X UK` and `born-outside-UK X`,
`was-c-of-UK-and-colonies-on X Y` and `was-c-of-UK-and-colonies X (on Y)`,
`days-absent-from-UK` and `whole-days-absent-from-UK`, and the application
facts `made-application-dated`, `is-true-of made-application` and
`is-true-of application-made`.

### 10.4 What was recovered or reconstructed

Six clauses missing from `bna.pl` were found **inside damaged records**: a
damaged record is often a broken first clause followed by several intact ones,
which the first recovery did not look for. They are marked in `bna.le` with
their offsets:

- the question `entitled-to-renunce-brit-citship` (2 copies);
- `b-c-from`, which defines citizenship by adoption under section 1(5) (2 copies);
- section 14(1)(b)(i);
- the formal consent of both parents to a registration;
- `born-outside-UK-after-Commencement`;
- a third way of having been naturalised before commencement.

Four rules are **reconstructed** and say so in their comments:

- **Renunciation, section 12** — `ceases-to-be-b-c-through-renunciation`
  survives only in three damaged copies, each keeping a different part; the
  rule in `bna.le` joins the parts that survive.
- **The entitlement to renounce, section 12(1)** — only its first conditions
  survive (a British citizen, of full age, of full capacity); the end of the
  rule is lost.
- **The question `entitled-to-register-as-brit-cit`** — only a misspelt fact
  with no arguments survives. The rule is written the way the other five
  questions are written.
- **Settled in the UK, section 50(2)** — the three conditions that survive; the
  end of the rule is lost.

Three small rules were **added** to make the translation work, and are not in
the original: "the birthplace of a person is in the UK" when the person is born
in a place that is part of the UK (the original took this as a fact of the
case); the renunciation takes effect on the date of the declaration (the
original took that date as a fact); and "six months on from" a date.

### 10.5 What is missing

- **Rules lost from the disk:** the entitlements to register under sections
  4(2), 5, 7 and 9, section 3(3)(a), section 14(1)(h) and section 14(2)(b). Some of the conditions these rules used are in `bna.le`
  (section 4(2)(a) to (d), section 9(2), the relevant service of section 7),
  but nothing uses them yet: the verifier reports five such templates as
  untested.
- **The list of dependent territories** — lost; "counts as a dependent
  territory" is a fact a scenario must state.
- **The explanation shell** — Logical English has its own explanations, which
  show each rule's section.

### 10.6 Assumptions

- **Commencement** is 30 October 1981, as the program on the disk recorded it.
  (The Act came into force on 1 January 1983; 30 October 1981 is the date of
  Royal Assent.)
- **The "uncertain" and "known" questions are dropped.** Before working out
  whether a person was a British citizen, the original asked the user whether
  that was uncertain; if the user already knew, the answer was taken from
  them. In `bna.le` a scenario may simply state that a person became a British
  citizen at commencement, and otherwise the rules work it out.
- **"Of full age" for section 12(5)** is, as in the original, "married, or not
  a minor". A person with no known date of birth is therefore of full age.

### 10.7 It works at least as well as the SWI-Prolog version

`bna_compare/compare.py` runs every test case on both programs, with the same
facts, and compares, for each of the six questions, the persons each program
names. The facts of each case are written twice in `bna_compare/cases.py`: as
Logical English sentences and as the facts `bna.pl` needs.

The 14 cases are: birth in the UK to a citizen parent; a foundling; descent
through a mother; registration under section 1(4) after ten years in the UK;
naturalisation; renunciation; annulment of a renunciation; resumption under
section 13(3); a parent settled in the UK; a parent in crown service abroad;
adoption; a woman who was a citizen by descent before 1983; a child born after
the father's death; and a person with no claim.

Of the 84 comparisons (14 cases, 6 questions):

- **73 give the same persons.**
- **11 give more persons in `bna.le`,** and never fewer:
  - 8 answers to `entitled_to_renounce`, which `bna.pl` cannot answer, having
    lost that question;
  - naturalisation, which `bna.pl` cannot grant, having lost the rule
    `approval-of-naturalisation-given-or-needed`;
  - citizenship by adoption, from the recovered rule `b-c-from`;
  - citizenship by descent under section 14(1)(b)(i), recovered from inside a
    damaged record.

One answer of `bna.pl` is not given by `bna.le`, on purpose: in the case of the
parent in crown service, `bna.pl` also answers that an unnamed person is a
British citizen, because of a damaged clause which says that anyone is a
citizen by descent whenever someone was born outside the UK after
commencement.

The 14 cases are also written into `bna.le` as scenarios, with the answers
expected of each question, and pass with the ordinary test runner:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('bna.le', R), print_test_result(R), halt."
```

All 84 expectations pass. The verifier reports no errors. It warns that the
program is not stratified (some rules depend on one another through negation,
as they did in the original), and that five templates are used by no query.
