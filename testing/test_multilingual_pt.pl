% Multilingual (Portuguese pilot) regression tests: language detection from the
% opener statement, locale-aware number tokenization (O-3 option B), keyword
% lexicon lookups, localized diagnostics, and localized number rendering.
:- use_module('../le_kbs').
:- use_module('../le_i18n').
:- use_module('../tokenizer').

:- begin_tests(multilingual_pt).

test(detect_en) :-
    tokenizer:tokenize("the target language is: prolog.", Ts),
    le_i18n:detect_language_tokens(Ts, en).

test(detect_pt) :-
    tokenizer:tokenize("a linguagem alvo é: prolog.", Ts),
    le_i18n:detect_language_tokens(Ts, pt).

test(detect_none_fails, [fail]) :-
    tokenizer:tokenize("o tempo está bom.", Ts),
    le_i18n:detect_language_tokens(Ts, _).

test(pt_decimal_comma) :-
    tokenizer:tokenize("o custo é 1,5", ',', '.', Ts),
    memberchk(number(1.5, _), Ts).

test(pt_thousands_dot) :-
    tokenizer:tokenize("o total é 1.234.567", ',', '.', Ts),
    memberchk(number(1234567, _), Ts).

test(pt_list_commas_survive) :-
    tokenizer:tokenize("[1, 5]", ',', '.', Ts),
    memberchk(number(1, _), Ts),
    memberchk(number(5, _), Ts),
    memberchk(punctuation(',', _), Ts).

test(en_decimal_point_unchanged) :-
    tokenizer:tokenize("pi is 3.14 and big is 10,000,000", Ts),
    memberchk(number(3.14, _), Ts),
    memberchk(number(10000000, _), Ts).

test(pt_keywords) :-
    le_i18n:with_le_language(pt, (
        le_i18n:kw_synonym_words(if, [se]),
        le_i18n:kw_synonym_words(forall, [para, todos, os, casos, em, que]),
        le_i18n:class_member(article, uma),
        le_i18n:class_member(article, 'Uma'),
        le_i18n:class_member(meta_marker, que),
        \+ le_i18n:class_member(article, the)
    )).

test(en_fallback_when_language_unset) :-
    le_i18n:kw_synonym_words(if, [if]),
    le_i18n:class_member(article, an).

test(pt_message_catalog) :-
    le_i18n:with_le_language(pt,
        le_i18n:le_msg(missing_template_desc, [name-'x voa'], Msg)),
    Msg == 'Falta um modelo para \'x voa\''.

test(msg_en_fallback_for_empty_cell) :-
    le_i18n:with_le_language(pt,
        le_i18n:le_msg(parsing_failed_desc, [], Msg)),
    atom(Msg).

test(pt_system_templates_active) :-
    le_i18n:with_le_language(pt,
        ( le_system_templates:le_system_template(dict([le_gt, _, _], _, WV)),
          include(atom, WV, Words),
          Words == [é, superior, a] )).

test(pt_program_loads_and_records_language) :-
    le_kbs:load_text("a linguagem alvo é: prolog.\n\nos modelos são:\n*uma pessoa* voa.\n\na base de conhecimento voo inclui:\nfred voa.\n\nconsulta um é:\nqual pessoa voa.\n", M),
    M:le_lang(pt).

test(pt_number_rendering) :-
    le_i18n:with_le_language(pt, le_kbs:token_to_atom(number(1.5, loc(0,0)), A)),
    A == '1,5'.

test(en_number_rendering_unchanged) :-
    % Reset the thread flag (an earlier test's load_text left it at pt).
    le_i18n:set_le_language(default),
    le_kbs:token_to_atom(number(1.5, loc(0,0)), A),
    A == '1.5'.

:- end_tests(multilingual_pt).

% --- Phase 5 languages (es/fr/it): detection + lexicon spot checks -----------
:- begin_tests(multilingual_es_fr_it).

test(detect_es) :-
    tokenizer:tokenize("el lenguaje objetivo es: prolog.", Ts),
    le_i18n:detect_language_tokens(Ts, es).

test(detect_fr) :-
    tokenizer:tokenize("la langue cible est: prolog.", Ts),
    le_i18n:detect_language_tokens(Ts, fr).

test(detect_it) :-
    tokenizer:tokenize("il linguaggio obiettivo è: prolog.", Ts),
    le_i18n:detect_language_tokens(Ts, it).

test(es_keywords) :-
    le_i18n:with_le_language(es, (
        le_i18n:kw_synonym_words(if, [si]),
        le_i18n:class_member(article, una),
        le_i18n:kw_synonym_words(forall, [para, todos, los, casos, en, que])
    )).

test(fr_keywords) :-
    le_i18n:with_le_language(fr, (
        le_i18n:kw_synonym_words(if, [si]),
        le_i18n:class_member(article, une),
        le_i18n:kw_synonym_words(not_the_case, [il, est, faux, que])
    )).

test(it_keywords) :-
    le_i18n:with_le_language(it, (
        le_i18n:kw_synonym_words(if, [se]),
        le_i18n:class_member(article, una),
        le_i18n:kw_synonym_words(forall, [per, tutti, i, casi, in, cui])
    )).

test(es_system_template, [nondet]) :-
    le_i18n:with_le_language(es,
        ( le_system_templates:le_system_template(dict([le_gt, _, _], _, WV)),
          include(atom, WV, Words),
          Words == [es, superior, a] )).

test(language_flag_reset_after_suite) :-
    le_i18n:set_le_language(default).

:- end_tests(multilingual_es_fr_it).
