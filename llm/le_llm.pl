/** <module> Which LLM client Logical English talks through

    LE2 ships `llm/llm_client.pl` and uses it directly everywhere. That is the
    right default and the wrong *requirement*: when LE2 is loaded as a library
    into another program — LPS2's IDE, which has its own client, its own key
    handling and its own model picker — a second client in the image means two
    registries, two sets of keys and two answers to "which model is this".

    So the language-facing code asks here instead. The default is
    `llm_client`, so nothing changes for LE2 on its own; an embedder calls
    set_le_llm_provider/1 with a module exporting the same `llm_request/4`,
    and every LE feature that needs a model uses theirs.

    The contract for a provider module is exactly llm_client's:

        llm_request(+Model, +Messages, -Answer, +Options)

    Messages is a list of role-content pairs, Options a list of Name(Value)
    terms forwarded as JSON fields, and Answer the reply text.
*/

:- module(le_llm,
    [ le_llm_request/4,          % +Model, +Messages, -Answer, +Options
      le_llm_provider/1,         % -Module
      set_le_llm_provider/1      % +Module
    ]).

:- use_module(library(error)).

%   Loaded, not imported: the default provider is called by module-qualified
%   goal like any other, so there is one code path rather than two.
:- use_module(llm_client, []).

:- dynamic provider_module/1.

%!  le_llm_provider(-Module:atom) is det.
le_llm_provider(Module) :-
    ( provider_module(M) -> Module = M ; Module = llm_client ).

%!  set_le_llm_provider(+Module:atom) is det.
%
%   Route LE's LLM calls through Module. It must export llm_request/4; the
%   check is here rather than at the call site so a wrong module is a clear
%   error now instead of an existence error in the middle of a conversion.
set_le_llm_provider(Module) :-
    must_be(atom, Module),
    (   current_predicate(Module:llm_request/4)
    ->  true
    ;   throw(error(existence_error(procedure, Module:llm_request/4),
                    set_le_llm_provider/1))
    ),
    retractall(provider_module(_)),
    assertz(provider_module(Module)).

%!  le_llm_request(+Model, +Messages, -Answer, +Options) is det.
le_llm_request(Model, Messages, Answer, Options) :-
    le_llm_provider(Module),
    call(Module:llm_request(Model, Messages, Answer, Options)).
