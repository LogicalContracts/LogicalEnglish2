/** <module> library(http/http_ssl_plugin), which a browser has already applied

    On a server this plugin teaches http_open/3 to speak TLS. In a browser the
    fetch is the browser's, and so is the TLS — there is nothing here to plug
    in. The module exists because llm/llm_client.pl imports it, and an import
    of a library that is not there is a load failure.
*/

:- module(http_ssl_plugin, []).
