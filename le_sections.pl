/** <module> The decision skeleton as a section convention

    A regulatory decision has a shape: is the rule applicable, what is the
    answer to the contested question, what follows (the remedy). A program
    expresses that shape with the ordinary section markers, using three
    reserved names (per language, from i18n/keywords.csv):

        section applicability is:   ...
        section question is:        ...
        section remedy is:          ...

    Nothing about solving changes. What this module adds is the reading of a
    FAILED query against that skeleton: the query fails at the earliest
    section, in checklist order, holding a rule for a goal the failed attempt
    could not prove —

        the query fails at section *a section*             (the program's first query)
        the query *a name* fails at section *a section*    (a named query)

    — and the checklist itself (passed / failed / not reached per section),
    which failure explanations lead with.
*/

:- module(le_sections, [
    section_role/2,             % +SectionName, -Role
    principal_query/3,          % +KM, -Name, -Goal
    failing_section/4,          % +SM, +KM, +QueryName|principal, -Section
    section_checklist/4         % +SM, +KM, +Goal, -Checklist
]).

:- use_module(le_i18n).

% Checklist order of the reserved roles.
role_order([applicability, question, remedy]).

role_key(applicability, section_applicability).
role_key(question, section_question).
role_key(remedy, section_remedy).

%!  section_role(+SectionName, -Role) is semidet.
%
%   The reserved role (applicability, question, remedy) named by a section
%   marker's name in the active language.
section_role(Name, Role) :-
    atom(Name),
    atomic_list_concat(Words0, ' ', Name),
    exclude(==(''), Words0, Words),
    role_key(Role, Key),
    kw_synonym_words(Key, Syn),
    maplist(same_word, Syn, Words), !.

same_word(A, B) :- downcase_atom(A, L), downcase_atom(B, L).

%!  principal_query(+KM, -Name, -Goal) is semidet.
%
%   The program's first query (in source order) that is not itself about
%   sections — "the query" of `the query fails at section ...`.
principal_query(KM, Name, Goal) :-
    current_predicate(KM:query_info/3),
    findall(S-(N-G),
            ( KM:query_info(N, G, _),
              \+ sub_term_functor(G, le_fails_at_section/1),
              \+ sub_term_functor(G, le_query_fails_at_section/2),
              query_start(KM, N, S) ),
            Pairs),
    keysort(Pairs, [_-(Name-Goal)|_]).

query_start(KM, Name, Start) :-
    (   clause(KM:query_info(Name, _, _), true, Ref),
        KM:le_source_info(Ref, S, _, _)
    ->  Start = S
    ;   Start = 0
    ).

sub_term_functor(T, F/A) :-
    compound(T),
    (   functor(T, F, A) -> true
    ;   arg(_, T, Sub), sub_term_functor(Sub, F/A)
    ), !.

query_goal(KM, principal, Goal) :- !,
    principal_query(KM, _, Goal).
query_goal(KM, Name, Goal) :-
    current_predicate(KM:query_info/3),
    (   KM:query_info(Name, Goal, _) -> true
    ;   atom(Name), atom_number(Name, N), KM:query_info(N, Goal, _)
    ), !.

%!  failing_section(+SM, +KM, +Query, -Section) is semidet.
%
%   Query (a query name, or `principal`) has no answer in session SM, and
%   Section is where it fails: the earliest section, in checklist order (the
%   reserved roles first, then any other named section in source order),
%   holding a rule for a goal that the attempt tried and could not prove.
failing_section(SM, KM, Query, Section) :-
    query_goal(KM, Query, Goal),
    copy_term(Goal, G),
    reasoner:goal_attempt(G, SM, KM, Result, Refs),
    Result = failed(Calls),
    failed_sections(KM, Calls, Refs, Sections),
    Sections = [Section|_].

% The sections blamed: those of the rules whose bodies called a goal that
% failed (with every ancestor failed) — the rule that needed the condition,
% not the rules of the predicate consulted; failing that (no calling rule
% recorded), the sections of the failed goals' own rules.
failed_sections(KM, Calls, Refs, Ordered) :-
    findall(Sec, ( member(Ref, Refs), clause_section(KM, Ref, Sec) ), Secs0),
    (   Secs0 == []
    ->  findall(Sec,
                ( member(G-failed, Calls),
                  goal_rule_section(KM, G, Sec) ),
                Secs1)
    ;   Secs1 = Secs0
    ),
    sort(Secs1, Secs),
    order_sections(KM, Secs, Ordered).

clause_section(KM, Ref, Section) :-
    catch(KM:le_source_info(Ref, _, _, ID), _, fail),
    KM:le_source_section(Section, ID),
    Section \== main.

% The sections holding a rule (not a fact) for Goal's predicate.
goal_rule_section(KM, Goal, Section) :-
    callable(Goal),
    functor(Goal, F, A),
    functor(H, F, A),
    current_predicate(KM:F/A),
    le_kbs:kb_own_predicate(KM, H),
    clause(KM:H, Body, Ref),
    Body \== true,
    KM:le_source_info(Ref, _, _, ID),
    KM:le_source_section(Section, ID),
    Section \== main.

% Reserved roles first, in checklist order; then the other sections in the
% order they appear in the program.
order_sections(KM, Secs, Ordered) :-
    role_order(Roles),
    findall(S, ( member(R, Roles), member(S, Secs), section_role(S, R) ), Reserved),
    findall(P-S, ( member(S, Secs), \+ section_role(S, _), section_position(KM, S, P) ), Others0),
    keysort(Others0, Others1),
    pairs_values(Others1, Others),
    append(Reserved, Others, Ordered).

section_position(KM, Section, Pos) :-
    findall(S, ( KM:le_source_section(Section, ID), KM:le_source_info(_, S, _, ID) ), Ss),
    ( Ss == [] -> Pos = inf ; min_list(Ss, Pos) ).

%!  section_checklist(+SM, +KM, +Goal, -Checklist) is semidet.
%
%   For a program that uses the reserved section names, and a Goal with no
%   answer: one Section-Status pair per reserved section the program has, in
%   checklist order, Status being passed, failed or not_reached. Fails when
%   the program uses none of the reserved names, or Goal has an answer.
section_checklist(SM, KM, Goal, Checklist) :-
    program_roles(KM, Present),
    Present \== [],
    copy_term(Goal, G),
    reasoner:goal_attempt(G, SM, KM, failed(Calls), Refs),
    failed_sections(KM, Calls, Refs, Failed),
    (   member(First, Failed), section_role(First, FirstRole) -> true ; FirstRole = none ),
    role_order(Roles),
    findall(Name-Status,
            ( member(Role, Roles), member(Role-Name, Present),
              role_status(Role, FirstRole, Roles, Status) ),
            Checklist).

program_roles(KM, Present) :-
    findall(Role-Name,
            ( current_predicate(KM:le_source_section/2),
              distinct(Name, KM:le_source_section(Name, _)),
              section_role(Name, Role) ),
            Present).

role_status(_, none, _, passed) :- !.
role_status(Role, Role, _, failed) :- !.
role_status(Role, First, Roles, Status) :-
    nth1(I, Roles, Role), nth1(J, Roles, First),
    ( I < J -> Status = passed ; Status = not_reached ).
