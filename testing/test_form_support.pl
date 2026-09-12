/** <module> What the forms and views of a program are told about it

    The load metadata and the verifier's help for people who state facts
    rather than write rules (the Scenario Editor, Scenario Variations, the
    executive view):

    - the program's own knowledge-base name, not an included library's;
    - a flip query's label in Logical English, not a Prolog term;
    - for each placeholder of a scenario template, the values the rules read
      there (le_verifier:slot_values/5), offered as a pick list;
    - the unread_value warning: a scenario value no rule reads, with a close
      value the rules do read ("knit" for "knitted");
    - a decision table's citation column: each row's passage becomes that
      row's provenance, cited by the explanation;
    - an explanation node's sentence without its trailers (`plain`).

    Run with:  swipl -q -g run_tests -t halt testing/test_form_support.pl
*/

:- module(test_form_support, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_verifier').
:- use_module('../classic_web_api').

garments("the target language is: prolog.

the templates are:
    the fabric construction of *a garment* is *a construction*; undefined.
    the construction of *a garment* is *a construction*.
    *a garment* is of a non-knitted fabric.
    *a garment* is of a knitted fabric.
    the principal use of *a garment* is *a use*; undefined.
    *a garment* is for sport.

the knowledge base garments includes:

the construction of a garment is a construction
    if the fabric construction of the garment is the construction.

a garment is of a knitted fabric
    if the construction of the garment is knitted.

a garment is of a non-knitted fabric
    if the construction of the garment is a construction
    and the construction is in [woven, nonwoven, felt].

a garment is for sport
    if the principal use of the garment is sport.

scenario slip is:
    the fabric construction of style A is knit.
    the fabric construction of style B is nonwoven.
    the principal use of style C is protecting a mobile phone.

query fabric is:
    which garment is of a knitted fabric.
").

kb(KB) :- garments(P), load_text(P, KB).

issues_of(KB, Type, Descs) :-
    findall(D-F, KB:le_issue(_, Type, D, F, _, _), Descs).

:- begin_tests(form_support).

% The rules read a construction through a derived predicate and a list: the
% pick list has every one of them, in order of the template's placeholders.
test(placeholder_values_follow_the_rules) :-
    kb(KB),
    get_kb_metadata(KB, M),
    member(D, M.template_defs),
    D.label == "the fabric construction of *a garment* is *a construction*", !,
    assertion(D.values == [[], ["felt", "knitted", "nonwoven", "woven"]]),
    assertion(D.scenario_element == true).

test(slot_values_directly) :-
    kb(KB),
    le_verifier:slot_values(KB, the_fabric_construction_of_is, 2, 2, Vs),
    assertion(Vs == [felt, knitted, nonwoven, woven]).

% "knit" is read by no rule and is close to "knitted": reported, with it.
% "nonwoven" is read (through the list); "protecting a mobile phone" is like
% no value the rules read — a description the program does not interpret.
test(unread_value_reports_the_slip_only) :-
    kb(KB),
    issues_of(KB, unread_value, Issues),
    assertion(Issues = [_]),
    Issues = [Desc-Fix],
    assertion(sub_atom(Desc, _, _, _, knit)),
    assertion(sub_atom(Fix, _, _, _, knitted)).

test(unread_value_positions_the_fact) :-
    kb(KB), garments(P),
    once(KB:le_issue(_, unread_value, _, _, S, E)),
    sub_string(P, S, _, 0, After),
    assertion(sub_string(After, 0, _, _, "the fabric construction of style A is knit")),
    assertion(E > S).

:- end_tests(form_support).

% ---------------------------------------------------------------------------

:- begin_tests(program_metadata).

resource_dir(Dir) :-
    tmp_file(le_meta, Dir),
    make_directory(Dir).

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S), write(S, Text), close(S)).

% The program includes a library with a knowledge base of its own; the name
% the views show is the program's.
test(own_kb_name_not_the_included_one, [setup(resource_dir(Dir)), cleanup(delete_directory_and_contents(Dir))]) :-
    directory_file_path(Dir, 'library.le', Lib),
    write_file(Lib, "the target language is: prolog.

the templates are:
    *a person* is happy.

the knowledge base library includes:

a person is happy if the person is happy.
"),
    directory_file_path(Dir, 'main.le', Main),
    write_file(Main, "the target language is: prolog.

the knowledge base main includes these resources:
    library.

the knowledge base main program includes:

bob is happy.
"),
    load(Main, KB),
    get_kb_metadata(KB, M),
    assertion(M.kb == 'main program').

% A flip query's label reads as the query the author wrote.
test(flip_query_label) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is happy; undefined.
    *a person* is glad.

the knowledge base k includes:

a person is glad if the person is happy.

scenario s is:
    ann is happy.

query flip is:
    which minimal change to the scenario makes it the case that
        bob is glad.
", KB),
    get_kb_metadata(KB, M),
    member(Q, M.queries), Q.name == flip, !,
    atom_string(Q.le, Label),
    assertion(Label == "which minimal change to the scenario makes it the case that bob is glad").

% A custom query (the editor's field, its Flip… button) may be a flip query or
% any query body — not only one literal. The flip opener is tried first: read
% as one literal, it would match the built-in "*a thing* is *a value*".
test(custom_query_flip_and_body) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is happy; undefined.
    *a person* is rich; undefined.
    *a person* is glad.

the knowledge base k includes:

a person is glad if the person is happy.

scenario s is:
    ann is happy.
", KB),
    parse_custom_query(KB, "which minimal change to the scenario makes it the case that it is not the case that ann is glad", G1),
    assertion(G1 = le_flip(_, _)),
    parse_custom_query(KB, "ann is happy and ann is rich", G2),
    assertion(G2 = and(_, _)),              % the form of a query body
    parse_custom_query(KB, "which person is glad", G3),
    assertion(G3 = is_glad(_)),
    createSession(KB, SM), setScenarion(SM, s),
    findall(A, ( query(SM, G1, I, _, _), canonical_string(I, A) ), As),
    destroySession(SM),
    assertion(As == ["remove: ann is happy"]).

:- end_tests(program_metadata).

% ---------------------------------------------------------------------------

tax(Header, Text) :-
    format(string(Text), "the target language is: prolog.

the templates are:
    the rate for *an income* is *a number* under table bands.
    the tax band of *a person* is *a number*.
    *a person* earns *an income*.

the knowledge base tax includes:

the tax act is published at \"https://example.org/tax.html\".
the text of the tax act is at \"sources/tax.txt\".
the rates schedule is published at \"https://example.org/rates.html\".

the tax band of a person is a number
    if the person earns an income
    and the rate for the income is the number under table bands.

the table bands is, with first match, with provenance the tax act, confer \"The rates are\":
    band | income    | rate | ~w
    b1   | <= 10000  | 0    | \"no tax on the first 10,000\"
    b2   | <= 50000  | 20   | \"20 percent up to 50,000\"
    b3   | any       | 40   |

scenario s is:
    ann earns 30000.

query q is:
    the tax band of which person is which number.
", [Header]).

:- begin_tests(table_citations).

% A `confer` column: each row's passage, in the table's own document.
test(confer_column_cites_each_row) :-
    tax("confer", P), load_text(P, KB),
    assertion(\+ KB:le_issue(error, _, _, _, _, _)),
    findall(R-Prov, KB:le_fact_provenance(_, _, le_table_row(bands, R), Prov), Rows),
    assertion(Rows == [b1-prov(none, doc('the tax act', "the tax act"), "\"no tax on the first 10,000\"", none),
                       b2-prov(none, doc('the tax act', "the tax act"), "\"20 percent up to 50,000\"", none)]),
    % the column is not an argument: the table still answers
    createSession(KB, SM), setScenarion(SM, s),
    findall(I, query(SM, q, I, _, _), Is),
    destroySession(SM),
    assertion(Is = [_]).

% `as stated in <document>`: the rows cite another document than the table.
test(as_stated_in_column_names_the_document) :-
    tax("as stated in the rates schedule", P), load_text(P, KB),
    assertion(\+ KB:le_issue(error, _, _, _, _, _)),
    KB:le_fact_provenance(_, _, le_table_row(bands, b2), prov(_, doc(Doc, _), _, _)),
    assertion(Doc == 'the rates schedule').

% The explanation's node for the row that answered carries the row's passage,
% and the row is a citation "Show original text" finds.
test(row_node_and_citation) :-
    tax("confer", P), load_text(P, KB),
    createSession(KB, SM), atom_string(SM, SMS),
    classic_web_api:handle_answering_query(_{sessionModule: SMS, query: "q", scenario: "s"}, R),
    R.results = [Answer|_],
    assertion(row_quote(Answer.why, "20 percent up to 50,000")),
    sub_string(P, B, _, _, "    b2 "), !,
    Pos is B + 6,
    le_provenance:citation_at(KB, Pos, none, none, Prov, _),
    assertion(Prov = prov(_, _, "\"20 percent up to 50,000\"", _)).

row_quote(Node, Quote) :- is_list(Node), !, member(N, Node), row_quote(N, Quote).
row_quote(Node, Quote) :-
    is_dict(Node),
    (   get_dict(provenance, Node, P), P.quote == Quote
    ->  true
    ;   get_dict(children, Node, Cs), row_quote(Cs, Quote)
    ).

% A fact's node: its sentence with the trailers its rendering appended, and
% without them (`plain`), for a view that shows the citation apart.
test(plain_sentence_without_trailers) :-
    load_text("the target language is: prolog.

the templates are:
    *a person* is resident; undefined.
    *a person* is eligible.

the knowledge base k includes:

the census is published at \"https://example.org/census\".

a person is eligible if the person is resident.

scenario s is, as stated in the census:
    ann is resident,
        confer \"Ann, resident of York\".

query q is:
    which person is eligible.
", KB),
    createSession(KB, SM), atom_string(SM, SMS),
    classic_web_api:handle_answering_query(_{sessionModule: SMS, query: "q", scenario: "s"}, R),
    R.results = [Answer|_],
    assertion(plain_of(Answer.why, "ann is resident")).

plain_of(Node, Plain) :- is_list(Node), !, member(N, Node), plain_of(N, Plain).
plain_of(Node, Plain) :-
    is_dict(Node),
    (   get_dict(plain, Node, Plain0), Plain0 == Plain
    ->  true
    ;   get_dict(children, Node, Cs), plain_of(Cs, Plain)
    ).

:- end_tests(table_citations).
