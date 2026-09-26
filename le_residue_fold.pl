/** <module> Folding translated residue into the rules that call it

    A skeleton written by a translator from another system names what it
    could not translate by a sentence of its own — `the counterparty meets
    condition c22` — and leaves a residue block concluding that sentence
    (docs/dev/migration.md §4). Once the block is translated, the sentence is
    a name standing between the rule that asks for it and the conditions that
    decide it. Folding removes the name: each condition line that asks for
    it is replaced by the translation's own conditions, and the block goes.

        rule r6 with provenance "...":                  rule r6 with provenance "...":
        the coverage of a counterparty ... if           the coverage of a counterparty ... if
            the counterparty is a central bank     =>       the counterparty is a central bank
            and the counterparty meets condition c22        and the counterparty is the Bank of England.
            and the counterparty meets condition c23.
        a counterparty meets condition c22 if
            the counterparty is the Bank of England.
        (and the same for c23)

    The folded rule reads as the source did — one row, its conditions — and
    every condition now sits under the caller's label, whose provenance is
    the row's. A condition the fold brings in twice is kept once. The
    residue's own text and source are kept as a comment above the rule.

    A residue is folded only when that changes nothing a query can see. It
    stays a rule of its own when its translation is not one rule concluding
    exactly its sentence (several rules, a fact, the placeholder), when its
    conditions are alternatives (a top-level `or` would bind differently
    inside the caller's `and`s), when anything besides a condition line
    names it (a scenario stating `acme fails condition c1`, which the
    skeleton's constraint reads through the sentence), when no rule calls
    it, or when its conditions introduce a variable the caller already uses.
    The report says which, and why.

    Run on a file:
        swipl -g "use_module(le_residue_fold), fold_residue_file('in.le', 'out.le'), halt."
*/

:- module(le_residue_fold, [
    residue_fold/3,             % +Program, -Folded, -Report
    fold_residue_file/2,        % +InFile, +OutFile
    fold_residue_file/3         % +InFile, +OutFile, -Report
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(le_i18n).
:- use_module(le_contract_assistant, []).   % the residue block readers
:- use_module(le_writer, []).               % writer_word/2

%!  residue_fold(+Program, -Folded, -Report) is det.
%
%   Report: one dict per residue block, `_{id, folded: true, into: [Head...]}`
%   or `_{id, folded: false, reason}`.
residue_fold(Program, Folded, Report) :-
    split_string(Program, "\n", "", Lines0),
    %  a scenario's statements about a residue's sentence become the facts it
    %  rests on, so that the scenario no longer names the residue
    index_blocks(Lines0, 1, Blocks0),
    scenario_rewrite(Lines0, Blocks0, Lines),
    index_blocks(Lines, 1, Blocks),
    one_slot_templates(Lines, OneSlot),
    b_setval(le_fold_one_slot, OneSlot),
    findall(I-L, ( nth1(I, Lines, L), \+ inside_block(I, Blocks) ), Outside),
    maplist(fold_decision(Lines, Outside), Blocks, Decisions),
    %  every caller line, with the block folded into it
    findall(I-D, ( member(D, Decisions), D = fold(_, _, Callers, _, _), member(I, Callers) ), CallerOf),
    findall(S-E, ( member(I-_, CallerOf), statement_range(Lines, I, S, E) ), Ranges0),
    sort(Ranges0, Ranges),
    rebuild(Lines, 1, Blocks, Decisions, CallerOf, Ranges, Out),
    atomic_list_concat(Out, "\n", Folded0),
    atom_string(Folded0, Folded),
    maplist(decision_report(Lines), Decisions, Report).

fold_residue_file(In, Out) :-
    fold_residue_file(In, Out, Report),
    forall(member(R, Report),
           (   R.folded == true
           ->  format("~w folded into ~w rule(s)~n", [R.id, R.count])
           ;   format("~w kept: ~w~n", [R.id, R.reason])
           )).

fold_residue_file(In, Out, Report) :-
    read_file_to_string(In, Program, [encoding(utf8)]),
    residue_fold(Program, Folded, Report),
    setup_call_cleanup(open(Out, write, S, [encoding(utf8)]),
                       write(S, Folded),
                       close(S)).

decision_report(Lines, fold(Id, _, Callers, _, _), _{id: Id, folded: true, count: N, into: Heads}) :- !,
    length(Callers, N),
    findall(H, ( member(I, Callers), statement_range(Lines, I, S, _),
                 statement_head(Lines, S, H) ), Heads0),
    sort(Heads0, Heads).
decision_report(_, keep(Id, Reason), _{id: Id, folded: false, reason: Reason}).

statement_head(Lines, S, Head) :-
    nth1(S, Lines, L0),
    (   label_line(L0), S1 is S + 1, nth1(S1, Lines, L1) -> normalize_space(string(Head), L1)
    ;   normalize_space(string(Head), L0)
    ).

		 /*******************************
		 *            BLOCKS            *
		 *******************************/

%   blk(Id, From, To, Src, Body): the block's marker lines are From and To.
index_blocks([], _, []).
index_blocks([L|Ls], N, Blocks) :-
    (   le_contract_assistant:residue_begin(L, Id, _)
    ->  le_contract_assistant:residue_take(Ls, Id, Inside, Rest),
        partition(le_contract_assistant:comment_line, Inside, Src, Body),
        length(Inside, K), To is N + K + 1, Next is To + 1,
        Blocks = [blk(Id, N, To, Src, Body)|More],
        index_blocks(Rest, Next, More)
    ;   N1 is N + 1,
        index_blocks(Ls, N1, Blocks)
    ).

inside_block(I, Blocks) :-
    member(blk(_, F, T, _, _), Blocks), I >= F, I =< T, !.

		 /*******************************
		 *           DECISION           *
		 *******************************/

%!  fold_decision(+Lines, +Outside, +Block, -Decision) is det.
%
%   fold(Id, BodyLines, CallerIndexes, HeadNoun, Comment) or keep(Id, Reason).
fold_decision(Lines, Outside, blk(Id, _, _, Src, Body), Decision) :-
    (   fold_check(Lines, Outside, Id, Src, Body, Decision0)
    ->  Decision = Decision0
    ;   Decision = keep(Id, "not foldable")
    ).

fold_check(Lines, Outside, Id, Src, Body, Decision) :-
    (   le_contract_assistant:residue_target(Src, Target)
    ->  exclude(le_contract_assistant:blank_line, Body, Body1),
        exclude(label_line, Body1, Body2),
        le_contract_assistant:fill_statements(Body2, Stmts0),
        include([X]>>(X = stmt(_)), Stmts0, Stmts),
        target_key(Target, TKey),
        findall(I, ( member(I-L, Outside), caller_line(L, TKey, _) ), Callers),
        (   Stmts = [stmt([HeadLine|Conds])]
        ->  fold_rule(Lines, Outside, Id, Src, TKey, HeadLine, Conds, Callers, Decision)
        ;   Decision = keep(Id, "its translation is not a single rule")
        )
    ;   Decision = keep(Id, "the block names no sentence it concludes")
    ).

fold_rule(Lines, Outside, Id, Src, TKey, HeadLine, Conds, Callers, Decision) :-
    head_noun(HeadLine, Noun),
    (   \+ rule_head(HeadLine, TKey)
    ->  Decision = keep(Id, "its translation does not conclude its sentence (or is the placeholder)")
    ;   Conds == []
    ->  Decision = keep(Id, "its rule has no conditions")
    ;   top_level_or(Conds)
    ->  Decision = keep(Id, "its conditions are alternatives (or)")
    ;   Callers == []
    ->  Decision = keep(Id, "no rule calls it")
    ;   other_use(Outside, Lines, Src, Callers, Use)
    ->  format(string(R), "it is also named outside a condition: ~w", [Use]),
        Decision = keep(Id, R)
    ;   member(I, Callers), captures(Lines, I, Conds, Noun, W)
    ->  format(string(R), "its conditions would reuse the caller's variable \"~w\"", [W]),
        Decision = keep(Id, R)
    ;   fold_comment(Id, Src, Comment),
        Decision = fold(Id, Conds, Callers, Noun, Comment)
    ).

%   A sentence's words without articles: two phrasings of one sentence, `a
%   counterparty meets condition c22` and `the counterparty meets condition
%   c22`, have the same key.
target_key(Sentence, Key) :-
    le_contract_assistant:sentence_words(Sentence, Ws),
    exclude([W]>>class_member(article, W), Ws, Key).

rule_head(Line, TKey) :-
    le_contract_assistant:sentence_words(Line, Ws),
    ( kw_main_words(if, [If|_]) -> true ; If = if ),
    append(HeadWs, [If], Ws),
    exclude([W]>>class_member(article, W), HeadWs, TKey).

%   A condition line asking for the sentence: indented, `and` or nothing
%   before it.
caller_line(L, TKey, Conn) :-
    le_contract_assistant:condition_line(L),
    le_contract_assistant:sentence_words(L, Ws0),
    (   Ws0 = [C|Ws1], kw_synonym_words(and, [C]) -> Conn = and
    ;   Ws0 = [C|_], kw_synonym_words(or, [C]) -> fail
    ;   Ws1 = Ws0, Conn = none
    ),
    exclude([W]>>class_member(article, W), Ws1, TKey).

label_line(L) :-
    \+ sub_string(L, 0, 1, _, " "),
    normalize_space(string(T), L), string_concat(_, ":", T),
    le_contract_assistant:sentence_words(T, [W|_]),
    ( kw_main_words(rule, [R|_]) -> true ; R = rule ),
    W == R.

top_level_or(Conds) :-
    maplist(indent_of, Conds, Is), min_list(Is, Base),
    member(L, Conds), indent_of(L, Base),
    le_contract_assistant:sentence_words(L, [C|_]),
    kw_synonym_words(or, [C]), !.

%   Anything outside the blocks that names the residue's constants and is
%   not one of its caller lines: a scenario's fact, a query, another rule.
other_use(Outside, _Lines, Src, Callers, Use) :-
    findall(L, ( member(_-L, Outside), sub_string(L, _, _, _, "*"),
                 \+ le_contract_assistant:comment_line(L) ), TLs),
    le_contract_assistant:residue_target_constants(TLs, Src, _, _, _, Constants),
    member(I-L, Outside), \+ memberchk(I, Callers),
    \+ le_contract_assistant:comment_line(L),
    le_contract_assistant:sentence_words(L, Ws),
    forall(member(K, Constants), memberchk(K, Ws)),
    !,
    normalize_space(string(Use), L).

%   The noun of the head's first indefinite phrase: `counterparty` in `a
%   counterparty meets condition c22`.
head_noun(HeadLine, Noun) :-
    le_contract_assistant:sentence_words(HeadLine, Ws),
    append(_, [A, Noun|_], Ws), indefinite(A), !.
head_noun(_, none).

indefinite(W) :- class_member(article, W), \+ class_member(definite_article, W).

%   A name the fold would make mean something else. In LE `a bank` (not in
%   `is a bank`, a type) introduces a variable and `the bank` refers back to
%   it. Folded into the caller, the conditions' `a bank` would capture a
%   `the bank` of the caller, and their `the bank` — their own variable or
%   a constant such as `the Bank of England` — would be captured by a `bank`
%   the caller already has.
captures(_, _, Conds, HeadNoun, _) :-
    %  conditions that are instances of templates whose one slot is the
    %  head's noun introduce no variable, and read none
    b_getval(le_fold_one_slot, OneSlot),
    maplist(simple_condition(OneSlot, HeadNoun), Conds, _),
    !, fail.
captures(Lines, I, Conds, HeadNoun, Noun) :-
    atomic_list_concat(Conds, ' ', CT),
    le_contract_assistant:sentence_words(CT, Ws),
    statement_range(Lines, I, S, E),
    findall(L, ( between(S, E, J), J \== I, nth1(J, Lines, L),
                 \+ le_contract_assistant:comment_line(L), \+ label_line(L) ), SLs),
    atomic_list_concat(SLs, ' ', ST),
    le_contract_assistant:sentence_words(ST, SWs),
    (   introduced(Ws, Noun), references(SWs, Noun)
    ;   references(Ws, Noun), ( introduced(SWs, Noun) ; references(SWs, Noun) )
    ),
    Noun \== HeadNoun, !.

introduced(Ws, Noun) :-
    append(_, [P, A, Noun|_], Ws), indefinite(A),
    \+ class_member(ignorable, P), \+ class_member(copula, P), P \== not.

references(Ws, Noun) :-
    append(_, [T, Noun|_], Ws), class_member(definite_article, T).

%   The residue's text and source, kept above the rule it is folded into.
fold_comment(Id, Src, Comment) :-
    ( le_writer:writer_word(residue_folded, FW) -> true ; FW = 'folded in from residue' ),
    findall(S, ( member(L, Src), normalize_space(string(T), L),
                 ( string_concat("% source:", S0, T) ; string_concat("% provenance:", S0, T) ),
                 normalize_space(string(S), S0) ), Sources),
    (   Sources = [First|_] -> format(string(H), "% ~w ~w (~w):", [FW, Id, First])
    ;   format(string(H), "% ~w ~w:", [FW, Id])
    ),
    findall(Q, ( member(L, Src), normalize_space(string(T), L),
                 string_concat("% | ", Q0, T), format(string(Q), "%   | ~w", [Q0]) ), Qs),
    Comment = [H|Qs].

		 /*******************************
		 *           REBUILD            *
		 *******************************/

%   The statement a line belongs to: from its label (or head) to the line
%   that ends it with a period.
statement_range(Lines, I, S, E) :-
    head_index(Lines, I, H),
    (   H > 1, H0 is H - 1, nth1(H0, Lines, LL), label_line(LL) -> S = H0 ; S = H ),
    end_index(Lines, I, E).

head_index(Lines, I, H) :-
    nth1(I, Lines, L),
    (   \+ sub_string(L, 0, 1, _, " "), \+ sub_string(L, 0, 1, _, "\t"),
        \+ le_contract_assistant:comment_line(L), \+ le_contract_assistant:blank_line(L)
    ->  H = I
    ;   I > 1, I1 is I - 1, head_index(Lines, I1, H)
    ).

end_index(Lines, I, E) :-
    nth1(I, Lines, L),
    (   \+ le_contract_assistant:comment_line(L), normalize_space(string(T), L), string_concat(_, ".", T)
    ->  E = I
    ;   I1 is I + 1, end_index(Lines, I1, E)
    ).

rebuild(Lines, N, _, _, _, _, []) :-
    length(Lines, Len), N > Len, !.
rebuild(Lines, N, Blocks, Decisions, CallerOf, Ranges, Out) :-
    (   member(blk(Id, N, To, _, _), Blocks), memberchk(fold(Id, _, _, _, _), Decisions)
    ->  %  a folded block goes, and the blank line after it
        Next0 is To + 1,
        ( nth1(Next0, Lines, BL), le_contract_assistant:blank_line(BL) -> Next is Next0 + 1 ; Next = Next0 ),
        Out = More
    ;   member(N-E, Ranges)
    ->  fold_statement(Lines, N, E, Decisions, CallerOf, New),
        append(New, More, Out),
        Next is E + 1
    ;   nth1(N, Lines, L), Out = [L|More], Next is N + 1
    ),
    rebuild(Lines, Next, Blocks, Decisions, CallerOf, Ranges, More).

%   The statement S..E with each caller line replaced by the conditions of
%   the block folded into it, a condition repeated at the top level kept
%   once, and the folded blocks' comments above it.
fold_statement(Lines, S, E, Decisions, CallerOf, New) :-
    findall(L2, ( between(S, E, J), nth1(J, Lines, L),
                  (   memberchk(J-fold(_, Conds, _, _, _), CallerOf)
                  ->  inline(L, Conds, Ls2), member(L2, Ls2)
                  ;   L2 = L
                  ) ),
            Body0),
    findall(C, ( between(S, E, J), memberchk(J-fold(Id, _, _, _, _), CallerOf),
                 memberchk(fold(Id, _, _, _, Cm), Decisions), member(C, Cm) ), Comments0),
    list_to_set(Comments0, Comments),
    dedupe_conditions(Body0, Body1),
    end_with_period(Body1, Body),
    append(Comments, Body, New).

%   The conditions in the caller line's place: its indentation, its
%   connective on the first, its period (or none) on the last.
inline(CallerLine, Conds, Out) :-
    indent_of(CallerLine, CI),
    caller_line(CallerLine, _, Conn),
    maplist(indent_of, Conds, Is), min_list(Is, Base),
    normalize_space(string(CT), CallerLine),
    ( string_concat(_, ".", CT) -> Period = true ; Period = false ),
    length(Conds, NC),
    findall(L, ( nth1(K, Conds, C0), indent_of(C0, I0),
                 normalize_space(string(T0), C0),
                 (   K =:= 1, Conn == and
                 ->  ( kw_main_words(and, [A|_]) -> true ; A = and ),
                     format(string(T1), "~w ~w", [A, T0])
                 ;   T1 = T0
                 ),
                 (   K =:= NC, Period == false, string_concat(T2, ".", T1) -> true ; T2 = T1 ),
                 Pad is CI + I0 - Base, length(Sp, Pad), maplist(=(' '), Sp),
                 atomic_list_concat(Sp, SpA),
                 string_concat(SpA, T2, L) ),
            Out).

indent_of(L, N) :-
    string_codes(L, Cs), leading_spaces(Cs, 0, N).

leading_spaces([0' |Cs], N0, N) :- !, N1 is N0 + 1, leading_spaces(Cs, N1, N).
leading_spaces([0'\t|Cs], N0, N) :- !, N1 is N0 + 4, leading_spaces(Cs, N1, N).
leading_spaces(_, N, N).

%   A one-line condition at the rule's top level that an earlier one already
%   states, removed.
dedupe_conditions(Lines, Out) :-
    (   member(L, Lines), le_contract_assistant:condition_line(L) -> indent_of(L, Base) ; Base = 4 ),
    dedupe(Lines, Base, [], Out).

dedupe([], _, _, []).
dedupe([L|Ls], Base, Seen, Out) :-
    (   le_contract_assistant:condition_line(L), indent_of(L, Base),
        \+ ( Ls = [N|_], indent_of(N, NI), NI > Base ),
        condition_key(L, K)
    ->  (   memberchk(K, Seen)
        ->  Out = More, Seen1 = Seen
        ;   Out = [L|More], Seen1 = [K|Seen]
        )
    ;   Out = [L|More], Seen1 = Seen
    ),
    dedupe(Ls, Base, Seen1, More).

condition_key(L, K) :-
    le_contract_assistant:sentence_words(L, Ws0),
    ( Ws0 = [C|Ws1], ( kw_synonym_words(and, [C]) ; kw_synonym_words(or, [C]) ) -> true ; Ws1 = Ws0 ),
    exclude([W]>>class_member(article, W), Ws1, K).

%   Removing the last condition takes its period with it: the new last line
%   gets one.
end_with_period(Lines, Out) :-
    (   append(Before, [Last], Lines),
        normalize_space(string(T), Last), \+ string_concat(_, ".", T)
    ->  string_concat(Last, ".", Last1),
        append(Before, [Last1], Out)
    ;   Out = Lines
    ).

		 /*******************************
		 *      SCENARIOS, UNFOLDED      *
		 *******************************/

%!  scenario_rewrite(+Lines, +Blocks, -Lines1) is det.
%
%   A scenario that states a residue's sentence of an entity — `d2 meets
%   condition c33`, a reviewer's reading carried over by the translator —
%   keeps the residue from being folded, and reads as a name rather than a
%   fact. Where the residue is translated as one rule of simple conditions,
%   the statement becomes those conditions, said of the entity:
%
%       d2 meets condition c33.   =>   d2 has a covered legal form stated in the appendix.
%
%   The program's constraints say which sentence denies which (`it must not
%   be true that a counterparty meets a condition and the counterparty fails
%   the condition`): a denial becomes `it is not the case that <condition>`,
%   of the entity — when the rule has a single condition; a denied
%   conjunction is not a list of facts, and stays as it is. The line the
%   statement came from is kept above it as a comment.
scenario_rewrite(Lines, Blocks, Out) :-
    opposite_pairs(Lines, Pairs),
    one_slot_templates(Lines, OneSlot),
    findall(Target-Conds-Noun,
            ( member(blk(_, _, _, Src, Body), Blocks),
              le_contract_assistant:residue_target(Src, Target),
              simple_single_rule(OneSlot, Body, Target, Conds, Noun) ),
            Rules),
    (   Rules == []
    ->  Out = Lines
    ;   scenario_flags(Lines, false, Flags),
        maplist(rewrite_in(Blocks, Rules, Pairs), Flags, Lines, Outs, Done),
        append(Outs, Out0),
        (   memberchk(true, Done)
        ->  drop_repeated_facts(Out0, [], Out)     % residues often share a condition
        ;   Out = Out0
        )
    ).

%   For each line, whether it is in a scenario: from a header that opens one
%   (`scenario ... is:`) to the next unindented line that ends with a colon
%   or the next section's header.
scenario_flags([], _, []).
scenario_flags([L|Ls], In0, [In|Ins]) :-
    (   \+ le_contract_assistant:comment_line(L), indent_of(L, 0),
        le_contract_assistant:sentence_words(L, [W|_]),
        normalize_space(string(T), L), string_concat(_, ":", T)
    ->  ( class_member(scenario, W) -> In = false, In1 = true ; In = false, In1 = false )
    ;   In = In0, In1 = In0
    ),
    scenario_flags(Ls, In1, Ins).

rewrite_in(Blocks, Rules, Pairs, true, Line, Out, Done) :- !,
    rewrite_line(Blocks, Rules, Pairs, Line, Out, Done).
rewrite_in(_, _, _, false, Line, [Line], false).

%   A statement repeated within one paragraph (a scenario), dropped; a blank
%   line starts the next paragraph.
drop_repeated_facts([], _, []).
drop_repeated_facts([L|Ls], Seen, Out) :-
    (   le_contract_assistant:blank_line(L)
    ->  Out = [L|More], drop_repeated_facts(Ls, [], More)
    ;   \+ le_contract_assistant:comment_line(L), indent_of(L, In), In > 0,
        normalize_space(string(K), L), string_concat(_, ".", K)
    ->  (   memberchk(K, Seen)
        ->  drop_repeated_facts(Ls, Seen, Out)
        ;   Out = [L|More], drop_repeated_facts(Ls, [K|Seen], More)
        )
    ;   Out = [L|More], drop_repeated_facts(Ls, Seen, More)
    ).

%   A block holding one rule concluding Target, whose conditions are single
%   lines about the head's noun only (no negation, no alternatives, no other
%   variable): their texts, without connectives.
simple_single_rule(OneSlot, Body, Target, Conds, Noun) :-
    exclude(le_contract_assistant:blank_line, Body, B1),
    exclude(label_line, B1, B2),
    le_contract_assistant:fill_statements(B2, Stmts),
    include([X]>>(X = stmt(_)), Stmts, [stmt([Head|CondLines])]),
    CondLines \== [],
    target_key(Target, TKey),
    rule_head(Head, TKey),
    head_noun(Head, Noun), Noun \== none,
    maplist(indent_of, CondLines, Is), min_list(Is, Base), max_list(Is, Base),
    maplist(simple_condition(OneSlot, Noun), CondLines, Conds).

simple_condition(OneSlot, Noun, Line, Text) :-
    normalize_space(string(T0), Line),
    ( string_concat(T1, ".", T0) -> true ; T1 = T0 ),
    le_contract_assistant:sentence_words(T1, [W0|_]),
    (   kw_synonym_words(and, [W0])
    ->  split_string(T1, " ", "", [_|Rest]), atomic_list_concat(Rest, ' ', TA)
    ;   \+ kw_synonym_words(or, [W0]), atom_string(TA, T1)
    ),
    atom_string(TA, Text),
    %  an instance of a template whose one slot is the head's noun: no
    %  other variable, whatever indefinite phrases its words hold
    le_contract_assistant:sentence_words(Text, Ws),
    memberchk(Ws-Noun, OneSlot).

%   The templates with a single slot, each as the words of its instance about
%   `the <noun>`, paired with that noun.
one_slot_templates(Lines, OneSlot) :-
    ( class_words(definite_article, [The|_]) -> true ; The = the ),
    findall(Ws-Noun,
            ( member(L, Lines), \+ le_contract_assistant:comment_line(L),
              split_string(L, "*", "", [Pre, Slot, Post]),
              normalize_space(string(SlotN), Slot),
              le_contract_assistant:sentence_words(SlotN, [A, Noun|_]), indefinite(A),
              ( sub_string(Post, B, _, _, ";") -> sub_string(Post, 0, B, _, Post1) ; Post1 = Post ),
              format(string(Inst), "~w~w ~w~w", [Pre, The, Noun, Post1]),
              le_contract_assistant:sentence_words(Inst, Ws) ),
            OneSlot0),
    sort(OneSlot0, OneSlot).

%   P-N: the words that state and deny a relation, from each constraint
%   `it must not be true that / a X <P> a Y / and the X <N> the Y`.
opposite_pairs(Lines, Pairs) :-
    ( kw_main_words(lps_must_not, CW) -> true ; CW = [it, must, not, be, true, that] ),
    findall(P-N,
            ( append(_, [L0, L1, L2|_], Lines),
              le_contract_assistant:sentence_words(L0, W0), W0 == CW,
              le_contract_assistant:sentence_words(L1, [A1, X|R1]), indefinite(A1),
              le_contract_assistant:sentence_words(L2, [_And, D2, X|R2]), class_member(definite_article, D2),
              append(P, [A3|_], R1), indefinite(A3), P \== [],
              append(N, [D4|_], R2), class_member(definite_article, D4), N \== [] ),
            Pairs).

%   One line: unchanged, or the facts a residue's statement stands for.
rewrite_line(Blocks, Rules, Pairs, Line, Out, Done) :-
    (   \+ le_contract_assistant:comment_line(Line),
        indent_of(Line, In), In > 0,
        normalize_space(string(T0), Line), string_concat(T1, ".", T0),
        le_contract_assistant:sentence_words(T1, LW),
        member(Target-Conds-Noun, Rules),
        le_contract_assistant:sentence_words(Target, [TA, Noun|Rest]), indefinite(TA),
        (   append(EntityWs, Rest, LW), Sign = pos
        ;   member(P-N, Pairs), append(P, Tail, Rest), append(N, Tail, NRest),
            append(EntityWs, NRest, LW), Sign = neg
        ),
        EntityWs \== [],
        entity_text(T1, EntityWs, Entity),
        ( Sign == neg -> Conds = [_] ; true )
    ->  length(Sp, In), maplist(=(' '), Sp), atomic_list_concat(Sp, Pad),
        format(string(Note), "~w% ~w", [Pad, T0]),
        (   Sign == pos
        ->  findall(F, ( member(C, Conds), of_entity(C, Noun, Entity, CE),
                         format(string(F), "~w~w.", [Pad, CE]) ), Facts)
        ;   Conds = [C], of_entity(C, Noun, Entity, CE),
            ( kw_main_words(not_the_case, NW) -> atomic_list_concat(NW, ' ', NotA) ; NotA = 'it is not the case that' ),
            format(string(F), "~w~w ~w.", [Pad, NotA, CE]), Facts = [F]
        ),
        Out = [Note|Facts], Done = true
    ;   Out = [Line], Done = false
    ),
    Blocks = Blocks.

%   The entity as the line writes it: its first words, in their own case.
entity_text(Text, EntityWs, Entity) :-
    length(EntityWs, K),
    split_string(Text, " ", " ", Ws0), exclude(==(""), Ws0, Ws),
    length(Pre, K), append(Pre, _, Ws),
    atomic_list_concat(Pre, ' ', EA), atom_string(EA, Entity).

%   A condition about `the <noun>`, said of the entity.
of_entity(Cond, Noun, Entity, Out) :-
    ( class_words(definite_article, [The|_]) -> true ; The = the ),
    format(string(Phrase), "~w ~w", [The, Noun]),
    atomic_list_concat(Parts, Phrase, Cond),
    atomic_list_concat(Parts, Entity, OutA), atom_string(OutA, Out).

