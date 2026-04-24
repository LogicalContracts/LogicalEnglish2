/* llm_client_examples.pl  –  Usage examples for llm_client.pl
 *
 * Run from the SWI-Prolog REPL:
 *   ?- [llm_client], [llm_client_examples].
 */

:- use_module(llm_client).


% ── 0. See available models ─────────────────────────────────────────

demo_list_models :-
    llm_print_models.


% ── 1. Simple one-shot query (OpenAI) ───────────────────────────────

demo_openai :-
    % Reads OPENAI_API_KEY from the environment.
    llm_request('gpt-4o-mini', "What is the capital of Portugal?", Answer),
    format("Answer: ~w~n", [Answer]).


% ── 2. Simple one-shot query (Groq / Llama 3) ───────────────────────

demo_groq :-
    % Reads GROQ_API_KEY from the environment.
    llm_request('llama-3.3-70b', "Explain recursion in one sentence.", Answer),
    format("Answer: ~w~n", [Answer]).


% ── 3. Multi-turn conversation with a system prompt ─────────────────

demo_conversation :-
    Messages = [
        system("You are a concise Prolog expert. Reply in plain text."),
        user("How do I reverse a list in Prolog?")
    ],
    llm_request('gpt-4o', Messages, Answer, [temperature(0.3)]),
    format("~w~n", [Answer]).


% ── 4. Extra options ────────────────────────────────────────────────

demo_options :-
    llm_request('gpt-4o-mini',
        "Write a haiku about logic programming.",
        Answer,
        [ temperature(0.9),
          max_tokens(100)
        ]),
    format("~w~n", [Answer]).


% ── 5. Setting API keys programmatically (instead of env vars) ──────

demo_set_keys :-
    set_prolog_flag(llm_openai_key, 'sk-YOUR-KEY-HERE'),
    set_prolog_flag(llm_groq_key,   'gsk_YOUR-KEY-HERE'),
    llm_request('gpt-4o-mini', "Say hello.", Answer),
    format("~w~n", [Answer]).


% ── 6. Groq with all role types ─────────────────────────────────────

demo_groq_roles :-
    llm_request('mixtral-8x7b',
        [ system("Reply in exactly three words."),
          user("What is love?")
        ],
        Answer,
        [max_tokens(20)]),
    format("~w~n", [Answer]).


% ── 7. Model look-up predicate ──────────────────────────────────────

demo_lookup :-
    llm_model('llama-3.3-70b', Provider, APIModel),
    format("Provider: ~w, API model: ~w~n", [Provider, APIModel]).


% ── 8. Error handling example ───────────────────────────────────────

demo_error_handling :-
    catch(
        llm_request('no-such-model', "Hi", _Answer),
        error(llm_unknown_model(M), _),
        format("Caught expected error: unknown model '~w'~n", [M])
    ).


% ── 9. Gemini 2 examples ────────────────────────────────────────────
%  Requires: export GEMINI_API_KEY=AIza...
%  Get a free key at https://aistudio.google.com/apikey

demo_gemini_simple :-
    llm_request('gemini', "What is Prolog good for?", Answer),
    format("~w~n", [Answer]).

demo_gemini_flash :-
    llm_request('gemini',
        "List three advantages of logic programming in one sentence each.",
        Answer,
        [temperature(0.4), max_tokens(200)]),
    format("~w~n", [Answer]).

demo_gemini_alias :-
    % 'gemini' is a convenience alias → gemini-2.0-flash
    llm_request('gemini', "Translate 'Hello, world!' into Portuguese.", Answer),
    format("~w~n", [Answer]).

demo_gemini_conversation :-
    llm_request('gemini',
        [ system("You are a helpful Prolog tutor. Be concise."),
          user("What is the difference between assert/1 and asserta/1?")
        ],
        Answer,
        [temperature(0.2)]),
    format("~w~n", [Answer]).
