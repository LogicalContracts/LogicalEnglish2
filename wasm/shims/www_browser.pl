/** <module> library(www_browser), for a program that is already in a browser

    le_kbs.pl calls www_open_url/1 in one place: `edit/1`, which opens an LE
    file in the editor. On a server that means "open a browser here", which is
    why the library is missing from a build whose *only* world is a browser.

    Here the tab is the host page's to open, so the request goes out to it
    (le_wasm.pl's `le_wasm_host_call/2`, which the worker relays to the page).
    If the host does not take it, the call quietly succeeds having done
    nothing, exactly as `www_open_url/1` does on a headless server.
*/

:- module(www_browser, [
    www_open_url/1,             % +URL
    expand_url_path/2           % +Spec, -URL
    ]).

www_open_url(URL) :-
    (   catch(le_wasm:le_wasm_host_call(_{action: "open", url: URL}, _), _, fail)
    ->  true
    ;   true
    ).

expand_url_path(URL, URL).
