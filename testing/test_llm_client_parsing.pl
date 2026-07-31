% Tests for llm_client's reply extraction with reasoning models (GLM,
% DeepSeek-R1 style): <think> blocks are stripped, and a reply whose whole
% completion budget went to reasoning (finish_reason "length", no visible
% answer) raises a distinct llm_truncated error.

:- use_module('../llm/llm_client').

:- begin_tests(llm_reply_extraction).

test(plain_content_passes_through) :-
    R = _{choices: [_{message: _{content: "the answer"}, finish_reason: "stop"}]},
    llm_client:extract_answer(together, R, A),
    assertion(A == "the answer").

test(think_block_is_stripped) :-
    R = _{choices: [_{message: _{content: "<think>step 1... step 2...</think>\nthe visible answer"}, finish_reason: "stop"}]},
    llm_client:extract_answer(together, R, A),
    assertion(A == "the visible answer").

test(last_think_block_wins) :-
    R = _{choices: [_{message: _{content: "<think>a</think>draft<think>b</think>final"}, finish_reason: "stop"}]},
    llm_client:extract_answer(together, R, A),
    assertion(A == "final").

test(unclosed_think_with_length_is_truncated_error) :-
    R = _{choices: [_{message: _{content: "<think>reasoning forever and ever"}, finish_reason: "length"}]},
    catch(llm_client:extract_answer(together, R, _), error(llm_truncated(_), _), Caught = true),
    assertion(Caught == true).

test(empty_content_with_length_is_truncated_error) :-
    R = _{choices: [_{message: _{content: ""}, finish_reason: "length"}]},
    catch(llm_client:extract_answer(together, R, _), error(llm_truncated(_), _), Caught = true),
    assertion(Caught == true).

test(null_content_with_length_is_truncated_error) :-
    R = _{choices: [_{message: _{content: null}, finish_reason: "length"}]},
    catch(llm_client:extract_answer(together, R, _), error(llm_truncated(_), _), Caught = true),
    assertion(Caught == true).

% An empty reply with a normal stop is NOT truncation — it stays an empty
% answer (the contract assistant handles that as empty_reply with retries).
test(empty_content_with_stop_is_just_empty) :-
    R = _{choices: [_{message: _{content: ""}, finish_reason: "stop"}]},
    llm_client:extract_answer(together, R, A),
    assertion(A == "").

% Anthropic's Messages API returns a LIST of content blocks. Thinking models
% put a thinking block (no `text` key) first, which used to crash the parser
% with existence_error(key, text, ...).
test(anthropic_plain_text_block) :-
    R = _{content: [_{type: "text", text: "the answer"}], stop_reason: "end_turn"},
    llm_client:extract_answer(anthropic, R, A),
    assertion(A == "the answer").

test(anthropic_thinking_block_before_text) :-
    R = _{content: [_{type: "thinking", thinking: "long reasoning", signature: "abc"},
                    _{type: "text", text: "the answer"}],
          stop_reason: "end_turn"},
    llm_client:extract_answer(anthropic, R, A),
    assertion(A == "the answer").

test(anthropic_several_text_blocks_are_joined) :-
    R = _{content: [_{type: "text", text: "part one"},
                    _{type: "text", text: "part two"}],
          stop_reason: "end_turn"},
    llm_client:extract_answer(anthropic, R, A),
    assertion(A == "part one\npart two").

% Only thinking, and the budget ran out: the same truncation error the
% OpenAI-compatible branch raises, so callers can raise max_tokens.
test(anthropic_thinking_only_at_max_tokens_is_truncated_error) :-
    R = _{content: [_{type: "thinking", thinking: "and on and on", signature: "abc"}],
          stop_reason: "max_tokens"},
    catch(llm_client:extract_answer(anthropic, R, _), error(llm_truncated(_), _), Caught = true),
    assertion(Caught == true).

test(anthropic_thinking_only_with_normal_stop_is_empty) :-
    R = _{content: [_{type: "thinking", thinking: "hmm", signature: "abc"}],
          stop_reason: "end_turn"},
    llm_client:extract_answer(anthropic, R, A),
    assertion(A == "").

:- end_tests(llm_reply_extraction).

% The provider-agnostic reasoning(minimal) option translates into each
% provider's own dialect — and is dropped where it would be rejected.
:- begin_tests(llm_reasoning_control).

test(together_uses_chat_template_kwargs) :-
    llm_client:reasoning_fields(together, 'zai-org/GLM-5.2', minimal, F),
    F = [chat_template_kwargs(D)],
    get_dict(enable_thinking, D, ET),
    assertion(ET == false).

test(groq_reasoning_model_uses_effort) :-
    llm_client:reasoning_fields(groq, 'openai/gpt-oss-120b', minimal, F),
    assertion(F == [reasoning_effort(low)]).

test(groq_plain_model_gets_nothing) :-
    llm_client:reasoning_fields(groq, 'llama-3.3-70b-versatile', minimal, F),
    assertion(F == []).

test(openai_plain_model_gets_nothing) :-
    llm_client:reasoning_fields(openai, 'gpt-4o', minimal, F),
    assertion(F == []).

test(openai_gpt5_uses_effort_minimal) :-
    llm_client:reasoning_fields(openai, 'gpt-5.2', minimal, F),
    assertion(F == [reasoning_effort(minimal)]).

test(openai_o_series_uses_effort_low) :-
    llm_client:reasoning_fields(openai, 'o3-mini', minimal, F),
    assertion(F == [reasoning_effort(low)]).

test(anthropic_no_op) :-
    llm_client:reasoning_fields(anthropic, 'claude-sonnet', minimal, F),
    assertion(F == []).

:- end_tests(llm_reasoning_control).

% OpenAI renamed max_tokens to max_completion_tokens, and its reasoning models
% (gpt-5*, o-series) reject non-default temperature: the body builder must
% translate/drop accordingly — and leave other providers untouched.
:- begin_tests(llm_openai_body).

test(openai_translates_max_tokens_and_drops_temperature_for_reasoning) :-
    llm_client:build_body(openai, 'gpt-5.5',
                          [_{role: user, content: "hi"}],
                          [max_tokens(100), temperature(0.2)], B),
    assertion(B.max_completion_tokens =:= 100),
    assertion(\+ get_dict(max_tokens, B, _)),
    assertion(\+ get_dict(temperature, B, _)).

test(openai_keeps_temperature_for_plain_models) :-
    llm_client:build_body(openai, 'gpt-4o',
                          [_{role: user, content: "hi"}],
                          [max_tokens(100), temperature(0.2)], B),
    assertion(B.max_completion_tokens =:= 100),
    assertion(\+ get_dict(max_tokens, B, _)),
    assertion(B.temperature =:= 0.2).

test(other_providers_keep_max_tokens) :-
    llm_client:build_body(groq, 'openai/gpt-oss-120b',
                          [_{role: user, content: "hi"}],
                          [max_tokens(100), temperature(0.2)], B),
    assertion(B.max_tokens =:= 100),
    assertion(\+ get_dict(max_completion_tokens, B, _)),
    assertion(B.temperature =:= 0.2).

:- end_tests(llm_openai_body).
