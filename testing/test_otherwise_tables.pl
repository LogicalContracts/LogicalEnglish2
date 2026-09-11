/** <module> "otherwise" cascades and decision tables

    LE_extensions_proposal §3.3, docs/le_summary.md §17.2-17.3.

    Run with:  swipl -q -g run_tests -t halt testing/test_otherwise_tables.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_otherwise_tables, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

answers(KB, Scenario, Query, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A, ( query(SM, Query, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

custom_answers(KB, Scenario, Text, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    once(parse_custom_query(KB, Text, Goal)),
    findall(A, ( query(SM, Goal, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

why_literals(Why, Lits) :- findall(L, why_literal(Why, L), Lits).
why_literal(L0, L) :- is_list(L0), !, member(X, L0), why_literal(X, L).
why_literal(success(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).
why_literal(failure(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).

explanation_literals(KB, Scenario, Query, Answer, Lits) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    once(( query(SM, Query, I, _, Why), canonical_string(I, Answer) )),
    destroySession(SM),
    why_literals(Why, Lits).

issue_types(KB, Severity, Types) :-
    findall(T, KB:le_issue(Severity, T, _, _, _, _), Ts),
    msort(Ts, Types).

discount_program(Rule, Text) :-
    format(string(Text), "the target language is: prolog.

the templates are:
    the discount for *a customer* is *a rate*.
    the discount rate for *a customer* is *a rate*.
    *a customer* is a member; undefined.
    *a customer* is a student; undefined.
    *a customer* is a customer; undefined.
    *a customer* is banned from discounts; undefined.

the knowledge base discounts includes:

the discount for a customer is a rate
    if the customer is a customer
    and the discount rate for the customer is the rate.

~w

scenario three is:
    ann is a customer.
    bob is a customer.
    cy is a customer.
    ann is a member.
    ann is a student.
    bob is a student.

query discounts is:
    the discount for which customer is which rate.
", [Rule]).

cascade("the discount rate for a customer is a rate
    if the customer is a member and the rate is 20
    otherwise the customer is a student and the rate is 10
    otherwise the rate is 0.").

:- begin_tests(otherwise).

test(one_alternative_per_case) :-
    cascade(R), discount_program(R, P), load_text(P, KB),
    answers(KB, three, discounts, As),
    As == ["the discount for ann is 20", "the discount for bob is 10", "the discount for cy is 0"].

% The guard negates the earlier alternative's CONDITIONS, so a known output
% does not let a later alternative through.
test(known_output_does_not_pass_the_guard) :-
    cascade(R), discount_program(R, P), load_text(P, KB),
    custom_answers(KB, three, "the discount rate for ann is 10", As),
    As == [],
    custom_answers(KB, three, "the discount rate for bob is 10", Bs),
    Bs == ["the discount rate for bob is 10"].

test(guard_explained_as_a_negation) :-
    cascade(R), discount_program(R, P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, three),
    once(parse_custom_query(KB, "the discount rate for cy is which rate", Goal)),
    once(query(SM, Goal, _, _, Why)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("it is not the case that cy is a member", Lits),
    memberchk("it is not the case that cy is a student", Lits).

% The "if" on the head's line: the otherwise lines are then nested under the
% first condition by indentation, and still continue the cascade.
test(inline_if_layout) :-
    discount_program("the discount rate for a customer is a rate if the customer is a member and the rate is 20
    otherwise the customer is a student and the rate is 10
    otherwise the rate is 0.", P),
    load_text(P, KB),
    answers(KB, three, discounts, As),
    As == ["the discount for ann is 20", "the discount for bob is 10", "the discount for cy is 0"].

% Multi-line alternatives: "and" binds tighter than "otherwise".
test(multi_line_alternatives) :-
    discount_program("the discount rate for a customer is a rate
    if the customer is a member
    and the rate is 20
    otherwise the customer is a student
    and the rate is 10
    otherwise the rate is 0.", P),
    load_text(P, KB),
    answers(KB, three, discounts, As),
    As == ["the discount for ann is 20", "the discount for bob is 10", "the discount for cy is 0"].

% An otherwise cascade inside a negation block is scoped by indentation.
test(nested_cascade) :-
    discount_program("the discount rate for a customer is a rate
    if it is not the case that
        the customer is banned from discounts
        otherwise the customer is a member
    and the rate is 5
    otherwise the rate is 1.", P),
    load_text(P, KB),
    answers(KB, three, discounts, As),
    % not(banned or (not banned and member)): true for bob and cy (5), ann is a member (1)
    As == ["the discount for ann is 1", "the discount for bob is 5", "the discount for cy is 5"].

% A body line that merely contains the word elsewhere is not a cascade.
test(word_inside_a_template_is_not_a_connective) :-
    load_text("the target language is: prolog.

the templates are:
    *a claim* is otherwise covered.
    *a claim* is paid.

the knowledge base k includes:
a claim is paid
    if the claim is otherwise covered.

scenario s is:
    c1 is otherwise covered.

query q is:
    which claim is paid.
", KB),
    answers(KB, s, q, As),
    As == ["c1 is paid"].

:- end_tests(otherwise).

shipping_program(Policy, Rows, Text) :-
    format(string(Text), "the target language is: prolog.

the templates are:
    the order of *a customer* weighs *a number* kg; undefined.
    the shipping cost for a weight of *a number* kg is *a cost* under table shipping.
    the shipping cost for *a customer* is *a cost*.

the table shipping is~w:
    band | weight kg          | cost
~w
the knowledge base shipping includes:

the shipping cost for a customer is a cost
    if the order of the customer weighs a number kg
    and the shipping cost for a weight of the number kg is the cost under table shipping.

scenario three is:
    the order of ann weighs 0.5 kg.
    the order of bob weighs 4 kg.
    the order of cy weighs 40 kg.

query shipping is:
    the shipping cost for which customer is which cost.
", [Policy, Rows]).

first_rows("    s    | <= 1               | 5
    m    | > 1 and <= 10      | 12
    l    | > 10               | 30
").

:- begin_tests(decision_tables).

test(first_match) :-
    first_rows(R), shipping_program(", with first match", R, P), load_text(P, KB),
    issue_types(KB, error, []),
    answers(KB, three, shipping, As),
    As == ["the shipping cost for ann is 5", "the shipping cost for bob is 12", "the shipping cost for cy is 30"].

test(explanation_cites_the_row) :-
    first_rows(R), shipping_program(", with first match", R, P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, three),
    once(parse_custom_query(KB, "the shipping cost for cy is which cost", Goal)),
    once(query(SM, Goal, _, _, Why)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("row l of table shipping", Lits).

test(first_match_takes_the_first_row) :-
    shipping_program(", with first match", "    a | any | 1
    b | > 1 | 2
", P), load_text(P, KB),
    answers(KB, three, shipping, As),
    As == ["the shipping cost for ann is 1", "the shipping cost for bob is 1", "the shipping cost for cy is 1"].

test(all_matches) :-
    shipping_program(", with all matches", "    a | any | 1
    b | > 1 | 2
", P), load_text(P, KB),
    answers(KB, three, shipping, As),
    As == ["the shipping cost for ann is 1", "the shipping cost for bob is 1", "the shipping cost for bob is 2",
           "the shipping cost for cy is 1", "the shipping cost for cy is 2"].

test(unique_match_violation_raises, [throws(error(le_table_error(unique_violation(shipping, [a, b])), _))]) :-
    shipping_program("", "    a | any | 1
    b | > 1 | 2
", P), load_text(P, KB),
    answers(KB, three, shipping, _).

test(or_cells_and_dash) :-
    shipping_program(", with first match", "    a | 0.5 or 4 | 7
    b | -        | 9
", P), load_text(P, KB),
    answers(KB, three, shipping, As),
    As == ["the shipping cost for ann is 7", "the shipping cost for bob is 7", "the shipping cost for cy is 9"].

test(rows_without_ids_are_numbered) :-
    load_text("the target language is: prolog.

the templates are:
    *a code* is a covered diagnosis under table covered.
    *a claim* has code *a code*; undefined.
    *a claim* is covered.

the table covered is, with all matches:
    code
    A10
    B20

the knowledge base k includes:
a claim is covered
    if the claim has code a code
    and the code is a covered diagnosis under table covered.

scenario s is:
    c1 has code B20.
    c2 has code Z99.

query q is:
    which claim is covered.
", KB),
    issue_types(KB, error, []),
    answers(KB, s, q, As),
    As == ["c1 is covered"],
    createSession(KB, SM), setScenarion(SM, s),
    once(query(SM, q, _, _, Why)), destroySession(SM),
    why_literals(Why, Lits),
    memberchk("row 2 of table covered", Lits).

test(table_without_template_is_an_error) :-
    load_text("the target language is: prolog.

the templates are:
    *a thing* is fine.

the table nowhere is:
    a | b
    1 | 2

the knowledge base k includes:
a thing is fine if the thing is fine.
", KB),
    issue_types(KB, error, Errors),
    memberchk(table_without_template, Errors).

test(arity_and_width_errors) :-
    shipping_program(", with first match", "    s | <= 1 | 5
    m | > 1
", P), load_text(P, KB),
    issue_types(KB, error, Errors),
    memberchk(table_row_width, Errors).

% A sentence that merely starts with "the table" is not a table header.
test(the_table_as_a_constant) :-
    load_text("the target language is: prolog.

the templates are:
    *a thing* is red.
    *a thing* is noticed.

the knowledge base k includes:
the table is red.
a thing is noticed if the thing is red.

query q is:
    which thing is noticed.
", KB),
    issue_types(KB, error, []),
    createSession(KB, SM),
    findall(A, ( query(SM, q, I, _, _), canonical_string(I, A) ), As),
    destroySession(SM),
    As == ["the table is noticed"].

test(loaded_table_and_reload) :-
    tmp_file(tables, Dir0), make_directory(Dir0),
    directory_file_path(Dir0, 'rates.csv', CSV),
    setup_call_cleanup(true,
        (   write_csv(CSV, "band,weight kg,cost\ns,<= 1,5\nl,> 1,30\n"),
            loaded_program(P),
            load_text(P, Dir0, KB),
            issue_types(KB, error, []),
            answers(KB, three, shipping, As1),
            As1 == ["the shipping cost for ann is 5", "the shipping cost for bob is 30", "the shipping cost for cy is 30"],
            sleep(1.1),
            write_csv(CSV, "s,<= 1,6\nl,> 1,31\n"),
            loaded_program(P2),
            string_concat(P2, "\n% reloaded\n", P3),
            load_text(P3, Dir0, KB2),
            answers(KB2, three, shipping, As2),
            As2 == ["the shipping cost for ann is 6", "the shipping cost for bob is 31", "the shipping cost for cy is 31"]
        ),
        delete_directory_and_contents(Dir0)).

:- end_tests(decision_tables).

write_csv(File, Text) :-
    setup_call_cleanup(open(File, write, S), write(S, Text), close(S)).

loaded_program(P) :-
    shipping_program(" loaded from rates.csv, with first match", "", P0),
    P = P0.
