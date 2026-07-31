% Tests for the LLM price table (llm/llm_prices.pl) and the Contract
% Assistant's cost estimate built on it. A tiny local price file (pointed at by
% LE_MODEL_PRICES_FILE, exactly as an offline deployment would) stands in for
% LiteLLM's model_prices_and_context_window.json, so nothing here touches the
% network.

:- use_module('../llm/llm_prices').
:- use_module('../llm/llm_client').
:- use_module('../le_contract_assistant').

% A handful of rows in LiteLLM's schema: bare keys for OpenAI/Anthropic,
% provider-prefixed keys for the rest, plus a costless entry that must be
% ignored and a dearer twin of one model to prove the conservative choice.
price_fixture('{
  "sample_spec": {"input_cost_per_token": "docs, not a model"},
  "gpt-4o": {"input_cost_per_token": 2.5e-06, "output_cost_per_token": 1e-05,
             "litellm_provider": "openai", "mode": "chat"},
  "claude-haiku-4-5-20251001": {"input_cost_per_token": 1e-06,
             "output_cost_per_token": 5e-06, "litellm_provider": "anthropic", "mode": "chat"},
  "groq/openai/gpt-oss-120b": {"input_cost_per_token": 1.5e-07,
             "output_cost_per_token": 6e-07, "litellm_provider": "groq", "mode": "chat"},
  "cheapcloud/zai-org/glm-5.2": {"input_cost_per_token": 1e-06,
             "output_cost_per_token": 2e-06, "litellm_provider": "cheapcloud", "mode": "chat"},
  "dearcloud/zai-org/glm-5.2": {"input_cost_per_token": 3e-06,
             "output_cost_per_token": 9e-06, "litellm_provider": "dearcloud", "mode": "chat"},
  "text-embedding-3-small": {"input_cost_per_token": 2e-08, "litellm_provider": "openai",
             "mode": "embedding"}
}').

prices_setup :-
    tmp_file(le_prices, File),
    price_fixture(JSON),
    setup_call_cleanup(open(File, write, S, [encoding(utf8)]),
                       write(S, JSON), close(S)),
    setenv('LE_MODEL_PRICES_FILE', File),
    retractall(llm_prices:price_row(_, _, _)),
    retractall(llm_prices:prices_meta(_)),
    retractall(llm_prices:prices_tried),
    nb_setval(le_price_fixture, File).

prices_cleanup :-
    unsetenv('LE_MODEL_PRICES_FILE'),
    retractall(llm_prices:price_row(_, _, _)),
    retractall(llm_prices:prices_meta(_)),
    retractall(llm_prices:prices_tried),
    ( nb_current(le_price_fixture, F) -> catch(delete_file(F), _, true) ; true ).

:- begin_tests(llm_prices, [setup(prices_setup), cleanup(prices_cleanup)]).

test(loads_from_local_file) :-
    llm_prices_status(S),
    assertion(S.loaded == true),
    assertion(S.models =:= 5).      % the embedding row and sample_spec are skipped

% Bare key (OpenAI), and Anthropic likewise.
test(bare_key_lookup) :-
    llm_price('gpt-4o', In, Out),
    assertion(In =:= 2.5e-06),
    assertion(Out =:= 1e-05),
    llm_price('claude-haiku-4-5-20251001', In2, _),
    assertion(In2 =:= 1e-06).

% The registry's short name is resolved to the provider-qualified LiteLLM key.
test(provider_prefixed_lookup) :-
    llm_price('openai/gpt-oss-120b', In, Out),
    assertion(In =:= 1.5e-07),
    assertion(Out =:= 6e-07).

% Served by several providers under a suffix match: the DEAREST wins, so an
% estimate is never flattering.
test(ambiguous_model_takes_the_dearest) :-
    llm_price('zai-org/GLM-5.2', In, Out),
    assertion(In =:= 3e-06),
    assertion(Out =:= 9e-06).

test(unknown_model_has_no_price) :-
    assertion(\+ llm_price('no-such-model-anywhere', _, _)).

:- end_tests(llm_prices).

% --------------------------- the cost estimate -------------------------------

:- begin_tests(contract_cost_estimate, [setup(prices_setup), cleanup(prices_cleanup)]).

test(priced_estimate_is_positive_and_conservative) :-
    cost_estimate(_{model: "gpt-4o", judge_model: "gpt-4o", k: 3, w: 2,
                    repairs: 3, probes: 4, input_chars: 120000}, E),
    assertion(E.priced == true),
    assertion(E.cost_usd > 0),
    assertion(E.calls > 10),
    % every call carries the materials (30000 tokens) plus the house style and
    % the LE syntax summary
    assertion(E.input_tokens_per_call > 30000).

% More effort must never cost less.
test(more_effort_costs_more) :-
    cost_estimate(_{model: "gpt-4o", judge_model: "gpt-4o", k: 1, w: 1,
                    repairs: 2, probes: 0, input_chars: 40000}, Draft),
    cost_estimate(_{model: "gpt-4o", judge_model: "gpt-4o", k: 5, w: 3,
                    repairs: 4, probes: 8, input_chars: 40000}, Thorough),
    assertion(Thorough.calls > Draft.calls),
    assertion(Thorough.cost_usd > Draft.cost_usd).

% A cheap model must be cheaper than a dear one for the same work.
test(cheaper_model_is_cheaper) :-
    Params = _{model: "gpt-4o", judge_model: "gpt-4o", k: 1, w: 1,
               repairs: 2, probes: 0, input_chars: 40000},
    cost_estimate(Params, Dear),
    cost_estimate(Params.put(_{model: "openai/gpt-oss-120b",
                               judge_model: "openai/gpt-oss-120b"}), Cheap),
    assertion(Cheap.cost_usd < Dear.cost_usd).

% An unpriced model is reported as such — never as free.
test(unpriced_model_says_so) :-
    cost_estimate(_{model: "no-such-model-anywhere", judge_model: "no-such-model-anywhere",
                    k: 1, w: 1, repairs: 2, probes: 0, input_chars: 1000}, E),
    assertion(E.priced == false),
    assertion(E.cost_usd == null),
    assertion(sub_string(E.note, _, _, _, "no price listed")).

% An unpriced JUDGE still yields a (noted) estimate at the main model's rate.
test(unpriced_judge_falls_back_to_the_main_model) :-
    cost_estimate(_{model: "gpt-4o", judge_model: "no-such-model-anywhere",
                    k: 3, w: 1, repairs: 2, probes: 0, input_chars: 1000}, E),
    assertion(E.priced == true),
    assertion(sub_string(E.note, _, _, _, "judge model")).

% The /leapi entry point: request dict in (preset budget, no explicit K/W),
% JSON-able dict out.
test(handler_prices_a_preset) :-
    handle_contract_estimate(_{model: "gpt-4o", budget: _{preset: "standard"},
                               input_chars: 50000}, R),
    assertion(R.priced == true),
    assertion(R.cost_usd > 0),
    assertion(R.currency == "USD").

test(handler_survives_a_bare_request) :-
    handle_contract_estimate(_{}, R),
    assertion(is_dict(R)),
    assertion(get_dict(priced, R, _)).

:- end_tests(contract_cost_estimate).
