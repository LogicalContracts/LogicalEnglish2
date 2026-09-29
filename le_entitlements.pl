/** <module> What the current request may use: the licensed parts of an installation

    Two parts of an installation are licensed rather than free, and neither
    lives in this repository:

      - `converters` and `extended_examples` — the translators of other
        systems (lpsPlus's `migration/le_importers.pl`) and the private example
        trees, sold together as the licence "with extensions";
      - `le_extensions` — InsurLE2's `le_extensions.pl`, the extra grammar
        (`which` clauses, `unless` bodies, grouped and numbered bodies, ...),
        sold as the licence "InsurLE".

    Which licences exist, who holds them and until when is decided in the
    lpsPlus repository (`accounts/lc_accounts.pl`, `accounts/licenses.csv`).
    This module only carries the answer for the request being served, so
    that the code which *uses* a licensed part can ask one question —
    entitled/1 — without knowing about accounts, cookies or servers.

    The answer is per thread: a server sets it at the start of every request
    (set_request_entitlements/1, from an HTTP request expansion), and a
    thread that no request has set gets the process default:

      - `all` — everything installed may be used. The default, and right for
        the command line, the test suites and a developer's machine.
      - `none` — nothing licensed may be used. What a server switches to when
        it starts (set_default_entitlements/1), so that a thread it creates
        for some other purpose cannot use what the visitor did not buy.

    `NO_RESTRICTIONS=true` in the environment lifts every restriction, as it
    does for restricted_paths.pl.
*/

:- module(le_entitlements, [
    entitled/1,                  % +Capability
    current_entitlements/1,      % -Capabilities (list) or `all`
    set_request_entitlements/1,  % +Capabilities (list) or `all`
    clear_request_entitlements/0,
    with_entitlements/2,         % +Capabilities, :Goal
    set_default_entitlements/1   % +all | none
    ]).

:- meta_predicate with_entitlements(+, 0).

:- thread_local request_entitlements/1.
:- dynamic default_entitlements/1.

%!  host_entitlements(-Caps) is semidet.
%
%   A program that embeds Logical English and keeps its own account of the
%   request (LPS2, whose server loads Logical English only when a `.le`
%   file is first opened) answers here instead: its answer, when it gives
%   one, is the answer.
:- multifile host_entitlements/1.
:- dynamic host_entitlements/1.

default_entitlements(all).

%!  entitled(+Capability:atom) is semidet.
%
%   True when the request being served may use Capability.
entitled(Capability) :-
    current_entitlements(Caps),
    (   Caps == all
    ->  true
    ;   memberchk(Capability, Caps)
    ).

%!  current_entitlements(-Caps) is det.
%
%   The capabilities of the request being served: a list, or `all`.
current_entitlements(Caps) :-
    (   getenv('NO_RESTRICTIONS', true)
    ->  Caps = all
    ;   host_entitlements(C)
    ->  Caps = C
    ;   request_entitlements(C)
    ->  Caps = C
    ;   default_entitlements(D),
        ( D == all -> Caps = all ; Caps = [] )
    ).

%!  set_request_entitlements(+Caps) is det.
%
%   What this thread's request may use, until the next call. An HTTP server
%   calls it for every request, so a pooled worker thread never carries one
%   visitor's licence into the next visitor's request.
set_request_entitlements(Caps) :-
    ( Caps == all -> true ; must_be(list, Caps) ),
    retractall(request_entitlements(_)),
    assertz(request_entitlements(Caps)).

%!  clear_request_entitlements is det.
clear_request_entitlements :-
    retractall(request_entitlements(_)).

%!  with_entitlements(+Caps, :Goal) is semidet.
%
%   Goal, run with Caps as this thread's entitlements; the previous ones are
%   restored afterwards.
with_entitlements(Caps, Goal) :-
    (   request_entitlements(Old) -> Restore = set_request_entitlements(Old)
    ;   Restore = clear_request_entitlements
    ),
    setup_call_cleanup(set_request_entitlements(Caps), Goal, Restore).

%!  set_default_entitlements(+Default) is det.
%
%   `all` or `none`: what a thread that no request has set may use.
set_default_entitlements(D) :-
    must_be(oneof([all, none]), D),
    retractall(default_entitlements(_)),
    assertz(default_entitlements(D)).
