/** <module> The general LE writer (Migration IR -> LE), E1 of the migration roadmap

    InsurLE2/docs/migration/roadmap.md §4.2, §7.2; docs/dev/migration.md.

    Run with:  swipl -q -g run_tests -t halt testing/test_le_writer.pl
    (or via testing/run_tests.sh unit). The whole-corpus round trip is
    testing/le_writer_roundtrip.pl; a sample of it runs here.
*/

:- module(test_le_writer, []).

:- use_module(library(plunit)).
:- use_module(library(lists)).
:- use_module(library(time)).
:- use_module('../le_kbs').
:- use_module('../le_writer').
:- use_module('../le_migration').
:- use_module('le_writer_roundtrip').

%   Load a written document and run every expectation it carries.
text_results(Text, Results) :-
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Text, KB), le_kbs:set_le_issue_reporting(true)),
    findall(R, ( current_predicate(KB:le_expected/4), KB:le_expected(Q, S, A, U),
                 le_kbs:run_one_test(KB, test(Q, S, A, U), R) ), Results).

text_errors(Text, Errors) :-
    le_kbs:set_le_issue_reporting(false),
    call_cleanup(le_kbs:load_text(Text, KB), le_kbs:set_le_issue_reporting(true)),
    findall(T-D, ( current_predicate(KB:le_issue/6), KB:le_issue(error, T, D, _, _, _) ), Errors).

all_pass(Results) :- Results \== [], forall(member(R, Results), R = pass(_, _)).

:- begin_tests(le_writer_ir).

%   A program built from the IR alone: every body form the writer knows.
ir_program(program([kb(tax), comment("An IR test program.")], [
    template(income, "the income of *a taxpayer* is *an amount*", [undefined]),
    template(children, "the number of children of *a taxpayer* is *a number*", [undefined]),
    template(tax, "the tax of *a taxpayer* is *an amount*", []),
    template(pays, "*a taxpayer* pays *an amount* to *a person*", [undefined]),
    template(total, "the total paid by *a taxpayer* is *an amount*", []),
    template(happy, "*a person* is happy", [undefined]),
    template(exempt, "*a taxpayer* is exempt", []),
    template(member, "*a customer* is a member", [undefined]),
    template(student, "*a customer* is a student", [undefined]),
    template(rate, "the discount rate for *a customer* is *a rate*", []),
    template(customer, "*a customer* is a customer", [undefined]),
    template(share, "the share of *a taxpayer* is *an amount*", []),
    template(cost, "the shipping cost for a weight of *a number* kg is *a cost* under table shipping", []),
    template(parcel, "the parcel of *a customer* weighs *a number* kg", [undefined]),
    template(shipping, "the shipping cost for *a customer* is *a cost*", []),
    table(shipping, [policy(first)], [band, 'weight kg', cost],
          [[s, cond((=<)-1), 5], [m, cond(and((>)-1, (=<)-10)), 12], [l, cond((>)-10), 30]]),
    rule(tax(P, T), and(and(income(P, I), T is I * 0.2), not(and(children(P, N), N >= 2))),
         [label(tax_base), provenance([as_stated_in('the tax act'), at('section 1')])]),
    rule(tax(P2, T2), and(and(and(income(P2, I2), children(P2, N2)), N2 >= 2), T2 is I2 * 0.15),
         [label(tax_children)]),
    rule(total(P3, S3), and(income(P3, _), agg(sum, A3, pays(P3, A3, _), S3)), []),
    rule(exempt(P4), and(income(P4, _), forall(pays(P4, _, Q4), happy(Q4))), []),
    rule(rate(C5, R5), and(customer(C5), otherwise([and(member(C5), R5 = 20),
                                                  and(student(C5), R5 = 10),
                                                  R5 = 0])), []),
    rule(share(P6, S6), and(income(P6, I6), S6 is I6 // 3 + I6 mod 3), []),
    rule(shipping(C7, K7), and(parcel(C7, W7), cost(W7, K7)), []),
    residue(r1, [title("a plugin the translator could not read"),
                 source(javascript, "premium = base * factor(state);")]),
    scenario(one, [
        fact(income(ann, 1000), [as_stated_in('the return'), confer("1000")]),
        fact(income(bob, 1000)),
        fact(children(bob, 3)),
        fact(pays(ann, 10, cy)), fact(pays(ann, 5, dee)),
        fact(happy(cy)), fact(happy(dee)),
        fact(customer(ann)), fact(customer(bob)), fact(customer(cy)),
        fact(member(ann)), fact(student(ann)), fact(student(bob)),
        fact(parcel(ann, 0.5)), fact(parcel(bob, 4)), fact(parcel(cy, 40)),
        expects(taxes, [tax(ann, 200.0), tax(bob, 150.0)]),
        expects(totals, [total(ann, 15), total(bob, 0)]),
        expects(exemptions, [exempt(ann), exempt(bob)]),
        expects(rates, [rate(ann, 20), rate(bob, 10), rate(cy, 0)]),
        expects(shares, [share(ann, 334), share(bob, 334)]),
        expects(shipping, [shipping(ann, 5), shipping(bob, 12), shipping(cy, 30)])
    ], []),
    query(taxes, tax(_, _)),
    query(totals, total(_, _)),
    query(exemptions, exempt(_)),
    query(rates, rate(_, _)),
    query(shares, share(_, _)),
    query(shipping, shipping(_, _))
])).

test(ir_program_verifies_and_passes) :-
    ir_program(IR),
    le_write(IR, Text, Issues),
    \+ member(issue(error, _, _), Issues),
    text_errors(Text, Errors),
    assertion(Errors == []),
    text_results(Text, Results),
    assertion(all_pass(Results)).

test(ir_forms_are_the_current_language) :-
    ir_program(IR),
    le_write(IR, Text),
    % a decision table, an otherwise cascade, provenance trailers, a label
    assertion(sub_string(Text, _, _, _, "the table shipping is, with first match:")),
    assertion(sub_string(Text, _, _, _, "otherwise the customer is a student")),
    assertion(sub_string(Text, _, _, _, "rule tax_base with provenance the tax act at section 1:")),
    assertion(sub_string(Text, _, _, _, "1000, as stated in the return, confer \"1000\"")),
    assertion(sub_string(Text, _, _, _, "is the sum of each")),
    assertion(sub_string(Text, _, _, _, "for all cases in which")),
    assertion(sub_string(Text, _, _, _, "// 3 + ")),
    assertion(sub_string(Text, _, _, _, "% RESIDUE r1 BEGIN")),
    assertion(sub_string(Text, _, _, _, "%   | premium = base * factor(state);")).

%   A function (`the functions are:`, §2.3): its own section, and its value
%   written where it is used rather than in a condition of its own.
function_ir(program([kb(cups)], [
    template(expensive, "*a cup* is expensive", []),
    template(capacity, "the capacity of *a cup* is *a number* ml", [undefined]),
    function(price, "the price of *a cup* is *an amount*", []),
    rule(price(C, A), and(capacity(C, K), A is K / 10), []),
    rule(expensive(C2), and(capacity(C2, _), and(price(C2, P), le_gt(P, 10))), []),
    scenario(one, [ fact(capacity(mug, 200)), fact(capacity(thimble, 20)),
                    expects(dear, [expensive(mug)]) ], []),
    query(dear, expensive(_))
])).

test(a_function_is_a_section_and_is_used_compactly) :-
    function_ir(IR),
    le_write(IR, Text, Issues),
    assertion(\+ member(issue(error, _, _), Issues)),
    assertion(sub_string(Text, _, _, _, "the functions are:")),
    assertion(sub_string(Text, _, _, _, "the price of *a cup* is *an amount*")),
    %  the value where it is used, and no condition of its own
    assertion(sub_string(Text, _, _, _, "and the price of the cup > 10")),
    assertion(\+ sub_string(Text, _, _, _, "the price of the cup is an amount")),
    %  and it reads back: the program it wrote answers its own expectation
    text_errors(Text, Errors),
    assertion(Errors == []),
    text_results(Text, Results),
    assertion(all_pass(Results)).

%   A value that feeds a formula is NOT written the compact way: a function
%   applied is not an arithmetic operand (§2.3), so the condition that binds it
%   stays and the document still reads back.
test(a_function_feeding_arithmetic_keeps_its_condition) :-
    le_write(program([kb(cups)], [
        template(expensive, "*a cup* is expensive", []),
        template(capacity, "the capacity of *a cup* is *a number* ml", [undefined]),
        function(price, "the price of *a cup* is *an amount*", []),
        rule(expensive(C), and(capacity(C, _), and(price(C, P), le_gt(P * 2, 10))), [])
    ]), Text, Issues),
    assertion(\+ member(issue(error, _, _), Issues)),
    assertion(sub_string(Text, _, _, _, "the price of the cup is an amount")),
    assertion(\+ sub_string(Text, _, _, _, "the price of the cup * 2")).

%   A value used where WORDS FOLLOW the phrase keeps its condition: written
%   compactly, "the select recalled of the policy is in [...]" reads back as
%   the function's value being `in [...]`. Ten expectations of a Socotra twin
%   went that way before the writer knew it.
test(a_function_before_a_word_form_keeps_its_condition) :-
    le_write(program([kb(uw)], [
        template(note, "the note for *a policy* is *a text*", []),
        function(recalled, "the select recalled of *a policy* is *a value*", [undefined]),
        rule(note(P, "rejected"), and(recalled(P, V), le_is_in(V, ["Yes"])), [])
    ]), Text, Issues),
    assertion(\+ member(issue(error, _, _), Issues)),
    assertion(sub_string(Text, _, _, _, "the select recalled of the policy is a value")),
    assertion(\+ sub_string(Text, _, _, _, "the select recalled of the policy is in")).

%   Conditions that compact away are REMOVED, not replaced by `true`: a `true`
%   among a body's conditions is written as a condition named "true", which no
%   template declares. An OIPA twin lost six expectations that way.
test(compacted_conditions_leave_no_true) :-
    le_write(program([kb(dates)], [
        template(due, "the due date of *an activity* is *a date*", []),
        function(advanced, "the months advanced of *an activity* is *a number*", [undefined]),
        function(paid, "the paid to date of *an activity* is *a date*", [undefined]),
        rule(due(A, D), and(paid(A, P), and(advanced(A, N), le_is_months_after(D, N, P))), [])
    ]), Text, Issues),
    assertion(\+ member(issue(error, _, _), Issues)),
    assertion(\+ sub_string(Text, _, _, _, "    true")),
    assertion(sub_string(Text, _, _, _,
        "the date is the months advanced of the activity months after the paid to date of the activity")).

test(missing_template_is_reported) :-
    le_write(program([kb(x)], [template(p, "*a thing* is p", []), rule(p(X), q(X), [])]), _, Issues),
    assertion(memberchk(issue(error, no_template, _), Issues)).

test(variables_named_from_their_places) :-
    le_write(program([kb(x)], [template(mother, "*a person* is the mother of *a person*", []),
                               template(gm, "*a person* is a grandmother of *a person*", []),
                               rule(gm(A, C), and(mother(A, B), mother(B, C)), [])]), Text),
    assertion(sub_string(Text, _, _, _, "a person is a grandmother of a second person if")),
    assertion(sub_string(Text, _, _, _, "the person is the mother of a third person")),
    assertion(sub_string(Text, _, _, _, "and the third person is the mother of the second person.")).

test(constants_that_would_read_as_something_else_are_quoted) :-
    render_constant('a car', T1), assertion(T1 == '"a car"'),
    render_constant('012', T2), assertion(T2 == '"012"'),
    render_constant('the UK', T3), assertion(T3 == 'the UK'),
    render_constant(date(2021, 3, 9), T4), assertion(T4 == '2021-03-09'),
    render_constant(0.2, T5), assertion(T5 == '0.2').

test(multilingual_articles) :-
    le_write(program([kb(x), language(pt)],
                     [template(rica, "*uma pessoa* fica rica", []),
                      template(aposta, "*uma pessoa* aposta em *um número*", []),
                      rule(rica(P), aposta(P, _), [])]), Text),
    assertion(sub_string(Text, _, _, _, "a linguagem alvo é: prolog.")),
    assertion(sub_string(Text, _, _, _, "uma pessoa fica rica se")),
    assertion(sub_string(Text, _, _, _, "a pessoa aposta em um número.")).

test(numbered_body, [condition(current_module(le_extensions))]) :-
    IR = program([kb(pension)], [
        template(eligible, "*a claimant* is eligible for a pension", []),
        template(poor, "*a claimant* is poor", [undefined]),
        template(sick, "*a claimant* is sick", [undefined]),
        template(other_income, "*a claimant* has another form of income", [undefined]),
        rule(eligible(C), or(poor(C), and(sick(C), not(other_income(C)))), [label(pension), numbered(true)]),
        scenario(sick, [fact(sick(ann)), expects(q, [eligible(ann)])], []),
        scenario(income, [fact(sick(ann)), fact(other_income(ann)), expects(q, [])], []),
        query(q, eligible(_))]),
    le_write(IR, Text),
    assertion(sub_string(Text, _, _, _, "a claimant is eligible for a pension if:")),
    assertion(sub_string(Text, _, _, _, "2.2. it is not the case that the claimant has another form of income.")),
    text_results(Text, Results),
    assertion(all_pass(Results)).

test(scenario_header_with_a_locator_keeps_its_lines) :-
    le_write(program([kb(x)], [template(p, "*a thing* is p", [undefined]),
                               scenario(s1, [fact(p(a)), expects(q, [p(a)])],
                                        [as_stated_in("tests.xlsx"), at('case 3')]),
                               query(q, p(_))]), Text),
    assertion(sub_string(Text, _, _, _, "scenario s1 is, as stated in \"tests.xlsx\" at case 3:\n    a is p.")),
    text_results(Text, Results),
    assertion(all_pass(Results)).

test(comparison_of_an_arithmetic_operand_is_evaluated) :-
    le_write(program([kb(x)], [template(after, "block *a height* is at least *a number* blocks after block *a first height*", []),
                               rule(after(H, N, F), H - F >= N, []),
                               scenario(s, [expects(q, []), expects(r, [after(2000, 1000, 100)])], []),
                               query(q, after(1050, 1000, 100)),
                               query(r, after(2000, 1000, 100))]), Text),
    text_results(Text, Results),
    assertion(all_pass(Results)).

:- end_tests(le_writer_ir).

:- begin_tests(le_writer_roundtrip).

%   LE -> knowledge base -> IR -> LE -> knowledge base, the same clauses.
roundtrips(File) :-
    le_writer_roundtrip:roundtrip_file(File, Outcome),
    assertion(Outcome == same).

test(citizenship) :- roundtrips('examples/moreExamples/citizenship.le').
test(otherwise_and_tables) :- roundtrips('examples/regulatory/otherwise_table.le').
test(provenance_views_scoped) :- roundtrips('examples/regulatory/eu261_integration.le').
test(aggregates) :- roundtrips('examples/moreExamples/domains/tax/sbpp_0.le').
test(portuguese) :- roundtrips('examples/pt/desconhecidos.le').
test(numbering, [condition(current_module(le_extensions))]) :-
    roundtrips('examples/moreExamples/language/extensions/numbering_test.le').

:- end_tests(le_writer_roundtrip).

:- begin_tests(prolog_to_le).

%   Plain Prolog to LE (§5.7): the translated program answers as Prolog does.
%   The expectations come from running the source — the scenario generator's
%   principle: the source's behaviour is the oracle.
prolog_oracle_ir(File, Queries, IR) :-
    prolog_file_to_ir(File, [kb(from_prolog), queries(Queries)], program(H, Items0)),
    % the source's own answers, by running it (its s(CASP) annotations aside)
    le_writer:read_prolog_terms(File, Terms),
    forall(( current_predicate(prolog_oracle_src:P/A), functor(Hd, P, A),
             \+ predicate_property(prolog_oracle_src:Hd, imported_from(_)) ),
           abolish(prolog_oracle_src:P/A)),
    forall(( member(C-_, Terms), \+ C = (:- _), \+ C = (#(_)) ),
           ( ( C = (Hd0 :- _) -> true ; Hd0 = C ),
             functor(Hd0, P0, A0), dynamic(prolog_oracle_src:P0/A0), assertz(prolog_oracle_src:C) )),
    findall(expects(QN, Answers),
            ( member(QN-G, Queries),
              findall(G, prolog_oracle_src:G, Answers0), sort(Answers0, Answers) ),
            Expects),
    append(Items0, [scenario(from_source, Expects, [])], Items),
    IR = program(H, Items).

test(family_answers_as_prolog) :-
    prolog_oracle_ir('testing/fixtures/prolog_to_le/family.pl',
                     [ancestors-ancestor(_, _), siblings-sibling(_, _), childless-childless(_),
                      adults-adult(_), gaps-grandparent_age_gap(_, _, _), counts-children_count(_, _)],
                     IR),
    le_write(IR, Text, Issues),
    \+ member(issue(error, _, _), Issues),
    text_results(Text, Results),
    assertion(all_pass(Results)).

test(scasp_pred_annotations_give_the_wording) :-
    prolog_oracle_ir('testing/fixtures/prolog_to_le/eligibility.pl', [eligible-eligible(_)], IR),
    le_write(IR, Text),
    assertion(sub_string(Text, _, _, _, "*a claimant* is eligible for the benefit")),
    assertion(sub_string(Text, _, _, _, "the income of *a claimant* is *an amount*")),
    text_results(Text, Results),
    assertion(all_pass(Results)).

%   `Z is max(X, Y)` (min, and either inside a formula or a comparison) is
%   the system condition `the maximum of X and Y is Z`: it used to loop in
%   the writer. The written rules compute what Prolog's max/min compute.
test(min_max_in_arithmetic_are_conditions) :-
    Clauses = [ (bigger(X, Y, Z) :- num(X), num(Y), Z is max(X, Y)),
                (lesser(X1, Y1, Z1) :- num(X1), num(Y1), Z1 is min(X1, Y1) + 1),
                (capped(X2, Y2) :- num(X2), num(Y2), Y2 > max(X2 * 2, 5)) ],
    prolog_to_ir(Clauses, [], program(H, Items0)),
    append(Items0, [scenario(s, [fact(num(3)), fact(num(7)),
                                 expects(big, [bigger(3, 3, 3), bigger(3, 7, 7), bigger(7, 3, 7), bigger(7, 7, 7)]),
                                 expects(less, [lesser(3, 3, 4), lesser(3, 7, 4), lesser(7, 3, 4), lesser(7, 7, 8)]),
                                 expects(cap, [capped(3, 7)])], []),
                    query(big, bigger(_, _, _)), query(less, lesser(_, _, _)), query(cap, capped(_, _))],
           Items),
    call_with_time_limit(20, le_write(program(H, Items), Text, Issues)),
    assertion(\+ member(issue(error, _, _), Issues)),
    assertion(sub_string(Text, _, _, _, "the maximum of")),
    assertion(sub_string(Text, _, _, _, "the minimum of")),
    assertion(\+ sub_string(Text, _, _, _, "max(")),
    text_results(Text, Results),
    assertion(all_pass(Results)).

%   A formula LE has no form for is an error issue and a comment naming the
%   rule, never a hang or a rule dropped without a word.
test(inexpressible_arithmetic_is_reported) :-
    prolog_to_ir([(square(X, Y) :- Y is X ** 2)], [], IR),
    call_with_time_limit(20, le_write(IR, Text, Issues)),
    assertion(memberchk(issue(error, rule_not_written, _), Issues)),
    assertion(sub_string(Text, _, _, _, "% a rule for square/2 the writer could not express")).

:- end_tests(prolog_to_le).

:- begin_tests(le_migration_pending).

%   An expectation whose query reaches what an open residue block must
%   conclude is pending: a comment in its scenario, counted in the ledger.
test(residue_dependent_expectations_are_pending) :-
    IR = program([kb(x)], [
        template(base, "the base premium of *a policy* is *an amount*", [undefined]),
        template(premium, "the premium of *a policy* is *an amount*", []),
        template(total, "the total of *a policy* is *an amount*", []),
        template(fee, "the fee of *a policy* is *an amount*", []),
        residue(r1, [title("the premium plugin"), concludes([premium])]),
        rule(total(P, T), and(premium(P, A), T is A + 5), []),
        rule(fee(P, F), and(base(P, B), F is B / 10), []),
        query(totals, total(_, _)), query(fees, fee(_, _))]),
    Tests = [test(t1, "tests.json", 'case 1', [base(p1, 100)],
                  [expects(totals, [total(p1, 125)]), expects(fees, [fee(p1, 10)])])],
    le_migration:migration_text(migration([], IR, [], Tests), Text, _),
    assertion(sub_string(Text, _, _, _, "% pending — waits for residue r1:")),
    assertion(sub_string(Text, _, _, _, "% totals expects answers")),
    text_results(Text, Results),
    assertion(Results = [pass(fees, t1)]),
    le_migration:ledger_markdown(migration([], IR, [], Tests), none, MD),
    assertion(sub_string(MD, _, _, _, "1 further expectation(s) are pending")).

:- end_tests(le_migration_pending).
