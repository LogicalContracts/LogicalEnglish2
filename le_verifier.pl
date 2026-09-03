/** <module> Logical English Verifier
    
    This module performs load-time verifications on a Logical English knowledge base.
    It checks for missing templates, undefined predicates, untested predicates,
    rules without variables, and other potential issues.
*/

:- module(le_verifier, [verify/2, verify/3, print_issue/1, is_intensional/3, find_in_body/2,
                        unmatched_sentences/3]).

:- use_module(le_kbs, [is_system_predicate/1, run_one_test/3, canonical_string/2, ensure_kb_language/1]).
:- use_module(le_i18n).
:- use_module(le_system_templates, [le_system_template/1]).
:- use_module(le_scasp, []).

%!  verify(+KBModule:atom, -Issues:list) is det.
%
%   Performs load-time verifications on a Logical English knowledge base.
verify(KB, Issues) :-
    verify(KB, [], Issues).

%!  verify(+KBModule:atom, +Options:list, -Issues:list) is det.
%
%   As verify/2. With Option skip_tests, the expected-answer tests embedded in
%   the KB are not run (the failed_test check is skipped): running them means
%   answering every test query, which can take tens of seconds on large KBs —
%   far too slow for callers that only need the cheap static checks, such as
%   the example-listing endpoints.
verify(KB, Options, Issues) :-
    ensure_kb_language(KB),
    ( setof(Issue, check_issue(KB, Options, Issue), Issues) -> true; Issues = []).

check_issue(KB, _, Issue) :- missing_template(KB, Issue).
check_issue(KB, _, Issue) :- undefined_predicate(KB, Issue).
check_issue(KB, _, Issue) :- suspicious_is_a(KB, Issue).
check_issue(KB, _, Issue) :- suspicious_is(KB, Issue).
check_issue(KB, _, Issue) :- defined_scenario_element(KB, Issue).
check_issue(KB, _, Issue) :- untested_predicate(KB, Issue).
check_issue(KB, _, Issue) :- rule_without_variables(KB, Issue).
check_issue(KB, _, Issue) :- facts_rules_ratio(KB, Issue).
check_issue(KB, Options, Issue) :- \+ memberchk(skip_tests, Options), failed_test(KB, Issue).
check_issue(KB, _, Issue) :- redefined_system_template(KB, Issue).
check_issue(KB, _, Issue) :- single_variable_fact(KB, Issue).
check_issue(KB, _, Issue) :- single_variable_scenario_fact(KB, Issue).
check_issue(KB, _, Issue) :- unmarked_meta_template(KB, Issue).
check_issue(KB, _, Issue) :- non_stratified(KB, Issue).
check_issue(KB, _, Issue) :- unused_template(KB, Issue).
check_issue(KB, _, Issue) :- unconsumed_facts(KB, Issue).

%!  unmatched_sentences(+KB:atom, +Scope, -Occurrences:list) is det.
%
%   The sentences of KB's scenarios and queries that matched NO declared
%   template. The parser does not reject them and does not warn: it parks them
%   in the loaded knowledge base as `unknown_template(Tokens, Start, End)`
%   terms, so a scenario fact or a query condition that says nothing at all
%   reaches the reasoner, decides nothing, and is reported by nobody.
%
%   Scope selects what to look at: `all`, `scenario(Name)` or `query(Name)`.
%   Occurrences are `unmatched(Where, Start, Text)`, Where being scenario(Name)
%   or query(Name), Start the character offset in the source and Text the words
%   as the author wrote them.
%
%   Deliberately NOT one of the check_issue/3 clauses of verify/2: turning this
%   into a load-time issue would change the diagnostics of every existing
%   document (and there are examples in this repository that would light up).
%   The LLM-facing callers — the Contract Assistant and the English→Logical
%   English conversion — ask for it explicitly, because for machine-written text
%   it is the single most valuable check there is: it is exactly how a fragment
%   that means nothing passes for a fragment that verifies clean.
unmatched_sentences(KB, Scope, Occurrences) :-
    findall(unmatched(scenario(Name), Start, Text),
            ( scope_admits(Scope, scenario(Name)),
              current_predicate(KB:scenario/2), KB:scenario(Name, Facts),
              unknown_template_in(Facts, Start, Text) ),
            Scenarios),
    findall(unmatched(query(Name), Start, Text),
            ( scope_admits(Scope, query(Name)),
              current_predicate(KB:query_info/3), KB:query_info(Name, Goal, _),
              unknown_template_in(Goal, Start, Text) ),
            Queries),
    append(Scenarios, Queries, All),
    sort(All, Occurrences).

scope_admits(all, _) :- !.
scope_admits(Where, Where).

%   A plain sub_term/2 walk is WRONG here: an unbound variable in a query goal
%   unifies with the pattern, so every query with a variable in it reported an
%   unmatched sentence at an unbound offset. Recurse explicitly and never match
%   through a variable.
unknown_template_in(Term, Start, Text) :-
    nonvar(Term),
    Term = unknown_template(Tokens, Start, _End),
    integer(Start),
    unmatched_tokens_text(Tokens, Text).
unknown_template_in(Term, Start, Text) :-
    compound(Term),
    \+ ( nonvar(Term), Term = unknown_template(_, _, _) ),
    arg(_, Term, Arg),
    unknown_template_in(Arg, Start, Text).

unmatched_tokens_text(Tokens, Text) :-
    findall(W, ( member(T, Tokens), nonvar(T), T = word(W, _) ), Words),
    atomic_list_concat(Words, ' ', Atom),
    atom_string(Atom, Text).

% --- Stratification (loops through negation) ---
% Reuse the s(CASP) dependency-graph analysis: a cycle through a `not` edge means
% the program is not stratified. Advisory — s(CASP) handles such programs under
% stable-model semantics, so we point the user at that engine rather than error.
non_stratified(KB, issue(non_stratified, Description, "", Start, End)) :-
    catch(le_scasp:le_scasp_stratification(KB, Cycles), _, fail),
    Cycles \== [],
    member(Cycle, Cycles),
    cycle_names(Cycle, NamesAtom),
    le_i18n:le_msg(non_stratified_desc, [name-NamesAtom], Description),
    ( cycle_source(KB, Cycle, Start, End) -> true ; Start = 0, End = 0 ).

% cycle_names(+Cycle:list(F/A), -Atom): a readable "p, q and r" list of the
% predicate names in the negation cycle.
cycle_names(Cycle, Atom) :-
    findall(N, ( member(F/_, Cycle), N = F ), Ns0),
    sort(Ns0, Ns),
    atomic_list_concat(Ns, ', ', Atom).

% cycle_source(+KB, +Cycle, -Start, -End): the source span of a rule defining one
% of the cycle's predicates, so the issue anchors into the editor.
cycle_source(KB, Cycle, Start, End) :-
    member(F/A, Cycle),
    functor(Head, F, A),
    KB:le_source_info(Ref, Start, End, _),
    clause(KB:Head, Body, Ref), Body \== true, !.

% --- 1. Missing template ---
missing_template(KB, issue(missing_template, Description, Fix, Start, End)) :-
    (   current_predicate(KB:unknown_template/1), clause(KB:unknown_template(Tokens), _, Ref)
    ;   current_predicate(KB:F/A), functor(Head, F, A), le_kbs:kb_own_predicate(KB, Head),
        clause(KB:Head, Body, Ref), find_in_body(Body, unknown_template(Tokens))
    ),
    le_grammar:reconstruct_name(Tokens, Name),
    le_i18n:le_msg(missing_template_desc, [name-Name], Description),
    tokens_to_template_hypothesis(Tokens, Hypothesis),
    format(atom(Fix), "~w.", [Hypothesis]),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

tokens_to_template_hypothesis(Tokens, Hypothesis) :-
    group_hypothesis_parts(Tokens, Grouped),
    maplist(hyp_part_to_string, Grouped, Strings),
    atomic_list_concat(Strings, ' ', Hypothesis).

group_hypothesis_parts([], []).
group_hypothesis_parts([var(Words, _)|Rest], [var(Words)|Grouped]) :- !,
    group_hypothesis_parts(Rest, Grouped).
% Article + ID -> *article ID*
group_hypothesis_parts([word(Art, _), word(ID, _)|Rest], [var([LowArt, ID])|Grouped]) :-
    le_grammar:is_article(Art),
    le_grammar:is_id(ID), !,
    downcase_atom(Art, LowArt),
    group_hypothesis_parts(Rest, Grouped).
% Just an ID -> *ID*
group_hypothesis_parts([word(ID, _)|Rest], [var([ID])|Grouped]) :-
    le_grammar:is_id(ID), !,
    group_hypothesis_parts(Rest, Grouped).
% Article + Word -> *article Word* 
% Only if Word is followed by a stop word or end of tokens
group_hypothesis_parts([word(Art, _), word(W, _)|Rest], [var([LowArt, W])|Grouped]) :-
    le_grammar:is_article(Art),
    \+ is_stop_word(W),
    (   Rest = [] 
    ;   Rest = [T|_], le_grammar:extract_simple_word(T, NextW), is_stop_word(NextW)
    ), !,
    downcase_atom(Art, LowArt),
    group_hypothesis_parts(Rest, Grouped).
% Proper name -> *a Name*
group_hypothesis_parts([word(W, _)|Rest], [var([a, W])|Grouped]) :-
    le_grammar:is_proper_name_atom(W),
    \+ le_grammar:is_article(W), !,
    group_hypothesis_parts(Rest, Grouped).
% Regular word
group_hypothesis_parts([T|Rest], [word(W)|Grouped]) :-
    le_grammar:extract_simple_word(T, W),
    group_hypothesis_parts(Rest, Grouped).

is_stop_word(W) :- le_grammar:is_reserved(W).
is_stop_word(W) :- le_grammar:is_ignorable(W).
is_stop_word(W) :- le_grammar:is_punct(W).

hyp_part_to_string(var(Words), String) :-
    atomic_list_concat(Words, ' ', Name),
    format(atom(String), '*~w*', [Name]).
hyp_part_to_string(word(W), W).

% --- 2. Undefined predicate ---
undefined_predicate(KB, issue(undefined_predicate, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A), functor(Head, F, A),
    \+ is_system_predicate(F/A),
    \+ predicate_property(KB:Head, imported_from(_)),
    clause(KB:Head, Body, Ref),
    find_in_body(Body, Literal),
    Literal \= unknown_template(_),
    \+ is_defined(KB, Literal),
    \+ is_built_in_literal(Literal),
    functor(Literal, FL, AL),
    % Suppress for predicates declared as scenario elements — those are
    % intentionally undefined in the KB; they live only in scenarios.
    \+ is_scenario_element_functor(KB, FL, AL),
    le_i18n:le_msg(undefined_predicate_desc, [functor-FL, arity-AL], Description),
    le_i18n:le_msg(undefined_predicate_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% --- 2a. Suspicious "is a" (predicate absorbed into a constant type) ---
% The generic "*X* is a *Y*" template matches almost any "... is ..." sentence,
% greedily absorbing everything after "is" into the constant type Y. So a rule
% head or condition whose intended template was never declared (e.g. "a vehicle
% is allowed to park in a parking zone at a time") parses silently into a bogus
% is_a(_, 'allowed to park in a parking zone at a time') instead of being flagged
% as a missing template. We detect the tell-tale sign: an is-a literal whose type
% is a multi-word *constant* containing connective words (articles, prepositions,
% conjunctions) that no genuine type name would contain.
suspicious_is_a(KB, issue(suspicious_is_a, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A),
    functor(Head, F, A),
    le_kbs:kb_own_predicate(KB, Head),
    clause(KB:Head, Body, Ref),
    ( Lit = Head ; find_in_body(Body, Lit) ),
    nonvar(Lit), Lit = is_a(_, Type),
    suspicious_type_phrase(Type, Phrase),
    le_i18n:le_msg(suspicious_is_a_desc, [phrase-Phrase], Description),
    le_i18n:le_msg(suspicious_is_a_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% --- 2a-bis. Suspicious "is" (predicate absorbed into a constant value) ---
% The same trap as suspicious_is_a, one template over. The generic "*X* is *Y*"
% fallback (le_is/2) is tried last by parse_literal_real/7, so any "... is ..."
% sentence whose intended template was never matched lands there instead of
% being reported as a missing template — and a single differing word is enough
% to miss. "the loss is not part of another claim different from the single
% claim", against a template declared as "... is not part of an OTHER claim
% ...", compiles to le_is(Loss, 'not part of another claim different from the
% single claim'): a goal that can never succeed, silently making the enclosing
% rule unprovable. Same tell-tale sign as the is-a case: a multi-word constant
% full of connectives is a swallowed predicate, not a value.
suspicious_is(KB, issue(suspicious_is, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A),
    functor(Head, F, A),
    le_kbs:kb_own_predicate(KB, Head),
    clause(KB:Head, Body, Ref),
    ( Lit = Head ; find_in_body(Body, Lit) ),
    nonvar(Lit), Lit = le_is(_, Value),
    suspicious_type_phrase(Value, Phrase),
    le_i18n:le_msg(suspicious_is_desc, [phrase-Phrase], Description),
    le_i18n:le_msg(suspicious_is_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% suspicious_type_phrase(+Type, -Phrase): Type is a constant (atom/string) made of
% at least three words, one of which is a connective — i.e. it looks like an
% absorbed predicate rather than a type name.
suspicious_type_phrase(Type, Phrase) :-
    ( atom(Type) -> Phrase = Type ; string(Type) -> atom_string(Phrase, Type) ; fail ),
    atomic_list_concat(Words, ' ', Phrase),
    length(Words, N), N >= 3,
    member(W, Words), W \== '', downcase_atom(W, WL), connective_word(WL), !.

connective_word(W) :-
    le_i18n:class_member(connective_heuristic, W).

% --- 2b. Defined scenario element ---
% Fires when a predicate declared 'undefined' (scenario element) has a fact or
% rule head in the knowledge base. Scenario facts (inside a scenario section)
% are stored in scenario/2, not as direct KB clauses, so they are not caught —
% only genuine KB-level facts and rule heads trigger this.
defined_scenario_element(KB, issue(defined_scenario_element, Description, Fix, Start, End)) :-
    is_scenario_element_functor(KB, F, A),
    functor(Head, F, A),
    current_predicate(KB:F/A),
    le_kbs:kb_own_predicate(KB, Head),
    clause(KB:Head, _, Ref),
    le_i18n:le_msg(defined_scenario_element_desc, [functor-F, arity-A], Description),
    le_i18n:le_msg(defined_scenario_element_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

%!  is_scenario_element_functor(+KB, ?F, ?A) is nondet.
%
%   True when F/A corresponds to a template declared 'undefined' (scenario
%   element) in KB. Checks the stored le_dict 7-arg form.
is_scenario_element_functor(KB, F, A) :-
    current_predicate(KB:le_dict/1),
    clause(KB:le_dict(dict([F|Args], _, _, _, _, _, Unknown)), true),
    Unknown == scenario_element,
    length(Args, A).

% find_in_body(+Body, -Literal)
% Recursively finds literals in a rule body.
% WARNING: This logic is dependent on the structure of solve_real/8 in reasoner.pl
find_in_body(prolog_call(_), _) :- !, fail.
find_in_body(le_at(G, _, _), L) :- !, find_in_body(G, L).
find_in_body((A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(and(A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body((A ; B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(or(A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(not(B), L) :- !, find_in_body(B, L).
find_in_body(forall(A, B), L) :- !, (find_in_body(A, L) ; find_in_body(B, L)).
find_in_body(sum(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(count(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(min(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(max(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(average(_, G, _), L) :- !, find_in_body(G, L).
find_in_body(true, _) :- !, fail.
find_in_body(fail, _) :- !, fail.
find_in_body(unknown_tokens(_), _) :- !, fail.
find_in_body(L, L).

is_defined(KB, Literal) :-
    catch(is_defined_real(KB, Literal), _, fail).

is_defined_real(KB, Literal) :-
    functor(Literal, F, A),
    (   Literal = is_a(_, _) -> true
    ;   memberchk(F/A, [and/2, or/2, not/1, forall/2, true/0, fail/0, sum/3, count/3, min/3, max/3, average/3]) -> true
    ;   memberchk(F/A, [le_is/2, le_equal_to/2, le_not_equal_to/2, le_assign/2, le_ge/2, le_le/2, le_gt/2, le_lt/2, le_known/1, le_is_in/2, le_type_check/2]) -> true
    ;   (F == says_that, A == 2) -> true
    ;   safe_clause(KB, Literal) -> true
    ;   safe_scenario_fact(KB, F, A) -> true
    ;   clause(KB:le_unknown(Literal), _) -> true
    ;   fail
    ).

safe_clause(KB, Literal) :-
    functor(Literal, F, A),
    current_predicate(KB:F/A),
    le_kbs:kb_own_predicate(KB, Literal),
    clause(KB:Literal, _).

safe_scenario_fact(KB, F, A) :-
    current_predicate(KB:scenario/2),
    clause(KB:scenario(_, Facts), _),
    member(FactItem, Facts),
    ( FactItem = fact_with_source(Fact, _, _) -> true ; Fact = FactItem ),
    functor(Fact, F, A).

is_built_in_literal(L) :- reasoner:is_built_in(L).
is_built_in_literal(says_that(_, _)).

% --- 3. Untested predicate ---
%   Reported AT the first rule head that defines the predicate (these are
%   intensional by construction, so there always is one) and named by its
%   Logical English template, not by the Prolog functor/arity the reader never
%   wrote.
untested_predicate(KB, issue(untested_predicate, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A),
    functor(G, F, A),
    \+ is_system_predicate(F/A),
    \+ reasoner:is_built_in(G),
    \+ predicate_property(KB:G, imported_from(_)),
    is_intensional(KB, F, A),
    \+ is_reachable_from_query(KB, F, A),
    predicate_le_label(KB, F, A, Label),
    first_rule_source(KB, F, A, Start, End),
    le_i18n:le_msg(untested_predicate_desc, [template-Label], Description),
    le_i18n:le_msg(untested_predicate_fix, [], Fix).

%!  predicate_le_label(+KB, +F, +A, -Label) is det.
%
%   The predicate as the author wrote it — its template, with the argument
%   places starred (`*a claim* is covered under *a section*`). Falls back to
%   functor/arity when no template can be found (imported or system predicates).
predicate_le_label(KB, F, A, Label) :-
    (   le_kbs:template_of(KB, F, A, _Dict, Label0)
    ->  Label = Label0
    ;   format(string(Label), "~w/~w", [F, A])
    ).

%!  first_rule_source(+KB, +F, +A, -Start, -End) is det.
first_rule_source(KB, F, A, Start, End) :-
    functor(Head, F, A),
    (   le_kbs:kb_own_predicate(KB, Head),
        clause(KB:Head, _, Ref),
        clause(KB:le_source_info(Ref, Start0, End0, _), true)
    ->  Start = Start0, End = End0
    ;   Start = 0, End = 0
    ).

is_intensional(KB, F, A) :-
    functor(G, F, A),
    le_kbs:kb_own_predicate(KB, G),
    KB:clause(G, Body),
    Body \== true, !.

% --- 3b. Unused template ---
%
% A template the program declares but never uses anywhere — no rule head, no
% rule condition, no fact, no scenario fact, no query. It is dead vocabulary:
% it costs the reader attention, it is never type-checked against a use, and
% (when marked `undefined`) it invites a scenario that will never be read.
% Generated programs are especially prone to it: a drafting model invents leaf
% classifications like `*a cost* is a cost; undefined.` that no rule consults.
unused_template(KB, issue(unused_template, Description, Fix, Start, End)) :-
    le_kbs:template_of(KB, F, A, Dict, Label),
    \+ template_used(KB, F, A),
    le_i18n:le_msg(unused_template_desc, [template-Label], Description),
    unused_template_fix(KB, Label, Fix),
    template_source(KB, Dict, Start, End).

%!  unused_template_fix(+KB, +Label, -Fix) is det.
%
%   "Never used" is easy to disbelieve when the program is full of sentences
%   that LOOK like uses. They usually belong to a LONGER template declared in
%   the same program — `*a claim* is excluded from *a section*` reads as unused
%   while a dozen `*a claim* is excluded from the employers liability section
%   for ...` templates carry all the traffic, because the parser matches the
%   longest template. Say so, and name one, or the reader hunts a phantom bug.
unused_template_fix(KB, Label, Fix) :-
    (   shadowing_templates(KB, Label, [Example|Rest])
    ->  length(Rest, N0), N is N0 + 1,
        le_i18n:le_msg(unused_template_shadowed_fix,
                       [count-N, example-Example], Fix)
    ;   le_i18n:le_msg(unused_template_fix, [], Fix)
    ).

%!  shadowing_templates(+KB, +Label, -Labels) is det.
%
%   The USED templates that open with the same words as this one — the ones the
%   sentences the reader is looking at actually match. Shortest first, so the
%   example shown is the one closest to the template being explained.
shadowing_templates(KB, Label, Labels) :-
    template_prefix(Label, Prefix),
    Prefix \== "",
    findall(Len-Other,
            ( le_kbs:template_of(KB, OF, OA, _, Other),
              Other \== Label,
              template_used(KB, OF, OA),
              sub_string(Other, 0, _, _, Prefix),
              string_length(Other, Len) ),
            Pairs),
    sort(Pairs, Sorted),
    findall(L, member(_-L, Sorted), Labels),
    Labels \== [].

% What a template commits to before its SECOND argument place — the words a
% longer template has to repeat to shadow it.
% `*claim* is excluded from *section*` -> "*claim* is excluded from ".
% A template with fewer than two arguments commits to all of itself.
template_prefix(Label, Prefix) :-
    findall(P, sub_string(Label, P, 1, _, "*"), Stars),
    (   nth0(2, Stars, Third)
    ->  sub_string(Label, 0, Third, _, Prefix)
    ;   Prefix = Label
    ).

%!  template_used(+KB, +F, +A) is semidet.
%
%   Anywhere at all: as the head of a rule or fact, inside any rule body,
%   inside a scenario's facts, or inside a query.
template_used(KB, F, A) :-
    functor(Head, F, A),
    current_predicate(KB:F/A),
    le_kbs:kb_own_predicate(KB, Head),
    clause(KB:Head, _), !.
template_used(KB, F, A) :-
    current_predicate(KB:Other/OA),
    \+ is_system_predicate(Other/OA),
    functor(H, Other, OA),
    le_kbs:kb_own_predicate(KB, H),
    clause(KB:H, Body),
    find_in_body(Body, Literal),
    functor(Literal, F, A), !.
%   Used by an LPS sentence. An `lps`-target program's rules are not Prolog
%   clauses — they are le_lps_item/3 payloads handed to the LPS2 engine — so
%   the clause-walking cases above find nothing and every template in a
%   perfectly ordinary LPS program is reported as dead vocabulary.
template_used(KB, F, A) :-
    current_predicate(KB:le_lps_item/3),
    KB:le_lps_item(_, Payload, _),
    contains_literal(Payload, F, A), !.
template_used(KB, F, A) :-
    safe_scenario_fact(KB, F, A), !.
template_used(KB, F, A) :-
    current_predicate(KB:query_info/3),
    KB:query_info(_, Goal, _),
    find_in_body(Goal, Literal),
    functor(Literal, F, A), !.

%!  contains_literal(+Term, +F, +A) is semidet.
%
%   Does this term mention F/A anywhere inside it? An LPS payload is a nest of
%   `r/2`, `and/2`, `lps_at/2`, `le_at/3` and friends around the literals, and
%   the only thing wanted here is whether the template appears at all.
contains_literal(T, F, A) :-
    compound(T),
    (   functor(T, F, A)
    ;   arg(_, T, Sub), contains_literal(Sub, F, A)
    ), !.

% --- 3c. Facts nobody reads ---
%
% The template is not dead vocabulary — the program states FACTS through it, in
% the knowledge base or in a scenario — but nothing ever reads them: no rule
% condition mentions it and no query asks about it. Data nothing consults
% changes no answer, so the fact is a statement the program silently ignores.
%
% This is the expensive half of `unused_template`. A dead template costs the
% reader attention; an unread FACT costs a wrong decision: a payment limit, an
% excess or an exclusion stated in a scenario and never consulted means the
% rules that should have been bounded by it are computing unbounded answers,
% and every test still passes because nothing was ever going to read it.
%
% Only EXTENSIONAL predicates are reported. A predicate with rules of its own
% that no query reaches is already `untested_predicate`, which says the same
% thing about a derivation rather than about data.
unconsumed_facts(KB, issue(unconsumed_facts, Description, Fix, Start, End)) :-
    le_kbs:template_of(KB, F, A, _Dict, Label),
    once(template_data(KB, F, A, Where, Start, End)),
    % `current_predicate` FIRST, always. is_intensional/3 probes the predicate
    % with predicate_property/clause, and probing one the KB never defined —
    % every `; undefined` template is one — creates it in the module, which
    % breaks the reasoner's later rendering of that program. Templates with no
    % predicate at all are extensional by definition anyway.
    \+ ( current_predicate(KB:F/A), is_intensional(KB, F, A) ),
    \+ template_consumed(KB, F, A),
    unconsumed_facts_desc(Where, Label, Description),
    le_i18n:le_msg(unconsumed_facts_fix, [], Fix).

unconsumed_facts_desc(knowledge_base, Label, Description) :-
    le_i18n:le_msg(unconsumed_facts_desc, [template-Label], Description).
unconsumed_facts_desc(scenario(Name), Label, Description) :-
    le_i18n:le_msg(unconsumed_scenario_facts_desc, [template-Label, scenario-Name],
                   Description).

%!  template_data(+KB, +F, +A, -Where, -Start, -End) is nondet.
%
%   The program states a fact through F/A: a knowledge-base fact (a clause with
%   a `true` body) or a scenario fact. Where says which, and the source span
%   anchors the warning at the ignored DATA — the sentence the reader wrote and
%   believes is doing something — rather than at the template declaration.
template_data(KB, F, A, knowledge_base, Start, End) :-
    functor(Head, F, A),
    current_predicate(KB:F/A),
    le_kbs:kb_own_predicate(KB, Head),
    clause(KB:Head, true, Ref),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true ; Start = 0, End = 0 ).
template_data(KB, F, A, scenario(Name), Start, End) :-
    current_predicate(KB:scenario/2),
    KB:scenario(Name, Terms),
    member(Item, Terms),
    ( Item = fact_with_source(Term, Start, End) -> true ; Term = Item, Start = 0, End = 0 ),
    ( Term = (Head :- _) -> true ; Head = Term ),
    compound(Head),
    functor(Head, F, A).

%!  template_consumed(+KB, +F, +A) is semidet.
%
%   Something READS F/A: a rule condition, a query, or an LPS sentence. Note
%   the asymmetry with template_used/3 — a fact or a rule HEAD is a use of the
%   template but not a consumer of its facts, which is the whole point here.
template_consumed(KB, F, A) :-
    current_predicate(KB:Other/OA),
    \+ is_system_predicate(Other/OA),
    functor(H, Other, OA),
    le_kbs:kb_own_predicate(KB, H),
    clause(KB:H, Body),
    Body \== true,
    find_in_body(Body, Literal),
    functor(Literal, F, A), !.
template_consumed(KB, F, A) :-
    current_predicate(KB:query_info/3),
    KB:query_info(_, Goal, _),
    find_in_body(Goal, Literal),
    functor(Literal, F, A), !.
%   An LPS program's rules are le_lps_item/3 payloads, not clauses, and the
%   payload nests head and body together — so any mention counts, rather than
%   reporting every fact template of a perfectly ordinary LPS program.
template_consumed(KB, F, A) :-
    current_predicate(KB:le_lps_item/3),
    KB:le_lps_item(_, Payload, _),
    contains_literal(Payload, F, A), !.

%!  template_source(+KB, +Dict, -Start, -End) is det.
template_source(KB, Dict, Start, End) :-
    (   current_predicate(KB:le_source_info/4),
        KB:le_source_info(Ref, Start0, End0, template),
        catch(clause(KB:le_dict(Dict), true, Ref), _, fail)
    ->  Start = Start0, End = End0
    ;   Start = 0, End = 0
    ).

is_reachable_from_query(KB, F, A) :-
    current_predicate(KB:query_info/3),
    KB:query_info(_, Goal, _),
    is_reachable(KB, Goal, F, A, []).

is_reachable(_KB, Goal, F, A, _) :-
    find_in_body(Goal, Literal),
    functor(Literal, F, A).
is_reachable(KB, Goal, F, A, Anc) :-
    find_in_body(Goal, Literal),
    functor(Literal, F1, A1),
    \+ member(F1/A1, Anc),
    functor(G1, F1, A1),
    current_predicate(KB:F1/A1),
    le_kbs:kb_own_predicate(KB, G1),
    KB:clause(G1, Body),
    is_reachable(KB, Body, F, A, [F1/A1|Anc]).

% --- 4. Rule without variables ---
rule_without_variables(KB, issue(rule_without_variables, Description, Fix, Start, End)) :-
    % Suppress this warning for a wholly propositional program: if EVERY rule is
    % ground it is obviously propositional by design, so flagging each rule is
    % just noise (e.g. abduction/planning KBs whose beliefs are propositional).
    \+ all_rules_ground(KB),
    ground_rule(KB, Head, Body, Ref),
    le_i18n:le_msg(rule_without_variables_desc, [head-Head, body-Body], Description),
    le_i18n:le_msg(rule_without_variables_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% a_rule(+KB, -Head, -Body, -Ref): a user rule (a clause with a real body, not an
% imported/system predicate).
a_rule(KB, Head, Body, Ref) :-
    current_predicate(KB:F/A), functor(Head, F, A),
    \+ predicate_property(KB:Head, imported_from(_)),
    clause(KB:Head, Body, Ref),
    Body \== true.

ground_rule(KB, Head, Body, Ref) :-
    a_rule(KB, Head, Body, Ref), ground(Head), ground(Body).

% all_rules_ground(+KB): the program has at least one rule and every rule is
% ground (propositional).
all_rules_ground(KB) :-
    once(a_rule(KB, _, _, _)),
    \+ ( a_rule(KB, H, B, _), \+ ( ground(H), ground(B) ) ).

% --- 5. Facts/Rules ratio ---
%
% Not for every target. count_rules/2 counts Prolog clauses with bodies in the
% KB's module, which is what `the target language is: prolog` produces. An
% `lps` program asserts none: its rules become reactive_rule/2, updated/4 and
% d_pre/1 facts handed to the LPS2 engine, so the heuristic sees a program of
% facts alone and reports missing_rules on a program that is nothing but rules.
% Same for too_many_facts, and for the same reason.
counts_prolog_rules(KB) :-
    le_kbs:kb_target_language(KB, Target),
    memberchk(Target, [prolog, scasp]).

facts_rules_ratio(KB, issue(missing_rules, Description, Fix, 0, 0)) :-
    counts_prolog_rules(KB),
    count_rules(KB, Rules),
    Rules == 0,
    count_facts(KB, Facts),
    Facts > 0,
    le_i18n:le_msg(missing_rules_desc, [], Description),
    le_i18n:le_msg(missing_rules_fix, [], Fix).
facts_rules_ratio(KB, issue(too_many_facts, Description, Fix, 0, 0)) :-
    counts_prolog_rules(KB),
    count_rules(KB, Rules),
    Rules > 0,
    count_facts(KB, Facts),
    Facts > Rules * 5,
    le_i18n:le_msg(too_many_facts_desc, [facts-Facts, rules-Rules], Description),
    le_i18n:le_msg(too_many_facts_fix, [], Fix).

% --- 6. Failed tests ---
failed_test(KB, issue(failed_test, Description, Fix, Start, End)) :-
    current_predicate(KB:le_expected/4),
    clause(KB:le_expected(QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns), true, Ref),
    run_one_test(KB, test(QueryName, ScenarioName, ExpectedStrings, ExpectedUnknowns), Result),
    Result \= pass(_, _),
    (   Result = fail(_, _, Expected, Actual) ->
        le_i18n:le_msg(failed_test_desc, [query-QueryName, scenario-ScenarioName, expected-Expected, actual-Actual], Description)
    ;   Result = fail(_, _, Expected, Actual, ExpectedU, ActualU) ->
        le_i18n:le_msg(failed_test_unknowns_desc, [query-QueryName, scenario-ScenarioName, expected-Expected, actual-Actual, expected_unknowns-ExpectedU, actual_unknowns-ActualU], Description)
    ;   Result = error(_, _, Error) ->
        le_i18n:le_msg(failed_test_error_desc, [query-QueryName, scenario-ScenarioName, error-Error], Description)
    ;   le_i18n:le_msg(failed_test_plain_desc, [query-QueryName, scenario-ScenarioName], Description)
    ),
    le_i18n:le_msg(failed_test_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% --- 7. Redefined system template ---
redefined_system_template(KB, issue(redefined_system_template, Description, Fix, Start, End)) :-
    current_predicate(KB:le_dict/1),
    clause(KB:le_dict(Dict), true, Ref),
    (Dict = dict(FA, NTs, WV, _, _, _, _) ; Dict = dict(FA, NTs, WV, _, _, _) ; Dict = dict(FA, NTs, WV, _, _) ; Dict = dict(FA, NTs, WV, _) ; Dict = dict(FA, NTs, WV)),
    % It's a user template if it's not in system templates
    \+ le_system_template(dict(FA, NTs, WV)),
    % And it matches a system template's words
    le_system_template(dict(_SysFA, _SysNTs, SysWV)),
    templates_match(WV, SysWV),
    % And it has no rules or facts
    FA = [F|Args],
    length(Args, Arity),
    functor(G, F, Arity),
    \+ is_defined(KB, G),
    % Get source info
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0),
    canonical_string(WV, TemplateStr),
    le_i18n:le_msg(redefined_system_template_desc, [template-TemplateStr], Description),
    le_i18n:le_msg(redefined_system_template_fix, [], Fix).

templates_match(WV1, WV2) :-
    length(WV1, L), length(WV2, L),
    maplist(match_token, WV1, WV2).

match_token(T1, T2) :-
    (is_var_placeholder(T1) ; var(T1)),
    (is_var_placeholder(T2) ; var(T2)), !.
match_token(T, T).

is_var_placeholder(var(_)).
is_var_placeholder(var(_, _)).

count_rules(KB, Count) :-
    findall(1, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
        functor(Head, F, A),
        le_kbs:kb_own_predicate(KB, Head),
        KB:clause(Head, Body),
        Body \== true
    ), L),
    length(L, Count).

count_facts(KB, Count) :-
    findall(1, (
        current_predicate(KB:F/A),
        \+ is_system_predicate(F/A),
        functor(Head, F, A),
        le_kbs:kb_own_predicate(KB, Head),
        KB:clause(Head, true)
    ), L1),
    length(L1, Count).

% --- 8. Fact with a single, likely-accidental variable ---
% A ground fact written as "the mad hatter is a lofty creature." quietly turns
% the subject into a *variable* (because "a"/"an"/"the"/"some" + noun introduces
% one), so the fact becomes universally true rather than a statement about one
% individual. The author usually does not realise this. We warn whenever a fact
% (a clause with a 'true' body) has exactly one variable. Subjects written as a
% proper name ("fluffy") or with "any" ("any beast") become constants, so such
% facts carry no variable and are not flagged.
single_variable_fact(KB, issue(single_variable_fact, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A),
    \+ is_system_predicate(F/A),
    functor(Head, F, A),
    \+ predicate_property(KB:Head, imported_from(_)),
    clause(KB:Head, true, Ref),
    term_variables(Head, [_]),
    fact_le_text(KB, Head, Text),
    le_i18n:le_msg(single_variable_fact_desc, [text-Text], Description),
    le_i18n:le_msg(single_variable_fact_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true ; Start = 0, End = 0 ).

% --- 8a. Scenario fact with a single, likely-accidental variable ---
% The same trap as single_variable_fact, but inside a scenario. There the
% articles behave differently from the knowledge base: "the individual is happy"
% names the constant 'the individual' (safe), but "a person is happy" quietly
% introduces a *variable*, so the scenario fact holds for every person. Such a
% fact compiles to a clause whose body is just the type check, and scenario
% facts are stored as terms inside scenario/2 rather than as KB clauses, so the
% check above does not see them. Rules and unknown facts (whose bodies contain
% more than type checks) are skipped.
single_variable_scenario_fact(KB, issue(single_variable_fact, Description, Fix, Start, End)) :-
    current_predicate(KB:scenario/2),
    KB:scenario(Name, Terms),
    member(fact_with_source(Term, Start, End), Terms),
    (   Term = (Head :- Body)
    ->  body_only_type_checks(Body)
    ;   Head = Term
    ),
    compound(Head),
    Head \= unknown_template(_),
    term_variables(Head, [_]),
    fact_le_text(KB, Head, Text),
    le_i18n:le_msg(single_variable_scenario_fact_desc, [text-Text, scenario-Name], Description),
    le_i18n:le_msg(single_variable_scenario_fact_fix, [], Fix).

body_only_type_checks((A, B)) :- !, body_only_type_checks(A), body_only_type_checks(B).
body_only_type_checks(le_type_check(_, _)).
body_only_type_checks(true).

% Render a fact head as readable LE text, falling back to the raw term.
fact_le_text(KB, Head, Text) :-
    (   catch(le_kbs:item_to_instance(KB, Head, Tokens), _, fail),
        catch(canonical_string(Tokens, Atom), _, fail)
    ->  atom_string(Atom, Text)
    ;   term_string(Head, Text)
    ).

% --- 9. Compound argument in a non-meta template slot ---
% When a sentence spans several templates that are NOT declared prepositional,
% the recursive parse can quietly swallow the tail of the sentence into a
% template slot as a COMPOUND term built from another template — e.g. with the
% templates "we will make *a payment*" and "*a payment* under *a policy*", the
% fact "we will make this payment under this policy" parses as
% we_will_make(under('this payment','this policy')), whereas the author almost
% certainly expected an atomic payment. Embedding a literal in a slot is only
% natural for a META-template, whose slot is, by convention, immediately
% preceded by the word 'that' (or 'says'). So warn whenever a head or body
% literal of a user template carries an embedded-template argument in a slot
% that is not marked that way.
unmarked_meta_template(KB, issue(unmarked_meta_template, Description, Fix, Start, End)) :-
    current_predicate(KB:F/A),
    \+ is_system_predicate(F/A),
    functor(Head, F, A),
    \+ predicate_property(KB:Head, imported_from(_)),
    clause(KB:Head, Body, Ref),
    ( Lit = Head ; find_in_body(Body, Lit) ),
    nonvar(Lit),
    compound(Lit),
    functor(Lit, LF, LA),
    user_template_functor(KB, LF, LA),
    arg(I, Lit, Arg),
    embedded_template_instance(KB, Arg),
    \+ template_meta_slot(KB, LF, LA, I),
    fact_le_text(KB, Arg, ArgText),
    fact_le_text(KB, Lit, LitText),
    le_i18n:le_msg(unmarked_meta_template_desc, [literal-LitText, arg-ArgText], Description),
    le_i18n:le_msg(unmarked_meta_template_fix, [], Fix),
    ( clause(KB:le_source_info(Ref, Start, End, _), true) -> true; Start = 0, End = 0).

% An argument that is an instance of a user-declared template (not data such as
% a date or a list): the tell-tale of an embedded literal in the slot.
embedded_template_instance(KB, Arg) :-
    compound(Arg),
    \+ is_list(Arg),
    Arg \= date(_),
    Arg \= date(_, _, _),
    functor(Arg, AF, AN),
    user_template_functor(KB, AF, AN).

%!  user_template_functor(+KB, +F, +A) is semidet.
%
%   F/A is the functor of a template the user declared (KB:le_dict holds only
%   user templates; system templates live in le_system_templates).
user_template_functor(KB, F, A) :-
    current_predicate(KB:le_dict/1),
    clause(KB:le_dict(Dict), true),
    dict_fa_wv(Dict, [F|Args], _),
    length(Args, A), !.

% dict_fa_wv(+Dict, -FunctorArgs, -WordsAndVars): destructure the stored le_dict
% across its historical layouts. FunctorArgs and WordsAndVars share variables.
dict_fa_wv(dict(FA, _, WV, _, _, _, _), FA, WV).
dict_fa_wv(dict(FA, _, WV, _, _, _), FA, WV).
dict_fa_wv(dict(FA, _, WV, _, _), FA, WV).
dict_fa_wv(dict(FA, _, WV, _), FA, WV).
dict_fa_wv(dict(FA, _, WV), FA, WV).

%!  template_meta_slot(+KB, +F, +A, +I) is semidet.
%
%   The I-th slot of some template for F/A is a META-variable: in the template's
%   word list the slot is immediately preceded by 'that' (or 'says'), so an
%   embedded literal is its intended value (see le_grammar:is_meta_prev/1).
template_meta_slot(KB, F, A, I) :-
    current_predicate(KB:le_dict/1),
    clause(KB:le_dict(Dict), true),
    dict_fa_wv(Dict, [F|Args], WV),
    length(Args, A),
    nth1(I, Args, V),
    append(_, [PrevWord, Slot | _], WV),
    Slot == V,
    atom(PrevWord),
    le_grammar:is_meta_prev(PrevWord), !.

% --- Printing ---
print_issues(Issues) :-
    forall(member(Issue, Issues), print_issue(Issue)).

print_issue(issue(Type, Description, Fix, Start, End)) :-
    format(atom(Msg), "~w~n    Fix: ~w~n    Position: ~w-~w", [Description, Fix, Start, End]),
    print_message(warning, Type - [Msg]).

% Extend prolog:message to handle our issues
:- multifile prolog:message//1.
prolog:message(Type - [Msg, Start, End]) -->
    { memberchk(Type, [missing_template, undefined_predicate, suspicious_is_a, misplaced_expectation, defined_scenario_element, untested_predicate, rule_without_variables, missing_rules, too_many_facts, failed_test, redefined_system_template, scenario_before_rules, missing_trailing_dot, prepositional_arity, prepositional_first_arg, reserved_word_in_template, single_variable_fact, include_too_deep, restricted_resource, skipped_directive, module_directive_stripped, missing_resource, unsafe_prolog_goal, stray_asterisk, unmarked_meta_template, unused_template, unconsumed_facts, image_nonground, image_on_rule, image_bad_url, image_template_vars]) },
    [ '~w: ~w at ~w-~w' - [Type, Msg, Start, End] ].
prolog:message(Type - [Msg]) -->
    { memberchk(Type, [missing_template, undefined_predicate, suspicious_is_a, misplaced_expectation, defined_scenario_element, untested_predicate, rule_without_variables, missing_rules, too_many_facts, failed_test, redefined_system_template, scenario_before_rules, missing_trailing_dot, prepositional_arity, prepositional_first_arg, reserved_word_in_template, single_variable_fact, include_too_deep, restricted_resource, skipped_directive, module_directive_stripped, missing_resource, unsafe_prolog_goal, stray_asterisk, unmarked_meta_template, unused_template, unconsumed_facts, image_nonground, image_on_rule, image_bad_url, image_template_vars]) },
    [ '~w: ~w' - [Type, Msg] ].
