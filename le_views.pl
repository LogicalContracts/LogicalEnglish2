/** <module> Views: how a screen shows a program (docs/le_summary.md §17.10)

    A view is a section of declarative sentences about a program — which facts
    a case states and how they are grouped, which query is the result, what is
    shown beside it — read by a screen that runs the program (the executive
    view renders it with generic widgets, editor/src/le-views.ts):

        the view claim desk is:
            the title is "Passenger claim desk".
            the case is a scenario, with the documents it is stated in.
            the facts about "the booking" are
                a passenger is booked on a flight,
                the distance of a flight is a number km.
            the judgments are
                an event is beyond the actual control of a carrier.
            the result is the answer to query claim, headed by the amount.
            the result shows its citations.
            the result can be flipped.

    Nothing reasons with a view, as nothing reasons with "scenario facts
    require provenance.". Its sentence forms are keyword phrases of
    i18n/keywords.csv (category `view`), so a view is written in the program's
    language; the facts, questions and results it names are instances of the
    program's templates, read like the conditions of a rule, so a view that
    names a template, query or scenario the program lacks is reported at its
    line (view_issue/2, run by the verifier).

    The parser keeps a view's lines as tokens (le_grammar.pl, section view/4);
    record_view_source/5 splits them into sentences, and program_views/2
    compiles them against the whole loaded program — templates, queries and
    scenarios of its included resources too — into the dict the load
    response carries as `views`.
*/

:- module(le_views, [
    record_view_source/5,   % +M, +Name, +Rows, +Start, +End
    program_views/2,        % +KB, -Views:list(dict)
    view_issue/2,           % +KB, -Issue
    draft_view/2,           % +KB, -Text:string
    draft_view/3            % +KB, +NameHint:string, -Text:string
]).

:- use_module(le_i18n).
:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module(library(pcre)).

% ---------------------------------------------------------------------------
% Recording (second pass)
% ---------------------------------------------------------------------------

%!  record_view_source(+M, +Name, +Rows, +Start, +End) is det.
%
%   Rows are the view's lines (row(Tokens, S, E)); its sentences end at a full
%   stop. Recorded as le_view_source(Name, Sentences, Start, End), Sentences a
%   list of sentence(Tokens, S, E).
record_view_source(M, Name, Rows, Start, End) :-
    (   nonvar(M), M \== (-)
    ->  findall(T, ( member(row(Ts, _, _), Rows), member(T, Ts) ), Tokens0),
        exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens),
        split_sentences(Tokens, Sentences),
        assertz(M:le_view_source(Name, Sentences, Start, End))
    ;   true
    ).

split_sentences([], []) :- !.
split_sentences(Tokens, Sentences) :-
    (   append(S0, [punctuation('.', loc(_, DotEnd))|Rest], Tokens)
    ->  End = DotEnd
    ;   S0 = Tokens, Rest = [],
        last(Tokens, L), le_grammar:get_token_end(L, End)
    ),
    split_sentences(Rest, Ss),
    (   S0 = [F|_]
    ->  le_grammar:get_token_start(F, Start),
        Sentences = [sentence(S0, Start, End)|Ss]
    ;   Sentences = Ss
    ).

% ---------------------------------------------------------------------------
% Compiling
% ---------------------------------------------------------------------------

%!  program_views(+KB, -Views:list) is det.
program_views(KB, Views) :-
    (   atom(KB), KB \== none, current_predicate(KB:le_view_source/4)
    ->  catch(le_kbs:ensure_kb_language(KB), _, true),
        findall(View, ( KB:le_view_source(Name, Sents, S, E),
                        compile_view(KB, Name, Sents, S, E, View, _) ), Views)
    ;   Views = []
    ).

%!  view_issue(+KB, -Issue) is nondet.
%
%   issue(Type, Description, Fix, Start, End) for each problem of each view.
view_issue(KB, Issue) :-
    atom(KB), KB \== none,
    current_predicate(KB:le_view_source/4),
    catch(le_kbs:ensure_kb_language(KB), _, true),
    (   KB:le_view_source(Name, Sents, S, E),
        compile_view(KB, Name, Sents, S, E, _, Issues),
        member(Issue, Issues)
    ;   % two views with one name
        KB:le_view_source(Name, _, S, E),
        aggregate_all(count, KB:le_view_source(Name, _, _, _), N), N > 1,
        \+ ( KB:le_view_source(Name, _, S0, _), S0 < S ),
        issue(view_duplicate_name, [name-Name], S, E, Issue)
    ).

compile_view(KB, Name, Sents, VStart, VEnd, View, Issues) :-
    findall(D, KB:le_dict(D), Dicts),
    le_grammar:prepare_templates(Dicts, Templates),
    foldl(compile_sentence(KB, Templates, Name), Sents, st([], []), st(Items0, Issues0)),
    reverse(Items0, Items),
    reverse(Issues0, SentenceIssues),
    assemble(Items, View0),
    put_dict(_{name: Name, start: VStart, end: VEnd}, View0, View),
    whole_view_issues(KB, Name, Items, View, VStart, VEnd, WholeIssues),
    append(SentenceIssues, WholeIssues, Issues).

compile_sentence(KB, Templates, VName, sentence(Toks, S, E), st(Items, Issues), st(Items1, Issues1)) :-
    (   Toks == []
    ->  Items1 = Items, Issues1 = Issues
    ;   catch(phrase(view_sentence(Item0), Toks), _, fail)
    ->  resolve_item(KB, Templates, VName, Item0, S, E, Item, NewIssues),
        Items1 = [item(Item, S, E)|Items],
        append(NewIssues, Issues, Issues1)
    ;   sentence_text(Toks, Text),
        issue(view_unknown_sentence, [name-VName, text-Text], S, E, I),
        Items1 = Items, Issues1 = [I|Issues]
    ).

sentence_text(Toks, Text) :-
    ( catch(le_grammar:reconstruct_name(Toks, A), _, fail) -> true ; A = '' ),
    format(string(Text), "~w", [A]).

% ---------------------------------------------------------------------------
% The sentence forms (keywords of category `view`)
% ---------------------------------------------------------------------------

kw(Key) --> le_grammar:kw(Key).

view_sentence(title(T)) --> kw(view_title), string_arg(T).
view_sentence(case_scenario(true)) --> kw(view_case_scenario), comma, kw(view_with_documents).
view_sentence(case_scenario(false)) --> kw(view_case_scenario).
view_sentence(case_about(Toks)) --> kw(view_case_about), rest(Toks), { Toks \== [] }.
view_sentence(group(T, Parts)) --> kw(view_facts_about), string_arg(T), kw(view_are), list_parts(Parts).
view_sentence(judgments(Parts)) --> kw(view_judgments), list_parts(Parts).
view_sentence(other_facts(false)) --> kw(view_no_other_facts).
view_sentence(other_facts(true)) --> kw(view_other_facts).
view_sentence(sources) --> kw(view_sources).
view_sentence(interview) --> kw(view_one_at_a_time).
view_sentence(question(Inst, Q)) --> kw(view_question_for), rest(Toks),
    { append(Inst, [IsTok, doubleQuoteString(Q0, _)], Toks), Inst \== [],
      le_grammar:extract_simple_word(IsTok, W), kw_word(marker_is, W),
      atom_string(Q0, Q) }.
view_sentence(result_query(Q, Head, Unit)) --> kw(view_result_query), rest(Toks), { Toks \== [],
      split_at_commas(Toks, [QToks|Opts]), QToks \== [],
      name_of(QToks, Q),
      option_part(Opts, view_headed_by, Head),
      option_part(Opts, view_in, Unit) }.
view_sentence(result_whether(Inst)) --> kw(view_result_whether), rest(Inst), { Inst \== [] }.
view_sentence(reads(holds, T)) --> kw(view_result_reads), string_arg(T), kw(view_when_holds).
view_sentence(reads(not, T)) --> kw(view_result_reads), string_arg(T), kw(view_when_not).
view_sentence(citations) --> kw(view_citations).
view_sentence(reasons) --> kw(view_reasons).
view_sentence(stage) --> kw(view_stage).
view_sentence(missing) --> kw(view_missing).
view_sentence(flip(L)) --> kw(view_flipped), comma, kw(view_as), string_arg(L).
view_sentence(flip(null)) --> kw(view_flipped).
view_sentence(compare(Toks)) --> kw(view_compare), rest(Toks), { Toks \== [] }.
view_sentence(table(Q, T)) --> kw(view_answers_to), string_arg(Q), kw(view_listed_as), string_arg(T).
view_sentence(documents) --> kw(view_documents).
view_sentence(cases) --> kw(view_cases).
view_sentence(draft(T)) --> kw(view_draft), string_arg(T).

string_arg(S) --> [doubleQuoteString(S0, _)], { atom_string(S0, S) }.
comma --> [punctuation(',', _)].
rest(Ts, Ts, []).

kw_word(Key, W) :-
    le_i18n:kw_synonym_words(Key, [W0]), W0 == W, !.

% "A, B, C" (continued over lines): the parts between commas.
list_parts(Parts, Toks, []) :-
    Toks \== [],
    split_at_commas(Toks, Parts),
    \+ memberchk([], Parts).

split_at_commas(Toks, [P|Ps]) :-
    (   append(P, [punctuation(',', _)|Rest], Toks)
    ->  split_at_commas(Rest, Ps)
    ;   P = Toks, Ps = []
    ).

% ", headed by the code", ", in euros": the words after the keyword
option_part(Opts, Key, Value) :-
    (   member(Part, Opts),
        le_i18n:kw_synonym_words(Key, Words),
        le_grammar:tokens_word_prefix(Words, Part, After), After \== []
    ->  name_of(After, Value)
    ;   Value = null
    ).

name_of(Toks, Name) :-
    le_grammar:reconstruct_name(Toks, A),
    atom_string(A, Name).

% ---------------------------------------------------------------------------
% Resolving what a sentence names
% ---------------------------------------------------------------------------

% A template instance: the literal it reads as, the template's label, the
% instance as the program renders it, and as the view writes it (the words a
% screen shows for it: the label and the rendering put English articles on the
% placeholders, "*a lugar*", whatever the program's language).
resolve_instance(KB, Templates, Toks, inst(F/A, Label, Text, Literal, Words)) :-
    catch(le_grammar:parse_literal(Toks, Templates, [], _, Literal0, _, true), _, fail),
    strip_extra(Literal0, Literal),
    callable(Literal),
    functor(Literal, F, A),
    \+ F == unknown_template,
    catch(le_kbs:template_def(KB, F, A, Label, _, _), _, fail), !,
    (   catch(le_kbs:item_to_instance(KB, Literal, Tokens), _, fail)
    ->  copy_term(Tokens, T1), numbervars(T1, 0, _),
        le_kbs:goal_string(T1, Text)
    ;   format(string(Text), "~w", [Literal])
    ),
    sentence_text(Toks, Words).

strip_extra(le_at(G, _, _), G) :- !.
strip_extra((G, _), L) :- !, strip_extra(G, L).
strip_extra(G, G).

resolve_item(KB, T, V, group(Title, Parts), S, E, group(Title, Insts), Issues) :- !,
    resolve_parts(KB, T, V, Parts, S, E, Insts, Issues).
resolve_item(KB, T, V, judgments(Parts), S, E, judgments(Insts), Issues) :- !,
    resolve_parts(KB, T, V, Parts, S, E, Insts, Issues0),
    findall(I, ( member(inst(F/A, _, _, _, Text), Insts), \+ judged_template(KB, F, A),
                 issue(view_not_judged, [name-V, text-Text], S, E, I) ), NotJ),
    append(Issues0, NotJ, Issues).
resolve_item(KB, T, V, question(Toks, Q), S, E, question(Inst, Q), Issues) :- !,
    resolve_parts(KB, T, V, [Toks], S, E, Insts, Issues),
    ( Insts = [Inst] -> true ; Inst = none ).
resolve_item(KB, T, V, result_whether(Toks), S, E, result_whether(Inst), Issues) :- !,
    (   resolve_instance(KB, T, Toks, Inst)
    ->  Issues = []
    ;   Inst = none, sentence_text(Toks, Text),
        issue(view_unknown_template, [name-V, text-Text], S, E, I), Issues = [I]
    ).
resolve_item(KB, _, V, result_query(Q, H, U), S, E, result_query(Q, H, U), Issues) :- !,
    (   query_named(KB, Q) -> Issues = []
    ;   issue(view_unknown_query, [name-V, query-Q], S, E, I), Issues = [I]
    ).
resolve_item(KB, _, V, compare(Toks), S, E, compare(Sc), Issues) :- !,
    name_of(Toks, Sc0),
    (   scenario_named(KB, Sc0, Sc) -> Issues = []
    ;   Sc = Sc0, issue(view_unknown_scenario, [name-V, scenario-Sc0], S, E, I), Issues = [I]
    ).
resolve_item(KB, _, V, table(Q, Title), S, E, table(Q, Title), Issues) :- !,
    (   catch(le_kbs:parse_custom_query(KB, Q, _), _, fail) -> Issues = []
    ;   issue(view_bad_question, [name-V, text-Q], S, E, I), Issues = [I]
    ).
resolve_item(_, _, _, case_about(Toks), _, _, case_about(Name), []) :- !,
    name_of(Toks, Name).
resolve_item(_, _, _, Item, _, _, Item, []).

resolve_parts(KB, T, V, Parts, S, E, Insts, Issues) :-
    foldl(resolve_part(KB, T, V, S, E), Parts, [], Pairs0),
    reverse(Pairs0, Pairs),
    findall(I, member(ok(I), Pairs), Insts),
    findall(I, member(bad(I), Pairs), Issues).

resolve_part(KB, T, V, S, E, Toks, Acc, [R|Acc]) :-
    (   resolve_instance(KB, T, Toks, Inst)
    ->  R = ok(Inst)
    ;   sentence_text(Toks, Text),
        issue(view_unknown_template, [name-V, text-Text], S, E, I),
        R = bad(I)
    ).

query_named(KB, Q) :-
    current_predicate(KB:query_info/3),
    atom_string(QA, Q),
    ( KB:query_info(QA, _, _) -> true ; atom_number(QA, N), KB:query_info(N, _, _) ), !.

scenario_named(KB, Name0, Name) :-
    current_predicate(KB:scenario/2),
    atom_string(A0, Name0),
    (   KB:scenario(A0, _) -> Name = Name0
    ;   atomic_list_concat(Ws, ' ', A0), atomic_list_concat(Ws, '_', A1),
        KB:scenario(A1, _), atom_string(A1, Name)
    ), !.

judged_template(KB, F, A) :-
    catch(le_kbs:template_def(KB, F, A, _, judged, _), _, fail), !.

case_fact_template(KB, F, A) :-
    functor(G, F, A),
    catch(le_flip:changeable(KB, G), _, fail), !.

% ---------------------------------------------------------------------------
% The view as the screen reads it
% ---------------------------------------------------------------------------

assemble(Items, View) :-
    Base = _{title: null,
             case: _{kind: "scenario", documents: false, subject: null},
             groups: [], otherFacts: true, sources: false, interview: false,
             questions: [],
             result: _{query: null, whether: null, headedBy: null, unit: null,
                       holds: null, not: null},
             citations: false, reasons: false, stage: false, missing: false,
             flip: null, compare: [], tables: [], documents: false,
             cases: false, draft: null, order: []},
    foldl(apply_item, Items, Base, View).

apply_item(item(Item, _, _), V0, V) :-
    apply_(Item, V0, V1), !,
    once(item_widget(Item, W)),
    (   W == none -> V = V1
    ;   Order0 = V1.order,
        ( memberchk(W, Order0) -> Order = Order0 ; append(Order0, [W], Order) ),
        V = V1.put(order, Order)
    ).

apply_(title(T), V0, V) :- V = V0.put(title, T).
apply_(case_scenario(D), V0, V) :- V = V0.put(case, V0.case.put(_{kind: "scenario", documents: D})).
apply_(case_about(N), V0, V) :- V = V0.put(case, V0.case.put(_{subject: N})).
apply_(group(T, Insts), V0, V) :-
    maplist(inst_json, Insts, Facts),
    append(V0.groups, [_{title: T, facts: Facts, judged: false}], Gs), V = V0.put(groups, Gs).
apply_(judgments(Insts), V0, V) :-
    maplist(inst_json, Insts, Facts),
    append(V0.groups, [_{title: null, facts: Facts, judged: true}], Gs), V = V0.put(groups, Gs).
apply_(other_facts(B), V0, V) :- V = V0.put(otherFacts, B).
apply_(sources, V0, V) :- V = V0.put(sources, true).
apply_(interview, V0, V) :- V = V0.put(interview, true).
apply_(question(none, _), V, V) :- !.
apply_(question(Inst, Q), V0, V) :-
    inst_json(Inst, J0), put_dict(text, J0, Q, J),
    append(V0.questions, [J], Qs), V = V0.put(questions, Qs).
apply_(result_query(Q, H, U), V0, V) :- V = V0.put(result, V0.result.put(_{query: Q, headedBy: H, unit: U})).
apply_(result_whether(none), V, V) :- !.
apply_(result_whether(inst(_, Label, Text, _, _)), V0, V) :-
    V = V0.put(result, V0.result.put(_{whether: Text, whetherLabel: Label})).
apply_(reads(holds, T), V0, V) :- V = V0.put(result, V0.result.put(holds, T)).
apply_(reads(not, T), V0, V) :- V = V0.put(result, V0.result.put(not, T)).
apply_(citations, V0, V) :- V = V0.put(citations, true).
apply_(reasons, V0, V) :- V = V0.put(reasons, true).
apply_(stage, V0, V) :- V = V0.put(stage, true).
apply_(missing, V0, V) :- V = V0.put(missing, true).
apply_(flip(L), V0, V) :- V = V0.put(flip, _{label: L}).
apply_(compare(Sc), V0, V) :- append(V0.compare, [Sc], Cs), V = V0.put(compare, Cs).
apply_(table(Q, T), V0, V) :- append(V0.tables, [_{question: Q, title: T}], Ts), V = V0.put(tables, Ts).
apply_(documents, V0, V) :- V = V0.put(documents, true).
apply_(cases, V0, V) :- V = V0.put(cases, true).
apply_(draft(T), V0, V) :- V = V0.put(draft, T).

inst_json(inst(_, Label, Text, _, Words), _{label: Label, instance: Text, words: Words}).

% the widget a sentence brings on screen, in the order the view names them
item_widget(group(_, _), facts).
item_widget(judgments(_), facts).
item_widget(question(_, _), questions).
item_widget(interview, questions).
item_widget(result_query(_, _, _), result).
item_widget(result_whether(_), result).
item_widget(citations, citations).
item_widget(reasons, reasons).
item_widget(stage, stage).
item_widget(missing, questions).
item_widget(flip(_), whatif).
item_widget(compare(_), compare).
item_widget(table(_, _), tables).
item_widget(documents, documents).
item_widget(cases, cases).
item_widget(draft(_), draft).
item_widget(_, none).

% ---------------------------------------------------------------------------
% Checks on the whole view
% ---------------------------------------------------------------------------

whole_view_issues(KB, Name, Items, View, VS, VE, Issues) :-
    findall(I, whole_issue(KB, Name, Items, View, VS, VE, I), Issues).

% no result
whole_issue(_, Name, Items, _, VS, VE, I) :-
    \+ memberchk(item(result_query(_, _, _), _, _), Items),
    \+ memberchk(item(result_whether(_), _, _), Items),
    issue(view_no_result, [name-Name], VS, VE, I).
% a fact to state that the rules conclude
whole_issue(KB, Name, Items, _, _, _, I) :-
    member(item(Item, S, E), Items),
    ( Item = group(_, Insts) ; Item = question(Inst0, _), Inst0 \== none, Insts = [Inst0] ),
    member(inst(F/A, _, _, _, Text), Insts),
    \+ case_fact_template(KB, F, A),
    issue(view_derived_fact, [name-Name, text-Text], S, E, I).
% a sentence said twice where one counts
whole_issue(_, Name, Items, _, _, _, I) :-
    member(Kind, [title, result, case]),
    findall(S-E, ( member(item(Item, S, E), Items), once_kind(Item, Kind) ), [_, S2-E2|_]),
    issue(view_said_twice, [name-Name, kind-Kind], S2, E2, I).
% "headed by" a word the query does not ask for
whole_issue(KB, Name, Items, _, _, _, I) :-
    member(item(result_query(Q, H, _), S, E), Items),
    H \== null,
    query_named(KB, Q),
    query_text(KB, Q, QText),
    \+ headed_word_in(H, QText),
    issue(view_headed_by_unknown, [name-Name, word-H, query-Q], S, E, I).
% the stage of a program without the reserved sections
whole_issue(KB, Name, Items, _, _, _, I) :-
    member(item(stage, S, E), Items),
    \+ catch(le_sections:program_roles(KB, [_|_]), _, fail),
    issue(view_stage_without_sections, [name-Name], S, E, I).
% citations or documents of a program that cites nothing
whole_issue(KB, Name, Items, _, _, _, I) :-
    member(item(Kind, S, E), Items),
    memberchk(Kind, [citations, documents]),
    \+ cites_anything(KB),
    issue(view_nothing_cited, [name-Name], S, E, I).

once_kind(title(_), title).
once_kind(result_query(_, _, _), result).
once_kind(result_whether(_), result).
once_kind(case_scenario(_), case).
once_kind(case_about(_), case).

query_text(KB, Q, Text) :-
    atom_string(QA, Q),
    KB:query_info(QA, _, Items),
    maplist(le_kbs:item_to_le_string, Items, Ss),
    atomic_list_concat(Ss, ' and ', Text0),
    atom_string(Text0, Text).

% "the amount" is asked for by "which amount" (or "a amount", "an amount")
headed_word_in(H, QText) :-
    split_string(H, " ", "", Ws0), exclude(==(""), Ws0, Ws),
    last(Ws, Noun),
    sub_string(QText, _, _, _, Noun), !.

cites_anything(KB) :-
    (   current_predicate(KB:le_fact_provenance/4), KB:le_fact_provenance(_, _, _, _)
    ;   current_predicate(KB:le_rule_provenance/2), KB:le_rule_provenance(_, _)
    ;   current_predicate(KB:le_scenario_provenance/2), KB:le_scenario_provenance(_, _)
    ), !.

issue(Type, Pairs, S, E, issue(Type, Desc, Fix, S, E)) :-
    atom_concat(Type, '_desc', D), atom_concat(Type, '_fix', F),
    le_msg(D, Pairs, Desc),
    le_msg(F, Pairs, Fix).

% ---------------------------------------------------------------------------
% A first draft of a view for a program (the LE Assistant's "Generate LE view")
% ---------------------------------------------------------------------------

%!  draft_view(+KB, -Text:string) is det.
%
%   A view section that shows the program as it is: its case facts (the
%   scenario-element templates, or those no rule concludes) as one group, its
%   judged templates as the judgments, its first query as the result, and
%   what the program can show — citations when it cites, the stage when it has
%   the reserved sections, the documents when its scenarios name them, a flip.
%   Written in the program's language; the author edits it (group the facts,
%   name the result's heading, word the questions).
draft_view(KB, Text) :-
    draft_view(KB, "", Text).

%!  draft_view(+KB, +NameHint:string, -Text:string) is det.
%
%   ... named after the program's knowledge base or, for a program that names
%   none (a contract, say), after NameHint — the editor sends the file's name.
draft_view(KB, Hint, Text) :-
    catch(le_kbs:ensure_kb_language(KB), _, true),
    draft_name(KB, Hint, KBName),
    findall(Label-F/A, ( le_kbs:template_def(KB, F, A, Label, Kind, _),
                         Kind \== judged, case_fact_template(KB, F, A),
                         listable(Label) ), Facts0),
    findall(Label, ( le_kbs:template_def(KB, _, _, Label, judged, _), listable(Label) ), Judged0),
    sort(Facts0, Facts1), pairs_keys(Facts1, FactLabels0), sort(FactLabels0, FactLabels),
    sort(Judged0, Judged),
    (   current_predicate(KB:query_info/3), KB:query_info(Q, _, _), \+ flip_query(KB, Q)
    ->  format(string(QS), "~w", [Q])
    ;   QS = null
    ),
    phrase_of(view_open, Open), phrase_of(marker_is, Is),
    format(string(Header), "~w ~w ~w:", [Open, KBName, Is]),
    phrase_of(view_title, TitleP),
    capitalise(KBName, Cap),
    format(string(TitleL), "    ~w \"~w\".", [TitleP, Cap]),
    phrase_of(view_case_scenario, CaseP),
    (   cites_anything(KB)
    ->  phrase_of(view_with_documents, WithD), format(string(CaseL), "    ~w, ~w.", [CaseP, WithD])
    ;   format(string(CaseL), "    ~w.", [CaseP])
    ),
    Lines0 = [Header, TitleL, CaseL],
    (   FactLabels == [] -> Lines1 = Lines0
    ;   phrase_of(view_facts_about, FA), phrase_of(view_are, Are),
        maplist(instance_phrase, FactLabels, FPs),
        atomic_list_concat(FPs, ',\n        ', FList),
        le_msg(view_draft_group, [], Group),
        format(string(GL), "    ~w \"~w\" ~w\n        ~w.", [FA, Group, Are, FList]),
        append(Lines0, [GL], Lines1)
    ),
    (   Judged == [] -> Lines2 = Lines1
    ;   phrase_of(view_judgments, JP),
        maplist(instance_phrase, Judged, JPs),
        atomic_list_concat(JPs, ',\n        ', JList),
        format(string(JL), "    ~w\n        ~w.", [JP, JList]),
        append(Lines1, [JL], Lines2)
    ),
    (   QS \== null
    ->  phrase_of(view_result_query, RQ), format(string(RL), "    ~w ~w.", [RQ, QS]),
        append(Lines2, [RL], Lines3)
    ;   % no query to answer (or only flips): the program's first conclusion
        catch(le_kbs:topPredicates(KB, [Top|_]), _, fail)
    ->  phrase_of(view_result_whether, RW),
        atomic_list_concat(TParts, ' - ', Top), atomic_list_concat(TParts, '-', TopJ),
        format(string(RL), "    ~w ~w.", [RW, TopJ]),
        append(Lines2, [RL], Lines3)
    ;   Lines3 = Lines2
    ),
    findall(L, ( optional_line(KB, Key), phrase_of(Key, P), format(string(L), "    ~w.", [P]) ), Opt),
    append(Lines3, Opt, Lines),
    atomic_list_concat(Lines, '\n', A),
    atom_string(A, Text).

optional_line(KB, view_citations) :- cites_anything(KB).
optional_line(KB, view_stage) :- catch(le_sections:program_roles(KB, [_|_]), _, fail).
optional_line(_, view_reasons).
optional_line(_, view_missing).
optional_line(_, view_flipped).
optional_line(KB, view_documents) :- cites_anything(KB).

flip_query(KB, Q) :- KB:query_info(Q, le_flip(_, _), _).

% "*a person* is born in *a place*" -> "a person is born in a place"
instance_phrase(Label, Phrase) :-
    split_string(Label, "*", "", Parts),
    atomic_list_concat(Parts, '', A),
    normalize_space(string(Phrase), A).

% A template a view can list: its facts are separated by commas and its
% sentences end at a full stop, so a wording with either cannot be listed.
listable(Label) :-
    \+ sub_atom(Label, _, _, _, ','),
    \+ sub_atom(Label, _, _, _, '.').

% The view's name: the knowledge base's, else the hint's words (a file name,
% "policy-GLM-5.2" -> "policy GLM 5 2"), else "main".
draft_name(KB, _, Name) :-
    le_kbs:program_kb_name(KB, N), N \== '', N \== "", !,
    Name = N.
draft_name(_, Hint, Name) :-
    atom_string(Hint, H0),
    re_replace("[^\\p{L}\\p{N}]+"/g, " ", H0, H1),
    normalize_space(string(Name), H1),
    Name \== "", !.
draft_name(_, _, main).

phrase_of(Key, Phrase) :-
    ( le_i18n:kw_main_words(Key, Words) -> atomic_list_concat(Words, ' ', Phrase) ; Phrase = Key ).

capitalise(Name, Cap) :-
    atom_string(Name, S),
    (   sub_string(S, 0, 1, _, F), sub_string(S, 1, _, 0, R)
    ->  string_upper(F, FU), string_concat(FU, R, Cap)
    ;   Cap = S
    ).
