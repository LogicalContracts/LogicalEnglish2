% Tests for the two lookup shortcuts a large program's load time depends on:
%
%   - le_dict_fa/3 and le_dict_opposite/3, the functor indexes written beside
%     every le_dict/1 clause (le_kbs:assert_le_dict/3). le_dict/1 keeps the whole
%     template in one compound, so every clause has the same first-argument key
%     and a lookup by predicate walks the entire templates section — which is
%     what the verifier does for each literal it checks.
%   - le_grammar:template_partition/4, the meta/non-meta split of the template
%     list, computed once per list instead of once per sentence parsed.
%
% Both are pure speed, so what has to be tested is that they answer exactly what
% the scans they replace answered.

:- use_module('../le_kbs').
:- use_module('../le_grammar').
:- use_module('../reasoner').

program("the target language is: prolog.

the templates are:
    *a person* is happy ; opposite: *a person* is sad.
    *a person* is healthy.
    *a person* is rich.
    *a claim* is covered under *a section*.

the knowledge base tiny includes:

a person is happy
    if the person is healthy.

a claim is covered under a section
    if the claim is rich.

query who is:
    which person is happy.
").

kb(KB) :- program(P), le_kbs:load_text(P, KB).

templates(KB, Templates) :-
    kb(KB),
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates).

:- begin_tests(template_index).

% Every template is in the index, under its own functor and arity, and the index
% holds nothing the templates section does not.
test(index_covers_every_template) :-
    kb(KB),
    findall(F/A-D,
            ( KB:le_dict(D), arg(1, D, [F|Args]), length(Args, A) ),
            Declared),
    findall(F/A-D, KB:le_dict_fa(F, A, D), Indexed),
    msort(Declared, S1), msort(Indexed, S2),
    assertion(S1 =@= S2),          % same templates, fresh copies of their variables
    assertion(Declared \== []).

% The index answers what the scan answered, template for template.
test(index_lookup_agrees_with_the_scan) :-
    kb(KB),
    forall(( KB:le_dict(D), arg(1, D, [F|Args]), length(Args, A) ),
           ( findall(X, ( KB:le_dict(X), arg(1, X, [F|XArgs]), length(XArgs, A) ), Scanned),
             findall(X, reasoner:dict_by_functor(KB, F, A, X), Looked),
             assertion(Scanned =@= Looked) )).

% The opposite index is keyed by the OPPOSITE's functor — the direction
% has_opposite/4 needs when it is handed the negative predicate.
test(opposite_index_is_keyed_by_the_opposite) :-
    kb(KB),
    % `*a person* is happy ; opposite: *a person* is sad` declares both
    % predicates, each naming the other, so each is a key
    assertion(KB:le_dict_opposite(is_sad, 1, _)),
    assertion(KB:le_dict_opposite(is_happy, 1, _)),
    % ... and a template with no opposite contributes no entry
    assertion(\+ KB:le_dict_opposite(is_healthy, 1, _)),
    assertion(\+ KB:le_dict_opposite(is_covered_under, 2, _)).

% Both directions of has_opposite/4 still resolve.
test(has_opposite_resolves_both_ways) :-
    kb(KB),
    reasoner:has_opposite(is_happy(bob), KB, none, Opp),
    assertion(Opp == is_sad(bob)),
    reasoner:has_opposite(is_sad(bob), KB, none, Main),
    assertion(Main == is_happy(bob)),
    assertion(\+ reasoner:has_opposite(is_healthy(bob), KB, none, _)).

:- end_tests(template_index).

% ---------------------------------------------------------------------------

:- begin_tests(template_partition).

% The cached split is the split: every template lands on exactly one side, in
% the order it had, and the meta side is the one the meta test picks out.
test(partition_is_the_meta_split) :-
    templates(_, Templates),
    le_i18n:class_word_list(meta_marker, Ms),
    le_grammar:template_partition(Templates, Ms, Metas, Rest),
    append(Metas, Rest, Both),
    msort(Both, S1), msort(Templates, S2),
    assertion(S1 =@= S2),
    forall(member(D, Metas), assertion(le_grammar:meta_candidate(Ms, D))),
    forall(member(D, Rest), assertion(\+ le_grammar:meta_candidate(Ms, D))).

% A second list is not served the first one's partition — the cache is keyed by
% the list it was computed from, and a miss recomputes.
test(a_different_list_gets_its_own_partition) :-
    templates(_, Templates),
    le_i18n:class_word_list(meta_marker, Ms),
    le_grammar:template_partition(Templates, Ms, _, _),
    Templates = [First|_],
    le_grammar:template_partition([First], Ms, M2, R2),
    append(M2, R2, Both2),
    assertion(Both2 =@= [First]),
    % ... and the original list still gets its own, in full
    le_grammar:template_partition(Templates, Ms, M3, R3),
    append(M3, R3, Both3),
    length(Both3, N), length(Templates, N).

% What candidate_template/3 enumerates is unchanged by the caching: every
% template whose fixed words the sentence contains, meta ones first.
test(candidate_template_still_finds_the_matching_templates) :-
    templates(_, Templates),
    findall(F,
            ( le_grammar:candidate_template(Templates, [a, person, is, happy], D),
              arg(1, D, [F|_]) ),
            Functors),
    assertion(memberchk(is_happy, Functors)),
    assertion(\+ memberchk(is_covered_under, Functors)).

:- end_tests(template_partition).
