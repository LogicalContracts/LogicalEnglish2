/** <module> Services: call once, cache, attribute (semantic predicates over text)

    LE_extensions_proposal §3.6 and §4.1, docs/le_summary.md §17.6. Covers
    canonicalisation, the session cache, the persistent cache (hit, version
    refusal, warm cache with the service down), the HTTP backend against a
    live stub server, attribution in explanations and scoped proofs,
    materialise, the built-in semantic templates and the verifier.

    Run with:  swipl -q -g run_tests -t halt testing/test_services.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_services, []).

:- use_module(library(plunit)).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module('../le_kbs').
:- use_module('../le_services').

:- http_handler(root(test_services), stub_handler, [prefix]).

stub_handler(Request) :-
    memberchk(path(Path), Request),
    atomic_list_concat(Parts, '/', Path), last(Parts, Name),
    http_read_json_dict(Request, SReq),
    stub_service(Name, SReq, Reply),
    reply_json_dict(Reply).

program(Address, Extra, Text) :-
    format(string(Text), "the target language is: prolog.

the knowledge base semantic match includes these services:
    matcher at ~w as a semantic matcher.

the templates are:
    the category of *an item* is *a category*.
    the description of *an item* is *a text*; undefined.
    the best match of *a text* among *a list* is *a category*; via service matcher.
    *an item* is certified.

the knowledge base semantic match includes:

the category of an item is a category
    if the description of the item is a text
    and the best match of the text among [fruit, vehicle, tool] is the category.

an item is certified
    if the description of the item is a text
    and the best match of the text among [fruit, vehicle, tool] is a category
        according to service matcher.
~w
scenario one is:
    the description of x is \"a red bicycle with a basket\".
    the description of y is \"a red   bicycle with a basket\".
    the description of z is \"a ripe banana\".

query category is:
    the category of which item is which category.

query certified is:
    which item is certified.
", [Address, Extra]).

answers(KB, Scenario, Query, Answers) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A, ( query(SM, Query, I, _, _), canonical_string(I, A) ), Answers0),
    destroySession(SM),
    msort(Answers0, Answers).

answers_unknowns(KB, Scenario, Query, Pairs) :-
    createSession(KB, SM),
    setScenarion(SM, Scenario),
    findall(A-N, ( query(SM, Query, I, Us, _), canonical_string(I, A), length(Us, N) ), Pairs0),
    destroySession(SM),
    msort(Pairs0, Pairs).

why_literals(Why, Lits) :- findall(L, why_literal(Why, L), Lits).
why_literal(L0, L) :- is_list(L0), !, member(X, L0), why_literal(X, L).
why_literal(success(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).
why_literal(failure(_, _, LE, Cs), L) :- ( L = LE ; why_literal(Cs, L) ).

expected(["the category of x is vehicle", "the category of y is vehicle", "the category of z is fruit"]).

with_cache_dir(Goal) :-
    tmp_file(service_cache, Dir), make_directory(Dir),
    ( current_prolog_flag(le_service_cache_dir, Old) -> true ; Old = '' ),
    setup_call_cleanup(set_prolog_flag(le_service_cache_dir, Dir),
                       call(Goal, Dir),
                       ( set_prolog_flag(le_service_cache_dir, Old),
                         delete_directory_and_contents(Dir) )).

with_stub_server(Goal) :-
    http_server(http_dispatch, [port(Port)]),
    format(atom(URL), 'http://127.0.0.1:~w/test_services/matcher', [Port]),
    setup_call_cleanup(true, call(Goal, URL, Port), catch(http_stop_server(Port, []), _, true)).

:- begin_tests(services).

test(one_call_per_distinct_request) :-
    program('stub:matcher', "", P), load_text(P, KB),
    reset_stub_calls,
    answers(KB, one, category, As),
    expected(Ex), As == Ex,
    % x and y differ only in spacing: one canonical request; z is another.
    stub_calls(matcher, 2).

test(canonical_requests_ignore_list_order_and_spacing) :-
    le_services:canonical_request(m, 'stub:m', k, f, "t", ["a  b", [c, a, b], _], _, H1),
    le_services:canonical_request(m, 'stub:m', k, f, "t", ['a b', [b, c, a], _], _, H2),
    H1 == H2,
    le_services:canonical_request(m, 'stub:m', k, f, "t", ["a b", [c, a], _], _, H3),
    H3 \== H1.

test(answer_attributed_in_the_explanation) :-
    program('stub:matcher', "", P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, one),
    once(query(SM, category, _, _, Why)),
    destroySession(SM),
    why_literals(Why, Lits),
    memberchk("the best match of a red bicycle with a basket among [fruit vehicle tool] is vehicle, according to service matcher, because \"bicycle names a kind of vehicle\"", Lits).

test(scoped_proof_admits_the_service) :-
    program('stub:matcher', "", P), load_text(P, KB),
    answers(KB, one, certified, As),
    As == ["x is certified", "y is certified", "z is certified"],
    program('stub:matcher', "", P0),
    re_replace("according to service matcher"/g, "according to the landlord", P0, P1),
    load_text(P1, KB1),
    answers(KB1, one, certified, Bs),
    Bs == [].

test(unreachable_service_gives_a_conditional_answer) :-
    program('http://127.0.0.1:9/nothing', "", P), load_text(P, KB),
    answers_unknowns(KB, one, category, Pairs),
    Pairs = [_-1, _-1, _-1].

test(http_backend_against_a_live_stub) :-
    with_stub_server([URL, _Port]>>(
        program(URL, "", P), load_text(P, KB),
        reset_stub_calls,
        answers(KB, one, category, As),
        expected(Ex), As == Ex,
        stub_calls(matcher, 2) )).

test(persistent_cache_hit) :-
    with_cache_dir([Dir]>>(
        program('stub:matcher', "", P), load_text(P, KB),
        reset_stub_calls,
        answers(KB, one, category, _),
        stub_calls(matcher, 2),
        directory_files(Dir, Fs), include([F]>>sub_atom(F, _, _, 0, '.json'), Fs, Js),
        length(Js, 2),
        % a new session: answered from the persistent cache, no call
        answers(KB, one, category, As),
        expected(Ex), As == Ex,
        stub_calls(matcher, 2) )).

test(persistent_cache_refuses_another_version) :-
    with_cache_dir([Dir]>>(
        program('stub:matcher', "", P), load_text(P, KB),
        reset_stub_calls,
        answers(KB, one, category, _),
        directory_files(Dir, Fs), include([F]>>sub_atom(F, _, _, 0, '.json'), Fs, Js),
        forall(member(J, Js),
               ( directory_file_path(Dir, J, Path),
                 read_file_to_string(Path, S0, []),
                 re_replace("stub:matcher"/g, "another-model", S0, S1),
                 setup_call_cleanup(open(Path, write, O), write(O, S1), close(O)) )),
        answers(KB, one, category, _),
        stub_calls(matcher, 4) )).

test(warm_cache_answers_with_the_service_down) :-
    with_cache_dir([_Dir]>>(
        with_stub_server([URL, Port]>>(
            program(URL, "", P), load_text(P, KB),
            answers(KB, one, category, _),
            http_stop_server(Port, []),
            answers_unknowns(KB, one, category, Pairs),
            Pairs == ["the category of x is vehicle"-0, "the category of y is vehicle"-0,
                      "the category of z is fruit"-0] )))).

test(materialise_round_trip) :-
    program('stub:matcher', "", P), load_text(P, KB),
    createSession(KB, SM), setScenarion(SM, one),
    findall(_, query(SM, category, _, _, _), _),
    service_materialise(SM, KB, Lines),
    destroySession(SM),
    % x and y share one request but are two facts.
    length(Lines, 3),
    Lines = [L1|_],
    once(sub_string(L1, _, _, _, ", according to service matcher, as stated in cache at ")),
    % The materialised facts, in a program whose service is down, answer alone.
    atomic_list_concat(Lines, '\n    ', Facts),
    format(string(P2), "the target language is: prolog.

the templates are:
    the category of *an item* is *a category*.
    the description of *an item* is *a text*; undefined.
    the best match of *a text* among *a list* is *a category*; undefined.

the knowledge base materialised includes:

the category of an item is a category
    if the description of the item is a text
    and the best match of the text among [fruit, vehicle, tool] is the category.

scenario one is:
    the description of x is \"a red bicycle with a basket\".
    the description of z is \"a ripe banana\".
    ~w

query category is:
    the category of which item is which category.
", [Facts]),
    load_text(P2, KB2),
    answers(KB2, one, category, As),
    As == ["the category of x is vehicle", "the category of z is fruit"].

test(builtin_semantic_template_uses_the_matcher) :-
    load_text("the target language is: prolog.

the knowledge base k includes these services:
    matcher at stub:matcher as a semantic matcher.

the templates are:
    the kind of *an item* is *a kind*.
    the description of *an item* is *a text*; undefined.
    *a text* reads like *another text*.

the knowledge base k includes:
the kind of an item is a kind
    if the description of the item is a text
    and the best match of the text among [fruit, tool] is the kind.

scenario s is:
    the description of h is \"a heavy hammer\".

query q is:
    the kind of which item is which kind.
", KB),
    answers(KB, s, q, As),
    As == ["the kind of h is tool"].

test(undeclared_service_is_an_error) :-
    load_text("the target language is: prolog.

the templates are:
    *a text* matches *a category*; via service ghost.
    *an item* is described by *a text*; undefined.
    *an item* is in *a category*.

the knowledge base k includes:
an item is in a category if the item is described by a text and the text matches the category.
", KB),
    findall(T, KB:le_issue(error, T, _, _, _, _), Ts),
    memberchk(service_undeclared, Ts).

:- end_tests(services).
