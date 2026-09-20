/** <module> library(http/json), which moved and left a forwarding address

    In SWI-Prolog 10 the JSON library became a package of its own: the code is
    `library(json)`, and `library(http/json)` is a two-line module that
    re-exports it for everything written before the move. The WebAssembly image
    ships the new one and not the compatibility wrapper, which is why eight
    modules here that import the old name cannot load in it.

    This is that wrapper. It is not a stand-in for anything: the predicates
    below are the real ones.
*/

:- module(http_json_compat, []).

:- use_module(library(json)).

:- reexport(library(json)).
