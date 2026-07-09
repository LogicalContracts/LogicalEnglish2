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

:- end_tests(llm_reply_extraction).
