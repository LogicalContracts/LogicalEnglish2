# Language features, one program each

Small programs, each showing one feature of Logical English, grouped by the
part of the [language reference](/docs/user/reference/language) they
illustrate. Open a folder's guide from its heading, or a program from the list.

## Start here

- [Functions](templates/functions.le?scenario=one_currency&query=expensive) — a value a sentence names, such as the price of a cup.
- [Unknowns](unknowns/unknowns.le?scenario=one&query=one) — answers that hold if something unknown turns out true.
- [Abduction](abduction/grass_is_wet.le?scenario=observation&query=explain) — explaining an observation by what it assumes.
- [Memoization](memoization/family_relatives.le?scenario=tudors&query=ancestors) — remembering answers so that a family tree is searched once.

## Try this

1. Open [functions](templates/functions.le?scenario=one_currency&query=expensive) and click **Query**: "mug is expensive".
2. Click the answer to see its explanation, step by step.
3. Open [unknowns](unknowns/unknowns.le?scenario=one&query=one) and click **Query**. Alice and bob both become rich, but alice only on a condition, shown in amber: that she knows 42 will win the lottery.
4. Open [memoization](memoization/family_relatives.le?scenario=tudors&query=ancestors) and click **Query**: the four ancestors of Lettice.

## The folders

| Folder | Programs | Reference |
|---|---|---|
| [`templates/`](templates/README.md) | functions, synonyms, named_vars, white_rabbit, is_a_class_of, longsentence, subset | §2, §6 |
| [`rules/`](rules/README.md) | rule_id_test | §3.1, §15.5 (labels) |
| [`negation/`](negation/README.md) | only_if, propositional, alice_propositional, inequality | §4, §15.1 |
| [`aggregates/`](aggregates/README.md) | sums, ecommerce | §5 |
| [`unknowns/`](unknowns/README.md) | unknowns, unknowns_in_aggregates, unknowns_in_forall, assumption_constraints | §2 (`; unknown`), §3.3 |
| [`abduction/`](abduction/README.md) | grass_is_wet, sunglasses, diagnosis, loan_approval | §2, §3.3 |
| [`includes/`](includes/README.md) | citizenship_including (+ citizenship_premier), prolog_resources/ | §14 |
| [`scasp/`](scasp/README.md) | dual_engine_demo, clp_coverage | docs/user/reference/scasp.md |
| [`prolog/`](prolog/README.md) | prolog_call | §15.6 (embedded `prolog` goals), §13 |
| [`memoization/`](memoization/README.md) | lattice_paths, family_relatives, memorable_warnings | §2.4 (`; memorable`) |
| [`extensions/`](extensions/README.md) | numbering_test | extensions.md §15.5 (needs le_extensions.pl) |

## More

- [The language reference](/docs/user/reference/language), and [the tutorial](/docs/user/tutorials/intro-to-le/intro-to-le), which builds small programs step by step.
