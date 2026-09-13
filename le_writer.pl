/** <module> The general Logical English writer: Migration IR -> LE text

    Every translator into Logical English — from Socotra product
    configurations, Oracle Intelligent Advisor rulebases, Miniscript policies,
    Solidity contracts, plain Prolog — ends with the same step: a set of
    clauses and a template dictionary become an LE document a lawyer can read
    and the LE server can run. This module is that step (extension E1 of
    InsurLE2/docs/MiggratingFromOtherSystems.md, §4.2 and §7.2). It is
    le_lps_write.pl's idea — render each literal through its template, name
    each variable from the type of the place it first appears in — taken from
    LPS internal terms to the whole of timeless LE: rules with nested
    and/or/negation, `for all cases in which`, aggregates, `otherwise`
    cascades, decision tables, provenance trailers, sections, scenarios with
    expectations, queries and residue markers.

    ## The Migration IR

    A program is `program(Header, Items)`. The IR is documented in full in
    docs/le_migration.md; in short:

        Header:  kb(Name), target(prolog|lps), comment(Text),
                 includes([Resource, ...]), provenance_required,
                 extensions(auto|true|false)
        Items:   template(F, "text with *a slot*", Additions)
                 fluent/event/action(F, Text, Additions)       (target lps)
                 rule(Head, Body, Options)   fact(Head, Options)
                 table(Name, Options, Columns, Rows)
                 section(Name)   comment(Text)   blank   raw(Text)
                 residue(Id, Options)
                 scenario(Name, Lines, Options)   query(Name, Body)
                 document(Name, Options)   view(Name, Sentences)
                 lps(InternalTerm)                              (target lps)

    The functor F of a template is the translator's own name for it; the
    literals of the IR use it (`balance(Account, Amount)`), and the writer
    renders them through the template's words. LE derives its own functor
    from the words when it reads the document back, so the translator's name
    never needs to match LE's.

    ## What the writer promises, and what it checks

    It writes the CURRENT language: decision tables where the IR has tables,
    `otherwise` cascades where it has ordered alternatives, provenance
    trailers where it has source locations — not comments standing in for
    them. Where the core grammar cannot express a nesting (a negation that
    must be the first line of a nested conjunction, say), it uses the
    `all of` / `either` blocks of the InsurLE extensions when they are
    available, and records an issue when they are not.

    Everything it cannot write is reported, never dropped silently:
    le_write/3 returns issue(Severity, Code, Message) terms. The round-trip
    tests (testing/test_le_writer.pl) check the claim that matters — that the
    document it writes reads back to the same clauses — on the example
    corpus and on plain Prolog programs.

    ## How variables are named

    From the type of the template place a variable first appears in: the
    first `person` is `a person`, the second `a second person`, and every
    later mention `the person` / `the second person`. A variable that takes
    part in arithmetic, a comparison, an aggregate or a Prolog goal also gets
    an id (`an amount A`, then `A`), because LE reads a bare word in an
    expression as a variable only when it is an id (le_summary.md §7). In a
    query the first mention is `which person`.
*/

:- module(le_writer, [
    le_write/2,                  % +IR, -Text
    le_write/3,                  % +IR, -Text, -Issues
    ir_dicts/2,                  % +IR, -Dicts
    render_ground_literal/3,     % +Dicts, +Literal, -Text
    render_constant/2,           % +Value, -Text
    template_text_dict/2,        % +Text, -dict(FA, NTs, WV)
    kb_to_ir/2,                  % +KB, -IR
    le_write_kb/2,               % +KB, -Text
    prolog_to_ir/3,              % +Terms, +Options, -IR
    prolog_file_to_ir/3          % +File, +Options, -IR
  ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).
:- use_module(library(option)).
:- use_module(library(readutil)).
:- use_module(library(csv)).
:- use_module(le_i18n).
:- use_module(le_grammar).
:- use_module(tokenizer).

:- dynamic issue_sink/1.
:- dynamic writer_word/3.        % writer_word(Key, Lang, Word): i18n/writer_words.csv

:- dynamic writer_dir/1.
:- prolog_load_context(directory, Dir), retractall(writer_dir(_)), assertz(writer_dir(Dir)).
:- initialization(load_writer_words).

%   The words the writer inserts (articles, ordinals, `which`), per
%   language, from i18n/writer_words.csv.
load_writer_words :-
    retractall(writer_word(_, _, _)),
    writer_dir(Dir),
    atomic_list_concat([Dir, '/i18n/writer_words.csv'], File),
    csv_read_file(File, [Header|Rows], [strip(true), convert(false)]),
    Header =.. [_, _|Langs],
    forall(( member(Row, Rows), Row =.. [_, Key|Cells] ),
           forall(nth1(I, Cells, Cell),
                  ( nth1(I, Langs, Lang),
                    ( Cell == '' -> true ; assertz(writer_word(Key, Lang, Cell)) ) ))).

writer_word(Key, Word) :-
    le_i18n:le_active_language(Lang),
    (   writer_word(Key, Lang, Word) -> true
    ;   writer_word(Key, en, Word)
    ).

%   s(CASP) annotations (`#pred p(X) :: '...'.`) and `not/1` as an operator,
%   for reading s(CASP) and Blawx sources (prolog_file_to_ir/3).
:- op(1150, fx, #).
:- op(1000, xfx, ::).

		 /*******************************
		 *        ENTRY POINTS          *
		 *******************************/

%!  le_write(+IR, -Text) is det.
%!  le_write(+IR, -Text, -Issues) is det.
%
%   Text is the Logical English document for the Migration IR
%   `program(Header, Items)`. Issues lists what could not be written as
%   asked: issue(Severity, Code, Message).
le_write(IR, Text) :-
    le_write(IR, Text, _).

le_write(program(Header, Items), Text, Issues) :-
    setup_call_cleanup(
        asserta(issue_sink([]), Ref),
        ( write_program(Header, Items, Text),
          collect_issues(Issues) ),
        erase(Ref)).

note(Severity, Code, Fmt-Args) :- !,
    format(string(Msg), Fmt, Args),
    note(Severity, Code, Msg).
note(Severity, Code, Msg) :-
    (   retract(issue_sink(L))
    ->  asserta(issue_sink([issue(Severity, Code, Msg)|L]))
    ;   true
    ).

collect_issues(Issues) :-
    ( issue_sink(L) -> reverse(L, Issues0) ; Issues0 = [] ),
    list_to_set(Issues0, Issues).        % one report per distinct problem

		 /*******************************
		 *     THE TEMPLATE DICTIONARY  *
		 *******************************/

%   A writer dictionary entry:
%       td(F, N, WV, NTs, Kind, Adds, Text)
%   F/N the IR functor, WV the words-and-variables list of the template (as
%   le_grammar builds it), NTs the variable-type pairs, Kind template |
%   fluent | event | action, Adds the additions, Text the declaration text.

%!  ir_dicts(+IR, -Dicts) is det.
ir_dicts(program(_, Items), Dicts) :-
    findall(TD, ( member(I, Items), item_td(I, TD) ), Dicts).

item_td(Item, TD) :-
    template_item(Item, _, _, _, Adds),
    memberchk(opposite(OText), Adds),
    %  The opposite form is a template of its own for writing a negative
    %  conclusion (the head of an `only if` rule): its LE functor is the one
    %  its words derive.
    template_text_dict(OText, dict([_|OArgs], ONTs, OWV)),
    wv_derives(OWV, OF),
    length(OArgs, N),
    TD = td(OF, N, OWV, ONTs, opposite, [], OText).
item_td(Item, td(F, N, WV, NTs, Kind, Adds, Text)) :-
    template_item(Item, Kind, F, Text, Adds),
    (   template_text_dict(Text, dict([_|Args], NTs, WV))
    ->  length(Args, N0),
        (   declared_arity(Item, N) -> true ; N = N0 ),
        (   N =:= N0 -> true
        ;   note(error, template_arity,
                 "template ~w/~w: its text '~w' has ~w place(s)"-[F, N, Text, N0]),
            fail
        )
    ;   note(error, bad_template, "template ~w: '~w' is not a template"-[F, Text]),
        fail
    ).

template_item(template(F, Text), template, F, Text, []).
template_item(template(F, Text, Adds), template, F, Text, Adds).
template_item(fluent(F, Text, Adds), fluent, F, Text, Adds).
template_item(event(F, Text, Adds), event, F, Text, Adds).
template_item(action(F, Text, Adds), action, F, Text, Adds).

declared_arity(Item, N) :-
    template_item(Item, _, F, _, Adds),
    ( memberchk(arity(N), Adds) -> true ; F = _/N ).

%!  template_text_dict(+Text, -Dict) is semidet.
%
%   The template dict LE itself builds for the declaration Text
%   ("*a person* is born in *a place* on *a date*"): dict(FA, NTs, WV).
template_text_dict(Text, dict(FA, NTs, WV)) :-
    tokenizer:tokenize(Text, Tokens0),
    exclude(is_indent, Tokens0, Tokens),
    phrase(le_grammar:template_instance(Parts), Tokens, []),
    le_grammar:process_template(Parts, FA, NTs, WV).

is_indent(indent(_, _)).

td_key(td(F0, N, _, _, _, _, _), F, N) :- ( F0 = F/_ -> true ; F = F0 ).

lookup_td(Dicts, F, N, TD) :-
    member(TD, Dicts),
    td_key(TD, F, N), !.

%   Of several templates of one functor, the one whose place types agree
%   with the type hints of the literal's variables; otherwise the first.
lookup_td_for(Dicts, G, TD) :-
    functor(G, F, N),
    findall(TD0, ( member(TD0, Dicts), td_key(TD0, F, N) ), [First|More]),
    (   More \== [], G =.. [_|Args],
        member(TD, [First|More]),
        TD = td(_, _, WV, NTs, _, _, _),
        forall(( nth1(I, Args, A), var(A), current_hint(A, HT) ),
               ( td_arg_type(WV, NTs, N, I, T0), clean_type(T0, HT) ))
    ->  true
    ;   TD = First
    ).

		 /*******************************
		 *         THE DOCUMENT         *
		 *******************************/

write_program(Header, Items, Text) :-
    option(language(Lang), Header, en),
    le_i18n:with_le_language(Lang, le_writer:write_program_(Header, Items, Text)).

write_program_(Header, Items, Text) :-
    ir_dicts(program(Header, Items), Dicts),
    option(target(Target), Header, prolog),
    kb_name(Header, KBName),
    extensions_mode(Header, Ext),
    Ctx = ctx(Dicts, Ext, Target),
    with_output_to(string(Text),
        ( write_header(Header, Target, KBName),
          write_templates(Ctx, Items),
          write_tables(Ctx, Items),
          write_kb(Ctx, KBName, Items),
          write_scenarios(Ctx, Items),
          write_queries(Ctx, Items),
          write_views(Items) )).

kb_name(Header, Name) :- ( memberchk(kb(Name), Header) -> true ; Name = program ).

%   Whether nested forms may use the InsurLE `all of` / `either` blocks.
extensions_mode(Header, Ext) :-
    option(extensions(E), Header, auto),
    (   E == auto
    ->  ( current_module(le_extensions) -> Ext = true ; Ext = false )
    ;   Ext = E
    ).

write_header(Header, Target, KBName) :-
    forall(member(comment(C), Header), write_comment_block(0, C)),
    ( memberchk(comment(_), Header) -> nl ; true ),
    kw(meta_target, MT),
    format("~w: ~w.~n", [MT, Target]),
    (   memberchk(provenance_required, Header)
    ->  kw(provenance_required, PR), format("~w.~n", [PR])
    ;   true
    ),
    nl,
    (   memberchk(includes(Rs), Header), Rs \== []
    ->  kw(kb_open, KO), kw(resources_include, RI),
        maplist(render_resource, Rs, RTs),
        atomic_list_concat(RTs, ',\n    ', RList),
        format("~w ~w ~w:~n    ~w.~n~n", [KO, KBName, RI, RList])
    ;   true
    ),
    (   memberchk(services(Ss), Header), Ss \== []
    ->  kw(kb_open, KO2), kw(services_include, SI),
        maplist(render_service, Ss, STs),
        atomic_list_concat(STs, ',\n    ', SList),
        format("~w ~w ~w:~n    ~w.~n~n", [KO2, KBName, SI, SList])
    ;   true
    ),
    forall(( member(setting(K, V), Header), lps_setting_kw(K, KK) ),
           ( kw(KK, KT), format("~w ~w.~n", [KT, V]) )),
    ( memberchk(setting(_, _), Header) -> nl ; true ).

lps_setting_kw(max_time, lps_max_time).
lps_setting_kw(max_real_time, lps_max_real_time).
lps_setting_kw(min_cycle_time, lps_min_cycle_time).

render_resource(R, T) :- format(atom(T), '~w', [R]).
render_service(service(Name, Address, Kind), T) :-
    kw(service_at, At), kw(service_as, As),
    format(atom(T), '~w ~w ~w ~w ~w', [Name, At, Address, As, Kind]).

		 /*******************************
		 *          TEMPLATES           *
		 *******************************/

write_templates(ctx(Dicts, _, Target), _Items) :-
    (   Target == lps
    ->  write_template_section(Dicts, event, events),
        write_template_section(Dicts, action, actions),
        write_template_section(Dicts, fluent, fluents)
    ;   true
    ),
    write_template_section(Dicts, template, templates).

write_template_section(Dicts, Kind, Key) :-
    include(td_kind(Kind), Dicts, Mine),
    (   Mine == []
    ->  true
    ;   kw(Key, Header),
        format("~w:~n", [Header]),
        forall(member(TD, Mine), write_template_line(TD)),
        nl
    ).

td_kind(Kind, TD) :- arg(5, TD, Kind).

write_template_line(td(_, _, _, _, _, Adds, _)) :-
    memberchk(included, Adds), !.        % declared by an included resource
write_template_line(td(_, _, _, _, _, Adds, Text)) :-
    include(real_addition, Adds, Adds1),
    maplist(addition_text, Adds1, ATs),
    atomic_list_concat(ATs, '', Suffix),
    format("    ~w~w.~n", [Text, Suffix]).

real_addition(A) :- \+ A = arity(_), \+ A = comment(_), A \== included.

addition_text(undefined, T)     :- kw(undefined, K), format(atom(T), '; ~w', [K]).
addition_text(scenario_element, T) :- addition_text(undefined, T).
addition_text(assumable, T)     :- kw(unknown, K), format(atom(T), '; ~w', [K]).
addition_text(unknown, T)       :- addition_text(assumable, T).
addition_text(judged, T)        :- kw(judged, K), format(atom(T), '; ~w', [K]).
addition_text(prepositional, T) :- kw(prepositional, K), format(atom(T), '; ~w', [K]).
addition_text(opposite(O), T)   :- kw(opposite, K), format(atom(T), '; ~w: ~w', [K, O]).
addition_text(synonym(S), T)    :- kw(synonym, K), format(atom(T), '; ~w ~w', [K, S]).
addition_text(via_service(S), T) :- kw(via_service, K), format(atom(T), '; ~w ~w', [K, S]).
addition_text(known_as(F), T)   :- kw(known_as, K), format(atom(T), '; ~w ~w', [K, F]).
addition_text(defines_global(G), T) :- kw(defines_global, K), format(atom(T), '; ~w ~w', [K, G]).

		 /*******************************
		 *            TABLES            *
		 *******************************/

write_tables(Ctx, Items) :-
    forall(member(table(Name, Opts, Columns, Rows), Items),
           write_table(Ctx, Name, Opts, Columns, Rows)).

write_table(_Ctx, Name, Opts, Columns, Rows) :-
    kw(table_open, TO),
    forall(member(comment(C), Opts), write_comment_block(0, C)),
    format("~w ~w ", [TO, Name]),
    kw(marker_is, Is),
    (   option(loaded_from(File), Opts)
    ->  kw(table_loaded_from, LF),
        format("~w ~w ~w", [Is, LF, File])
    ;   format("~w", [Is])
    ),
    option(policy(Policy), Opts, unique),
    policy_key(Policy, PK), kw(table_with, With), kw(PK, PW),
    format(", ~w ~w", [With, PW]),
    (   option(provenance(Prov), Opts), Prov \== []
    ->  kw(with_provenance, WP),
        provenance_parts(Prov, Parts),
        rule_provenance_text(Parts, PT),
        format(", ~w ~w", [WP, PT])
    ;   true
    ),
    format(":~n"),
    maplist(cell_header_text, Columns, HTs),
    (   option(loaded_from(_), Opts)
    ->  atomic_list_concat(HTs, ' | ', HLine),
        format("    ~w~n~n", [HLine])
    ;   maplist(row_texts, Rows, RTs),
        column_widths([HTs|RTs], Ws),
        write_table_row(Ws, HTs),
        forall(member(RT, RTs), write_table_row(Ws, RT)),
        nl
    ).

policy_key(first, first_match).
policy_key(unique, unique_match).
policy_key(all, all_matches).

cell_header_text(C, T) :- format(atom(T), '~w', [C]).

row_texts(Row, Texts) :- maplist(cell_text, Row, Texts).

%   A cell: a constant; `any`; or_list([...]) (alternatives); cond(Expr) with
%   Expr built from Op-Value comparisons (`>=`-1) and and/2, or/2; quote(Q)
%   for a citation column; raw(Text).
cell_text(any, T) :- !, kw(table_any, T).
cell_text(raw(T0), T) :- !, format(atom(T), '~w', [T0]).
cell_text(quote(Q), T) :- !, render_string(Q, T).
cell_text(or_list(Vs), T) :- !,
    maplist(render_constant, Vs, Ts),
    kw(or, Or), format(atom(Sep), ' ~w ', [Or]),
    atomic_list_concat(Ts, Sep, T).
cell_text(cond(E), T) :- !, cond_text(E, T).
cell_text(V, T) :- render_constant(V, T).

cond_text(and(A, B), T) :- !, cond_text(A, TA), cond_text(B, TB), kw(and, K), format(atom(T), '~w ~w ~w', [TA, K, TB]).
cond_text(or(A, B), T) :- !, cond_text(A, TA), cond_text(B, TB), kw(or, K), format(atom(T), '~w ~w ~w', [TA, K, TB]).
cond_text(Op-V, T) :- !, cell_op(Op, OT), render_constant(V, VT), format(atom(T), '~w ~w', [OT, VT]).
cond_text(E, T) :- format(atom(T), '~w', [E]).

cell_op(>=, '>=').  cell_op(=<, '<=').  cell_op(<=, '<=').
cell_op(>, '>').    cell_op(<, '<').    cell_op(=, '=').
cell_op(\=, '!=').  cell_op('!=', '!=').

column_widths(Rows, Ws) :-
    Rows = [First|_], length(First, N),
    numlist(1, N, Is),
    maplist(column_width(Rows), Is, Ws).

column_width(Rows, I, W) :-
    findall(L, ( member(R, Rows), nth1(I, R, C), atom_length(C, L) ), Ls),
    max_list(Ls, W).

padded_cell(W, C, P) :-
    atom_length(C, L), Pad is W - L,
    length(Sp, Pad), maplist(=(' '), Sp),
    atomic_list_concat([C|Sp], P).

write_table_row(Ws, Cells) :-
    maplist(padded_cell, Ws, Cells, Padded),
    atomic_list_concat(Padded, ' | ', Line0),
    trim_right(Line0, Line),
    format("    ~w~n", [Line]).

trim_right(A, T) :-
    atom_codes(A, Cs), reverse(Cs, R), drop_spaces(R, R1), reverse(R1, Cs1), atom_codes(T, Cs1).
drop_spaces([0' |T], R) :- !, drop_spaces(T, R).
drop_spaces(L, L).

		 /*******************************
		 *       THE KNOWLEDGE BASE     *
		 *******************************/

write_kb(Ctx, KBName, Items) :-
    include(ontology_fact, Items, Onto),
    (   Onto == [] -> true
    ;   kw(ontology, O),
        format("~w:~n", [O]),
        setup_call_cleanup(b_setval(le_writer_mode, fact),
                           forall(member(F, Onto), write_ontology_fact(Ctx, F)),
                           b_setval(le_writer_mode, none)),
        nl
    ),
    exclude(ontology_fact, Items, Items1),
    include(kb_item, Items1, KBItems),
    kw(kb_open, KO), kw(kb_include, KI),
    format("~w ~w ~w:~n~n", [KO, KBName, KI]),
    forall(member(I, KBItems), write_kb_item(Ctx, I)).

%   A fact marked `ontology` goes to the ontology section (`the ontology
%   is:`), where it came from.
ontology_fact(fact(H, Opts)) :- memberchk(ontology, Opts), ground(H).

write_ontology_fact(Ctx, F) :-
    ( F = fact(H, _) -> true ; F = fact(H) ),
    clause_naming(Ctx, fact, H, true, St),
    render_head(Ctx, St, H, T),
    format("    ~w.~n", [T]).

kb_item(rule(_, _)).
kb_item(rule(_, _, _)).
kb_item(fact(_)).
kb_item(fact(_, _)).
kb_item(section(_)).
kb_item(comment(_)).
kb_item(blank).
kb_item(raw(_)).
kb_item(residue(_, _)).
kb_item(document(_, _)).
kb_item(lps(_)).

write_kb_item(Ctx, rule(H, B)) :- !, write_kb_item(Ctx, rule(H, B, [])).
write_kb_item(Ctx, rule(H, B, Opts)) :- !,
    catch(write_rule(Ctx, H, B, Opts), E,
          ( message_to_codes(E, S), note(error, rule_not_written, "a rule could not be written: ~s"-[S]),
            format("% a rule the writer could not express (see the ledger)~n~n") )).
write_kb_item(Ctx, fact(H)) :- !, write_kb_item(Ctx, fact(H, [])).
write_kb_item(Ctx, fact(H, Opts)) :- !, write_fact(Ctx, H, Opts).
write_kb_item(_, section(Name)) :- !,
    kw(marker, M), kw(marker_is, Is),
    format("~w ~w ~w:~n~n", [M, Name, Is]).
write_kb_item(_, comment(C)) :- !, write_comment_block(0, C).
write_kb_item(_, blank) :- !, nl.
write_kb_item(_, raw(T)) :- !, format("~w~n~n", [T]).
write_kb_item(_, residue(Id, Opts)) :- !, write_residue(Id, Opts).
write_kb_item(_, document(Name, Opts)) :- !, write_document_facts(Name, Opts).
write_kb_item(Ctx, lps(Term)) :- !, write_lps_term(Ctx, Term).

message_to_codes(E, S) :- catch(message_to_codes_(E, S), _, format(codes(S), '~q', [E])).
message_to_codes_(E, S) :- format(codes(S), '~q', [E]).

write_comment_block(Indent, Text) :-
    split_string(Text, "\n", "", Lines),
    forall(member(L, Lines),
           ( tab(Indent), ( L == "" -> format("%~n") ; format("% ~w~n", [L]) ) )).

%   A residue marker: the source fragment no deterministic rule translated,
%   kept verbatim (as comments) where its translation belongs, between two
%   lines the Contract Assistant's residue mode recognises and fills in.
write_residue(Id, Opts) :-
    option(title(Title), Opts, ''),
    format("% RESIDUE ~w BEGIN: ~w~n", [Id, Title]),
    (   option(locator(Loc), Opts) -> format("%   source: ~w~n", [Loc]) ; true ),
    (   option(note(Note), Opts) -> write_comment_block(0, Note) ; true ),
    (   option(source(Lang, Code), Opts)
    ->  format("%   ~w:~n", [Lang]),
        split_string(Code, "\n", "", CLs),
        forall(member(CL, CLs), format("%   | ~w~n", [CL]))
    ;   true
    ),
    (   option(placeholder(P), Opts) -> format("~w~n", [P]) ; true ),
    format("% RESIDUE ~w END~n~n", [Id]).

write_document_facts(Name, Opts) :-
    render_constant(Name, NT),
    (   option(url(U), Opts)
    ->  render_string(U, UT),
        format("~w is published at ~w.~n", [NT, UT])
    ;   true
    ),
    (   option(text(P), Opts)
    ->  render_string(P, PT),
        format("the text of ~w is at ~w.~n", [NT, PT])
    ;   true
    ),
    nl.

		 /*******************************
		 *        RULES AND FACTS       *
		 *******************************/

write_rule(Ctx, Head, Body0, Opts) :-
    strip_at(Body0, Body1),
    type_hints(Body1, Hints0),
    simplify_body(Body1, Body),
    (   Body == true
    ->  write_fact(Ctx, Head, Opts)
    ;   forall(member(comment(C), Opts), write_comment_block(0, C)),
        write_rule_label(Opts),
        copy_term(Head-Body-Hints0, H-B-Hints),
        b_setval(le_writer_hints, Hints),
        clause_naming(Ctx, rule, H, B, St),
        render_head(Ctx, St, H, HT),
        kw(if, If),
        St = st(_, _, M, _), arg(1, M, Before),
        (   option(numbered(true), Opts),
            numbered_body(Ctx, St, B, Lines)
        ->  format("~w ~w:~n", [HT, If]),
            forall(member(L, Lines), format("~w~n", [L]))
        ;   setarg(1, M, Before),                % a failed numbered attempt mentioned nothing
            body_nodes(Ctx, St, B, Nodes),
            format("~w ~w~n", [HT, If]),
            write_nodes(Nodes, 4, last)
        ),
        nl
    ).

		 /*******************************
		 *       NUMBERED BODIES        *
		 *******************************/

%   A body as the numbered outline of a statute or a Word rule document
%   (le_summary.md §15.5, InsurLE extensions): `1. ...; and` / `2. either:`
%   / `2.1. ...; or` / `2.2. all of:` / `2.2.1 ...`. Each item ends with the
%   connective that joins it to the next one at its level, the last item of
%   a group with the connective of the group, and the last of all with a
%   full stop. Fails (and the rule is written unnumbered) for a body with a
%   universal or an aggregate, which have no numbered form.
numbered_body(Ctx, St, Body, Lines) :-
    (   chain(Body, or, Alts), Alts = [_, _|_]
    ->  numbered_list(Ctx, St, Alts, or, '', end, Lines)
    ;   chain(Body, and, Conjs),
        numbered_list(Ctx, St, Conjs, and, '', end, Lines)
    ).

%   The operands of a left- or right-nested chain of one connective.
chain(B, Op, Items) :-
    (   binary_conn(B, Op, L, R), \+ otherwise_pattern(B, _, _)
    ->  chain(L, Op, IL), chain(R, Op, IR), append(IL, IR, Items)
    ;   Items = [B]
    ).

numbered_list(Ctx, St, Goals, Op, Prefix, After, Lines) :-
    length(Goals, N),
    numbered_items(Goals, 1, N, Ctx, St, Op, Prefix, After, Lines).

numbered_items([], _, _, _, _, _, _, _, []).
numbered_items([G|Gs], I, N, Ctx, St, Op, Prefix, After, Lines) :-
    format(atom(D), '~w~w', [Prefix, I]),
    ( I < N -> Trail = Op ; Trail = After ),
    numbered_item(Ctx, St, G, D, Trail, L1),
    I1 is I + 1,
    numbered_items(Gs, I1, N, Ctx, St, Op, Prefix, After, L2),
    append(L1, L2, Lines).

numbered_item(Ctx, St, G, D, Trail, [Line|Sub]) :-
    format(atom(SubPrefix), '~w.', [D]),
    (   chain(G, or, Alts), Alts = [_, _|_]
    ->  kw(either, K), format(atom(Line), '~w. ~w:', [D, K]),
        numbered_list(Ctx, St, Alts, or, SubPrefix, Trail, Sub)
    ;   chain(G, and, Conjs), Conjs = [_, _|_]
    ->  kw(all_of, K), format(atom(Line), '~w. ~w:', [D, K]),
        numbered_list(Ctx, St, Conjs, and, SubPrefix, Trail, Sub)
    ;   G = not(N0), line_goal(N0)
    ->  goal_text(Ctx, St, G, T), trail_text(Trail, TT),
        format(atom(Line), '~w. ~w~w', [D, T, TT]), Sub = []
    ;   G = not(N0)
    ->  kw(not_the_case, K), format(atom(Line), '~w. ~w:', [D, K]),
        (   chain(N0, or, Alts), Alts = [_, _|_]
        ->  numbered_item(Ctx, St, N0, SubPrefix1, Trail, Sub0),
            format(atom(SubPrefix1), '~w1', [SubPrefix]), Sub = Sub0
        ;   chain(N0, and, Conjs),
            numbered_list(Ctx, St, Conjs, and, SubPrefix, Trail, Sub)
        )
    ;   line_goal(G)
    ->  goal_text(Ctx, St, G, T), trail_text(Trail, TT),
        format(atom(Line), '~w. ~w~w', [D, T, TT]), Sub = []
    ).

trail_text(end, '.').
trail_text(and, T) :- kw(and, K), format(atom(T), '; ~w', [K]).
trail_text(or, T) :- kw(or, K), format(atom(T), '; ~w', [K]).

write_rule_label(Opts) :-
    (   option(label(L), Opts)
    ->  kw(rule, R),
        (   option(provenance(P), Opts), P \== []
        ->  kw(with_provenance, WP),
            provenance_parts(P, Parts),
            rule_provenance_text(Parts, PT),
            format("~w ~w ~w ~w:~n", [R, L, WP, PT])
        ;   format("~w ~w:~n", [R, L])
        )
    ;   option(provenance(P), Opts), P \== []
    ->  % A rule can carry provenance only through its label.
        note(warning, provenance_without_label,
             "a rule's provenance needs a label to be written; it was dropped"-[])
    ;   true
    ).

write_fact(Ctx, Head0, Opts) :-
    setup_call_cleanup(b_setval(le_writer_mode, fact),
                       write_fact_(Ctx, Head0, Opts),
                       b_setval(le_writer_mode, none)).

write_fact_(Ctx, Head0, Opts) :-
    forall(member(comment(C), Opts), write_comment_block(0, C)),
    copy_term(Head0, Head),
    clause_naming(Ctx, fact, Head, true, St),
    render_head(Ctx, St, Head, HT),
    (   option(provenance(P), Opts), P \== []
    ->  provenance_parts(P, Parts),
        trailer_text(Parts, TT),
        format("~w, ~w.~n", [HT, TT])
    ;   format("~w.~n", [HT])
    ),
    (   option(blank(false), Opts) -> true ; nl ).

render_head(Ctx, St, not(H), T) :- !,     % a negative conclusion: its opposite form
    (   opposite_text(Ctx, St, H, T0) -> T = T0
    ;   render_literal(Ctx, St, H, T1),
        note(warning, negative_head, "a negated conclusion with no opposite form: ~w"-[T1]),
        T = T1
    ).
render_head(Ctx, St, H, T) :- render_literal(Ctx, St, H, T).

opposite_text(Ctx, St, H, T) :-
    Ctx = ctx(Dicts, _, _),
    functor(H, F, N),
    lookup_td(Dicts, F, N, td(_, _, _, _, _, Adds, _)),
    memberchk(opposite(OText), Adds),
    template_text_dict(OText, dict([_|OArgs], _, OWV)),
    H =.. [_|Args],
    maplist(arg_marker, Args, OArgs),
    render_wv(Ctx, St, OWV, T).

		 /*******************************
		 *      BODY -> LINE NODES      *
		 *******************************/

%   A body is written as a tree of lines, the shape le_grammar reads back:
%   node(Op, Text, Children), Op the connective the line opens with (none |
%   and | or | otherwise). Siblings fold left to right with their own
%   connectives; a line's children fold onto that line's literal — so
%   and(a, or(b, c)) is `a` / `and b` / `    or c`, and or(and(a, b), c) is
%   `a` / `and b` / `or c` (le_grammar:fold_nodes/6).

body_nodes(Ctx, St, Body, Nodes) :-
    seq(Ctx, St, Body, Nodes).

%   seq: a list of sibling nodes that folds to the body.
seq(Ctx, St, B, Nodes) :-
    otherwise_pattern(B, A, Alt), !,
    seq(Ctx, St, A, NA),
    seq(Ctx, St, Alt, NB),
    set_first_op(NB, otherwise, NB1),
    append(NA, NB1, Nodes).
seq(Ctx, St, otherwise([A]), Nodes) :- !, seq(Ctx, St, A, Nodes).
seq(Ctx, St, otherwise([A|As]), Nodes) :- !,
    seq(Ctx, St, A, NA),
    seq(Ctx, St, otherwise(As), NB),
    set_first_op(NB, otherwise, NB1),
    append(NA, NB1, Nodes).
seq(Ctx, St, B, Nodes) :-
    binary_conn(B, Op, L, R), !,
    seq(Ctx, St, L, NL),
    single(Ctx, St, R, NR),
    set_op(NR, Op, NR1),
    append(NL, [NR1], Nodes).
seq(Ctx, St, B, [N]) :-
    single(Ctx, St, B, N).

binary_conn(and(L, R), and, L, R).
binary_conn((L, R), and, L, R).
binary_conn(or(L, R), or, L, R).
binary_conn((L ; R), or, L, R) :- \+ L = (_ -> _).

set_op(node(_, T, C), Op, node(Op, T, C)).
set_first_op([N|Ns], Op, [N1|Ns]) :- set_op(N, Op, N1).

%   The `A otherwise B` pattern as LE compiles it:
%   or(A, and(not(Guard), B)), with Guard the conditions of A.
otherwise_pattern(or(A, and(not(G), B)), A, B) :-
    le_grammar:otherwise_guard(A, G0),
    strip_at(G0, G1),
    G1 =@= G, G1 = G.

%   single: ONE node that parses to the body.
single(Ctx, St, B, Node) :-
    ( binary_conn(B, _, _, _) ; otherwise_pattern(B, _, _) ; B = otherwise(_) ), !,
    compound_single(Ctx, St, B, Node).
single(Ctx, St, not(G), Node) :- !,
    kw(not_the_case, NTC),
    (   line_goal(G)
    ->  goal_text(Ctx, St, G, GT),
        format(atom(T), '~w ~w', [NTC, GT]),
        Node = node(none, T, [])
    ;   seq(Ctx, St, G, Kids),
        Node = node(none, NTC, Kids)
    ).
single(Ctx, St, forall(C, G), node(none, FA, Kids)) :- !,
    kw(forall, FA), kw(it_the_case, ITC),
    seq(Ctx, St, C, CN),
    seq(Ctx, St, G, GN),
    append(CN, [node(none, ITC, GN)], Kids).
single(Ctx, St, agg(Op, E, G, R), node(none, T, Kids)) :- !,
    aggregate_head(Ctx, St, Op, E, R, T),
    seq(Ctx, St, G, Kids).
single(Ctx, St, according_to(G, S), Node) :- !,
    single(Ctx, St, G, node(Op, T, Kids0)),
    arg_text(Ctx, St, S, ST), kw(according_to, AT),
    format(atom(ScopeLine), '~w ~w', [AT, ST]),
    append(Kids0, [node(none, ScopeLine, [])], Kids),
    Node = node(Op, T, Kids).
single(Ctx, St, G, node(none, T, [])) :-
    goal_text(Ctx, St, G, T).

%   A conjunction or disjunction that has to be ONE line with children: its
%   leftmost condition is the line, every connective up the left spine a child.
compound_single(Ctx, St, B, Node) :-
    left_spine(B, Leaf, Steps),
    (   line_goal(Leaf)
    ->  goal_text(Ctx, St, Leaf, LT),
        maplist(step_node(Ctx, St), Steps, Kids),
        Node = node(none, LT, Kids)
    ;   block_single(Ctx, St, B, Node)
    ).

%   left_spine(+Tree, -Leaf, -Steps): Tree = op_n(...op_2(Leaf, R_2)..., R_n),
%   Steps = [op_2-R_2, ..., op_n-R_n].
left_spine(B, Leaf, Steps) :-
    left_spine_(B, Leaf, [], Steps).
left_spine_(B, Leaf, Acc, Steps) :-
    otherwise_pattern(B, A, Alt), !,
    left_spine_(A, Leaf, [otherwise-Alt|Acc], Steps).
left_spine_(B, Leaf, Acc, Steps) :-
    binary_conn(B, Op, L, R), !,
    left_spine_(L, Leaf, [Op-R|Acc], Steps).
left_spine_(Leaf, Leaf, Steps, Steps).

step_node(Ctx, St, otherwise-Alt, Node) :- !,
    %  `otherwise` is a sibling-level connective, and a child list is a
    %  sibling list: the alternative's first line opens with it.
    single(Ctx, St, Alt, N0), set_op(N0, otherwise, Node).
step_node(Ctx, St, Op-R, Node) :-
    single(Ctx, St, R, N0), set_op(N0, Op, Node).

%   The leftmost condition needs children of its own (a negation block, a
%   universal, an aggregate): the whole group becomes an `all of` block (an
%   `either` block for a disjunction), from the InsurLE extensions.
block_single(ctx(D, Ext, T), St, B, Node) :-
    (   Ext == true -> true
    ;   note(warning, needs_extensions,
             "a nested group opening with a negation, a universal or an aggregate is written as an 'all of'/'either' block, which needs le_extensions.pl"-[])
    ),
    Ctx = ctx(D, Ext, T),
    (   top_connective(B, or)
    ->  kw(either, Kw), or_alternatives(B, Alts),
        maplist(single(Ctx, St), Alts, Kids)
    ;   kw(all_of, Kw), seq(Ctx, St, B, Kids)
    ),
    Node = node(none, Kw, Kids).

top_connective(B, or) :- ( B = or(_, _) ; B = (_ ; _) ), \+ otherwise_pattern(B, _, _), !.
top_connective(_, and).

or_alternatives(B, Alts) :-
    (   ( B = or(L, R) ; B = (L ; R) ), \+ otherwise_pattern(B, _, _)
    ->  or_alternatives(L, AL), or_alternatives(R, AR), append(AL, AR, Alts)
    ;   Alts = [B]
    ).

%   Goals that are written on one line with nothing nested under them.
line_goal(G) :- var(G), !, fail.
line_goal(not(G)) :- !, line_goal(G), \+ G = not(_).
line_goal(G) :- \+ binary_conn(G, _, _, _), \+ G = forall(_, _), \+ G = agg(_, _, _, _),
    \+ G = otherwise(_), \+ G = according_to(_, _), \+ otherwise_pattern(G, _, _).

aggregate_head(Ctx, St, Op, E, R, T) :-
    var_text(Ctx, St, R, RT),
    kw(is_the, IsThe), agg_key(Op, OpK), kw(OpK, OpW), kw(of_each, OfEach), kw(such_that, SuchThat),
    %  `each <element>`: the element by its id alone, and not counted as a
    %  mention, so the goal below still introduces it (`an amount A`).
    St = st(_, Names, _, _),
    (   var(E), name_info(Names, E, ni(_, _, Id)), Id \== none -> ET = Id
    ;   var(E) -> var_text(Ctx, St, E, ET)
    ;   render_constant(E, ET)
    ),
    format(atom(T), '~w ~w ~w ~w ~w ~w', [RT, IsThe, OpW, OfEach, ET, SuchThat]).

agg_key(sum, sum). agg_key(count, count). agg_key(average, average).
agg_key(min, min). agg_key(max, max).

write_nodes(Nodes, Indent, Last) :-
    length(Nodes, N),
    forall(nth1(I, Nodes, Node),
           ( ( I =:= N, Last == last -> L = last ; L = more ),
             write_node(Node, Indent, L) )).

write_node(node(Op, Text, Kids), Indent, Last) :-
    tab(Indent),
    ( Op == none -> true ; kw(Op, OW), format("~w ", [OW]) ),
    format("~w", [Text]),
    (   Kids == []
    ->  ( Last == last -> format(".~n") ; nl )
    ;   nl,
        Indent1 is Indent + 4,
        write_nodes(Kids, Indent1, Last)
    ).

		 /*******************************
		 *    NORMALISING A BODY        *
		 *******************************/

%   The source position wrappers LE puts around every literal.
strip_at(V, V) :- var(V), !.
strip_at(le_at(G, _, _), S) :- !, strip_at(G, S).
strip_at(T, S) :-
    compound(T), T =.. [Op, [each|E], G, R], agg_key(Op, _), !,
    strip_at(G, G1), S =.. [Op, [each|E], G1, R].
strip_at(T, S) :-
    compound(T), T =.. [F|Args],
    memberchk(F, [and, or, not, ',', ';', '\\+', forall, agg, according_to, le_scoped,
                  otherwise, '->']), !,
    ( F == otherwise -> Args = [L], maplist(strip_at, L, L1), S = otherwise(L1)
    ; maplist(strip_at, Args, Args1), S =.. [F|Args1] ).
strip_at(T, T).

%   LE's internal forms and Prolog's, to the IR's.
simplify_body(V, V) :- var(V), !.
simplify_body(and(T, B), S) :- inserted_goal(T), !, simplify_body(B, S).
simplify_body(and(B, T), S) :- inserted_goal(T), !, simplify_body(B, S).
simplify_body(and(true, B), S) :- !, simplify_body(B, S).
simplify_body(T, true) :- inserted_goal(T), !.
simplify_body(and(A, true), S) :- !, simplify_body(A, S).
simplify_body((A, B), S) :- !, simplify_body(and(A, B), S).
simplify_body((C -> T ; E), S) :- !,
    simplify_body(or(and(C, T), and(not(C), E)), S).
simplify_body((C -> T), S) :- !, simplify_body(and(C, T), S).
simplify_body((A ; B), S) :- !, simplify_body(or(A, B), S).
simplify_body(\+ G, S) :- !, simplify_body(not(G), S).
simplify_body(le_scoped(G, Sc), according_to(G1, Sc)) :- !, simplify_body(G, G1).
simplify_body(Agg, agg(Op, E, G1, R)) :-
    compound(Agg), Agg =.. [Op, [each|EL], G, RL], agg_key(Op, _), !,
    agg_var(EL, E), agg_var(RL, R),
    simplify_body(G, G1).
simplify_body(T, S) :-
    compound(T), T =.. [F|Args], memberchk(F, [and, or, not, forall, according_to, agg]), !,
    maplist(simplify_body, Args, Args1), S =.. [F|Args1].
simplify_body(otherwise(L), otherwise(L1)) :- !, maplist(simplify_body, L, L1).
simplify_body(X = Y, le_equal_to(X, Y)) :- !.
simplify_body(X \= Y, le_not_equal_to(X, Y)) :- !.
simplify_body(X \== Y, le_not_equal_to(X, Y)) :- !.
simplify_body(member(X, L), le_is_in(X, L)) :- !.
simplify_body(in(X, L), le_is_in(X, L)) :- !.
simplify_body(known(X), le_known(X)) :- !.
simplify_body(min(X, Y, Z), le_minimum(X, Y, Z)) :- !.
simplify_body(max(X, Y, Z), le_maximum(X, Y, Z)) :- !.
simplify_body(T, T).

%   Goals LE adds on its own when it reads a rule (the type checks of typed
%   head places), which it adds again when it reads the written rule.
inserted_goal(T) :- nonvar(T), T = le_type_check(_, _).
inserted_goal(true).

agg_var([var(_, V)], V) :- !.
agg_var([V], V) :- !.
agg_var(V, V).

		 /*******************************
		 *    NAMING THE VARIABLES      *
		 *******************************/

%   The naming state of one clause:
%       st(Mode, Names, Mentioned, Ctx)
%   Mode rule | fact | query | scenario; Names the list Var-ni(Type, Name, Id)
%   (Id none, or the id atom); Mentioned a mutable list of the variables
%   already written (setarg/3 — writing is deterministic).

clause_naming(Ctx, Mode, Head, Body, st(Mode, Names, m([]), Ctx)) :-
    term_variables(Head-Body, Vars),
    id_vars(Head-Body, IdVars1),
    prolog_local_vars(Head-Body, Locals),
    append(IdVars1, Locals, IdVars0),
    maplist(var_type(Ctx, Head-Body), Vars, Types),
    pairs_keys_values(Pairs, Vars, Types),
    words_in(Ctx, Head-Body, Words),
    append(Words, Types, Taken),             % an id must not be a type either (`a D D`)
    definite_constants(Head-Body, Reserved),
    name_vars(Pairs, IdVars0, Taken-Reserved, [], [], Names).

%   Names a variable must not take: `the policy` is a constant of the clause,
%   and a variable named `policy` would turn it into a back-reference.
definite_constants(Term, Names) :-
    findall(N, ( sub_atom_const(Term, A), atomic_list_concat([The|Rest], ' ', A),
                 Rest \== [], le_i18n:class_member(definite_article, The),
                 atomic_list_concat(Rest, ' ', N) ), Ns),
    sort(Ns, Names).

sub_atom_const(T, A) :- atom(T), !, A = T.
sub_atom_const(T, A) :- compound(T), T =.. [_|Args], member(X, Args), sub_atom_const(X, A).

var_type(Ctx, Term, V, Type) :-
    (   current_hint(V, T0)
    ->  Type = T0
    ;   typed_occurrence(Ctx, Term, V, T0)
    ->  Type = T0
    ;   writer_word(type_thing, Type)
    ).

%   Type checks LE compiled into a rule it read (le_type_check/2, at the
%   head places where two templates of one functor disagree on the type)
%   say which of those templates the rule was written with.
type_hints(B, Hints) :-
    hint_walk(B, [], Hints).

hint_walk(T, H, H) :- var(T), !.
hint_walk(le_type_check(V, Ty), H, [V-Ty|H]) :- var(V), atom(Ty), !.
hint_walk(T, H0, H) :- compound(T), !, T =.. [_|As], foldl(hint_walk, As, H0, H).
hint_walk(_, H, H).

current_hint(V, T) :-
    nb_current(le_writer_hints, Hints), is_list(Hints),
    member(V0-T, Hints), V0 == V, !.

%   The type of the first place V fills, reading the term left to right.
typed_occurrence(Ctx, Term, V, Type) :-
    sub_goal(Term, G),
    goal_arg_type(Ctx, G, V, Type), !.

sub_goal(T, G) :-
    compound(T),
    (   G = T
    ;   T =.. [_|Args], member(A, Args), sub_goal(A, G)
    ).

goal_arg_type(ctx(Dicts, _, _), G, V, Type) :-
    functor(G, _, N),
    (   lookup_td_for(Dicts, G, td(_, _, WV, NTs, _, _, _))
    ->  copy_term(WV-NTs, _),
        G =.. [_|Args],
        nth1(I, Args, A), A == V,
        td_arg_type(WV, NTs, N, I, Type0),
        clean_type(Type0, Type)
    ;   system_arg_type(G, V, Type)
    ).

%   The type of the I-th argument place of a template: the NTs entry of the
%   I-th argument variable (FA order, which is WV order of first appearance).
td_arg_type(WV, NTs, _N, I, Type) :-
    include(var, WV, Vs0), list_to_set_eq(Vs0, Vs),
    nth1(I, Vs, AV),
    member(K-T, NTs), K == AV, !,
    Type = T.

list_to_set_eq([], []).
list_to_set_eq([X|Xs], [X|Ys]) :- exclude(==(X), Xs, Xs1), list_to_set_eq(Xs1, Ys).

system_arg_type(G, V, T) :-
    G =.. [F|Args], memberchk(F, [le_gt, le_ge, le_lt, le_le, le_minimum, le_maximum,
                                  >, >=, <, =<, min, max]),
    member(A, Args), A == V, !,
    writer_word(type_number, T).
system_arg_type(le_is_days_after(A, B, C), V, T) :-
    ( A == V -> K = type_date ; B == V -> K = type_number ; C == V -> K = type_date ),
    writer_word(K, T).
system_arg_type(le_is_months_after(A, B, C), V, T) :-
    ( A == V -> K = type_date ; B == V -> K = type_number ; C == V -> K = type_date ),
    writer_word(K, T).
system_arg_type(agg(_, _, _, R), V, T) :-
    R == V, writer_word(type_number, T).

clean_type(T0, T) :-
    (   atom(T0), T0 \== any, T0 \== expr, T0 \== ''
    ->  (   catch(le_grammar:head_noun_type(T0, T1), _, fail), T1 \== ''
        ->  T = T1
        ;   T = T0
        )
    ;   writer_word(type_thing, T)
    ).

%   Variables that must be written as ids: in arithmetic, comparisons,
%   aggregates and Prolog goals.
%   Variables that appear only inside `prolog` goals: they have no template
%   place to be named after, and are written as ids. The others are written
%   in the goal as `the <name>`, which the extension resolves.
prolog_local_vars(Term, Locals) :-
    prolog_walk(Term, in, [], [], PVs, OVs),
    exclude(occurs_in_list(OVs), PVs, Locals0),
    list_to_set_eq(Locals0, Locals).

occurs_in_list(L, V) :- memberchk_eq(V, L).

prolog_walk(T, _, P, O, P, O) :- var(T), !.         % reached only through the cases below
prolog_walk(T, _, P0, O0, P, O) :-
    compound(T), ( T = prolog(G) ; T = prolog_call(G) ), !,
    term_variables(G, Vs), append(P0, Vs, P), O = O0.
prolog_walk(T, _, P0, O0, P, O) :-
    compound(T), !,
    T =.. [_|Args],
    foldl(prolog_walk_arg, Args, P0-O0, P-O).
prolog_walk(_, _, P, O, P, O).

prolog_walk_arg(A, P0-O0, P-O) :-
    (   var(A) -> P = P0, O = [A|O0]
    ;   prolog_walk(A, in, P0, O0, P, O)
    ).

%   (A walk, not findall/3: findall copies its solutions, and a copied
%   variable is a stranger to the clause.)
id_vars(Term, Vs) :-
    id_walk(Term, [], Vs0),
    list_to_set_eq(Vs0, Vs).

id_walk(T, Acc, Acc) :- var(T), !.
id_walk(T, Acc0, Acc) :-
    compound(T), !,
    ( id_args(T, Xs) -> term_variables(Xs, XVs), append(Acc0, XVs, Acc1) ; Acc1 = Acc0 ),
    T =.. [_|Args],
    foldl(id_walk, Args, Acc1, Acc).
id_walk(_, Acc, Acc).

id_args(G, Args) :-
    G =.. [F|Args],
    memberchk(F, [le_gt, le_ge, le_lt, le_le, >, >=, <, =<, le_assign, is, =:=, =\=,
                  le_minimum, le_maximum]), !.
id_args(agg(_, E, _, R), [E, R]) :- !.
id_args(G, Xs) :-
    G =.. [_|Args],
    include(arith_expr, Args, Xs), Xs \== [].

arith_expr(X) :- compound(X), X =.. [Op|Args], length(Args, N),
    (   N =:= 2, memberchk(Op, [+, -, *, /, //, mod, min, max, **, ^])
    ;   N =:= 1, memberchk(Op, [-, ceiling, floor, round, truncate, integer, abs, sign, sqrt])
    ), !.

%   Words of the templates used by the clause: an id must not be one of them.
words_in(ctx(Dicts, _, _), Term, Words) :-
    findall(W, ( sub_goal(Term, G), functor(G, F, N), lookup_td(Dicts, F, N, td(_, _, WV, _, _, _, _)),
                 member(W, WV), atom(W) ), Ws),
    sort(Ws, Words).

name_vars([], _, _, _, _, []).
name_vars([V-Type|Rest], IdVars, Taken-Reserved, Counts0, Ids0, [V-ni(Type, Name, Id)|More]) :-
    next_count(Type, Reserved, Counts0, C, Counts),
    (   ( memberchk_eq(V, IdVars) ; C > 6 ; C > 1, le_grammar:is_id(Type) )
    ->  pick_id(Type, Taken, Ids0, Id), Ids = [Id|Ids0],
        format(atom(Name), '~w ~w', [Type, Id])
    ;   Id = none, Ids = Ids0,
        count_name(C, Type, Name)
    ),
    name_vars(Rest, IdVars, Taken-Reserved, Counts, Ids, More).

%   The next ordinal for a type, skipping the names the clause's constants
%   hold (`the policy` a constant: the first policy variable is `a second
%   policy`).
next_count(Type, Reserved, Counts0, C, [Type-C|Counts1]) :-
    (   select(Type-C0, Counts0, Counts1) -> C1 is C0 + 1 ; C1 = 1, Counts1 = Counts0 ),
    skip_reserved(Type, Reserved, C1, C).

skip_reserved(Type, Reserved, C0, C) :-
    (   C0 =< 6, count_name(C0, Type, Name), memberchk(Name, Reserved)
    ->  C1 is C0 + 1, skip_reserved(Type, Reserved, C1, C)
    ;   C = C0
    ).

count_name(1, Type, Type) :- !.
count_name(C, Type, Name) :-
    (   ordinal(C, Type, Ord) -> format(atom(Name), '~w ~w', [Ord, Type])
    ;   format(atom(Name), '~w ~w', [Type, C])
    ).

memberchk_eq(X, [Y|Ys]) :- ( X == Y -> true ; memberchk_eq(X, Ys) ).

pick_id(Type, Taken, Used, Id) :-
    upcase_atom(Type, UT), sub_atom(UT, 0, 1, _, First),
    id_pool(Pool),
    (   member(Id, [First|Pool]), ok_id(Id, Taken, Used) -> true
    ;   member(A, Pool), member(B, Pool), atom_concat(A, B, Id), ok_id(Id, Taken, Used) -> true
    ).

id_pool(['N','M','K','P','Q','R','S','T','U','V','W','X','Y','Z','B','C','D','E','F','G','H','J','L']).

ok_id(Id, Taken, Used) :-
    \+ memberchk(Id, ['A', 'I', 'O']),
    \+ memberchk(Id, Used),
    downcase_atom(Id, Low), \+ memberchk(Low, Taken), \+ memberchk(Id, Taken).

%   The ordinal that tells the N-th variable of a type from the others
%   (N from 2 to 6; beyond that, an id).
ordinal(N, Ord) :- ordinal(N, thing, Ord).
ordinal(N, Type, Ord) :-
    between(2, 6, N),
    gender(Type, G),
    format(atom(Key), 'ordinal_~w_~w', [N, G]),
    writer_word(Key, Ord).

name_info(Names, V, Info) :- member(V0-Info, Names), V0 == V, !.

%   The text of one mention of a variable.
var_text(_Ctx, St, V, Text) :-
    St = st(Mode, Names, M, _),
    (   name_info(Names, V, ni(Type, Name, Id))
    ->  true
    ;   Type = thing, Name = thing, Id = none
    ),
    arg(1, M, Mentioned),
    (   memberchk_eq(V, Mentioned)
    ->  (   Id \== none -> Text = Id
        ;   definite_for(Type, The), format(atom(Text), '~w ~w', [The, Name])
        )
    ;   setarg(1, M, [V|Mentioned]),
        (   Mode == query
        ->  which_for(Type, Which), format(atom(Text), '~w ~w', [Which, Name])
        ;   article_for(Type, Name, Art),
            format(atom(Text), '~w ~w', [Art, Name])
        )
    ).

%   The indefinite article for a generated variable of this type.
article_for(Type, Name, Art) :-
    le_i18n:le_active_language(Lang),
    (   Lang == en
    ->  (   sub_atom(Name, 0, 1, _, C0), downcase_atom(C0, C),
            memberchk(C, [a, e, i, o, u])
        ->  Art = an
        ;   Art = a
        )
    ;   gender(Type, G), atom_concat(indefinite_, G, Key), writer_word(Key, Art)
    ).

definite_for(Type, Art) :-
    gender(Type, G), atom_concat(definite_, G, Key), writer_word(Key, Art).

which_for(Type, W) :-
    gender(Type, G), atom_concat(which_, G, Key), writer_word(Key, W).

%   Grammatical gender, guessed from the noun's ending (i18n/
%   writer_words.csv, feminine_endings) — for readability only: the parser
%   accepts every article of the class.
gender(Type, G) :-
    (   atom(Type), writer_word(feminine_endings, Endings),
        atomic_list_concat(Es, '|', Endings),
        head_word(Type, Noun),
        member(E, Es), E \== '', sub_atom(Noun, _, _, 0, E)
    ->  G = f
    ;   G = m
    ).

head_word(Type, W) :- atomic_list_concat(Ws, ' ', Type), last(Ws, W).

		 /*******************************
		 *     RENDERING A CONDITION    *
		 *******************************/

goal_text(Ctx, St, G, T) :- var(G), !, var_text(Ctx, St, G, T).
goal_text(Ctx, St, not(G), T) :- !,
    kw(not_the_case, NTC), goal_text(Ctx, St, G, GT), format(atom(T), '~w ~w', [NTC, GT]).
goal_text(Ctx, St, G, T) :- comparison_goal(G, X, Op, Y), !,
    expr_text(Ctx, St, X, XT), expr_text(Ctx, St, Y, YT),
    format(atom(T), '~w ~w ~w', [XT, Op, YT]).
goal_text(Ctx, St, G, T) :- assign_goal(G, X, E), !,
    arg_text(Ctx, St, X, XT), expr_text(Ctx, St, E, ET),
    format(atom(T), '~w = ~w', [XT, ET]).
goal_text(_Ctx, St, G, T) :- prolog_goal(G, PG), !,
    prolog_text(St, PG, PT), format(atom(T), 'prolog ~w', [PT]).
goal_text(Ctx, St, G, T) :-
    render_literal(Ctx, St, G, T).

comparison_goal(le_gt(X, Y), X, '>', Y).
comparison_goal(le_ge(X, Y), X, '>=', Y).
comparison_goal(le_lt(X, Y), X, '<', Y).
comparison_goal(le_le(X, Y), X, '<=', Y).
comparison_goal(X > Y, X, '>', Y).
comparison_goal(X >= Y, X, '>=', Y).
comparison_goal(X < Y, X, '<', Y).
comparison_goal(X =< Y, X, '<=', Y).

assign_goal(le_assign(X, E), X, E).
assign_goal(X is E, X, E).
assign_goal(X =:= E, X, E).

%   The word-form system templates, rendered through their i18n wording.
word_system_goal(G, Parts) :-
    G =.. [F|Args],
    system_words(F, Args, Parts).

system_words(le_equal_to, [X, Y], [arg(X), is, equal, to, arg(Y)]).
system_words(=, [X, Y], [arg(X), is, equal, to, arg(Y)]).
system_words(le_not_equal_to, [X, Y], [arg(X), is, different, from, arg(Y)]).
system_words(\=, [X, Y], [arg(X), is, different, from, arg(Y)]).
system_words(\==, [X, Y], [arg(X), is, different, from, arg(Y)]).
system_words(le_is, [X, Y], [arg(X), is, arg(Y)]).
system_words(le_known, [X], [arg(X), is, known]).
system_words(known, [X], [arg(X), is, known]).
system_words(le_is_in, [X, L], [arg(X), is, in, arg(L)]).
system_words(in, [X, L], [arg(X), is, in, arg(L)]).
system_words(le_is_days_after, [A, N, B], [arg(A), is, arg(N), days, after, arg(B)]).
system_words(le_is_months_after, [A, N, B], [arg(A), is, arg(N), months, after, arg(B)]).
system_words(le_minimum, [X, Y, Z], [the, minimum, of, arg(X), and, arg(Y), is, arg(Z)]).
system_words(min, [X, Y, Z], [the, minimum, of, arg(X), and, arg(Y), is, arg(Z)]).
system_words(le_maximum, [X, Y, Z], [the, maximum, of, arg(X), and, arg(Y), is, arg(Z)]).
system_words(max, [X, Y, Z], [the, maximum, of, arg(X), and, arg(Y), is, arg(Z)]).
system_words(is_a, [X, T], [arg(X), is, Art, type(T)]) :- ( atom(T), article_for(T, T, Art) -> true ; Art = a ).
system_words(le_published_at, [D, U], [arg(D), is, published, at, arg(U)]).
system_words(le_text_at, [D, U], [the, text, of, arg(D), is, at, arg(U)]).
system_words(le_admissible_under, [S, C], [arg(S), is, admissible, under, arg(C)]).

part_text(Ctx, St, arg(X), T) :- !, arg_text(Ctx, St, X, T).
part_text(_, _, type(T0), T) :- !, format(atom(T), '~w', [T0]).
part_text(_, _, W, W).

prolog_goal(prolog(G), G).
prolog_goal(prolog_call(G), G).

%   A Prolog goal, its LE variables written as their ids.
prolog_text(st(_, Names, M, _), G, T) :-
    copy_term(G-Names, G1-Names1),
    foldl(bind_prolog_name, Names1, 1-[], _-Subs),
    term_variables(G1, Rest), maplist(=('$VAR'('_')), Rest),
    with_output_to(atom(T0), write_term(G1, [quoted(true), numbervars(true), spacing(next_argument)])),
    foldl(substitute_placeholder, Subs, T0, T1),
    ( sub_atom(T1, 0, 1, _, '(') -> T = T1 ; format(atom(T), '(~w)', [T1]) ),
    term_variables(G, Vs), arg(1, M, Mentioned), append(Vs, Mentioned, M1), setarg(1, M, M1).

%   A variable of the goal: its id, or `the <name>` (through a placeholder
%   the Prolog writer prints as a variable name, replaced afterwards).
bind_prolog_name(V-ni(Type, Name, Id), K0-S0, K-S) :-
    (   var(V), Id \== none
    ->  V = '$VAR'(Id), K = K0, S = S0
    ;   var(V)
    ->  format(atom(PH), 'LEWPH~w', [K0]), V = '$VAR'(PH), K is K0 + 1,
        definite_for(Type, The), format(atom(Ref), '~w ~w', [The, Name]),
        S = [PH-Ref|S0]
    ;   K = K0, S = S0
    ).

substitute_placeholder(PH-Ref, T0, T) :-
    atomic_list_concat(Parts, PH, T0), atomic_list_concat(Parts, Ref, T).

%   A literal through its template.
render_literal(Ctx, St, G, T) :-
    Ctx = ctx(Dicts, _, _),
    (   callable(G), functor(G, _, N), lookup_td_for(Dicts, G, td(_, _, WV0, _, _, _, _))
    ->  copy_term(WV0, WV1),
        template_fa_vars(WV1, FAVars),
        G =.. [_|Args],
        (   length(FAVars, N) -> maplist(arg_marker, Args, FAVars) ; true ),
        render_wv(Ctx, St, WV1, T)
    ;   G = unknown_template(Tokens)
    ->  tokens_text(Tokens, T)
    ;   G = unknown_template(Tokens, _, _)
    ->  tokens_text(Tokens, T)
    ;   G = unknown_tokens(Tokens)
    ->  tokens_text(Tokens, T)
    ;   is_a_goal(Ctx, St, G, T0)
    ->  T = T0
    ;   system_dict(G, WV0)
    ->  copy_term(WV0, WV1),
        template_fa_vars(WV1, FAVars),
        G =.. [_|Args], maplist(arg_marker, Args, FAVars),
        render_wv(Ctx, St, WV1, T)
    ;   word_system_goal(G, Parts)
    ->  maplist(part_text(Ctx, St), Parts, Ts), atomic_list_concat(Ts, ' ', T)
    ;   callable(G), functor(G, F, N)
    ->  format(atom(T0), '~q', [G]),
        note(error, no_template, "no template for ~w/~w (~w)"-[F, N, T0]),
        format(atom(T), '~w', [T0])
    ;   format(atom(T), '~w', [G])
    ).

%   A built-in template of the active language (system_templates.csv), for
%   a functor the IR does not declare: `the query fails at section ...`,
%   `... is semantically similar to ...`. The symbolic comparison forms are
%   written by goal_text/4 before this is reached.
system_dict(G, WV) :-
    callable(G), functor(G, F, N),
    le_system_templates:le_system_template(dict([F|Args], _, WV)),
    length(Args, N),
    \+ ( member(W, WV), atom(W), memberchk(W, ['>=', '<=', '=<', '>', '<', '=']) ), !.

%   `X is a T` (taxonomy), with the language's own indefinite article.
is_a_goal(Ctx, St, is_a(X, T), Text) :-
    arg_text(Ctx, St, X, XT),
    (   var(T) -> arg_text(Ctx, St, T, TT), Noun = TT ; format(atom(TT), '~w', [T]), Noun = T ),
    (   catch(le_i18n:indefinite_isa_words(Noun, Words), _, fail) -> true ; Words = [is, a] ),
    atomic_list_concat(Words, ' ', IsA),
    format(atom(Text), '~w ~w ~w', [XT, IsA, TT]).

%   The words of a sentence LE could not read (an unknown_template of the
%   source), written back as they were.
tokens_text(Tokens, T) :-
    findall(W, ( member(Tk, Tokens), token_word(Tk, W) ), Ws),
    atomic_list_concat(Ws, ' ', T0),
    tidy_punctuation(T0, T).

token_word(word(W, _), W) :- !.
token_word(word(W), W) :- !.
token_word(number(N, _), N) :- !.
token_word(punct(P, _), P) :- !.
token_word(punctuation(P, _), P) :- !.
token_word(string(S, _), T) :- !, render_string(S, T).
token_word(quoteString(S, _), T) :- !, render_string(S, T).
token_word(doubleQuoteString(S, _), T) :- !, render_string(S, T).
token_word(date(D, _), T) :- !, render_constant(D, T).
token_word(var(Ws, _), T) :- !, atomic_list_concat(Ws, ' ', W), format(atom(T), '*~w*', [W]).
token_word(expr(E), T) :- !, tokens_text(E, T0), format(atom(T), '(~w)', [T0]).
token_word(list(L, _), T) :- !, maplist(tokens_text, L, Ts), atomic_list_concat(Ts, ', ', In), format(atom(T), '[~w]', [In]).
token_word(indent(_, _), _) :- !, fail.
token_word(line_comment(_, _), _) :- !, fail.
token_word(multi_comment(_, _), _) :- !, fail.
token_word(T, W) :- format(atom(W), '~w', [T]).

%   The argument variables of a template's word list, in order of first
%   appearance (which is the order of its functor's arguments).
template_fa_vars(WV, Vars) :- include(var, WV, Vs0), list_to_set_eq(Vs0, Vars).

render_wv(Ctx, St, WV, T) :-
    maplist(wv_text(Ctx, St), WV, Ts),
    exclude(==(''), Ts, Ts1),
    atomic_list_concat(Ts1, ' ', T0),
    tidy_punctuation(T0, T).

%   A template's argument places are bound to '$arg'(Value) before its words
%   are written, so a value is never mistaken for one of the words.
arg_marker(A, '$arg'(A)).

wv_text(Ctx, St, X, T) :- nonvar(X), X = '$arg'(A), !, arg_text(Ctx, St, A, T).
wv_text(Ctx, St, X, T) :- var(X), !, arg_text(Ctx, St, X, T).
wv_text(Ctx, St, X, T) :- \+ atomic(X), !, arg_text(Ctx, St, X, T).
wv_text(_, _, W, T) :- ( string(W) -> render_string(W, T) ; format(atom(T), '~w', [W]) ).

%   "a place , a date" -> "a place, a date"
tidy_punctuation(T0, T) :-
    atomic_list_concat(Parts, ' ,', T0), atomic_list_concat(Parts, ',', T1),
    T = T1.

%   A template argument: a variable, a constant, or an embedded sentence (the
%   argument of a meta template such as `*a person* says that *a sentence*`).
arg_text(Ctx, St, X, T) :- var(X), !, var_text(Ctx, St, X, T).
arg_text(Ctx, St, X, T) :-
    compound(X), \+ is_list(X), \+ X = date(_, _, _), \+ arith_expr(X), \+ X = '$VAR'(_), !,
    goal_text(Ctx, St, X, T).
arg_text(Ctx, St, X, T) :- is_list(X), \+ ground(X), !,
    maplist(arg_text(Ctx, St), X, Ts), atomic_list_concat(Ts, ', ', In),
    format(atom(T), '[~w]', [In]).
arg_text(Ctx, St, X, T) :- arith_expr(X), !, expr_text(Ctx, St, X, T).
arg_text(_, _, X, T) :- render_constant(X, T).

%   An arithmetic operand: variables as their ids.
expr_text(Ctx, St, X, T) :- var(X), !,
    St = st(_, Names, _, _),
    (   name_info(Names, X, ni(_, _, Id)), Id \== none
    ->  var_text(Ctx, St, X, T0),
        ( T0 == Id -> T = Id ; T = T0 )
    ;   var_text(Ctx, St, X, T)
    ).
expr_text(_, _, X, T) :- number(X), !, render_number(X, T).
expr_text(Ctx, St, X, T) :-
    compound(X), X =.. [Op, A, B], memberchk(Op, [+, -, *, /, //, mod]), !,
    operand_text(Ctx, St, Op, left, A, AT), operand_text(Ctx, St, Op, right, B, BT),
    format(atom(T), '~w ~w ~w', [AT, Op, BT]).
expr_text(Ctx, St, X, T) :-
    compound(X), X =.. [Fn, A], memberchk(Fn, [ceiling, floor, round, truncate, integer, abs, sign, sqrt]), !,
    expr_text(Ctx, St, A, AT),
    format(atom(T), '~w(~w)', [Fn, AT]).
expr_text(Ctx, St, -(A), T) :- !, expr_text(Ctx, St, 0 - A, T).
expr_text(Ctx, St, X, T) :- arg_text(Ctx, St, X, T).

%   Parentheses where precedence (or the non-associativity of - and /) needs
%   them.
operand_text(Ctx, St, Op, Side, X, T) :-
    expr_text(Ctx, St, X, T0),
    (   compound(X), X =.. [SubOp, _, _], memberchk(SubOp, [+, -, *, /, //, mod]),
        needs_parens(Op, SubOp, Side)
    ->  format(atom(T), '(~w)', [T0])
    ;   T = T0
    ).

prec(+, 1). prec(-, 1). prec(*, 2). prec(/, 2). prec(//, 2). prec(mod, 2).
needs_parens(Op, Sub, _) :- prec(Op, P), prec(Sub, PS), PS < P, !.
needs_parens(Op, Sub, right) :- prec(Op, P), prec(Sub, P), !.

		 /*******************************
		 *          CONSTANTS           *
		 *******************************/

%!  render_constant(+Value, -Text) is det.
%
%   A value as LE reads it back: numbers and dates as themselves, strings
%   in double quotes, lists in brackets, and atoms bare — unless LE would
%   read the bare atom as something else (a variable, a number, a
%   connective), in which case it is quoted, and a translator that cares
%   about the difference between an atom and a string is told.
render_constant(X, T) :- number(X), !, render_number(X, T).
render_constant(date(Y, M, D), T) :- integer(Y), !,
    format(atom(T), '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D]).
render_constant(X, T) :- string(X), !, render_string(X, T).
render_constant(X, T) :- is_list(X), !,
    maplist(list_element_text, X, Ts), atomic_list_concat(Ts, ', ', In),
    format(atom(T), '[~w]', [In]).
render_constant(X, T) :- atom(X), !,
    (   bare_atom_ok(X) -> T = X
    ;   note(info, quoted_constant, "the constant '~w' is written in quotes"-[X]),
        render_string(X, T)
    ).
render_constant('$VAR'(N), T) :- !, format(atom(T), '~w', [N]).
render_constant(X, T) :- format(atom(T), '~q', [X]).

%   Inside a list, a connective word does not split the element
%   ([fish fillets, prepared or preserved fish]).
list_element_text(X, T) :-
    (   atom(X), X \== '', atomic_list_concat(Ws, ' ', X), \+ member('', Ws),
        atom_codes(X, Cs), \+ ( member(C, Cs), bad_char(C) ),
        \+ catch(atom_number(X, _), _, fail),
        Ws = [W1|_], \+ le_i18n:class_member(article_narrow, W1)
    ->  T = X
    ;   render_constant(X, T)
    ).

render_number(X, T) :- integer(X), !, format(atom(T), '~d', [X]).
render_number(X, T) :- float(X), !,
    (   X =:= float_integer_part(X), abs(X) < 1.0e15
    ->  format(atom(T0), '~1f', [X])
    ;   format(atom(T1), '~15f', [X]), strip_zeros(T1, T0)
    ),
    localized_decimal(T0, T).
render_number(X, T) :- rational(X), !, F is float(X), render_number(F, T).

%   A comma-decimal language (languages.csv) writes 1,5 for 1.5.
localized_decimal(T0, T) :-
    le_i18n:le_active_language(Lang),
    (   catch(le_i18n:language_param(Lang, decimal_sep, Dec), _, fail),
        Dec \== '.', Dec \== "."
    ->  atomic_list_concat(Parts, '.', T0), atomic_list_concat(Parts, Dec, T)
    ;   T = T0
    ).

strip_zeros(T0, T) :-
    atom_codes(T0, Cs), reverse(Cs, R0),
    drop_zeros(R0, R1), reverse(R1, Cs1), atom_codes(T, Cs1).
drop_zeros([0'0|T], R) :- !, drop_zeros(T, R).
drop_zeros([0'.|T], [0'0, 0'.|T]) :- !.
drop_zeros(L, L).

render_string(S, T) :-
    format(atom(A), '~w', [S]),
    (   sub_atom(A, _, _, _, '"')
    ->  atomic_list_concat(Parts, '"', A), atomic_list_concat(Parts, '”', A1),
        format(atom(T), '"~w"', [A1])
    ;   format(atom(T), '"~w"', [A])
    ).

%   An atom LE reads back as the same atom.
bare_atom_ok(A) :-
    A \== '',
    atom_codes(A, Cs),
    \+ ( member(C, Cs), bad_char(C) ),
    atomic_list_concat(Ws, ' ', A),
    \+ member('', Ws),
    Ws = [W1|_],
    %  An indefinite phrase introduces a variable; a definite one (`the UK`)
    %  is a constant, as it was in the source.
    \+ ( Ws = [_, _|_], le_i18n:class_member(article_narrow, W1),
         \+ le_i18n:class_member(definite_article, W1) ),
    \+ ( Ws = [_, _|_], ( le_i18n:class_member(which, W1) ; le_i18n:class_member(each, W1) ) ),
    %  In a fact a connective inside a multi-word constant stays in it (the
    %  template is matched around it); in a rule it would split the line.
    \+ ( member(W, Ws), reserved_in_value(W), \+ ( in_scenario, Ws = [_, _|_], W \== W1 ) ),
    \+ catch(atom_number(A, _), _, fail),
    \+ ( Ws = [One], le_grammar:is_id(One), \+ in_scenario ),
    \+ sub_atom(A, 0, 1, _, '_').

bad_char(C) :- memberchk(C, `,.;:"'|[]()*%#{}\n\t=<>+/`).

%   In a scenario a bare id-like word (Bob, UK) is read as a constant; in a
%   rule it would be a variable.
in_scenario :- nb_current(le_writer_mode, Mode), memberchk(Mode, [scenario, fact]).

reserved_in_value(W) :-
    (   le_i18n:class_member(reserved, W)
    ;   memberchk(W, [if, and, or, unless, otherwise, either, not, that, expects])
    ), !.

		 /*******************************
		 *         PROVENANCE           *
		 *******************************/

%   Provenance in the IR is a list of according_to(Source),
%   as_stated_in(Document), at(Locator), confer(Quote), because(Reason).
provenance_parts(P, P) :- is_list(P), !.
provenance_parts(P, [P]).

trailer_text(Parts, T) :-
    findall(X, trailer_part(Parts, X), Xs),
    atomic_list_concat(Xs, ', ', T).

trailer_part(Parts, T) :- memberchk(according_to(S), Parts), render_constant(S, ST), kw(according_to, K), format(atom(T), '~w ~w', [K, ST]).
trailer_part(Parts, T) :-
    memberchk(as_stated_in(D), Parts), document_text(D, DT), kw(as_stated_in, K),
    (   memberchk(at(L), Parts), \+ memberchk(confer(_), Parts)
    ->  locator_text(L, LT), kw(at_locator, AtK), format(atom(T), '~w ~w ~w ~w', [K, DT, AtK, LT])
    ;   format(atom(T), '~w ~w', [K, DT])
    ).
trailer_part(Parts, T) :- memberchk(confer(Q), Parts), render_string(Q, QT), kw(confer, K), format(atom(T), '~w ~w', [K, QT]).
trailer_part(Parts, T) :- memberchk(because(R), Parts), render_string(R, RT), kw(because, K), format(atom(T), '~w ~w', [K, RT]).

rule_provenance_text(Parts, T) :-
    (   memberchk(as_stated_in(D), Parts) -> true ; memberchk(document(D), Parts) ),
    !,
    document_text(D, DT),
    (   memberchk(at(L), Parts), \+ memberchk(confer(_), Parts)
    ->  locator_text(L, LT), kw(at_locator, AtK), format(atom(T0), '~w ~w ~w', [DT, AtK, LT])
    ;   T0 = DT
    ),
    (   memberchk(confer(Q), Parts)
    ->  render_string(Q, QT), kw(confer, K),
        format(atom(T), '~w,~n        ~w ~w', [T0, K, QT])
    ;   T = T0
    ).
rule_provenance_text(Parts, T) :-
    trailer_text(Parts, T).

%   A document: a constant, or a quoted address/file name when its name
%   would not read back as one.
document_text(D, T) :-
    (   atom(D), bare_atom_ok(D) -> T = D
    ;   render_string(D, T)
    ).

locator_code(C, D) :- ( bad_char(C) -> D = 0'  ; D = C ).

%   A locator is plain words: brackets, dots and the like would end the
%   sentence or open a list, so they become spaces.
locator_text(L, T) :-
    format(atom(A), '~w', [L]),
    atom_codes(A, Cs),
    maplist(locator_code, Cs, Ds),
    atom_codes(A1, Ds),
    normalize_space(atom(T), A1).

		 /*******************************
		 *          SCENARIOS           *
		 *******************************/

write_scenarios(Ctx, Items) :-
    forall(member(scenario(Name, Lines, Opts), Items),
           write_scenario(Ctx, Name, Lines, Opts)).

write_scenario(Ctx, Name, Lines, Opts) :-
    forall(member(comment(C), Opts), write_comment_block(0, C)),
    kw(scenario, S), kw(marker_is, Is),
    (   option(as_stated_in(D), Opts)
    ->  document_text(D, DT), kw(as_stated_in, K),
        (   option(at(L), Opts)
        ->  locator_text(L, LT), kw(at_locator, AtK),
            format("~w ~w ~w, ~w ~w ~w ~w:~n", [S, Name, Is, K, DT, AtK, LT])
        ;   format("~w ~w ~w, ~w ~w:~n", [S, Name, Is, K, DT])
        )
    ;   format("~w ~w ~w:~n", [S, Name, Is])
    ),
    forall(member(L, Lines), write_scenario_line(Ctx, L)),
    nl.

write_scenario_line(Ctx, L) :-
    setup_call_cleanup(b_setval(le_writer_mode, scenario),
                       scenario_line(Ctx, L),
                       b_setval(le_writer_mode, none)).

scenario_line(Ctx, fact(F)) :- !, scenario_line(Ctx, fact(F, [])).
scenario_line(Ctx, fact(F, Prov)) :- !,
    scenario_literal_text(Ctx, F, T),
    (   Prov \== [], provenance_parts(Prov, Parts), Parts \== []
    ->  trailer_text(Parts, TT), format("    ~w, ~w.~n", [T, TT])
    ;   format("    ~w.~n", [T])
    ).
scenario_line(Ctx, unknown(F)) :- !,
    scenario_literal_text(Ctx, F, T),
    kw(it_is, ItIs), kw(whether, Wh),
    format("    ~w unknown ~w ~w.~n", [ItIs, Wh, T]).
scenario_line(Ctx, expects(Q, Answers)) :- !,
    scenario_line(Ctx, expects(Q, Answers, [])).
scenario_line(Ctx, expects(Q, Answers, Unknowns)) :- !,
    maplist(answer_text(Ctx), Answers, ATs),
    kw(expects, E), kw(answers, A),
    atomic_list_concat(ATs, ', ', AList),
    (   Unknowns == []
    ->  format("    ~w ~w ~w [~w].~n", [Q, E, A, AList])
    ;   maplist(answer_text(Ctx), Unknowns, UTs), atomic_list_concat(UTs, ', ', UList),
        kw(and_unknowns, AU),
        format("    ~w ~w ~w [~w] ~w [~w].~n", [Q, E, A, AList, AU, UList])
    ).
scenario_line(Ctx, expects_changes(Q, Sets)) :- !,
    maplist(change_set_text(Ctx), Sets, STs),
    atomic_list_concat(STs, ', ', SList),
    kw(expects, E), kw(changes, C),
    format("    ~w ~w ~w [~w].~n", [Q, E, C, SList]).
scenario_line(_, comment(C)) :- !, write_comment_block(4, C).
scenario_line(_, raw(T)) :- !, format("    ~w~n", [T]).
scenario_line(Ctx, rule(H, B)) :- !,
    %  A rule stated in a scenario, written as in the knowledge base, one
    %  level in.
    b_setval(le_writer_mode, none),
    with_output_to(string(S), write_rule(Ctx, H, B, [])),
    split_string(S, "\n", "", Ls),
    forall(( member(L, Ls), L \== "" ), format("    ~w~n", [L])).
scenario_line(Ctx, F) :- scenario_line(Ctx, fact(F, [])).

change_set_text(Ctx, Set, ST) :-
    maplist(change_text(Ctx), Set, CTs), atomic_list_concat(CTs, ', ', In),
    format(atom(ST), '[~w]', [In]).

scenario_literal_text(Ctx, F, T) :-
    copy_term(F, F1),
    clause_naming(Ctx, scenario, F1, true, St),
    render_head(Ctx, St, F1, T).

%   An expected answer: a string as given, or a ground literal rendered.
answer_text(_, A, T) :- string(A), !, render_string(A, T).
answer_text(Ctx, A, T) :-
    scenario_literal_text(Ctx, A, T0), render_string(T0, T).

change_text(_, C, T) :- string(C), !, render_string(C, T).
change_text(Ctx, add(F), T) :- !, scenario_literal_text(Ctx, F, T0), format(atom(T1), 'add: ~w', [T0]), render_string(T1, T).
change_text(Ctx, remove(F), T) :- !, scenario_literal_text(Ctx, F, T0), format(atom(T1), 'remove: ~w', [T0]), render_string(T1, T).

%!  render_ground_literal(+Dicts, +Literal, -Text) is det.
%
%   A ground literal as its sentence — what an expected answer compares
%   with. Dicts is ir_dicts/2's.
render_ground_literal(Dicts, Lit, Text) :-
    Ctx = ctx(Dicts, false, prolog),
    setup_call_cleanup(asserta(issue_sink([]), Ref),
                       scenario_literal_text(Ctx, Lit, T),
                       erase(Ref)),
    atom_string(T, Text).

		 /*******************************
		 *           QUERIES            *
		 *******************************/

write_queries(Ctx, Items) :-
    forall(member(query(Name, Body), Items),
           write_query(Ctx, Name, Body)).

write_query(Ctx, Name, Body0) :-
    kw(query, Q), kw(marker_is, Is),
    format("~w ~w ~w:~n", [Q, Name, Is]),
    (   Body0 = flip(Goal0)
    ->  strip_at(Goal0, Goal1), simplify_body(Goal1, Goal), copy_term(Goal, G),
        clause_naming(Ctx, query, true, G, St),
        kw(flip_query, FQ),
        format("    ~w~n", [FQ]),
        body_nodes(Ctx, St, G, Nodes),
        write_nodes(Nodes, 8, last)
    ;   strip_at(Body0, Body1), simplify_body(Body1, Body), copy_term(Body, B),
        clause_naming(Ctx, query, true, B, St),
        body_nodes(Ctx, St, B, Nodes),
        write_nodes(Nodes, 4, last)
    ),
    nl.

write_views(Items) :-
    forall(member(view(Name, Sentences), Items),
           ( kw(view_open, VO), kw(marker_is, Is),
             format("~w ~w ~w:~n", [VO, Name, Is]),
             forall(member(S, Sentences), format("    ~w~n", [S])),
             nl )).

		 /*******************************
		 *              LPS             *
		 *******************************/

%   An LPS internal term, written by le_lps_write.pl over a scratch module
%   holding the IR's templates.
write_lps_term(ctx(Dicts, _, _), Term) :-
    lps_scratch_module(Dicts, M),
    (   catch(le_lps_write:le_lps_sentence(M, Term, S), E,
              ( print_message(error, E), fail ))
    ->  format("~w", [S])
    ;   format(atom(T), '~q', [Term]),
        note(error, lps_not_written, "an LPS term could not be written: ~w"-[T])
    ).

lps_scratch_module(Dicts, M) :-
    variant_sha1(Dicts, H), atom_concat(le_writer_lps_, H, M),
    (   current_predicate(M:le_dict/1) -> true
    ;   dynamic(M:le_dict/1), dynamic(M:le_lps_functor/2), dynamic(M:le_lps_role/2),
        forall(member(td(F0, N, WV, NTs, Kind, _Adds, _), Dicts),
               ( td_key(td(F0, N, WV, NTs, Kind, _, _), F, N),
                 le_grammar:wv_functor(WV, Derived),
                 length(Args, N), copy_term(WV-NTs, WV1-NTs1),
                 template_fa_vars(WV1, Args),
                 assertz(M:le_dict(dict([Derived|Args], NTs1, WV1, [], _, _, _))),
                 ( Derived == F -> true ; assertz(M:le_lps_functor(Derived/N, F)) ),
                 ( Kind == template -> true ; assertz(M:le_lps_role(F/N, Kind)) ) ))
    ).

		 /*******************************
		 *          KEYWORDS            *
		 *******************************/

%   The main spelling of a keyword in the active language.
kw(Key, Text) :-
    (   catch(le_i18n:kw_main_words(Key, Words), _, fail), Words \== []
    ->  atomic_list_concat(Words, ' ', Text)
    ;   kw_default(Key, Text) -> true
    ;   Text = Key
    ).

kw_default(and, and).
kw_default(or, or).
kw_default(otherwise, otherwise).
kw_default(it_is, 'it is').
kw_default(whether, whether).

		 /*******************************
		 *   A LOADED KB, BACK TO LE    *
		 *******************************/

%!  le_write_kb(+KB, -Text) is det.
%
%   A loaded knowledge base module, written back as Logical English through
%   the Migration IR — the writer's own round-trip test bed.
le_write_kb(KB, Text) :-
    kb_to_ir(KB, IR),
    le_write(IR, Text).

%!  kb_to_ir(+KB, -IR) is det.
%
%   The Migration IR of a loaded knowledge base: its own templates, rules,
%   facts, tables, scenarios and queries (not those of included resources;
%   not its views).
kb_to_ir(KB, program(Header, Items)) :-
    ( catch(KB:le_kb(Name0), _, fail) -> Name = Name0 ; Name = program ),
    ( catch(KB:le_target_language(T), _, fail) -> Target = T ; Target = prolog ),
    (   current_predicate(KB:le_provenance_required/0), KB:le_provenance_required
    ->  PR = [provenance_required] ; PR = [] ),
    ( catch(KB:le_lang(L), _, fail) -> Lang = [language(L)] ; Lang = [] ),
    findall(R, ( current_predicate(KB:le_included_resource/3), KB:le_included_resource(R, _, _) ), Rs0),
    list_to_set(Rs0, Rs),
    ( Rs == [] -> Inc = [] ; Inc = [includes(Rs)] ),
    append([[kb(Name), target(Target)], Lang, PR, Inc], Header),
    kb_templates(KB, Templates),
    kb_tables(KB, Tables),
    kb_clauses(KB, Clauses),
    kb_scenarios(KB, Scenarios),
    kb_queries(KB, Queries),
    append([Templates, Tables, Clauses, Scenarios, Queries], Items).

own_range(Start) :- integer(Start), Start < 10000000.     % not in an included resource

kb_templates(KB, Items) :-
    findall(Start-template(F, Text, Adds1),
            ( current_predicate(KB:le_dict/1),
              clause(KB:le_dict(D), true, Ref),
              D = dict([F|Args], NTs, WV, Globals, Opp, Prep, Unknown),
              \+ le_system_templates:le_system_template(dict([F|Args], _, _)),
              wv_derives(WV, F),                             % the main dict, not a synonym
              catch(KB:le_source_info(Ref, Start, _, template), _, fail),
              wv_template_text(WV, NTs, Text),
              length(Args, N),
              template_additions(KB, F, N, Args, Globals, Opp, Prep, Unknown, Adds),
              ( own_range(Start) -> Adds1 = Adds ; Adds1 = [included|Adds] ) ),
            Pairs),
    keysort(Pairs, Sorted),
    %  A template with an opposite is two dicts from one declaration (one
    %  source range), the main one asserted first.
    first_per_key(Sorted, Items).

%   The functor LE derives from a template's words: its words and numbers,
%   joined with '_' (le_grammar:extract_functor/2), punctuation left out.
wv_derives(WV, F) :-
    include(functor_part, WV, Parts),
    Parts \== [],
    atomic_list_concat(Parts, '_', F).

functor_part(X) :- atom(X), \+ le_grammar:is_punct(X).
functor_part(X) :- number(X).

first_per_key([], []).
first_per_key([K-V|Rest], [V|Vs]) :-
    exclude(same_key(K), Rest, Rest1),
    first_per_key(Rest1, Vs).

same_key(K, K2-_) :- K2 == K.

wv_template_text(WV, NTs, Text) :-
    maplist(wv_template_part(NTs), WV, Ts),
    atomic_list_concat(Ts, ' ', T0),
    tidy_punctuation(T0, Text).

wv_template_part(NTs, X, T) :-
    (   var(X)
    ->  ( member(K-Ty, NTs), K == X -> true ; Ty = thing ),
        slot_text(Ty, T)
    ;   string(X) -> format(atom(T), '"~w"', [X])
    ;   format(atom(T), '~w', [X])
    ).

slot_text(Type, T) :- article_for(Type, Type, Art), format(atom(T), '*~w ~w*', [Art, Type]).

template_additions(KB, F, N, Args, Globals, Opp, Prep, Unknown, Adds) :-
    findall(A,
            (   Unknown == scenario_element, A = undefined
            ;   Unknown == unknown, A = assumable
            ;   Unknown == judged, A = judged
            ;   Prep == prepositional, A = prepositional
            ;   member(G, Globals), A = defines_global(G)
            ;   nonvar(Opp), opposite_dict_text(KB, Opp, Args, OT), A = opposite(OT)
            ;   synonym_text(KB, F, N, ST), A = synonym(ST)
            ;   current_predicate(KB:le_service_template/2), KB:le_service_template(F/N, S), A = via_service(S)
            ;   current_predicate(KB:le_lps_functor/2), KB:le_lps_functor(F/N, KA), A = known_as(KA)
            ),
            Adds).

opposite_dict_text(KB, Opp, _Args, Text) :-
    functor(Opp, OF, ON),
    KB:le_dict(dict([OF|_], NTs, WV, _, _, _, _)),
    length(WVArgs, ON), template_fa_vars(WV, WVArgs), !,
    wv_template_text(WV, NTs, Text).

synonym_text(KB, F, N, Text) :-
    KB:le_dict(dict([F|Args], NTs, WV, _, _, _, _)),
    length(Args, N),
    \+ wv_derives(WV, F),
    wv_template_text(WV, NTs, Text).

kb_tables(KB, Items) :-
    findall(table(Name, [policy(P)|Load], Columns, Rows),
            ( current_predicate(KB:le_table/6),
              KB:le_table(Name, Policy, _, Columns, _IdCol, Source),
              policy_key(P, PK), policy_word(PK, Policy),
              ( Source = csv(File) -> Load = [loaded_from(File)] ; Load = [] ),
              findall(Row, ( current_predicate(KB:le_table_row/6),
                             KB:le_table_row(Name, _, RowId, Cells, _, _),
                             table_row_cells(RowId, Cells, Columns, Row) ), Rows) ),
            Items).

policy_word(PK, P) :- policy_key(P, PK), !.
policy_word(P, P) :- policy_key(P, _), !.

table_row_cells(RowId, Cells, Columns, Row) :-
    maplist(ir_cell, Cells, Cs),
    length(Columns, NC), length(Cs, NCs),
    ( NC =:= NCs + 1 -> Row = [RowId|Cs] ; Row = Cs ).

ir_cell(any, any) :- !.
ir_cell(val(V), C) :- !, ( V = or_list(_) -> C = V ; C = V ).
ir_cell(test(E), cond(C)) :- !, ir_test(E, C).
ir_cell(C, raw(C)).

ir_test(cmp(Op, V), Op-V) :- !.
ir_test(and(A, B), and(CA, CB)) :- !, ir_test(A, CA), ir_test(B, CB).
ir_test(or(A, B), or(CA, CB)) :- !, ir_test(A, CA), ir_test(B, CB).
ir_test(E, E).

kb_clauses(KB, Items) :-
    findall(Start-Item,
            ( current_predicate(KB:F/N),
              ( \+ le_kbs:is_system_predicate(F/N) ; F/N == is_a/2 ),
              \+ memberchk(F/N, [le_target_language/1, le_lang/1, le_kb_module_fact/1,
                                 le_program_base/1, le_tests_skipped/0, le_dict_fa/3]),
              functor(H, F, N),
              le_kbs:kb_own_predicate(KB, H),
              clause(KB:H, B, Ref),
              \+ B = le_table(_, _),
              catch(KB:le_source_info(Ref, Start, _, ID), _, fail),
              own_range(Start),
              clause_item(KB, H, B, ID, Start, Item) ),
            Pairs0),
    keysort(Pairs0, Pairs),
    sections_in(KB, Pairs, Items).

clause_item(KB, H, true, _, Start, fact(H, Opts)) :- !,
    fact_opts(KB, Start, Opts).
clause_item(KB, H, B, ID, _, rule(H, B, Opts)) :-
    rule_opts(KB, ID, Opts).

fact_opts(KB, Start, Opts) :-
    (   current_predicate(KB:ontology/1),
        clause(KB:ontology(_), true, Ref),
        catch(KB:le_source_info(Ref, OS, OE, ontology), _, fail),
        Start >= OS, Start =< OE
    ->  Opts = [ontology]
    ;   Opts = []
    ).

rule_opts(KB, ID, Opts) :-
    (   atom(ID), \+ sub_atom(ID, 0, _, _, rule_), \+ sub_atom(ID, 0, _, _, lps_)
    ->  (   current_predicate(KB:le_rule_provenance/2), KB:le_rule_provenance(ID, Prov)
        ->  prov_ir(Prov, P), Opts0 = [label(ID), provenance(P)]
        ;   Opts0 = [label(ID)]
        )
    ;   Opts0 = []
    ),
    (   current_predicate(KB:le_source_element/3), KB:le_source_element(ID, _, _)
    ->  Opts = [numbered(true)|Opts0]
    ;   Opts = Opts0
    ).

prov_ir(prov(S, D, L, R), P) :-
    findall(X, ( S \== none, X = according_to(S)
               ; D = doc(Const, _), X = as_stated_in(Const)
               ; L \== none, ( le_provenance:quoted_text(L, Q) -> X = confer(Q) ; X = at(L) )
               ; R \== none, X = because(R) ), P).

%   Section markers, where the rule's section changes.
sections_in(KB, Pairs, Items) :-
    (   current_predicate(KB:le_source_section/2), KB:le_source_section(S, _), S \== main
    ->  foldl(section_step(KB), Pairs, main-[], _-Rev), reverse(Rev, Items)
    ;   pairs_values(Pairs, Items)
    ).

section_step(KB, _-Item, Cur-Acc, New-Acc1) :-
    item_id(Item, ID),
    (   nonvar(ID), KB:le_source_section(S, ID) -> New = S ; New = Cur ),
    (   New \== Cur -> Acc1 = [Item, section(New)|Acc] ; Acc1 = [Item|Acc] ).

item_id(rule(_, _, Opts), ID) :- ( memberchk(label(ID), Opts) -> true ; true ).
item_id(fact(_, _), _).

kb_scenarios(KB, Items) :-
    findall(Start-scenario(Name, Lines, []),
            ( current_predicate(KB:scenario/2),
              clause(KB:scenario(Name, Terms), true, Ref),
              catch(KB:le_source_info(Ref, Start, _, _), _, Start = 0),
              scenario_lines(KB, Name, Terms, Lines) ),
            Pairs),
    keysort(Pairs, Sorted), pairs_values(Sorted, Items).

scenario_lines(KB, Name, Terms, Lines) :-
    findall(L, ( member(T, Terms), scenario_term_line(KB, T, L) ), Facts),
    findall(expects(Q, As, Us), ( current_predicate(KB:le_expected/4), KB:le_expected(Q, Name, As0, Us0),
                                  maplist(expect_string, As0, As), maplist(expect_string, Us0, Us) ), E1),
    findall(expects_changes(Q, Sets), ( current_predicate(KB:le_expected_changes/3),
                                        KB:le_expected_changes(Q, Name, Sets0),
                                        maplist(maplist(expect_string), Sets0, Sets) ), E2),
    append([Facts, E1, E2], Lines).

scenario_term_line(KB, fact_with_source(F0, S, E), Line) :- !,
    (   F0 \= (_ :- _), current_predicate(KB:le_fact_provenance/4),
        KB:le_fact_provenance(S, E, _, Prov)
    ->  prov_ir(Prov, P), Line = fact(F0, P)
    ;   scenario_term_line(KB, F0, Line)
    ).
scenario_term_line(_, (H :- B), rule(H, B)) :- !.
scenario_term_line(_, unknown(F), unknown(F)) :- !.
scenario_term_line(_, le_unknown(F), unknown(F)) :- !.
scenario_term_line(_, F, fact(F)).

expect_string(string(S, _), S1) :- !, expect_string(S, S1).
expect_string(S, S1) :- ( string(S) -> S1 = S ; atom(S) -> atom_string(S, S1) ; term_string(S, S1) ).

kb_queries(KB, Items) :-
    findall(Start-query(Name, Goal),
            ( current_predicate(KB:query_info/3),
              clause(KB:query_info(Name, Goal0, _), true, Ref),
              catch(KB:le_source_info(Ref, Start, _, _), _, Start = 0),
              query_goal(Goal0, Goal) ),
            Pairs),
    keysort(Pairs, Sorted), pairs_values(Sorted, Items).

query_goal(le_flip(G, _), flip(G)) :- !.
query_goal(G, G).

		 /*******************************
		 *   PLAIN PROLOG, TO LE (§5.7) *
		 *******************************/

%!  prolog_file_to_ir(+File, +Options, -IR) is det.
%
%   A Prolog (or s(CASP)) file as Migration IR. s(CASP) `#pred` annotations
%   supply the template wording (`#pred parent(X, Y) :: '@(X) is a parent
%   of @(Y)'.`); every other predicate gets the naive verbalisation, its
%   places named after the variables of its first clause.
prolog_file_to_ir(File, Options, IR) :-
    read_prolog_terms(File, Terms),
    prolog_to_ir(Terms, Options, IR).

read_prolog_terms(File, Terms) :-
    setup_call_cleanup(
        ( open(File, read, In), push_scasp_ops ),
        read_terms(In, Terms),
        ( close(In), pop_scasp_ops )).

read_terms(In, Terms) :-
    read_term(In, T, [variable_names(Bs), module(le_writer_ops)]),
    (   T == end_of_file -> Terms = []
    ;   Terms = [T-Bs|Rest], read_terms(In, Rest)
    ).

push_scasp_ops :-
    op(1150, fx, le_writer_ops:(#)),
    op(1100, fx, le_writer_ops:pred),
    op(1000, xfx, le_writer_ops:(::)),
    op(900, fy, le_writer_ops:not).
pop_scasp_ops.

%!  prolog_to_ir(+Terms, +Options, -IR) is det.
%
%   Terms are clauses, each optionally paired with its variable names
%   (Clause-Bindings, as read_term/3's variable_names gives them). Options:
%   kb(Name); queries([Name-Goal, ...]).
prolog_to_ir(Terms0, Options, program(Header, Items)) :-
    maplist(term_bindings, Terms0, Terms),
    option(kb(Name), Options, prolog_program),
    Header = [kb(Name), target(prolog),
              comment("Translated from Prolog by le_writer:prolog_to_ir/3.")],
    findall(Spec-Words, ( member(T-Bs, Terms), pred_annotation(T, Spec, Words),
                          maplist(bind_var_name, Bs) ), Annotated),
    program_predicates(Terms, Preds),
    maplist(predicate_template(Terms, Annotated), Preds, Templates),
    findall(Item, ( member(C-_, Terms), prolog_clause_item(C, Item) ), Clauses),
    option(queries(Qs), Options, []),
    findall(query(QN, QG), member(QN-QG, Qs), Queries),
    append([Templates, Clauses, Queries], Items).

bind_var_name(Name = Var) :- ( var(Var) -> Var = Name ; true ).

term_bindings(T-Bs, T-Bs) :- is_list(Bs), !.
term_bindings(T, T-[]).

pred_annotation((# pred(Spec :: W)), Spec, W) :- !.
pred_annotation((#(pred(Spec :: W))), Spec, W).

prolog_clause_item(C, _) :- ( C = (:- _) ; C = (# _) ), !, fail.
prolog_clause_item((H :- B), rule(H, B2, [])) :- !, prolog_body(B, B1), left_assoc(B1, B2).
prolog_clause_item(H, fact(H, [])) :- callable(H).

prolog_body(V, V) :- var(V), !.
prolog_body((A, B), and(A1, B1)) :- !, prolog_body(A, A1), prolog_body(B, B1).
prolog_body((C -> T ; E), or(and(C1, T1), and(not(C1), E1))) :- !,
    prolog_body(C, C1), prolog_body(T, T1), prolog_body(E, E1).
prolog_body((A ; B), or(A1, B1)) :- !, prolog_body(A, A1), prolog_body(B, B1).
prolog_body(\+ G, not(G1)) :- !, prolog_body(G, G1).
prolog_body(not(G), not(G1)) :- !, prolog_body(G, G1).
prolog_body(forall(C, G), forall(C1, G1)) :- !, prolog_body(C, C1), prolog_body(G, G1).
prolog_body(aggregate_all(count, G, R), agg(count, E, G1, R)) :- !,
    prolog_body(G, G1),
    ( term_variables(G, Vs), last(Vs, E) -> true ; true ).
prolog_body(aggregate_all(sum(E), G, R), agg(sum, E, G1, R)) :- !, prolog_body(G, G1).
prolog_body(aggregate_all(max(E), G, R), agg(max, E, G1, R)) :- !, prolog_body(G, G1).
prolog_body(aggregate_all(min(E), G, R), agg(min, E, G1, R)) :- !, prolog_body(G, G1).
prolog_body(member(X, L), le_is_in(X, L)) :- !.
prolog_body(X = Y, le_equal_to(X, Y)) :- !.
prolog_body(X \= Y, le_not_equal_to(X, Y)) :- !.
prolog_body(X is E, le_assign(X, E)) :- !.
prolog_body(X > Y, le_gt(X, Y)) :- !.
prolog_body(X >= Y, le_ge(X, Y)) :- !.
prolog_body(X < Y, le_lt(X, Y)) :- !.
prolog_body(X =< Y, le_le(X, Y)) :- !.
prolog_body(G, prolog(G)) :- prolog_builtin(G), !.
prolog_body(G, G).

%   (A, B, C) is and(A, and(B, C)) in Prolog; LE reads sibling lines as
%   and(and(A, B), C). The same conjunction, written the way LE reads it.
left_assoc(B, B) :- var(B), !.
left_assoc(B, L) :-
    ( B = and(_, _) ; B = or(_, _) ), !,
    functor(B, Op, 2),
    chain(B, Op, Items0),
    maplist(left_assoc, Items0, Items),
    Items = [First|Rest],
    foldl(left_step(Op), Rest, First, L).
left_assoc(B, L) :-
    compound(B), B =.. [F|Args], memberchk(F, [not, forall, agg]), !,
    maplist(left_assoc, Args, Args1), L =.. [F|Args1].
left_assoc(B, B).

left_step(Op, I, Acc, New) :- New =.. [Op, Acc, I].

prolog_builtin(G) :-
    callable(G), functor(G, F, N),
    \+ memberchk(F/N, [true/0]),
    functor(H, F, N),
    predicate_property(system:H, defined), !.

program_predicates(Terms, Preds) :-
    findall(F/N, ( member(C-_, Terms), clause_head(C, H), functor(H, F, N) ), Ps0),
    findall(F/N, ( member(C-_, Terms), C = (_ :- B), body_literal(B, L), functor(L, F, N),
                   \+ prolog_builtin(L) ), Ps1),
    findall(F/N, ( member(T-_, Terms), pred_annotation(T, Spec, _), functor(Spec, F, N) ), Ps2),
    append([Ps0, Ps1, Ps2], Ps), list_to_set(Ps, Preds).

clause_head(C, _) :- ( C = (:- _) ; C = (# _) ), !, fail.
clause_head((H :- _), H) :- !.
clause_head(H, H) :- callable(H).

body_literal(V, _) :- var(V), !, fail.
body_literal((A, B), L) :- !, ( body_literal(A, L) ; body_literal(B, L) ).
body_literal((A ; B), L) :- !, ( body_literal(A, L) ; body_literal(B, L) ).
body_literal((A -> B), L) :- !, ( body_literal(A, L) ; body_literal(B, L) ).
body_literal(\+ G, L) :- !, body_literal(G, L).
body_literal(not(G), L) :- !, body_literal(G, L).
body_literal(forall(A, B), L) :- !, ( body_literal(A, L) ; body_literal(B, L) ).
body_literal(aggregate_all(_, G, _), L) :- !, body_literal(G, L).
body_literal(G, G) :- callable(G), \+ comparison_or_builtin(G).

comparison_or_builtin(G) :- functor(G, F, _), memberchk(F, [=, \=, is, >, <, >=, =<, member, ==, \==]), !.

%   A template for F/N: the s(CASP) annotation's wording, or the naive
%   verbalisation — the functor's words between the places, the places
%   named after the variables of the first clause that has them.
predicate_template(Terms, Annotated, F/N, template(F/N, Text, [arity(N)])) :-
    (   member(Spec-W, Annotated), functor(Spec, F, N)
    ->  annotation_text(Terms, Spec, W, Text)
    ;   place_names(Terms, F, N, Names),
        (   N =:= 2, numeric_place(Terms, F, 2) -> Shape = value ; Shape = relation ),
        naive_text(F, Names, Shape, Text)
    ).

%   The place holds numbers in some fact of the program (`age(bob, 55)`).
numeric_place(Terms, F, I) :-
    member(C-_, Terms), clause_head(C, H), C \= (_ :- _),
    functor(H, F, _), arg(I, H, A), number(A), !.

annotation_text(Terms, Spec, W, Text) :-
    Spec =.. [F|Vars],
    length(Vars, N),
    numlist(1, N, Is),
    maplist(annotation_place(Terms, F, N), Is, Vars, Places),
    distinct_place_names(Places, Distinct),
    atom_string(W, S0),
    foldl(annotation_slot, Vars, Distinct, S0, S),
    atom_string(Text, S).

%   A one- or two-letter annotation variable (`@(X)`) says nothing: the
%   place takes its name from the clauses' variables instead.
annotation_place(Terms, F, N, I, V, Name) :-
    (   atom(V), atom_length(V, L), L > 2
    ->  place_type(V, Name)
    ;   place_name(Terms, F, N, I, Name)
    ).

%   `@(X)` in the annotation's wording becomes the slot `*an x*`. The
%   annotation's arguments are read with their variable names bound to the
%   names (read_term's variable_names), or are atoms already.
annotation_slot(V, Place, S1, S2) :-
    format(string(Pat), "@(~w)", [V]),
    (   sub_string(S1, B, _, A, Pat)
    ->  sub_string(S1, 0, B, _, Pre), sub_string(S1, _, A, 0, Post),
        slot_text(Place, Slot),
        string_concat(Pre, Slot, P1), string_concat(P1, Post, S2)
    ;   S2 = S1
    ).

place_type(V, T) :- ( var(V) -> T = thing ; downcase_atom(V, T0), clean_word(T0, T) ).

%   Each place is named after the first variable found in it, in any clause
%   head or body literal of the predicate.
place_names(Terms, F, N, Names) :-
    numlist(1, N, Is),
    maplist(place_name(Terms, F, N), Is, Names).

place_name(Terms, F, N, I, Name) :-
    (   member(C-Bs, Terms), clause_literal(C, L), functor(L, F, N),
        arg(I, L, A), arg_place_name(Bs, A, Name0), Name0 \== thing
    ->  Name = Name0
    ;   Name = thing
    ).

clause_literal(C, L) :- clause_head(C, L).
clause_literal((_ :- B), L) :- body_literal(B, L).

arg_place_name(Bs, A, Name) :-
    (   var(A), member(VN = V, Bs), V == A, \+ sub_atom(VN, 0, _, _, '_'),
        downcase_atom(VN, L), clean_word(L, Name0),
        \+ le_i18n:class_member(qualifier, Name0), \+ le_i18n:class_member(article, Name0)
    ->  Name = Name0
    ;   Name = thing
    ).

alpha_code(C) :- code_type(C, alpha).

clean_word(W0, W) :-
    atom_codes(W0, Cs), include(alpha_code, Cs, Cs1),
    ( Cs1 == [] -> W = thing ; atom_codes(W, Cs1) ).

%   The naive verbalisation (§5.7): correct, and meant to be improved by the
%   assistant or a person. `parent(X, Y)` is `*a person* is the parent of
%   *a child*`; `age(X, N)`, with numbers in the second place, `the age of
%   *a person* is *a number*`; `is_parent_of`, `owns` and the like keep their
%   own words between the places.
naive_text(F, Names, Shape, Text) :-
    functor_words(F, Words),
    length(Names, N),
    distinct_place_names(Names, Places),
    maplist(slot_text, Places, Slots),
    (   N =:= 0 -> atomic_list_concat(Words, ' ', Text)
    ;   N =:= 1 -> Slots = [S1], unary_words(Words, Ws1), atomic_list_concat([S1|Ws1], ' ', Text0), dedupe_is(Text0, Text)
    ;   N =:= 2, Slots = [S1, S2]
    ->  binary_words(Words, Shape, S1, S2, All), atomic_list_concat(All, ' ', Text)
    ;   Slots = [S1, S2|More],
        findall(P, ( member(S, More), member(P, [with, S]) ), Tail),
        append([[S1], Words, [S2], Tail], All),
        atomic_list_concat(All, ' ', Text)
    ).

binary_words(Words, _, S1, S2, All) :-
    (   Words = [W1|_], memberchk(W1, [is, has, have, can, does, was, were, may, must])
    ;   last(Words, WL), memberchk(WL, [of, to, in, on, at, for, with, from, by, than, as])
    ;   Words = [W], sub_atom(W, _, 1, 0, s), \+ sub_atom(W, _, 2, 0, ss)
    ), !,
    append([[S1], Words, [S2]], All).
binary_words(Words, value, S1, S2, All) :- !,
    append([[the], Words, [of, S1, is, S2]], All).
binary_words(Words, relation, S1, S2, All) :-
    append([[S1, is, the], Words, [of, S2]], All).

%   `*a thing* is childless`, `*a thing* is a person`: an adjective-looking
%   single word takes the bare copula, anything else the indefinite article.
unary_words([W], [is, W]) :- adjective_like(W), !.
unary_words([W], [is, Art, W]) :- !, article_for(W, W, Art).
unary_words(Words, [is|Words]).

adjective_like(W) :-
    member(Suffix, [ful, less, ous, able, ible, al, ive, ic, ed, ing, ent, ant, y, ish]),
    sub_atom(W, _, _, 0, Suffix), !.

dedupe_is(T0, T) :- ( sub_atom(T0, B, _, A, ' is is '), sub_atom(T0, 0, B, _, P), sub_atom(T0, _, A, 0, S) -> atomic_list_concat([P, ' is ', S], T) ; T = T0 ).

%   Two places of the same name would be the same variable in a query:
%   `a person ... a second person`.
distinct_place_names(Names, Places) :-
    foldl(place_name_step, Names, []-[], _-Rev),
    reverse(Rev, Places).

place_name_step(N, C0-Acc, C1-[P|Acc]) :-
    ( select(N-K0, C0, C2) -> K is K0 + 1 ; K = 1, C2 = C0 ),
    C1 = [N-K|C2],
    ( K =:= 1 -> P = N ; ordinal(K, N, O) -> format(atom(P), '~w ~w', [O, N]) ; format(atom(P), '~w ~w', [N, K]) ).

functor_words(F, Words) :-
    atomic_list_concat(Ws0, '_', F),
    exclude(==(''), Ws0, Ws1),
    maplist(spell_digits, Ws1, Wss), append(Wss, Words0),
    ( Words0 == [] -> Words = [holds] ; Words = Words0 ).

spell_digits(W, Ws) :-
    atom_codes(W, Cs),
    (   \+ ( member(C, Cs), code_type(C, digit) ) -> Ws = [W]
    ;   phrase(digit_split(Parts), Cs), maplist(codes_atom, Parts, Ws0),
        maplist(digit_word, Ws0, Ws)
    ).

codes_atom(Cs, A) :- atom_codes(A, Cs).

digit_split([P|Ps]) --> alpha_run(P), { P \== [] }, !, digit_split(Ps).
digit_split([[D]|Ps]) --> [D], { code_type(D, digit) }, !, digit_split(Ps).
digit_split([]) --> [].
alpha_run([C|Cs]) --> [C], { \+ code_type(C, digit) }, !, alpha_run(Cs).
alpha_run([]) --> [].

digit_word(A, W) :- ( atom_number(A, D), integer(D), nth0(D, [zero,one,two,three,four,five,six,seven,eight,nine], W) -> true ; W = A ).
