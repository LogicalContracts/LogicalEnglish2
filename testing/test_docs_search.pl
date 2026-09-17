/*  The documentation's search on the server (le_docs_search.pl) and how the
    assistants use it: a question gets the sections that answer it, its links
    are the viewer's own anchors, and the Light assistant's `docs` action
    answers with them.
*/
:- use_module('../le_docs_search').
:- use_module('../le_assistant').
:- use_module('../le_assistant_light').

docs_root(Root) :-
    module_property(le_docs_search, file(F)),
    file_directory_name(F, Dir),
    directory_file_path(Dir, 'docs/user', Root).

:- begin_tests(docs_search).

%   A question in plain words finds the section about it, first.
test(question_finds_its_section) :-
    docs_root(Root),
    docs_search(Root, "How do I write a decision table?", [], [First|_]),
    assertion(sub_string(First.url, _, _, _, "reference/language#173-decision-tables")).

test(unknowns_despite_the_question_words) :-
    docs_root(Root),
    docs_search(Root, "how do I say that something is unknown?", [], [First|_]),
    assertion(sub_string(First.section, _, _, _, "Unknowns")).

%   A quoted phrase must occur; no section is listed twice, nor more than
%   two of one document.
test(phrase_and_no_duplicates) :-
    docs_root(Root),
    docs_search(Root, "\"scenario variations\"", [limit(10)], Hits),
    assertion(Hits \== []),
    findall(U, ( member(H, Hits), U = H.url ), Us),
    sort(Us, Set), length(Us, N), length(Set, N),
    findall(P, ( member(H, Hits), split_string(H.url, "#", "", [P|_]) ), Ps),
    msort(Ps, Sorted), clumped(Sorted, Counts),
    assertion(forall(member(_-C, Counts), C =< 2)),
    assertion(forall(( member(H, Hits), get_dict(section, H, S) ), sub_string(S, _, _, _, "Scenario Variations"))).

%   Nothing to look for: no hits, and no material for the prompt.
test(greeting_finds_nothing) :-
    docs_root(Root),
    docs_search(Root, "hello there", [], Hits),
    assertion(Hits == []),
    assistant_docs_material("hello there", Block),
    assertion(Block == "").

%   The anchors are the viewer's (viewer.html's slug): punctuation out, each
%   space a dash, a trailing space kept as one.
test(anchors_as_the_viewer_makes_them) :-
    le_docs_search:slug(le2, "16. Example 4 — the tea shop: numbers, cascades, tables, dates", S1),
    assertion(S1 == "16-example-4--the-tea-shop-numbers-cascades-tables-dates"),
    le_docs_search:slug(le2, "3.3 Integrity constraints: it must not be true that …", S2),
    assertion(S2 == "33-integrity-constraints-it-must-not-be-true-that-").

test(material_says_how_to_cite) :-
    assistant_docs_material("How do I write a decision table?", Block),
    assertion(sub_string(Block, _, _, _, "(/docs/user/reference/language#173-decision-tables)")),
    assertion(sub_string(Block, _, _, _, "at most three")).

%   The Light loop: a model that asks `docs` gets the sections, and its
%   `finish` is the answer, the program unchanged.
test(light_loop_docs_action, [setup(mock_model), cleanup(unwrap_predicate(llm_client:llm_request/4, docs_test))]) :-
    JobID = "job_docs_test",
    asserta(le_assistant:assistant_job_status(JobID, running)),
    Program = "the target language is: prolog.\n",
    once(run_light_assistant(JobID, "What is an otherwise cascade?", Program, "docs-test-model",
                             _{openai: "test-key"}, [], 4, Explanation, Final)),
    retractall(le_assistant:assistant_job_status(JobID, _)),
    assertion(Final == Program),
    assertion(sub_string(Explanation, _, _, _, "/docs/user/reference/language#172-otherwise-cascades")),
    nb_getval(docs_test_seen, Seen),
    assertion(sub_string(Seen, _, _, _, "Sections of the documentation for \"otherwise cascade\"")),
    assertion(sub_string(Seen, _, _, _, "Documentation that may help")).

:- end_tests(docs_search).

%   A model that searches first, then answers citing the link it was given.
mock_model :-
    nb_setval(docs_test_seen, ""),
    wrap_predicate(llm_client:llm_request(_Model, Messages, Reply, _Opts), docs_test, _Wrapped,
                   docs_test_reply(Messages, Reply)).

docs_test_reply(Messages, Reply) :-
    last(Messages, Last),
    Messages = [System|_],
    (   get_dict(role, Last, user), sub_string(Last.content, _, _, _, "Sections of the documentation")
    ->  string_concat(System.content, Last.content, Seen),
        nb_setval(docs_test_seen, Seen),
        sub_string(Last.content, B, _, _, "(/docs/user/"),
        sub_string(Last.content, B, _, 0, After),
        sub_string(After, 1, _, _, Rest), sub_string(Rest, E, _, _, ")"), !,
        sub_string(Rest, 0, E, _, Url),
        format(string(Reply), "{\"action\": \"finish\", \"explanation\": \"It chooses the first alternative that applies. See [otherwise cascades](~w).\"}", [Url])
    ;   Reply = "{\"action\": \"docs\", \"query\": \"otherwise cascade\"}"
    ).
