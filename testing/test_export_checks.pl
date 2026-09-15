/** <module> The check before a program is written in another language

    Every conversion of a Logical English (or LPS) program into another
    language refuses, with the list of what it cannot say, rather than write
    a program that means something else (le_import.pl, "the check comes
    before the text"). The exporters of le_import's registry are tested in
    test_le_import.pl and beside each exporter (InsurLE2/migration); here
    are the converters of this repository:

      - LE for LPS -> LPS (le_lps.pl): a construct with no LPS reading is an
        error at its sentence, and no LPS text is written;
      - LE -> s(CASP) (le_scasp.pl): an emitter issue that loses meaning
        refuses See s(CASP) and the s(CASP) engine;
      - LPS -> LE (le_lps_write.pl): a term with no Logical English sentence
        refuses the document, unless a translator asks for residue.

    Run with:  swipl -q -g run_tests -t halt testing/test_export_checks.pl
*/

:- module(test_export_checks, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').
:- use_module('../le_lps').
:- use_module('../le_lps_write').
:- use_module('../le_scasp').
:- use_module('../le_import').

lps_doc("the target language is: lps.

the maximum time is 5.

the fluents are:
    *a person* is rich.

the events are:
    *a person* wins *an amount*.

the templates are:
    *a person* is lucky; unknown.
    *a person* is eligible.

the knowledge base t includes:

a person is eligible if
    for all cases in which
        the person is rich at a time
    it is the case that
        the person is lucky.

if a person wins an amount from a time to a second time
    and the person is lucky
then the person is rich.

when a person wins an amount
then the person is rich.
").

:- begin_tests(le_to_lps).

%   A universal and a condition on an assumable template have no LPS
%   reading: each is an error at its sentence's line, and there is no LPS.
test(not_lps_refuses) :-
    lps_doc(Doc),
    le_lps_text(Doc, Text, Prov, Issues),
    assertion(Text == ""),
    assertion(Prov == []),
    findall(L, member(le_lps_issue(error, not_lps, _, L, _), Issues), Ls0),
    sort(Ls0, Ls),
    assertion(Ls == [17, 23]).

%   The same program without them translates, and says nothing of the kind.
test(lps_program_translates) :-
    Doc = "the target language is: lps.\n\nthe fluents are:\n    *a person* is rich.\n\nthe events are:\n    *a person* wins *an amount*.\n\nthe knowledge base t includes:\n\nwhen a person wins an amount\nthen the person is rich.\n",
    le_lps_text(Doc, Text, _, Issues),
    assertion(Text \== ""),
    assertion(\+ memberchk(le_lps_issue(error, _, _, _, _), Issues)).

:- end_tests(le_to_lps).

:- begin_tests(lps_to_le).

%   A term with no sentence refuses the document; residue(true) writes it
%   as a comment instead (the importers' contract).
test(no_sentence_refuses) :-
    Doc = "the target language is: lps.\n\nthe fluents are:\n    *a person* is rich.\n\nthe events are:\n    *a person* wins *an amount*.\n\nthe knowledge base t includes:\n\nwhen a person wins an amount\nthen the person is rich.\n",
    le_kbs:load_text(Doc, KB),
    Terms = [fluents([is_rich(_)]), events([wins(_, _)]), strange_term(x)],
    le_lps_check(KB, Terms, Problems),
    assertion(Problems = [problem(none, _)]),
    catch(( le_lps_document(KB, Terms, _), Thrown = no ), le_lps_not_expressible(Ps), Thrown = Ps),
    assertion(Thrown = [_]),
    le_lps_document(KB, Terms, Text, [residue(true)]),
    assertion(sub_string(Text, _, _, _, "% not expressible in Logical English")).

:- end_tests(lps_to_le).

:- begin_tests(le_to_scasp).

%   An aggregate has no s(CASP) lowering: the emitter's issue names the rule
%   it is in, it blocks, and the check gives the rule's position.
test(aggregate_blocks) :-
    Doc = "the target language is: prolog.\n\nthe templates are:\n    *a person* owes *an amount*.\n    *a person* has a debt of *an amount*.\n\nthe knowledge base t includes:\n\na person has a debt of a total if\n    the total is the sum of each amount such that\n        the person owes the amount.\n",
    le_kbs:load_text(Doc, KB),
    le_scasp_program_text(KB, _, Issues),
    assertion(( member(I, Issues), le_scasp_blocking_issue(I) )),
    assertion(\+ memberchk(le_scasp_issue(_, unknown, _), Issues)),
    le_scasp_check(KB, Issues, Problems),
    Problems = [problem(at(S, _), _)],
    export_refusal("s(CASP)", Problems, [text(Doc)], R),
    R.problems = [P],
    assertion(integer(S)),
    assertion(P.line == 9).

%   A non-numeric `is different from` is s(CASP)'s constructive
%   disequality, not a dropped condition.
test(disequality_is_constructive) :-
    Doc = "the target language is: prolog.\n\nthe templates are:\n    *a person* lives in *a place*.\n    *a person* moved.\n\nthe knowledge base t includes:\n\na person moved if\n    the person lives in a place\n    and the person lives in a second place\n    and the place is different from the second place.\n",
    le_kbs:load_text(Doc, KB),
    le_scasp_program_text(KB, Text, Issues),
    assertion(\+ ( member(I, Issues), le_scasp_blocking_issue(I) )),
    assertion(sub_string(Text, _, _, _, "\\=")).

:- end_tests(le_to_scasp).
