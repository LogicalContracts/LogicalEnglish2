/** <module> library(http/http_session), for a build with no accounts

    The WASM build has no server, so it has no sessions and no users: it
    serves what it was built with, and everything in it is public. le_api.pl
    asks who the user is through its own hook (le_api_user/2) and gets no
    answer, which is the anonymous case it already handles. le_assistant.pl
    asks this library directly, so this library has to exist and say the same
    thing: nobody is logged in.
*/

:- module(http_session, [
    http_in_session/1,          % -SessionID
    http_session_id/1,          % -SessionID
    http_session_data/1,        % ?Data
    http_session_assert/1,      % +Data
    http_session_retract/1,     % ?Data
    http_session_retractall/1   % ?Data
    ]).

http_in_session(_) :- fail.
http_session_id(_) :- fail.
http_session_data(_) :- fail.
http_session_assert(_) :- fail.
http_session_retract(_) :- fail.
http_session_retractall(_).
