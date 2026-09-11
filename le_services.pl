/** <module> Services: call once, cache, attribute

    A program may declare external services and back templates with them:

        the knowledge base semantic match includes these services:
            matcher at http://127.0.0.1:3050/test_services/matcher as a semantic matcher.

        the templates are:
            the best match of *a text* among *a list* is *a category*; via service matcher.

    A goal on a service-backed template is answered by the service, at run
    time, with its inputs bound. The LAST argument may be unknown (the answer
    the service fills in); every other argument is an input and must be known.
    Each distinct request is made ONCE: the request is canonicalised (service,
    template, inputs with strings normalised and lists sorted, the service's
    declared version, the request format version) and hashed, and the answer
    is kept in the session (always) and in a persistent, content-addressed
    cache (when the flag `le_service_cache_dir` names a directory). An answer
    enters the proof attributed to the service: its explanation node reads
    "..., according to service matcher", and a source-scoped proof
    (`according to service matcher`) admits it like any other evidence. A
    service that cannot be reached, with nothing cached, makes the goal an
    unknown — a conditional answer, not a crash.

    Backends, by the declared address:
      http(s)://...   POST of the request as JSON; the reply is
                      {"answers": [[arg, ...], ...], "rationale": "..."}
      llm:<model>     an LLM (llm/llm_client.pl, e.g. llm:openai/gpt-oss-120b
                      on Groq, key from GROQ_API_KEY), prompted with the
                      template and the known arguments, replying in the same
                      JSON shape
      stub:<name>     the in-process test stubs below (also served over HTTP at
                      /test_services/<name> by the LE server)

    The three built-in semantic templates (`*a text* is semantically similar
    to *a second text*`, `the best match of *a text* among *a list* is *an
    item*`, `*a text* satisfies the description *a description*`) are backed
    by the program's first service declared "as a semantic matcher".
*/

:- module(le_services, [
    service_backed/3,           % +KM, +Goal, -Service
    service_call/7,             % +Goal, +Service, +SM, +KM, -Us, -Ref, -Rationale
    service_source/2,           % +ServiceName, -SourceConstant
    stub_service/3,             % +StubName, +RequestDict, -ResponseDict
    stub_calls/2,               % ?StubName, ?Count
    reset_stub_calls/0,
    service_materialise/3       % +SM, +KB, -Lines
]).

:- use_module(library(sha)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(http/http_open)).
:- use_module(library(http/http_json)).
:- use_module(le_i18n).

request_format_version(1).

:- dynamic stub_call_count/2.

% ---------------------------------------------------------------------------
% Which goals are service-backed
% ---------------------------------------------------------------------------

%!  service_backed(+KM, +Goal, -Service) is semidet.
%
%   Goal's template is backed by Service = service(Name, Address, Kind).
service_backed(KM, Goal, Service) :-
    KM \== none,
    compound(Goal),
    functor(Goal, F, A),
    (   current_predicate(KM:le_service_template/2),
        KM:le_service_template(F/A, Name)
    ->  declared_service(KM, Name, Service)
    ;   semantic_system_functor(F/A),
        semantic_matcher(KM, Service)
    ).

semantic_system_functor(le_semantically_similar/2).
semantic_system_functor(le_best_match/3).
semantic_system_functor(le_satisfies_description/2).

declared_service(KM, Name, service(Name, Address, Kind)) :-
    current_predicate(KM:le_service/3),
    KM:le_service(Name, Address, Kind), !.
declared_service(_, Name, _) :-
    throw(error(le_service_error(undeclared(Name)), context(le_services, 'service not declared'))).

% The first service declared as a semantic matcher.
semantic_matcher(KM, service(Name, Address, Kind)) :-
    current_predicate(KM:le_service/3),
    kw_main_words(kind_semantic_matcher, KindWords),
    atomic_list_concat(KindWords, ' ', KindAtom),
    KM:le_service(Name, Address, Kind),
    sub_atom(Kind, _, _, _, KindAtom), !.
semantic_matcher(_, _) :-
    throw(error(le_service_error(no_semantic_matcher), context(le_services, 'no semantic matcher declared'))).

%!  service_source(+Name, -Source) is det.
%
%   The provenance source of a service's answers: the constant a program
%   writes as `according to service matcher`.
service_source(Name, Source) :-
    le_msg(service_source, [name-Name], Source).

% ---------------------------------------------------------------------------
% Calling
% ---------------------------------------------------------------------------

%!  service_call(+Goal, +Service, +SM, +KM, -Us, -Ref, -Rationale) is nondet.
%
%   Answers Goal through Service: one solution per answer tuple, with Us = []
%   and Ref = service(Name, Hash). When the service cannot be reached and
%   nothing is cached, Goal is returned as an unknown (Us = [Goal], Ref =
%   unknown).
service_call(Goal, service(Name, Address, Kind), SM, KM, Us, Ref, Rationale) :-
    Goal =.. [F|Args],
    append(Inputs, [_Last], Args),
    (   ground(Inputs) -> true
    ;   throw(error(le_service_error(unbound_input(Name, F)),
                    context(le_services, 'a service is called with its inputs known')))
    ),
    template_text(KM, Goal, TemplateText),
    canonical_request(Name, Address, Kind, F, TemplateText, Args, Request, Hash),
    (   session_cached(SM, Hash, Result) -> true
    ;   persistent_cached(Hash, Address, Result0) -> Result = Result0, remember(SM, Hash, Result)
    ;   call_backend(Address, Name, Request, Result),
        remember(SM, Hash, Result),
        ( Result = answers(_, _) -> persist(Hash, Address, Request, Result) ; true )
    ),
    (   Result = answers(Tuples, Rationale)
    ->  last(Args, Last),
        answer_value(Tuples, Last),
        note_service_fact(SM, Hash, Name, Goal),
        Us = [], Ref = service(Name, Hash)
    ;   Us = [Goal], Ref = unknown, Rationale = none
    ).

%   Only the LAST argument can be unknown, so what an answer contributes is its
%   last element: the inputs are the program's own, whatever a service (a
%   language model rewording a description, say) echoes back for them. With
%   every argument known, any answer means true.
answer_value(Tuples, Last) :-
    var(Last), !,
    findall(V, ( member(T, Tuples), T = [_|_], last(T, V) ), Vs0),
    sort(Vs0, Vs),
    member(Last, Vs).
answer_value(Tuples, _Last) :-
    Tuples \== [].               % a yes/no question, answered yes

% The answers a session used, for service_materialise/3.
note_service_fact(SM, Hash, Name, Goal) :-
    SM:dynamic(le_service_fact/3),
    (   SM:le_service_fact(Hash, Name, G0), G0 =@= Goal -> true
    ;   assertz(SM:le_service_fact(Hash, Name, Goal))
    ).

session_cached(SM, Hash, Result) :-
    catch(SM:le_service_cache(Hash, Result), _, fail), !.

remember(SM, Hash, Result) :-
    SM:dynamic(le_service_cache/2),
    ( SM:le_service_cache(Hash, _) -> true ; assertz(SM:le_service_cache(Hash, Result)) ).

% ---------------------------------------------------------------------------
% Canonical requests
% ---------------------------------------------------------------------------

canonical_request(Name, Address, Kind, F, TemplateText, Args, Request, Hash) :-
    request_format_version(V),
    maplist(request_arg, Args, JArgs),
    service_version(Address, SVersion),
    Request = _{ request_format_version: V,
                 service: Name,
                 kind: Kind,
                 service_version: SVersion,
                 predicate: F,
                 template: TemplateText,
                 args: JArgs },
    % The key: service, template, inputs, version — NOT the program (the
    % answer depends on the request, not on the program around it).
    KeyTerm = key(V, Name, SVersion, F, TemplateText, JArgs),
    variant_sha1(KeyTerm, Hash).

% A known argument in canonical form (strings normalised, lists sorted);
% an unknown one as null.
request_arg(A, null) :- var(A), !.
request_arg(A, J) :- canonical_value(A, J).

canonical_value(L, J) :- is_list(L), !, maplist(canonical_value, L, J0), msort(J0, J1), sort(J1, J).
canonical_value(N, N) :- number(N), !.
canonical_value(date(Y, M, D), S) :- !, format(string(S), "~w-~|~`0t~w~2|-~|~`0t~w~2|", [Y, M, D]).
canonical_value(A, S) :- ( atom(A) ; string(A) ), !,
    atom_string(A, S0), normalize_space(string(S), S0).
canonical_value(T, S) :- term_string(T, S).

service_version(Address, Version) :-
    (   atom_concat('llm:', Model, Address) -> Version = Model ; Version = Address ).

% The template's surface with its slots starred: what the service is asked.
template_text(KM, Goal, Text) :-
    functor(Goal, F, A),
    (   catch(le_kbs:template_of(KM, F, A, _, Label), _, fail)
    ->  Text = Label
    ;   le_system_templates:le_system_template(dict([F|Args], NTs, WV)), length(Args, A)
    ->  copy_term(NTs-WV, NTsC-WVC), maplist(le_kbs:starred_type, NTsC),
        le_kbs:canonical_string(WVC, Text)
    ;   term_string(F/A, Text)
    ).

% ---------------------------------------------------------------------------
% Persistent cache (optional)
% ---------------------------------------------------------------------------

cache_file(Hash, File) :-
    current_prolog_flag(le_service_cache_dir, Dir),
    atom(Dir), Dir \== '',
    exists_directory(Dir),
    atomic_list_concat([Dir, '/', Hash, '.json'], File).

persistent_cached(Hash, Address, answers(Tuples, Rationale)) :-
    cache_file(Hash, File),
    exists_file(File),
    catch(setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                             json_read_dict(In, D),
                             close(In)), _, fail),
    service_version(Address, V),
    atom_string(V, VS),
    % A stored answer from another model/version is refused.
    get_dict(service_version, D, StoredV), atom_string(StoredV, VS),
    get_dict(answers, D, JTuples),
    maplist(maplist(json_value), JTuples, Tuples),
    ( get_dict(rationale, D, R0), R0 \== null -> atom_string(R0, R1), Rationale = R1 ; Rationale = none ).

persist(Hash, _Address, Request, answers(Tuples, Rationale)) :-
    (   cache_file(Hash, File)
    ->  maplist(maplist(to_json_value), Tuples, JTuples),
        ( Rationale == none -> JR = null ; JR = Rationale ),
        D = Request.put(_{answers: JTuples, rationale: JR}),
        catch(setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                                 json_write_dict(Out, D),
                                 close(Out)), _, true)
    ;   true
    ).

% ---------------------------------------------------------------------------
% Backends
% ---------------------------------------------------------------------------

%!  call_backend(+Address, +Name, +Request, -Result) is det.
%
%   Result is answers(Tuples, Rationale) or failed(Reason).
call_backend(Address, _Name, Request, Result) :-
    catch(backend(Address, Request, Reply), E, (Reply = error(E))),
    (   Reply = error(Err)
    ->  term_string(Err, Reason), Result = failed(Reason),
        print_message(warning, format("LE service ~w: ~w", [Address, Reason]))
    ;   reply_answers(Reply, Request, Result)
    ).

backend(Address, Request, Reply) :-
    atom_concat('stub:', Stub, Address), !,
    stub_service(Stub, Request, Reply).
backend(Address, Request, Reply) :-
    atom_concat('llm:', Model, Address), !,
    llm_backend(Model, Request, Reply).
backend(Address, Request, Reply) :-
    ( sub_atom(Address, 0, _, _, 'http://') ; sub_atom(Address, 0, _, _, 'https://') ), !,
    le_kbs:le_network_allowed,
    setup_call_cleanup(
        http_open(Address, In, [post(json(Request)), request_header('Accept'='application/json'),
                                timeout(20), status_code(Code)]),
        ( Code =:= 200 -> json_read_dict(In, Reply) ; Reply = error(http_status(Code)) ),
        close(In)).
backend(Address, _, _) :-
    throw(error(le_service_error(unknown_address(Address)), _)).

reply_answers(Reply, Request, answers(Tuples, Rationale)) :-
    is_dict(Reply),
    get_dict(answers, Reply, JTuples0), is_list(JTuples0), !,
    maplist(as_tuple, JTuples0, JTuples1),
    maplist(maplist(json_value), JTuples1, Tuples0),
    maplist(resolve_to_inputs(Request.args), Tuples0, Tuples),
    ( get_dict(rationale, Reply, R), R \== null, R \== "" -> atom_string(R, RS), Rationale = RS ; Rationale = none ).
reply_answers(Reply, _, failed(Reason)) :-
    term_string(bad_reply(Reply), Reason).

% An answer is a tuple of arguments; a bare value stands for the last one.
as_tuple(T, T) :- is_list(T), T \== [], !.
as_tuple(V, [V]).

json_value(J, V) :- is_list(J), !, maplist(json_value, J, V).
json_value(J, J) :- number(J), !.
json_value(J, V) :- string(J), !, atom_string(V, J).
json_value(J, V) :- atom(J), !, V = J.
json_value(J, V) :- term_string(J, V).

to_json_value(V, J) :- is_list(V), !, maplist(to_json_value, V, J).
to_json_value(V, V) :- number(V), !.
to_json_value(V, J) :- ( atom(V) ; string(V) ), !, atom_string(V, J).
to_json_value(V, J) :- term_string(V, J).

% An answer value that names one of the elements of a list input (the
% candidates of a best match) is that element, whatever its case or spacing.
resolve_to_inputs(ReqArgs, Tuple, Resolved) :-
    findall(E, ( member(L, ReqArgs), is_list(L), member(E, L) ), Candidates),
    maplist(resolve_value(Candidates), Tuple, Resolved).

resolve_value(Candidates, V, R) :-
    (   atom(V), downcase_atom(V, LV),
        member(C, Candidates), atom_string(CA, C), downcase_atom(CA, LV)
    ->  R = CA
    ;   R = V
    ).

% ---------------------------------------------------------------------------
% The LLM backend
% ---------------------------------------------------------------------------

llm_backend(Model, Request, Reply) :-
    ensure_llm_client,
    format(string(System),
"You decide a single predicate of a logic program. You are given the predicate's
sentence template, where each *...* is an argument slot, and the arguments in
order; null marks the ONE unknown argument you must fill in. Reply with JSON
only, no prose: {\"answers\": [[arg1, arg2, ...]], \"rationale\": \"one sentence\"}.
- If there is an unknown argument, give the tuple(s) that make the sentence
  true, with the known arguments copied unchanged; when a known argument is a
  list of candidates, the unknown must be one of them. Give only the best
  tuple unless several are equally correct.
- If every argument is known, answer [[...the arguments...]] when the sentence
  is true and [] when it is false.
Judge by meaning, not by spelling.", []),
    format(string(User), "Template: ~w~nArguments: ~w",
           [Request.template, Request.args]),
    atom_string(Model, ModelS),
    atom_string(ModelA, ModelS),
    llm_client:llm_request(ModelA, [role(system, System), role(user, User)], Answer,
                           [temperature(0)]),
    extract_json(Answer, Reply).

ensure_llm_client :-
    (   current_predicate(llm_client:llm_request/4) -> true
    ;   use_module(le2('llm/llm_client'))
    ).

% The first {...} object in the model's reply.
extract_json(Text0, Dict) :-
    ( string(Text0) -> Text = Text0 ; atom_string(Text0, Text) ),
    sub_string(Text, B, _, _, "{"),
    sub_string(Text, E0, _, _, "}"), E0 > B,
    \+ ( sub_string(Text, E1, _, _, "}"), E1 > E0 ),
    Len is E0 - B + 1,
    sub_string(Text, B, Len, _, JSON),
    catch(atom_json_dict(JSON, Dict, []), _, fail), !.
extract_json(Text, _) :-
    throw(error(le_service_error(unparsable_reply(Text)), _)).

% ---------------------------------------------------------------------------
% Test stubs (in process, and over HTTP at /test_services/<name>)
% ---------------------------------------------------------------------------

%!  stub_service(+Name, +Request, -Reply) is det.
%
%   Deterministic stand-ins for a semantic matcher and a judgment assistant,
%   counting their calls (stub_calls/2). The matcher knows a fixed vocabulary
%   of categories; with every argument known it answers by word overlap.
stub_service(Name, Request, Reply) :-
    count_stub_call(Name),
    Args = Request.args,
    (   Name == matcher -> stub_matcher(Args, Answers, Why)
    ;   Name == judge -> stub_judge(Args, Answers, Why)
    ;   Answers = [], Why = "unknown stub"
    ),
    Reply = _{answers: Answers, rationale: Why}.

count_stub_call(Name) :-
    with_mutex(le_service_stubs,
        (   ( retract(stub_call_count(Name, N0)) -> N is N0 + 1 ; N = 1 ),
            assertz(stub_call_count(Name, N)) )).

stub_calls(Name, N) :- ( stub_call_count(Name, N0) -> N = N0 ; N = 0 ).
reset_stub_calls :- retractall(stub_call_count(_, _)).

stub_matcher(Args, Answers, Why) :-
    append(Known, [null], Args),
    member(Candidates, Known), is_list(Candidates), !,
    exclude(is_list, Known, Texts),
    atomic_list_concat(Texts, ' ', Text),
    text_words(Text, Words),
    (   member(C, Candidates), stub_category(C, Keys),
        member(K, Keys), memberchk(K, Words)
    ->  append(Known, [C], Tuple), Answers = [Tuple],
        format(string(Why), "~w names a kind of ~w", [K, C])
    ;   Answers = [], Why = "no candidate matches"
    ).
stub_matcher(Args, Answers, Why) :-
    \+ memberchk(null, Args),
    maplist(value_words, Args, WordSets),
    WordSets = [W1, W2|_],
    intersection(W1, W2, Common), exclude(stop_word, Common, Content),
    (   Content \== []
    ->  Answers = [Args], format(string(Why), "they share ~w", [Content])
    ;   Answers = [], Why = "no content word in common"
    ).
stub_matcher(_, [], "unsupported request").

stub_judge(Args, [Tuple], "stub judgment") :-
    ( append(Known, [null], Args) -> append(Known, [yes], Tuple) ; Tuple = Args ).

stub_category(C, Keys) :-
    atom_string(CA, C),
    (   stub_vocabulary(CA, Keys0) -> true ; Keys0 = [] ),
    Keys = [CA|Keys0].

stub_vocabulary(vehicle, [bicycle, bike, car, truck, bus, van, scooter, motorcycle]).
stub_vocabulary(fruit, [apple, banana, pear, orange, grape, cherry]).
stub_vocabulary(tool, [hammer, saw, drill, wrench, screwdriver, pliers]).

value_words(V, Ws) :- ( is_list(V) -> atomic_list_concat(V, ' ', T) ; T = V ), text_words(T, Ws).

text_words(Text, Words) :-
    ( string(Text) -> S = Text ; atom_string(Text, S) ),
    string_lower(S, L),
    split_string(L, " ,.;:!?\"'()[]", " ,.;:!?\"'()[]", Parts),
    exclude(==(""), Parts, Parts1),
    maplist(atom_string, Words, Parts1).

stop_word(W) :- memberchk(W, [a, an, the, of, with, and, or, in, on, at, to, is, it, its, for, by]).

% ---------------------------------------------------------------------------
% Materialise
% ---------------------------------------------------------------------------

%!  service_materialise(+SM, +KB, -Lines) is det.
%
%   The answers a session obtained from services, as ordinary provenance-
%   bearing scenario facts ("<fact>, according to service matcher, as stated
%   in cache at <hash>.") — pasted into a scenario, they make the program run
%   without the service or its cache.
service_materialise(SM, KB, Lines) :-
    findall(Line,
            ( catch(SM:le_service_fact(Hash, Name, Fact), _, fail),
              source_form(KB, Fact, FS),
              service_source(Name, Src),
              kw_main_words(according_to, AW), atomic_list_concat(AW, ' ', A),
              kw_main_words(as_stated_in, SW), atomic_list_concat(SW, ' ', St),
              kw_main_words(at_locator, [At|_]),
              format(string(Line), "~w, ~w ~w, ~w cache ~w ~w.", [FS, A, Src, St, At, Hash]) ),
            Lines0),
    sort(Lines0, Lines).

% A fact as Logical English source: its template's main form with each
% argument written as it would be in a scenario — strings quoted, lists in
% brackets with commas — so that the line parses back to the same fact.
source_form(KB, Fact, Text) :-
    Fact =.. [F|Args],
    length(Args, A),
    (   le_kbs:template_of(KB, F, A, Dict, _)
    ->  arg(1, Dict, [F|Formal]), arg(3, Dict, WV0),
        copy_term(Formal-WV0, Args-WV),
        maplist(source_part, WV, Parts),
        atomic_list_concat(Parts, ' ', Text)
    ;   term_string(Fact, Text)
    ).

source_part(P, S) :- string(P), !, source_value(P, S).
source_part(P, S) :- is_list(P), !, source_value(P, S).
source_part(P, P) :- atom(P), !.
source_part(P, S) :- source_value(P, S).

source_value(S, Q) :- string(S), !,
    split_string(S, "\"", "", Parts), atomic_list_concat(Parts, '\\"', Esc),
    format(atom(Q), '"~w"', [Esc]).
source_value(L, Q) :- is_list(L), !,
    maplist(source_value, L, Es), atomic_list_concat(Es, ', ', In),
    format(atom(Q), '[~w]', [In]).
source_value(N, N) :- number(N), !.
source_value(date(Y, M, D), Q) :- !, format(atom(Q), '~w-~|~`0t~w~2|-~|~`0t~w~2|', [Y, M, D]).
source_value(A, A) :- atom(A), !.
source_value(T, Q) :- term_to_atom(T, Q).
