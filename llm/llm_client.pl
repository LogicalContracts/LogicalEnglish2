/** <module> LLM Client
    
    A SWI-Prolog client for OpenAI-compatible LLM APIs.
    Supports OpenAI, Groq, Anthropic, Together AI, and Google Gemini.
    
    Public interface:
    - llm_request(+Model, +Query, -Answer): Send Query (atom or string) to Model, unify Answer with the assistant's reply text.
    - llm_request(+Model, +Messages, -Answer, +Options): Low-level call. Messages is a list of role-content pairs. Options is a list of Name(Value) terms that are forwarded verbatim as extra JSON fields (e.g. temperature(0.2), max_tokens(512)).
    - llm_model(+Model, -Provider, -APIModel): Look up the provider and the exact model string for a short name.
    - llm_list_models(-Rows): Rows = list of row(ShortName, Provider, APIModel).

    Message format:
    Messages may be given as:
    - A plain atom/string -> treated as a single user message.
    - A list of role(Role, Content) terms where Role in {system, user, assistant}.

    API-key configuration:
    Keys are read from environment variables:
    - OPENAI_API_KEY - for provider openai
    - GROQ_API_KEY - for provider groq
    - ANTHROPIC_API_KEY - for provider anthropic
    - TOGETHER_API_KEY - for provider together (also TOGETHERAI_API_KEY)
    - GEMINI_API_KEY - for provider gemini (free at aistudio.google.com)

    Alternatively set Prolog flags:
    - :- set_prolog_flag(llm_openai_key, 'sk-...').
    - :- set_prolog_flag(llm_groq_key, 'gsk_...').
    - :- set_prolog_flag(llm_anthropic_key, 'sk-ant-...').
    - :- set_prolog_flag(llm_gemini_key, 'AIza...').

    Dependencies:
    - library(http/http_client) - ships with SWI-Prolog
    - library(http/http_json) - ships with SWI-Prolog
    - library(http/http_ssl_plugin) - TLS support (usually auto-loaded)
*/

:- module(llm_client,
    [ llm_request/3,        % +Model, +Query, -Answer
      llm_request/4,        % +Model, +Messages, -Answer, +Options
      llm_model/3,          % +ShortName, -Provider, -APIModel
      llm_list_models/1,    % -Rows
      llm_print_models/0,   % pretty-print registry
      api_key/2             % +Provider, -Key
    ]).

:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_open)).
:- use_module(library(http/http_ssl_plugin)).
:- use_module(library(option)).
:- use_module(library(lists)).
:- use_module(library(apply)).


% ═══════════════════════════════════════════════════════════════════
% 1.  MODEL REGISTRY
%     llm_model_entry(ShortName, Provider, APIModelString, BaseURL)
% ═══════════════════════════════════════════════════════════════════

%% OpenAI  ──────────────────────────────────────────────────────────
% cf. https://platform.openai.com/docs/models
% llm_model_entry('o1',                openai, 'o1',                'https://api.openai.com/v1').
% llm_model_entry('o1-mini',           openai, 'o1-mini',           'https://api.openai.com/v1').
% llm_model_entry('o3-mini',           openai, 'o3-mini',           'https://api.openai.com/v1').
llm_model_entry('gpt-4o',            openai, 'gpt-4o',            'https://api.openai.com/v1').
llm_model_entry('gpt-4o-mini',       openai, 'gpt-4o-mini',       'https://api.openai.com/v1').
llm_model_entry('gpt-4-turbo',       openai, 'gpt-4-turbo',       'https://api.openai.com/v1').
llm_model_entry('gpt-4',             openai, 'gpt-4',             'https://api.openai.com/v1').
llm_model_entry('gpt-5.5',             openai, 'gpt-5.5',             'https://api.openai.com/v1').


%% Groq  ────────────────────────────────────────────────────────────
% https://console.groq.com/docs/models
llm_model_entry('llama-3.3-70b',    groq, 'llama-3.3-70b-versatile',          'https://api.groq.com/openai/v1').
% llm_model_entry('llama-3.1-70b',    groq, 'llama-3.1-70b-versatile',          'https://api.groq.com/openai/v1').
% llm_model_entry('llama-3.1-8b',     groq, 'llama-3.1-8b-instant',             'https://api.groq.com/openai/v1').
llm_model_entry('meta-llama/llama-4-scout-17b-16e-instruct',     groq, 'meta-llama/llama-4-scout-17b-16e-instruct',               'https://api.groq.com/openai/v1').
% llm_model_entry('gemma2-9b',        groq, 'gemma2-9b-it',                     'https://api.groq.com/openai/v1').
% llm_model_entry('deepseek-r1',      groq, 'deepseek-r1-distill-llama-70b',    'https://api.groq.com/openai/v1').
llm_model_entry('openai/gpt-oss-120b',      groq, 'openai/gpt-oss-120b',    'https://api.groq.com/openai/v1'). % our favorite


%% Anthropic  ───────────────────────────────────────────────────────
% https://platform.claude.com/docs/en/about-claude/models/overview
%  Native Messages API (NOT OpenAI-compat) – handled separately in call_api/5.
llm_model_entry('claude-haiku-4-5-20251001', anthropic, 'claude-haiku-4-5-20251001', 'https://api.anthropic.com/v1').
llm_model_entry('claude-opus-5', anthropic, 'claude-opus-5', 'https://api.anthropic.com/v1').
% llm_model_entry('claude',     anthropic, 'claude-haiku-4-5-20251001',     'https://api.anthropic.com/v1').

%% Together AI  ─────────────────────────────────────────────────────
% https://api.together.ai/models
% llm_model_entry('llama-3.3-70b-together', together, 'meta-llama/Llama-3.3-70B-Instruct-Turbo', 'https://api.together.xyz/v1').
% llm_model_entry('llama-3.1-405b',         together, 'meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo', 'https://api.together.xyz/v1').
llm_model_entry('MiniMaxAI/MiniMax-M2.7',          together, 'MiniMaxAI/MiniMax-M2.7', 'https://api.together.xyz/v1').
llm_model_entry('deepseek-ai/DeepSeek-V4-Pro',          together, 'deepseek-ai/DeepSeek-V4-Pro', 'https://api.together.xyz/v1').
llm_model_entry('zai-org/GLM-5.2',          together, 'zai-org/GLM-5.2', 'https://api.together.xyz/v1').

%% Google Gemini  (OpenAI-compatible endpoint) ──────────────────────
% cf. https://ai.google.dev/gemini-api/docs/models
%  Endpoint: https://generativelanguage.googleapis.com/v1beta/openai
%  Key:      GEMINI_API_KEY  –  get one free at aistudio.google.com
%
llm_model_entry('gemini-2.0-flash',      gemini, 'gemini-2.0-flash',             'https://generativelanguage.googleapis.com/v1beta/openai').
% llm_model_entry('gemini-2.0-flash-lite', gemini, 'gemini-2.0-flash-lite-preview', 'https://generativelanguage.googleapis.com/v1beta/openai').
% llm_model_entry('gemini-1.5-pro',        gemini, 'gemini-1.5-pro',               'https://generativelanguage.googleapis.com/v1beta/openai').
llm_model_entry('gemini-3-flash-preview',      gemini, 'gemini-3-flash-preview',             'https://generativelanguage.googleapis.com/v1beta/openai').
llm_model_entry('gemini-3.1-flash-lite-preview',      gemini, 'gemini-3.1-flash-lite-preview',             'https://generativelanguage.googleapis.com/v1beta/openai').
llm_model_entry('gemini-3.1-pro-preview', gemini, 'gemini-3.1-pro-preview','https://generativelanguage.googleapis.com/v1beta/openai').
llm_model_entry('gemini-3.5-flash', gemini, 'gemini-3.5-flash','https://generativelanguage.googleapis.com/v1beta/openai').

%  Convenience alias 
% llm_model_entry('gemini',                gemini, 'gemini-3.1-flash-lite-preview',             'https://generativelanguage.googleapis.com/v1beta/openai').


% ───────────────────────────────────────────────────────────────────
% llm_model(+Short, -Provider, -APIModel)
% ───────────────────────────────────────────────────────────────────
llm_model(Short, Provider, APIModel) :-
    ( atom(Short) -> S = Short ; atom_string(S, Short) ),
    llm_model_entry(S, Provider, APIModel, _).

% ───────────────────────────────────────────────────────────────────
% llm_list_models(-Rows)
% ───────────────────────────────────────────────────────────────────
llm_list_models(Rows) :-
    findall(row(S,P,M), llm_model_entry(S,P,M,_), Rows).


% ═══════════════════════════════════════════════════════════════════
% 2.  PUBLIC ENTRY POINTS
% ═══════════════════════════════════════════════════════════════════

%% llm_request(+Model, +Query, -Answer)
llm_request(Model, Query, Answer) :-
    llm_request(Model, Query, Answer, []).

%% llm_request(+Model, +Query, -Answer, +Options)
%
%  Options are extra JSON fields: temperature(T), max_tokens(N), top_p(P), …
%
llm_request(Model, Query, Answer, Options) :-
    resolve_model(Model, Provider, APIModel, BaseURL),
    normalise_messages(Query, Messages),
    (   option(api_key(Key), Options)
    ->  true
    ;   api_key(Provider, Key)
    ),
    % Remove api_key option from Options before building body
    select_option(api_key(_), Options, CleanOptions0, Options),
    % reasoning(minimal) is provider-agnostic: translate it into the
    % provider's own dialect (or drop it where unsupported) instead of
    % forwarding it verbatim.
    (   select_option(reasoning(Level), CleanOptions0, CleanOptions1)
    ->  reasoning_fields(Provider, APIModel, Level, RFields),
        append(CleanOptions1, RFields, CleanOptions)
    ;   CleanOptions = CleanOptions0
    ),
    build_body(Provider, APIModel, Messages, CleanOptions, BodyPairs),
    call_api(Provider, BaseURL, Key, BodyPairs, RawJSON),
    extract_answer(Provider, RawJSON, Answer).

%!  reasoning_fields(+Provider, +APIModel, +Level, -ExtraOptions) is det.
%
%   How to ask each provider's models to think less. Only level `minimal` is
%   mapped for now. Where a provider would reject the parameter (or thinking
%   is off by default), the option is dropped rather than risking a 400.
%   - OpenAI-compatible reasoning models take reasoning_effort.
%   - Together serves GLM/Qwen-style models via vLLM, whose chat templates
%     take chat_template_kwargs.enable_thinking.
%   - Anthropic thinking is off unless explicitly enabled: nothing to do.
reasoning_fields(groq, Model, minimal, Fields) :- !,
    (   reasoning_effort_model(Model)
    ->  Fields = [reasoning_effort(low)]
    ;   Fields = []
    ).
reasoning_fields(openai, Model, minimal, Fields) :- !,
    (   atom_string(M, Model), sub_atom(M, 0, _, _, 'gpt-5')
    ->  Fields = [reasoning_effort(minimal)]   % gpt-5* accepts "minimal"
    ;   reasoning_effort_model(Model)
    ->  Fields = [reasoning_effort(low)]       % o-series knows only low/medium/high
    ;   Fields = []
    ).
reasoning_fields(gemini, _Model, minimal, [reasoning_effort(low)]) :- !.
reasoning_fields(together, _Model, minimal,
                 [chat_template_kwargs(_{enable_thinking: false})]) :- !.
reasoning_fields(_, _, _, []).

reasoning_effort_model(Model) :-
    atom_string(M, Model),
    member(Prefix, ['o1', 'o3', 'o4', 'gpt-5', 'openai/gpt-oss', 'gpt-oss', 'qwen', 'Qwen', 'deepseek', 'moonshotai/kimi']),
    sub_atom(M, 0, _, _, Prefix), !.


% ═══════════════════════════════════════════════════════════════════
% 3.  MODEL RESOLUTION
% ═══════════════════════════════════════════════════════════════════

resolve_model(Model, Provider, APIModel, BaseURL) :-
    ( atom(Model) -> M = Model ; atom_string(M, Model) ),
    llm_model_entry(M, Provider, APIModel, BaseURL), !.
resolve_model(Model, Provider, APIModel, BaseURL) :-
    infer_provider(Model, Provider, BaseURL),
    APIModel = Model, !.
resolve_model(Model, _, _, _) :-
    format(atom(Msg),
        "Unknown model '~w'. Use llm_list_models/1 to see available models.",
        [Model]),
    throw(error(llm_unknown_model(Model), context(llm_client, Msg))).

infer_provider(M, openai,   'https://api.openai.com/v1')                             :- sub_atom(M,0,_,_,'gpt-'),    !.
infer_provider(M, openai,   'https://api.openai.com/v1')                             :- sub_atom(M,0,_,_,'o1'),      !.
infer_provider(M, openai,   'https://api.openai.com/v1')                             :- sub_atom(M,0,_,_,'o3'),      !.
infer_provider(M, anthropic,'https://api.anthropic.com/v1')                          :- sub_atom(M,0,_,_,'claude'),  !.
infer_provider(M, gemini,   'https://generativelanguage.googleapis.com/v1beta/openai'):- sub_atom(M,0,_,_,'gemini'), !.
infer_provider(M, groq,     'https://api.groq.com/openai/v1')                        :- sub_atom(M,0,_,_,'llama'),   !.
infer_provider(M, groq,     'https://api.groq.com/openai/v1')                        :- sub_atom(M,0,_,_,'mixtral'), !.
infer_provider(M, groq,     'https://api.groq.com/openai/v1')                        :- sub_atom(M,0,_,_,'gemma'),   !.
% infer_provider(_M, openai,  'https://api.openai.com/v1').                           % fallback removed to avoid accidental backtracking


% ═══════════════════════════════════════════════════════════════════
% 4.  MESSAGE NORMALISATION
% ═══════════════════════════════════════════════════════════════════

normalise_messages(Query, [_{role:user, content:QA}]) :-
    ( atom(Query) ; string(Query) ), !,
    atom_string(QA, Query).
normalise_messages(Messages, JSON) :-
    is_list(Messages), !,
    maplist(msg_to_dict, Messages, JSON).
normalise_messages(role(R,C), [_{role:R, content:C}]) :- !.

msg_to_dict(role(Role, Content), _{role:Role, content:Content}) :- !.
msg_to_dict(system(Content),     _{role:system,    content:Content}) :- !.
msg_to_dict(user(Content),       _{role:user,      content:Content}) :- !.
msg_to_dict(assistant(Content),  _{role:assistant, content:Content}) :- !.
msg_to_dict(Dict, Dict) :- is_dict(Dict), !.
msg_to_dict(json(Pairs), Dict) :- dict_pairs(Dict, _, Pairs).


% ═══════════════════════════════════════════════════════════════════
% 5.  REQUEST BODY CONSTRUCTION
%
%  build_body/5 produces a dict ready for http_post(..., json(Dict), ...).
% ═══════════════════════════════════════════════════════════════════

build_body(anthropic, APIModel, Messages, Options, Body) :- !,
    % Anthropic Messages API: max_tokens is required; system is a top-level field.
    option(max_tokens(MaxTok), Options, 1024),
    extract_system(Messages, SysContent, UserMessages),
    Base = _{model:APIModel, max_tokens:MaxTok, messages:UserMessages},
    ( SysContent \= '' -> Body0 = Base.put(system, SysContent); Body0 = Base),
    option_pairs(Options, [max_tokens], OptionPairs),
    dict_pairs(Extra, _, OptionPairs),
    Body = Body0.put(Extra).

build_body(openai, APIModel, Messages, Options, Body) :- !,
    % Newer OpenAI models (gpt-5*, o-series) reject max_tokens: the parameter
    % was renamed max_completion_tokens (which all current chat models accept).
    (   select_option(max_tokens(MT), Options, Options1)
    ->  Options2 = [max_completion_tokens(MT)|Options1]
    ;   Options2 = Options
    ),
    % ... and the reasoning models also reject any non-default temperature.
    (   reasoning_effort_model(APIModel)
    ->  exclude(is_temperature_option, Options2, Options3)
    ;   Options3 = Options2
    ),
    Body0 = _{model:APIModel, messages:Messages},
    option_pairs(Options3, [], OptionPairs),
    dict_pairs(Extra, _, OptionPairs),
    Body = Body0.put(Extra).

build_body(_Provider, APIModel, Messages, Options, Body) :-
    % OpenAI-compatible: Groq, Gemini, Together …
    Body0 = _{model:APIModel, messages:Messages},
    option_pairs(Options, [], OptionPairs),
    dict_pairs(Extra, _, OptionPairs),
    Body = Body0.put(Extra).

is_temperature_option(temperature(_)).

% Pull the system message out of the list for Anthropic
extract_system(Messages, System, Rest) :-
    ( selectchk(_{role:system, content:S}, Messages, Rest1) -> System = S, Rest = Rest1; System = '', Rest = Messages).

% Convert Options list → JSON key=Value pairs, skipping SkipKeys
option_pairs(Options, SkipKeys, Pairs) :-
    include(option_allowed(SkipKeys), Options, Allowed),
    maplist(option_to_pair, Allowed, Pairs).

option_allowed(Skip, Opt) :-
    Opt =.. [Key | _],
    \+ memberchk(Key, Skip).

option_to_pair(Opt, Key-Val) :-
    Opt =.. [Key, Val].


% ═══════════════════════════════════════════════════════════════════
% 6.  HTTP CALL
%
%  Receives Body as a dict from build_body.
%  Posts it as json(Body) → http_post sees json(Dict) which tells it
%  to use the JSON plugin to write the dict as a JSON object.
% ═══════════════════════════════════════════════════════════════════

call_api(anthropic, BaseURL, Key, Body, Response) :- !,
    atomic_list_concat([BaseURL, '/messages'], Endpoint),
    atom_string(Key, KeyStr),
    catch(
        http_post(Endpoint,
            json(Body),
            Response,
            [ json_object(dict),
              status_code(Code),
              timeout(600),
              request_header('x-api-key'=KeyStr),
              request_header('anthropic-version'='2023-06-01')
            ]),
        E, handle_http_error(E)
    ),
    check_status(Code, Response).

call_api(_Provider, BaseURL, Key, Body, Response) :-
    atomic_list_concat([BaseURL, '/chat/completions'], Endpoint),
    atom_string(Key, KeyStr),
    atomic_list_concat(['Bearer ', KeyStr], Auth),
    catch(
        http_post(Endpoint,
            json(Body),
            Response,
            [ json_object(dict),
              status_code(Code),
              timeout(600),
              request_header('Authorization'=Auth)
            ]),
        E, handle_http_error(E)
    ),
    check_status(Code, Response).

handle_http_error(E) :-
    throw(error(llm_http_error(E), context(llm_client, "HTTP request failed"))).

check_status(Code, _) :-
    Code >= 200, Code < 300, !.
check_status(Code, Response) :-
    format(atom(Msg), "API returned HTTP ~w: ~w", [Code, Response]),
    throw(error(llm_api_error(Code, Response), context(llm_client, Msg))).


% ═══════════════════════════════════════════════════════════════════
% 7.  RESPONSE PARSING
% ═══════════════════════════════════════════════════════════════════

% Anthropic: { content: [ <block>, ... ], stop_reason: "..." }
%
% The content is a LIST OF BLOCKS, and the visible answer is not necessarily
% the first one: thinking models put `{type:"thinking", thinking:"...",
% signature:"..."}` (or a redacted_thinking block) ahead of the text, so
% reading content[0].text blows up with existence_error(key, text, ...).
% Keep every text block, in order; a reply with none is either an answer that
% drowned in reasoning (stop_reason "max_tokens" -> the same llm_truncated
% error the OpenAI-compatible branch raises) or simply empty.
extract_answer(anthropic, Response, Answer) :- !,
    (   is_dict(Response)
    ->  ( get_dict(content, Response, Blocks) -> true ; Blocks = [] ),
        ( get_dict(stop_reason, Response, Stop) -> true ; Stop = none )
    ;   Response = json(RList),
        ( member(content=Blocks, RList) -> true ; Blocks = [] ),
        ( member(stop_reason=Stop, RList) -> true ; Stop = none )
    ),
    findall(T, ( member(B, Blocks), block_text(B, T) ), Texts),
    atomic_list_concat(Texts, '\n', AnswerAtom),
    atom_string(AnswerAtom, Answer0),
    (   empty_text(Answer0),
        truncated_finish(Stop)
    ->  throw(error(llm_truncated(max_tokens),
                    context(llm_client,
                            "The model hit max_tokens while still thinking (stop_reason=max_tokens): no text block was produced. Raise max_tokens, or use a less reasoning-heavy model.")))
    ;   Answer = Answer0
    ).

% The text of one Anthropic content block; fails for thinking, redacted
% thinking and tool-use blocks, which carry no `text` key.
block_text(Block, Text) :- is_dict(Block), !, get_dict(text, Block, Text).
block_text(json(Pairs), Text) :- memberchk(text=Text, Pairs).

% OpenAI-compatible (OpenAI, Groq, Gemini, Together):
%   { choices: [ { message: { content: "..." } } ] }
% Reasoning models (GLM, DeepSeek-R1 style) complicate this: the visible
% answer may follow a <think>...</think> block inside content, or content may
% be empty/unclosed because the whole completion budget went to reasoning
% (finish_reason "length"). The latter is reported as a distinct
% llm_truncated error so callers can give the right advice (RAISE max_tokens).
extract_answer(_Provider, Response, Answer) :-
    (   is_dict(Response) ->
            Response.choices = [First|_],
            Message = First.message,
            ( get_dict(content, Message, Raw0) -> true ; Raw0 = "" ),
            ( get_dict(finish_reason, First, FinishReason) -> true ; FinishReason = none )
        ;
        Response = json(RList),
        member(choices=[json(C0)|_], RList),
        member(message=json(M0), C0),
        ( member(content=Raw0, M0) -> true ; Raw0 = "" ),
        ( member(finish_reason=FinishReason, C0) -> true ; FinishReason = none )
    ),
    ( Raw0 == null -> Raw = "" ; Raw0 = '@'(null) -> Raw = "" ; Raw = Raw0 ),
    strip_think_block(Raw, Answer0),
    (   empty_text(Answer0),
        truncated_finish(FinishReason)
    ->  throw(error(llm_truncated(max_tokens),
                    context(llm_client,
                            "The model hit max_tokens while still reasoning (finish_reason=length): no visible answer was produced. Raise max_tokens, or use a less reasoning-heavy model.")))
    ;   Answer = Answer0
    ).

truncated_finish(FR) :- ( FR == "length" ; FR == length ; FR == "max_tokens" ; FR == 'MAX_TOKENS' ), !.

empty_text(T) :-
    ( T == "" ; T == '' ), !.
empty_text(T) :-
    atom_string(A, T), normalize_space(atom(N), A), N == ''.

%!  strip_think_block(+Raw, -Out) is det.
%
%   Drops a <think>...</think> reasoning block, keeping what follows the LAST
%   closing tag. An opened but never-closed block means the reply is all
%   reasoning: no visible answer.
strip_think_block(Raw, Out) :-
    atom_string(RA, Raw),
    (   sub_atom(RA, _, _, _, '<think>')
    ->  atomic_list_concat(Parts, '</think>', RA),
        (   Parts = [_]
        ->  Out = ""
        ;   last(Parts, LastA),
            atom_string(LastA, S1),
            split_string(S1, "", " \t\n\r", [Out])
        )
    ;   Out = Raw
    ).


% ═══════════════════════════════════════════════════════════════════
% 8.  API KEY RESOLUTION
% ═══════════════════════════════════════════════════════════════════

api_key(openai,    Key) :- key_from_flag_or_env(llm_openai_key,    'OPENAI_API_KEY',    Key), !.
api_key(groq,      Key) :- key_from_flag_or_env(llm_groq_key,      'GROQ_API_KEY',      Key), !.
api_key(anthropic, Key) :- key_from_flag_or_env(llm_anthropic_key, 'ANTHROPIC_API_KEY', Key), !.
api_key(together,  Key) :- (key_from_flag_or_env(llm_together_key,  'TOGETHER_API_KEY',  Key) ; key_from_flag_or_env(llm_together_key, 'TOGETHERAI_API_KEY', Key)), !.
api_key(gemini,    Key) :- (key_from_flag_or_env(llm_gemini_key,    'GEMINI_API_KEY',    Key) ; key_from_flag_or_env(llm_gemini_key, 'GOOGLE_API_KEY', Key) ; key_from_flag_or_env(llm_gemini_key, 'GOOGLE_GENERATIVE_AI_API_KEY', Key)), !.
api_key(Provider, _) :-
    format(atom(Msg),
        "No API key for provider '~w'. Set env var or set_prolog_flag(llm_~w_key, 'KEY').",
        [Provider, Provider]),
    throw(error(llm_no_api_key(Provider), context(llm_client, Msg))).

key_from_flag_or_env(Flag, EnvVar, Key) :-
    ( (current_prolog_flag(Flag, Key), Key \= '') -> true; getenv(EnvVar, Key)).


% ═══════════════════════════════════════════════════════════════════
% 9.  UTILITIES
% ═══════════════════════════════════════════════════════════════════

%% llm_print_models/0  – Pretty-print the model table
llm_print_models :-
    llm_list_models(Rows),
    format("~`─t~65|~n"),
    format("~w~t~25|~w~t~42|~w~n", ['Short name', 'Provider', 'API model string']),
    format("~`─t~65|~n"),
    forall(member(row(S,P,M), Rows),
        format("~w~t~25|~w~t~42|~w~n", [S, P, M])),
    format("~`─t~65|~n").
