/** <module> LLM price table

    Per-token prices for the models of llm_client.pl, taken from LiteLLM's
    community-maintained price list

        https://github.com/BerriAI/litellm
        model_prices_and_context_window.json

    (schema documented in that repository: one JSON object per model, with
    `input_cost_per_token`, `output_cost_per_token`, `litellm_provider`,
    `max_input_tokens`, ... — the sample_spec entry describes every field).

    The file is fetched ONCE at server startup (llm_prices_start/0, from a
    detached thread so a slow or unreachable GitHub never delays the server)
    and cached on disk, so a later restart without network still has prices.

    Prices are only ever used for ESTIMATES (see the LE Contract Assistant's
    cost estimate), never for billing, so every failure mode here is soft: an
    unknown model simply has no price and the estimate says so.

    Environment overrides:
      - LE_MODEL_PRICES_FILE   read this local JSON file, never fetch (tests)
      - LE_MODEL_PRICES_URL    fetch from here instead of GitHub
      - LE_MODEL_PRICES_CACHE  cache path (default tmp/model_prices.json)
*/

:- module(llm_prices, [
    llm_prices_start/0,      % background refresh, called at server startup
    llm_prices_refresh/0,    % synchronous fetch + cache
    llm_prices_ensure/0,     % load from cache/file if the table is empty
    llm_price/3,             % +Model, -InputCostPerToken, -OutputCostPerToken
    llm_prices_status/1      % -Dict
]).

:- use_module(library(http/http_open)).
:- use_module(library(http/http_ssl_plugin)).
:- use_module(library(http/json)).
:- use_module(library(apply)).
:- use_module(library(lists)).

:- dynamic price_row/3.        % LowercaseKey (string), InputPerToken, OutputPerToken
:- dynamic prices_meta/1.      % _{models: N, source: S, fetched: Stamp}
:- dynamic prices_tried/0.     % a local load was already attempted (empty or not)

prices_url(URL) :-
    (   getenv('LE_MODEL_PRICES_URL', U)
    ->  URL = U
    ;   URL = 'https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json'
    ).

cache_file(File) :-
    (   getenv('LE_MODEL_PRICES_CACHE', F)
    ->  File = F
    ;   File = 'tmp/model_prices.json'
    ).

% A local file wins over the network entirely: offline runs and tests.
local_file(File) :-
    getenv('LE_MODEL_PRICES_FILE', File).

% =============================== Loading =====================================

%!  llm_prices_start is det.
%
%   Called once when the server starts: publish whatever is cached (instant),
%   then refresh from the network in the background.
llm_prices_start :-
    catch(llm_prices_ensure, _, true),
    (   local_file(_)
    ->  true                                  % pinned to a local file: never fetch
    ;   catch(thread_create(refresh_quietly, _, [detached(true)]), E,
              print_message(warning, format("LLM price refresh could not start: ~w", [E])))
    ).

refresh_quietly :-
    catch(llm_prices_refresh, E,
          print_message(warning,
              format("LLM prices unavailable (~w); cost estimates will be partial", [E]))).

%!  llm_prices_refresh is det.
%
%   Fetches the price list and replaces the table; also writes the cache.
llm_prices_refresh :-
    prices_url(URL),
    fetch_json(URL, Dict),
    store_prices(Dict, N),
    get_time(Now),
    set_meta(N, URL, Now),
    catch(write_cache(Dict), _, true),
    print_message(informational,
        format("LLM prices loaded: ~w models from ~w", [N, URL])).

fetch_json(URL, Dict) :-
    setup_call_cleanup(
        http_open(URL, In, [timeout(60)]),
        json_read_dict(In, Dict, [value_string_as(string)]),
        close(In)).

%!  llm_prices_ensure is det.
%
%   Makes sure the table has been given a chance to fill, WITHOUT touching the
%   network (an HTTP request must never wait on GitHub): the pinned local file
%   if there is one, else the cache written by an earlier fetch.
llm_prices_ensure :-
    ( price_row(_, _, _) -> true ; prices_tried -> true ; load_local ).

load_local :-
    assertz(prices_tried),
    (   local_file(File), exists_file(File)
    ->  load_file(File)
    ;   cache_file(Cache), exists_file(Cache)
    ->  load_file(Cache)
    ;   true
    ).

load_file(File) :-
    catch(
        ( read_json_file(File, Dict),
          store_prices(Dict, N),
          ( exists_file(File), time_file(File, Stamp) -> true ; get_time(Stamp) ),
          set_meta(N, File, Stamp)
        ),
        E,
        print_message(warning, format("Cannot read LLM prices from ~w: ~w", [File, E]))).

read_json_file(File, Dict) :-
    setup_call_cleanup(open(File, read, S, [encoding(utf8)]),
                       json_read_dict(S, Dict, [value_string_as(string)]),
                       close(S)).

write_cache(Dict) :-
    cache_file(File),
    file_directory_name(File, Dir),
    ( Dir == '.' -> true ; make_directory_path(Dir) ),
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       json_write_dict(S, Dict, [width(0)]),
                       close(S)).

set_meta(N, Source, Stamp) :-
    retractall(prices_meta(_)),
    term_string(Source, SourceS),
    assertz(prices_meta(_{models: N, source: SourceS, fetched: Stamp})).

%!  store_prices(+Dict, -Count) is det.
%
%   Keeps the two fields an estimate needs, under a lowercased key. Entries
%   without both per-token prices (embeddings, image models, the sample_spec
%   documentation entry) are skipped.
store_prices(Dict, Count) :-
    dict_pairs(Dict, _, Pairs),
    retractall(price_row(_, _, _)),
    foldl(store_price_pair, Pairs, 0, Count).

store_price_pair(Key-Val, N0, N) :-
    (   is_dict(Val),
        price_field(Val, input_cost_per_token, In),
        price_field(Val, output_cost_per_token, Out)
    ->  atom_string(Key, KS), string_lower(KS, KL),
        assertz(price_row(KL, In, Out)),
        N is N0 + 1
    ;   N = N0
    ).

price_field(D, Field, V) :-
    get_dict(Field, D, V0), number(V0), V is float(V0).

% ================================ Lookup =====================================

%!  llm_price(+Model, -InputPerToken, -OutputPerToken) is semidet.
%
%   Model is a short name of llm_client's registry (or any model string). The
%   candidates tried are LiteLLM's provider-qualified key ("groq/openai/
%   gpt-oss-120b"), then the bare model string. As a last resort a key ending
%   in "/<model>" is accepted — and when several providers serve the same
%   model, the MOST EXPENSIVE one is chosen: estimates must never flatter.
llm_price(Model, In, Out) :-
    llm_prices_ensure,
    once(price_row(_, _, _)),                % table non-empty
    model_keys(Model, ApiKey, ShortKey),
    (   candidate(ApiKey, ShortKey, Cand),
        price_row(Cand, In0, Out0)
    ->  In = In0, Out = Out0
    ;   suffix_price(ApiKey, In, Out)
    ->  true
    ;   suffix_price(ShortKey, In, Out)
    ->  true
    ;   segment_price(ApiKey, In, Out)
    ).

model_keys(Model, ApiKey, ShortKey) :-
    atom_string(Model, MS),
    string_lower(MS, ShortKey0),
    (   catch(llm_client:llm_model(Model, Provider, APIModel), _, fail)
    ->  atom_string(APIModel, AS), string_lower(AS, ApiName)
    ;   Provider = unknown, ApiName = ShortKey0
    ),
    ( provider_prefix(Provider, Pfx) -> true ; Pfx = "" ),
    string_concat(Pfx, ApiName, ApiKey0),
    ApiKey = key(ApiKey0, ApiName),
    string_concat(Pfx, ShortKey0, ShortKey1),
    ShortKey = key(ShortKey1, ShortKey0).

% LiteLLM prefixes its keys per provider; OpenAI and Anthropic models are bare.
provider_prefix(openai,    "").
provider_prefix(anthropic, "").
provider_prefix(groq,      "groq/").
provider_prefix(together,  "together_ai/").
provider_prefix(gemini,    "gemini/").
provider_prefix(unknown,   "").

candidate(key(Prefixed, _), _, Prefixed).
candidate(key(_, Bare), _, Bare).
candidate(_, key(Prefixed, _), Prefixed).
candidate(_, key(_, Bare), Bare).

suffix_price(key(_, Bare), In, Out) :-
    string_concat("/", Bare, Suffix),
    findall(C-p(I, O),
            ( price_row(K, I, O), sub_string(K, _, _, 0, Suffix), C is I + O ),
            Rows),
    dearest(Rows, In, Out).

% Last resort: the same model served under another org prefix
% ("deepseek-ai/DeepSeek-V4-Pro" vs LiteLLM's "azure_ai/deepseek-v4-pro").
% Again the dearest match wins.
segment_price(key(_, Bare), In, Out) :-
    last_segment(Bare, Seg), Seg \== "",
    findall(C-p(I, O),
            ( price_row(K, I, O), last_segment(K, Seg), C is I + O ),
            Rows),
    dearest(Rows, In, Out).

last_segment(Key, Seg) :-
    split_string(Key, "/", "", Parts),
    last(Parts, Seg).

dearest(Rows, In, Out) :-
    Rows \== [],
    keysort(Rows, Sorted),
    last(Sorted, _-p(In, Out)).

%!  llm_prices_status(-Status:dict) is det.
llm_prices_status(Status) :-
    catch(llm_prices_ensure, _, true),
    (   prices_meta(M)
    ->  Status = M.put(loaded, true)
    ;   Status = _{loaded: false, models: 0, source: "none", fetched: 0}
    ).
