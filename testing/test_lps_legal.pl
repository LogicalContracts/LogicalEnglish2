/** <module> The legal view of an LPS program (le_lps_legal.pl)

    An LE-for-LPS program's integrity constraints become one permission rule
    per action, its causal laws effect rules, its fluents scenario elements —
    an ordinary Prolog-target LE program whose queries run in the editor. The
    wording is the program's own (English morphology for a template that
    starts with its actor and a verb; fixed words otherwise); a constraint on
    two actions at once and an action nothing governs are said, not turned
    into permissions. Also the /leapi operation `legalView`.

    Run with:  swipl -q -g run_tests -t halt testing/test_lps_legal.pl
*/

:- module(test_lps_legal, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module('../le_kbs').
:- use_module('../le_lps_legal').
:- use_module('../le_writer').
:- use_module('../classic_web_api').

bank("the target language is: lps.

the maximum time is 4.

the actions are:
    *a sender* transfers *an amount* to *a recipient*; known as transfer.
    *a pauser* halts the bank; known as halt.
    *a caller* calls audit; known as audit.

the fluents are:
    the balance of *an account* is *an amount*; known as balance.
    the bank is halted; known as halted.
    the pauser of the bank is *an account*; known as pauser.

the knowledge base bank includes:

initially the balance of alice is 100.
initially the pauser of the bank is carol.

it must not be true that
    a sender transfers an amount to a recipient from a time to a second time
    and the balance of the sender is a second amount at a time
    and the second amount < the amount.

it must not be true that
    a sender transfers an amount to a recipient from a time to a second time
    and the bank is halted at a time.

it must not be true that
    a sender transfers an amount to a recipient from a time to a second time
    and the sender transfers a second amount to a second recipient from the time to the second time
    and the recipient is different from the second recipient.

it must not be true that
    a pauser halts the bank from a time to a second time
    and the pauser of the bank is an account at a time
    and the account is different from the pauser.

it must not be true that
    a pauser halts the bank from a time to a second time
    and it is not the case that the pauser of the bank is an account at a time.

when a sender transfers an amount to a recipient from a time to a second time
    and the balance of the recipient is a second amount at a time
then the balance of the recipient that is a third amount becomes third amount + amount.

when a sender transfers an amount to a recipient from a time to a second time
    and the balance of the sender is a second amount at a time
then the balance of the sender that is a third amount becomes third amount - amount.

when a pauser halts the bank from a time to a second time
then initiate the bank is halted.

scenario one is:
    alice transfers 30 to bob from 1 to 2.
    carol halts the bank from 2 to 3.
").

view(Options, Text) :-
    bank(Doc),
    legal_view_text(Doc, Options, Text, Issues),
    assertion(\+ member(issue(error, _, _), Issues)).

has(Text, Sub) :- sub_string(Text, _, _, _, Sub).

:- begin_tests(lps_legal_wording).

wording(Template, May, Gerund) :-
    b_setval(le_lps_legal_lang, en),
    le_lps_legal:permission_text(Template, May),
    (   le_lps_legal:gerund_text(Template, Gerund) -> true ; Gerund = none ).

test(third_person_verbs) :-
    wording("*a sender* transfers *an amount* to *a recipient*", M1, G1),
    assertion(M1 == "*a sender* may transfer *an amount* to *a recipient*"),
    assertion(G1 == "*a sender* transferring *an amount* to *a recipient*"),
    wording("*a spender* moves *an amount*", _, G2), assertion(G2 == "*a spender* moving *an amount*"),
    wording("*a pauser* pauses the token", M3, G3),
    assertion(M3 == "*a pauser* may pause the token"), assertion(G3 == "*a pauser* pausing the token"),
    wording("*a guard* stops *a car*", _, G4), assertion(G4 == "*a guard* stopping *a car*"),
    wording("*a porter* carries *a bag*", M5, G5),
    assertion(M5 == "*a porter* may carry *a bag*"), assertion(G5 == "*a porter* carrying *a bag*"),
    wording("*a clerk* pushes *a form*", M6, _), assertion(M6 == "*a clerk* may push *a form*"),
    wording("*an object* is carried to *a place*", M7, G7),
    assertion(M7 == "*an object* may be carried to *a place*"),
    assertion(G7 == "*an object* being carried to *a place*").

%   A template that does not start with its actor and a verb takes the fixed
%   wording: no morphology is attempted.
test(fixed_wording) :-
    wording("farmer rows from *a first place* to *a second place*", M, G),
    assertion(M == "it is allowed that farmer rows from *a first place* to *a second place*"),
    assertion(G == none).

%   Another language: the fixed words of i18n/writer_words.csv.
test(other_language) :-
    b_setval(le_lps_legal_lang, pt),
    le_lps_legal:permission_text("*um remetente* transfere *um montante*", M),
    b_setval(le_lps_legal_lang, en),
    assertion(M == "é permitido que *um remetente* transfere *um montante*").

:- end_tests(lps_legal_wording).

:- begin_tests(lps_legal_view).

test(permissions_and_effects) :-
    view([], T),
    assertion(has(T, "the target language is: prolog.")),
    assertion(has(T, "the balance of *an account* is *an amount*; scenario element.")),
    assertion(has(T, "*a sender* may transfer *an amount* to *a recipient*.")),
    %  a role check becomes the positive condition naming the caller
    assertion(has(T, "a pauser may halt the bank if\n    the pauser of the bank is the pauser.")),
    assertion(has(T, "*a pauser* halting the bank results in the bank being halted.")),
    assertion(has(T, "results in the balance of *an account* being *an amount*")),
    %  the program's calls are the questions
    assertion(has(T, "query may_call_1 is:\n    alice may transfer 30 to bob.")),
    assertion(has(T, "which minimal change to the scenario makes it the case that")),
    assertion(has(T, "scenario start is:\n    the balance of alice is 100.")).

%   Permissions read positively: a negated comparison is the opposite one,
%   and a value the constraint reads is quantified, not double-negated.
test(permissions_read_positively) :-
    view([], T),
    assertion(\+ has(T, "it is not the case that it is not the case that")),
    assertion(has(T, "for all cases in which\n        the balance of the sender is an amount")),
    assertion(has(T, ">= N")),
    assertion(has(T, "it is not the case that the bank is halted")).

%   A constraint on two actions at once is not a permission: left out, said.
test(concurrency_constraint_said) :-
    view([], T),
    assertion(has(T, "(a constraint on this action happening together with another is left out")),
    assertion(\+ has(T, "transfers")).

%   An action no constraint or law is about gets no permission rule.
test(ungoverned_action_said) :-
    view([], T),
    assertion(has(T, "% nothing in the program governs audit")),
    assertion(\+ has(T, "may call audit")).

%   The view runs: in a state the caller's scenario gives, "may <call>?"
%   answers as the constraints say.
test(view_answers) :-
    bank(Doc), le_kbs:load_text(Doc, KB),
    lps_program_items(KB, Items),
    call_queries(Items, [transfer(alice, 30, bob), transfer(alice, 300, bob), halt(bob)], [], Qs),
    Scenario = scenario(rich, [fact(balance(alice, 100)), fact(pauser(carol)),
                               expects(may_call_1, [may_transfer(alice, 30, bob)]),
                               expects(may_call_2, []),
                               expects(may_call_3, [])], []),
    Halted = scenario(halted, [fact(balance(alice, 100)), fact(halted),
                               expects(may_call_1, [])], []),
    legal_view_ir(Items, [kb(bank_view), scenarios([Scenario, Halted]), queries(Qs)], IR),
    le_write(IR, Text),
    tmp_file(legal, F0), atom_concat(F0, '.le', F),
    setup_call_cleanup(open(F, write, S), write(S, Text), close(S)),
    le_kbs:runTestsFor(F, test_file(_, Rs)),
    assertion(Rs \== []),
    assertion(forall(member(R, Rs), R = pass(_, _))).

test(not_an_lps_program, [fail]) :-
    legal_view_text("the target language is: prolog.\n\nthe templates are:\n    *a person* is happy.\n\nthe knowledge base k includes:\n\nalice is happy.\n", [], _, _).

%   The comment above a permission rule names the action in its own words.
test(permission_comment_in_the_actions_words) :-
    view([], T),
    assertion(has(T, "% who may halt the bank: none of the action's integrity constraints applies")).

%   With a run of the program (the state at each time, the events that
%   happened), the scenarios are the states before each call of the
%   program's scenario, and the expectations say what the run did: the view
%   is checked against the program by running its own tests.
test(run_scenarios_and_expectations) :-
    States = [0-[balance(alice, 100), pauser(carol)], 1-[balance(alice, 100), pauser(carol)],
              2-[balance(alice, 70), balance(bob, 30), pauser(carol)],
              3-[balance(alice, 70), balance(bob, 30), pauser(carol), halted]],
    Happened = [2-[transfer(alice, 30, bob)], 3-[halt(carol)]],
    view([run(States, Happened)], T),
    assertion(has(T, "scenario before_call_1 is:")),
    assertion(has(T, "% the state before call 1, transfer(alice,30,bob) (accepted in the program's run)")),
    assertion(has(T, "may_call_1 expects answers [\"alice may transfer 30 to bob\"].")),
    assertion(has(T, "scenario before_call_2 is:")),
    assertion(has(T, "Scenario before_call_N is the program's state just before")),
    assertion(\+ has(T, "scenario start is:")),
    le_kbs:load_text(T, KB),
    findall(test(Q, S, A, U), KB:le_expected(Q, S, A, U), Ts),
    assertion(Ts \== []),
    maplist(le_kbs:run_one_test(KB), Ts, Rs),
    assertion(forall(member(R, Rs), R = pass(_, _))).

%   A call the run refused is expected not to be permitted, with its flip query.
test(run_refused_call) :-
    States = [0-[balance(alice, 100), pauser(carol)], 2-[balance(alice, 100), pauser(carol)]],
    Happened = [],
    view([run(States, Happened)], T),
    assertion(has(T, "(refused in the program's run)")),
    assertion(has(T, "may_call_1 expects answers [].")),
    assertion(has(T, "query flip_call_1 is:")).

%   A program with events and no actions: nobody needs permission, and no
%   empty section is written.
test(no_actions_said) :-
    Doc = "the target language is: lps.\n\nthe maximum time is 3.\n\nthe events are:\n    *a person* arrives.\n\nthe fluents are:\n    *a person* is present.\n\nthe knowledge base k includes:\n\nwhen a person arrives from a time to a second time\nthen the person is present.\n",
    legal_view_text(Doc, [], T, _),
    assertion(has(T, "declares no actions")),
    assertion(\+ has(T, "section permissions is:")),
    assertion(\+ has(T, "section effects is:")).

:- end_tests(lps_legal_view).

:- begin_tests(lps_legal_api).

test(operation) :-
    bank(Doc),
    classic_web_api:handle_legal_view(_{le: Doc}, R),
    get_dict(document, R, D),
    assertion(sub_string(D, _, _, _, "may transfer")),
    assertion(R.name == 'bank').

test(operation_refuses_prolog) :-
    classic_web_api:handle_legal_view(_{le: "the target language is: prolog.\n\nthe knowledge base k includes:\n\nalice is happy.\n"}, R),
    assertion(get_dict(error, R, _)).

:- end_tests(lps_legal_api).
