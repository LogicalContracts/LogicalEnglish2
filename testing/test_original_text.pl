/** <module> View Original Text: where the original of a construct is

    le_original_text.pl, the operation originalTextAt of the editor's "View
    Original Text": a citation at the cursor; else the construct under the
    cursor found in the program's originals (sources/, the documents it says
    the text of is at) by its label, its ledger's entries and what it cites;
    else the originals; else nothing.

    Run with:  swipl -q -g run_tests -t halt testing/test_original_text.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_original_text, []).

:- use_module(library(plunit)).
:- use_module(library(filesex)).
:- use_module('../le_kbs').
:- use_module('../le_original_text').

kin_program("the target language is: prolog.

the templates are:
    *a thing* is the anc of *a second thing*.
    *a thing* is the parent of *a second thing*.
    *a thing* is tall.

the knowledge base kin includes:

the text of the rulebook is at \"sources/book.xml\".

rule r7:
a thing is tall if
    the thing is the parent of a second thing.

rule tallness with provenance the rulebook at Rule TallRule9:
a thing is tall if
    the thing is the anc of a second thing.

a thing is the anc of a second thing if
    the thing is the parent of the second thing.

scenario s is:
    ann is the parent of bob.

query q is:
    which thing is tall.
").

kin_rules("% kinship
anc(X,Z) :- parent(X,Z).
anc(X,Z) :-
    parent(X,Y),
    anc(Y,Z).

tall(X) :- parent(X,_).
").

book_xml("<book><rule id=\"r7\"><if>parent</if></rule><rule id=\"r7b\"/><Rule name=\"TallRule9\"><Rule>nested</Rule></Rule><Rule name=\"Other\"/></book>").

kin_ledger("{\"entries\": [
  {\"element\": \"anc/2\", \"in_program\": \"*a thing* is the anc of *a second thing*\", \"kind\": \"view\"},
  {\"element\": \"the rulebook\", \"in_program\": \"the rules\", \"kind\": \"document\"}
]}").

write_file(Path, Text) :-
    setup_call_cleanup(open(Path, write, S, [encoding(utf8)]), write(S, Text), close(S)).

% A program in a folder of its own: kin.le, its ledger and sources/.
with_kin(Goal) :-
    tmp_file(original_text, Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/sources'], Sources),
    make_directory_path(Sources),
    kin_program(P), kin_rules(R), book_xml(B), kin_ledger(L),
    atomic_list_concat([Dir, '/kin.le'], File),
    write_file(File, P),
    atomic_list_concat([Sources, '/kin.rules'], RF), write_file(RF, R),
    atomic_list_concat([Sources, '/book.xml'], BF), write_file(BF, B),
    atomic_list_concat([Dir, '/kin.ledger.json'], LF), write_file(LF, L),
    setup_call_cleanup(true,
                       ( le_kbs:load(File, KB), call(Goal, P, KB) ),
                       delete_directory_and_contents(Dir)).

% The reply for the cursor K characters into the first occurrence of Text.
reply_at(P, KB, Text, K, Reply) :-
    sub_string(P, B, _, _, Text), !,
    Pos is B + K,
    sub_string(P, 0, Pos, _, Before),
    ( aggregate_all(max(I), sub_string(Before, I, 1, _, "\n"), NL) -> LS is NL + 1 ; LS = 0 ),
    sub_string(P, LS, _, 0, Rest),
    ( sub_string(Rest, E, 1, _, "\n") -> LE is LS + E ; string_length(P, LE) ),
    le_original_text:original_text_at(none, KB, Pos, LS, LE, -, [], Reply).

check_label_found_as_a_key_of_an_xml_element(P, KB) :-
    reply_at(P, KB, "the thing is the parent of a second thing.", 3, R),
    assertion(R.kind == "passage"),
    assertion(R.via == label),
    assertion(R.rule == "r7"),
    assertion(R.provenance.text == "sources/book.xml"),
    assertion(R.provenance.quote == "<rule id=\"r7\"><if>parent</if></rule>"),
    % the label line finds the rule below it
    reply_at(P, KB, "rule r7:", 2, R2),
    assertion(R2.provenance.quote == R.provenance.quote).

check_ledger_entry_of_a_template_finds_its_clauses(P, KB) :-
    reply_at(P, KB, "a thing is the anc of a second thing if", 5, R),
    assertion(R.kind == "passage"),
    assertion(R.via == ledger),
    assertion(R.provenance.text == "sources/kin.rules"),
    Q = R.provenance.quote,
    assertion(sub_string(Q, 0, _, _, "anc(X,Z) :- parent(X,Z).")),
    assertion(sub_string(Q, _, _, 0, "anc(Y,Z).")),
    assertion(\+ sub_string(Q, _, _, _, "tall")),
    [S, E] = R.provenance.at,
    string_length(Q, QL),
    assertion(E - S =:= QL),
    % and the template itself
    reply_at(P, KB, "*a thing* is the anc of", 3, R2),
    assertion(R2.provenance.quote == Q).

check_citation_locator_identifier_is_located(P, KB) :-
    reply_at(P, KB, "the thing is the anc of a second thing.", 3, R),
    assertion(R.kind == "citation"),
    assertion(R.rule == tallness),
    assertion(R.provenance.document == "the rulebook"),
    assertion(R.provenance.quote == "<Rule name=\"TallRule9\"><Rule>nested</Rule></Rule>").

check_no_passage_gives_the_originals(P, KB) :-
    reply_at(P, KB, "which thing is tall", 3, R),
    assertion(R.kind == "originals"),
    assertion(R.construct.kind == query),
    findall(T, ( member(F, R.files), get_dict(text, F, T) ), Ts),
    assertion(Ts == ["sources/book.xml", "sources/kin.rules"]).

:- begin_tests(original_text).

% A rule's label, defined by an attribute of the original: the element.
test(label_found_as_a_key_of_an_xml_element) :-
    with_kin(check_label_found_as_a_key_of_an_xml_element).

% The ledger says which element a template came from: its clauses, all of them.
test(ledger_entry_of_a_template_finds_its_clauses) :-
    with_kin(check_ledger_entry_of_a_template_finds_its_clauses).

% A citation whose locator names an identifier: the element it defines,
% nested elements of the same name included.
test(citation_locator_identifier_is_located) :-
    with_kin(check_citation_locator_identifier_is_located).

% Nothing of the originals is about a query: the originals themselves.
test(no_passage_gives_the_originals) :-
    with_kin(check_no_passage_gives_the_originals).

% A program with no sources and no document text: nothing.
test(no_originals_no_text) :-
    tmp_file(original_text_none, Dir),
    make_directory_path(Dir),
    atomic_list_concat([Dir, '/plain.le'], File),
    P = "the target language is: prolog.

the templates are:
    *a thing* is tall.

the knowledge base plain includes:

rule r1:
a thing is tall if
    the thing is tall.
",
    write_file(File, P),
    call_cleanup(( le_kbs:load(File, KB),
                   reply_at(P, KB, "the thing is tall.", 2, R) ),
                 delete_directory_and_contents(Dir)),
    assertion(R.kind == "none"),
    assertion(R.construct.kind == rule).

% Identifiers are compared without case, `_` and `-`; a mention is not a
% definition; a word must match whole.
test(key_occurrences) :-
    T = "ref=\"#ps2-tblock1\"\n<s key=\"ps2-tblock1\">x</s> ps2_tblock10",
    string_lower(T, L),
    findall(O-K, le_original_text:key_occurrence(t(T, L), "ps2_tblock1", K, O, _), Os),
    assertion(Os = [6-mention, 27-definition(other)]).

:- end_tests(original_text).
