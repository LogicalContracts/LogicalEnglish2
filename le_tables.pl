/** <module> Decision tables

    A decision table is a section of its own, bound to ONE template whose
    words name it ("... under table shipping"):

        the table shipping is, with first match:
            band | weight kg          | cost
            s    | <= 1               | 5
            m    | > 1 and <= 10      | 12
            l    | > 10               | 30

    or, for a large table, with its rows in a CSV file next to the program:

        the table postcode_region is loaded from postcodes.csv, with unique match:
            postcode | region

    Columns and template arguments correspond IN ORDER. When the table has one
    column more than the template has arguments, the first column is the row
    id (cited by explanations); otherwise rows are identified by their number.
    The LAST column is the output; the others are inputs. A cell holds a
    constant, `any` (or `-`), or a simple condition — comparisons joined by
    `and`/`or` (`> 1 and <= 10`). Hit policies (DMN): `first match` (the
    first row whose inputs match), `unique match` (the default; two matching
    rows are a run-time error) and `all matches` (every matching row — the
    policy for relations).

    The table compiles to one clause, Head :- le_table(Name, Args), plus row
    records; the reasoner solves le_table/2 through table_solution/5 and
    explains an answer by the row that produced it.
*/

:- module(le_tables, [
    compile_table/9,        % +M, +Templates, +Name, +Policy, +Source, +HeaderTokens, +RowLines, +Start, +End
    table_solution/5,       % +KM, +Name, +Args, -RowId, -RowRange
    table_row_words/3       % +Name, +RowId, -Words
]).

:- use_module(le_i18n).
:- use_module(library(csv)).

:- dynamic csv_table_cache/4.     % csv_table_cache(Path, Stamp, HeaderCells, Rows)

%!  compile_table(+M, +Templates, +Name, +Policy, +Source, +Header, +Rows, +Start, +End) is det.
%
%   Called from the second pass. Records in module M:
%       le_table(Name, Policy, F/A, Columns, IdColumn, Source)
%       le_table_row(Name, Index, RowId, Cells, RowStart, RowEnd)   (inline rows)
%   and returns nothing: the clause binding the template is asserted by
%   le_kbs when the section is processed (le_table_clause/4 below).
%   Problems are asserted as le_issue/6 against the table.
compile_table(M, Templates, Name, Policy, Source, HeaderTokens, RowLines, Start, End) :-
    split_cells(HeaderTokens, HeaderCells0),
    citation_column(HeaderCells0, Cite, HeaderCells),
    maplist(cell_text, HeaderCells, Columns),
    length(Columns, K),
    (   table_template(Templates, Name, FA)
    ->  FA = [F|Args], length(Args, A),
        (   K =:= A + 1 -> IdCol = true
        ;   K =:= A -> IdCol = false
        ;   table_issue(M, error, table_arity_mismatch, [name-Name, columns-K, arity-A], Start, End),
            fail
        ),
        (   Source = file(File)
        ->  (   load_csv_rows(File, Columns, Rows0, Problem)
            ->  ( Problem == none -> true
                ; table_issue(M, warning, table_csv_problem, [name-Name, problem-Problem], Start, End) ),
                Rows = Rows0
            ;   table_issue(M, error, table_csv_missing, [name-Name, file-File], Start, End),
                Rows = []
            )
        ;   Rows = RowLines
        ),
        assertz(M:le_table(Name, Policy, F/A, Columns, IdCol, Source)),
        forall(nth1(I, Rows, Row),
               compile_row(M, Name, I, K, IdCol, Cite, Row, Start, End))
    ;   table_issue(M, error, table_without_template, [name-Name], Start, End)
    ),
    !.
compile_table(_, _, _, _, _, _, _, _, _).

cell_text(Tokens, Text) :-
    (   Tokens == [] -> Text = ''
    ;   le_grammar:reconstruct_name(Tokens, Text)
    ).

% The template bound to table Name: its fixed words contain "table <name>".
table_template(Templates, Name, FA) :-
    table_word(TW),
    atomic_list_concat(NameWords0, ' ', Name),
    exclude(==(''), NameWords0, NameWords),
    append([TW], NameWords, Seq),
    member(Dict, Templates),
    arg(1, Dict, FA0), arg(3, Dict, WV),
    FA0 = [F|_], atom(F),
    \+ sub_atom(F, 0, 3, _, le_),
    include(atom, WV, Words),
    contiguous(Seq, Words), !,
    FA = FA0.

table_word(TW) :-
    ( kw_main_words(table_word, [TW]) -> true ; TW = table ).

contiguous(Sub, List) :- append(_, Tail, List), append(Sub, _, Tail), !.

compile_row(M, Name, I, K, IdCol, Cite, row(Tokens, RS, RE), TStart, TEnd) :- !,
    split_cells(Tokens, CellToks0),
    (   Cite = cite(CiteCol, _),
        nth1(CiteCol, CellToks0, CiteToks, CellToks)
    ->  true
    ;   CellToks = CellToks0, CiteToks = []
    ),
    length(CellToks, N),
    (   N =:= K
    ->  (   IdCol == true
        ->  CellToks = [IdToks|ValueToks], cell_text(IdToks, RowId)
        ;   ValueToks = CellToks, RowId = I
        ),
        (   parse_row_cells(RS, ValueToks, Cells),
            citation_cell(CiteToks, Quote)
        ->  (   last(Cells, Out), \+ output_cell(Out)
            ->  table_issue(M, error, table_bad_output, [name-Name, row-RowId], RS, RE)
            ;   assertz(M:le_table_row(Name, I, RowId, Cells, RS, RE)),
                (   Quote \== none, RS \== 0, Cite = cite(_, Doc)
                ->  assertz(M:le_table_row_citation(Name, RowId, Doc, Quote, RS, RE))
                ;   true
                )
            )
        ;   table_issue(M, error, table_bad_cell, [name-Name, row-RowId], RS, RE)
        )
    ;   ( RS == 0 -> S = TStart, E = TEnd ; S = RS, E = RE ),
        table_issue(M, error, table_row_width, [name-Name, row-I, cells-N, columns-K], S, E)
    ).

output_cell(val(_)).
output_cell(oneof(_)).

% The cells of a row. A loaded (CSV) row — RS = 0 — is data: its output cell
% is the value written there, a text whose words may include "or" and "and"
% ("Duchenne or Becker muscular dystrophy"), never a list of alternatives or
% a condition; its input cells are read as an inline row's are.
parse_row_cells(RS, ValueToks, Cells) :-
    (   RS == 0,
        append(InToks, [OutToks], ValueToks),
        OutToks \== []
    ->  maplist(parse_cell, InToks, InCells),
        (   parse_cell(OutToks, OutCell0), OutCell0 = val(_)
        ->  OutCell = OutCell0
        ;   cell_value(OutToks, V) -> OutCell = val(V)
        ;   parse_cell(OutToks, OutCell)
        ),
        append(InCells, [OutCell], Cells)
    ;   maplist(parse_cell, ValueToks, Cells)
    ).

table_issue(M, Severity, Type, Pairs, Start, End) :-
    (   nonvar(M), M \== (-)
    ->  atom_concat(Type, '_desc', DescId),
        atom_concat(Type, '_fix', FixId),
        le_msg(DescId, Pairs, Desc),
        le_msg(FixId, Pairs, Fix),
        assertz(M:le_issue(Severity, Type, Desc, Fix, Start, End))
    ;   true
    ).

% ---------------------------------------------------------------------------
% A citation column
% ---------------------------------------------------------------------------
% One column of an inline table may cite, row by row, the passage each row
% encodes — a tax band's line of the statute, a subheading's line of a tariff.
% Its header is the provenance keyword `confer` (the passage is in the table's
% own document, the one its `with provenance` names) or `as stated in` followed
% by a document ("as stated in HTSUS Chapter 62"); each cell is a quoted
% passage, or empty. The column is not one of the template's: it is set aside
% before the columns are matched with the template's arguments, and each
% row's passage becomes the provenance of that row (le_provenance:
% record_table_row_provenance/2), so an explanation citing the row, "Show
% original text" on it and the verifier's quotation check all see it.
%
%   citation_column(+HeaderCells, -Cite, -OtherCells): Cite is cite(Column,
%   Document) — Document `table` or doc(Constant, Text) — or none.
citation_column(Cells0, Cite, Cells) :-
    (   nth1(Col, Cells0, Toks, Cells),
        citation_header(Toks, Doc)
    ->  Cite = cite(Col, Doc)
    ;   Cite = none, Cells = Cells0
    ).

citation_header(Toks0, Doc) :-
    exclude(le_grammar:is_indent_or_comment, Toks0, Toks),
    (   le_i18n:kw_synonym_words(confer, Words),
        le_grammar:tokens_word_prefix(Words, Toks, [])
    ->  Doc = own
    ;   le_i18n:kw_synonym_words(as_stated_in, Words),
        le_grammar:tokens_word_prefix(Words, Toks, DocToks),
        DocToks \== [],
        le_provenance:document_parts(DocToks, Const, Text),
        Doc = doc(Const, Text)
    ).

% The passage of a citation cell: a quoted string, or none when empty.
citation_cell([], none) :- !.
citation_cell(Toks0, Quote) :-
    exclude(le_grammar:is_indent_or_comment, Toks0, Toks),
    (   Toks == [] -> Quote = none
    ;   Toks = [doubleQuoteString(Q, _)] -> atom_string(Q, Quote)
    ).

% ---------------------------------------------------------------------------
% Cells
% ---------------------------------------------------------------------------

% Split a row's tokens at '|' into the cell token lists.
split_cells(Tokens0, Cells) :-
    exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens),
    split_at_bar(Tokens, Cells).

split_at_bar(Tokens, [Cell|Cells]) :-
    (   append(Cell, [Bar|Rest], Tokens), bar_token(Bar)
    ->  split_at_bar(Rest, Cells)
    ;   Cell = Tokens, Cells = []
    ).

bar_token(T) :- le_grammar:extract_simple_word(T, '|').

%!  parse_cell(+Tokens, -Cell) is semidet.
%
%   Cell is `any`, val(Value) or test(Expr) with Expr built from cmp(Op, V),
%   and/2 and or/2.
parse_cell([], any) :- !.
parse_cell([T], any) :-
    le_grammar:extract_simple_word(T, W),
    ( W == '-' ; class_member(table_any, W) ), !.
parse_cell(Tokens, Cell) :-
    split_connective(or, Tokens, Alts),
    Alts = [_, _|_], !,
    maplist(parse_cell, Alts, Cells),
    \+ memberchk(any, Cells),
    (   maplist(val_cell, Cells, Vals)
    ->  Cell = oneof(Vals)
    ;   maplist(cell_expr, Cells, Exprs),
        foldl1(or, Exprs, Expr),
        Cell = test(Expr)
    ).
% a cell is a conjunction only when every part is a condition: a value
% whose words include "and" ("with acute and chronic ...") stays a value
parse_cell(Tokens, test(Expr)) :-
    split_connective(and, Tokens, Parts),
    Parts = [_, _|_],
    maplist(parse_condition, Parts, Exprs), !,
    foldl1(and, Exprs, Expr).
parse_cell(Tokens, test(Expr)) :-
    parse_condition(Tokens, Expr), !.
parse_cell(Tokens, val(V)) :-
    cell_value(Tokens, V).

val_cell(val(V), V).
cell_expr(val(V), cmp(=, V)).
cell_expr(test(E), E).

foldl1(Op, [X|Xs], R) :- foldl(fold_op(Op), Xs, X, R).
fold_op(Op, X, Acc, R) :- R =.. [Op, Acc, X].

% Split at every top-level connective word of class Key.
split_connective(Key, Tokens, Parts) :-
    (   append(Before, [T|After], Tokens),
        le_grammar:extract_simple_word(T, W), class_member(Key, W),
        Before \== [], After \== []
    ->  Parts = [Before|More],
        split_connective(Key, After, More)
    ;   Parts = [Tokens]
    ).

parse_condition([OpTok|ValToks], cmp(Op, V)) :-
    le_grammar:extract_simple_word(OpTok, Op0),
    cmp_op(Op0, Op),
    ValToks \== [],
    cell_value(ValToks, V).

cmp_op('<', <).    cmp_op('<=', =<).  cmp_op('=<', =<).
cmp_op('>', >).    cmp_op('>=', >=).  cmp_op('=', =).
cmp_op('==', =).   cmp_op('!=', \=).

% A cell value is read exactly as a scenario argument is, so that a table
% constant and a scenario constant written the same way are the same value.
cell_value([T], V) :-
    ( T = number(N, _) ; T = number(N) ), !, V = N.
cell_value([T], V) :-
    ( T = date(D, _) ; T = date(D) ), !, V = D.
cell_value(Tokens, V) :-
    le_grammar:extract_value_from_parts(Tokens, V, [], _, [], true, indefinite, 0).

% ---------------------------------------------------------------------------
% Loaded tables (CSV)
% ---------------------------------------------------------------------------

%!  load_csv_rows(+File, +Columns, -Rows, -Problem) is semidet.
%
%   Rows of the CSV File as row(Tokens, 0, 0) terms (cells re-joined with '|'
%   and tokenized, so a CSV cell may hold a condition exactly like an inline
%   one). A first CSV row repeating the declared header is skipped. Cached by
%   path and modification time; fails when the file cannot be read.
load_csv_rows(File, Columns, Rows, Problem) :-
    exists_file(File),
    time_file(File, Stamp),
    (   csv_table_cache(File, Stamp, Columns, Rows0)
    ->  Rows = Rows0, Problem = none
    ;   catch(csv_read_file(File, CsvRows, [convert(false), strip(true), encoding(utf8)]), E, true),
        (   var(E)
        ->  maplist(csv_row_cells, CsvRows, CellRows0),
            maplist(normalize_header_cell, Columns, NormCols),
            (   CellRows0 = [First|Rest], maplist(normalize_header_cell, First, NormFirst), NormFirst == NormCols
            ->  CellRows = Rest
            ;   CellRows = CellRows0
            ),
            maplist(cells_row, CellRows, Rows),
            retractall(csv_table_cache(File, _, _, _)),
            assertz(csv_table_cache(File, Stamp, Columns, Rows)),
            Problem = none
        ;   term_string(E, Problem), Rows = []
        )
    ).

csv_row_cells(Row, Cells) :-
    Row =.. [row|Cells0],
    maplist(to_text, Cells0, Cells).

to_text(X, T) :- ( atom(X) -> T = X ; string(X) -> atom_string(T, X) ; term_to_atom(X, T) ).

normalize_header_cell(C, N) :-
    to_text(C, T), downcase_atom(T, L), normalize_space(atom(N), L).

cells_row(Cells, row(Tokens, 0, 0)) :-
    maplist(csv_cell_text, Cells, Texts),
    atomic_list_concat(Texts, ' | ', Line),
    tokenizer:tokenize(Line, Tokens0),
    exclude(le_grammar:is_indent_or_comment, Tokens0, Tokens).

% A CSV cell as the text of an inline cell. The CSV reader has removed any
% quotes, so a code such as G71.01 or 012 would be tokenized as a number and
% lose its zeros: a cell of plain text is quoted again. A number, an empty
% cell, "-" or "any", a condition (a cell opening with a comparison) and a
% list of alternatives ("cotton or silk") are left to be read as an inline
% cell is.
csv_cell_text(Cell, Text) :-
    normalize_space(atom(C), Cell),
    (   C == ''
    ->  Text = C
    ;   atom_number(C, _)
    ->  Text = C
    ;   ( C == '-' ; class_member(table_any, C) )
    ->  Text = C
    ;   sub_atom(C, 0, 1, _, F), memberchk(F, [<, >, =, !])
    ->  Text = C
    ;   atomic_list_concat(Parts, ' or ', C), Parts = [_, _|_],
        \+ ( member(P, Parts), sub_atom(P, _, _, _, ' ') )
    ->  Text = C
    ;   atomic_list_concat(Pieces, '"', C),
        atomic_list_concat(Pieces, '\'', C1),
        format(atom(Text), '"~w"', [C1])
    ).

% ---------------------------------------------------------------------------
% Solving
% ---------------------------------------------------------------------------

%!  table_solution(+KM, +Name, +Args, -RowId, -RowRange) is nondet.
%
%   Args (the template arguments, output last) are answered by table Name
%   under its hit policy. RowRange is range(Start, End) for an inline row, or
%   none for a loaded one.
table_solution(KM, Name, Args, RowId, RowRange) :-
    KM:le_table(Name, Policy, _, Columns, _, _),
    append(Inputs, [Output], Args),
    findall(I-RowId0-Cells-Range,
            ( KM:le_table_row(Name, I, RowId0, Cells, S, E),
              ( S == 0 -> Range = none ; Range = range(S, E) ) ),
            Rows),
    inputs_bound_or_values(Name, Columns, Inputs, Rows),
    table_policy(Policy, Name, Inputs, Output, Rows, RowId, RowRange).

table_policy(first, _Name, Inputs, Output, Rows, RowId, RowRange) :-
    once(( member(_-RowId-Cells-RowRange, Rows),
           append(InCells, [OutCell], Cells),
           inputs_match(InCells, Inputs) )),
    output_value(OutCell, Output).
table_policy(all, _Name, Inputs, Output, Rows, RowId, RowRange) :-
    member(_-RowId-Cells-RowRange, Rows),
    append(InCells, [OutCell], Cells),
    inputs_match(InCells, Inputs),
    output_value(OutCell, Output).
table_policy(unique, Name, Inputs, Output, Rows, RowId, RowRange) :-
    findall(Id-Cells-Rg-Inputs,
            ( member(_-Id-Cells-Rg, Rows),
              append(InCells, [_], Cells),
              inputs_match(InCells, Inputs) ),
            Matches),
    (   Matches = [_, _|_], ground(Inputs)
    ->  findall(Id, member(Id-_-_-_, Matches), Ids),
        throw(error(le_table_error(unique_violation(Name, Ids)),
                    context(le_tables, 'unique match violated')))
    ;   member(RowId-Cells-RowRange-Inputs, Matches),
        last(Cells, OutCell),
        output_value(OutCell, Output)
    ).

% A condition cell needs its argument known; say which column when it is not.
inputs_bound_or_values(Name, Columns, Inputs, Rows) :-
    length(Inputs, NI),
    (   nth1(Pos, Inputs, Arg), var(Arg),
        member(_-_-Cells-_, Rows), nth1(Pos, Cells, test(_))
    ->  ( length(Columns, K), K > NI + 1 -> P1 is Pos + 1 ; P1 = Pos ),
        nth1(P1, Columns, Col),
        throw(error(le_table_error(unbound_input(Name, Col)),
                    context(le_tables, 'table input must be known')))
    ;   true
    ).

inputs_match([], []).
inputs_match([Cell|Cells], [Arg|Args]) :-
    cell_matches(Cell, Arg),
    inputs_match(Cells, Args).

cell_matches(any, _) :- !.
cell_matches(val(V), A) :- !, value_equal(V, A).
cell_matches(oneof(Vs), A) :- !, member(V, Vs), value_equal(V, A).
cell_matches(test(E), A) :- eval_test(E, A).

value_equal(V, A) :- var(A), !, A = V.
value_equal(V, A) :- number(V), number(A), !, V =:= A.
value_equal(V, A) :- V == A, !.
value_equal(V, A) :- ( atom(V) ; string(V) ), ( atom(A) ; string(A) ),
    atom_string(V, S), atom_string(A, S).

eval_test(and(X, Y), A) :- !, eval_test(X, A), eval_test(Y, A).
eval_test(or(X, Y), A) :- !, ( eval_test(X, A) -> true ; eval_test(Y, A) ).
eval_test(cmp(=, V), A) :- !, value_equal(V, A).
eval_test(cmp(\=, V), A) :- !, \+ value_equal(V, A).
eval_test(cmp(Op, V), A) :-
    nonvar(A),
    (   number(A), number(V)
    ->  G =.. [Op, A, V], call(G)
    ;   std_op(Op, SOp), G =.. [SOp, A, V], call(G)
    ).

std_op(<, @<). std_op(=<, @=<). std_op(>, @>). std_op(>=, @>=).

output_value(val(V), Out) :- value_equal(V, Out).
output_value(oneof(Vs), Out) :- member(V, Vs), value_equal(V, Out).

%!  table_row_words(+Name, +RowId, -Words) is det.
%
%   How an explanation cites a row: "row l of table shipping".
table_row_words(Name, RowId, Words) :-
    le_msg(table_row, [row-RowId, name-Name], Atom),
    atomic_list_concat(Words0, ' ', Atom),
    exclude(==(''), Words0, Words).
