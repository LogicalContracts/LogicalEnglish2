/** <module> Scenario fact image additions ("<fact>; image "URL".")

    A scenario fact may end with `; image "https://…"`; the URL is stored as
    le_fact_image(Start, End, URL) against the fact's source range and served
    in load metadata (fact_images) for the Bento Box. Validation: an image on
    a non-ground fact, on a rule, or with an ill-formed URL yields a warning
    and the image is dropped.

    Run with:  swipl -q -g run_tests -t halt testing/test_fact_images.pl
    (or via testing/run_tests.sh unit)
*/

:- module(test_fact_images, []).

:- use_module(library(plunit)).
:- use_module('../le_kbs').

program("the target language is: prolog.

the templates are:
    *a thing* is red,
    *a thing* is pretty.

the knowledge base pics includes:

a thing is pretty
    if the thing is red; image \"https://example.com/rule.png\".

scenario s is:
    Rosie is red; image \"https://upload.wikimedia.org/x/rose.png\".
    a thing is red; image \"https://example.com/var.png\".
    Bricky is red; image \"not a url\".

query q is:
    which thing is pretty.
").

:- begin_tests(fact_images).

test(ground_fact_image_stored_and_in_metadata) :-
    program(P),
    le_kbs:load_text(P, KB),
    findall(U, KB:le_fact_image(_, _, U), URLs),
    URLs == ['https://upload.wikimedia.org/x/rose.png'],
    le_kbs:get_kb_metadata(KB, M),
    [Img] = M.fact_images,
    Img.url == 'https://upload.wikimedia.org/x/rose.png',
    integer(Img.start), integer(Img.end), Img.end > Img.start.

test(warnings_for_rule_nonground_and_bad_url) :-
    program(P),
    le_kbs:load_text(P, KB),
    findall(T, KB:le_issue(warning, T, _, _, _, _), Types0),
    msort(Types0, Types),
    % single_variable_fact also fires for the deliberate non-ground fact.
    subtract(Types, [single_variable_fact], ImageTypes),
    ImageTypes == [image_bad_url, image_nonground, image_on_rule].

% The stored range covers the whole annotated fact, so an explanation node for
% that fact (whose range equals the fact's) falls inside it.
test(image_range_covers_the_fact) :-
    program(P),
    le_kbs:load_text(P, KB),
    KB:le_fact_image(S, E, _),
    KB:scenario(s, Terms),
    member(fact_with_source(is_red('Rosie'), FS, FE), Terms),
    S == FS, E == FE.

% --- Template image additions ("; image "URL"" on a template) ---------------
% Acceptable only on a no-variable template; a template with variables gets a
% warning and the image is dropped.

template_program("the target language is: prolog.

the templates are:
    *a thing* is red; image \"https://example.com/red.png\",
    night has fallen; image \"https://example.com/night.png\".

the knowledge base night includes:

night has fallen.

query q is:
    night has fallen.
").

test(no_variable_template_image_stored_and_in_metadata) :-
    template_program(P),
    le_kbs:load_text(P, KB),
    findall(F-U, KB:le_template_image(F, U), Pairs),
    Pairs = [_-'https://example.com/night.png'],
    le_kbs:get_kb_metadata(KB, M),
    [TImg] = M.template_images,
    TImg.url == 'https://example.com/night.png',
    % Matched by the literal's canonical rendering — what explanation leaves carry.
    atom_string(A, TImg.literal), A == 'night has fallen'.

test(template_with_variables_image_warns) :-
    template_program(P),
    le_kbs:load_text(P, KB),
    once(KB:le_issue(warning, image_template_vars, _, _, S, E)),
    integer(S), integer(E), E > S.

:- end_tests(fact_images).
