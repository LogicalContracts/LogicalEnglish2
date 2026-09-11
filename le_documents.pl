/** <module> The text of a cited document

    Provenance cites documents (docs/le_summary.md §17.1, §15.5): "as stated in
    ruling NY N362700 at "a zipper garage at the top of the collar"". A program
    may say where a document's text is — `the text of <document> is at
    <address>` — and the editor then shows that text with the quoted passage
    highlighted; the "Write it in English…" dialog reads a document through the
    same door to extract facts from it. Nothing here knows any kind of
    document: an address is a file beside the program or a URL, and the text is
    whatever that address serves — plain text as it is, the readable text of an
    HTML page, the `text` field (else the longest string) of a JSON reply.
*/

:- module(le_documents, [ document_text/4 ]).     % +Address, +Base, +Roles, -Text

:- use_module(library(sgml)).
:- if(exists_source(library(json))).
:- use_module(library(json)).
:- else.
:- use_module(library(http/json)).
:- endif.
:- use_module(library(http/http_open)).
:- use_module(library(uri)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(le_kbs, [le_network_allowed/0]).

max_document_bytes(4000000).

%!  document_text(+Address, +Base, +Roles, -Text:string) is det.
%
%   The text at Address: a URL (fetched when the server allows outbound
%   requests), or a path relative to Base — the directory of the program that
%   cites it — which must stay inside that directory and be readable by a user
%   with Roles (restricted_paths). Throws error(document_error(Reason), _) with
%   a readable Reason otherwise.
document_text(Address0, Base, Roles, Text) :-
    atom_string(Address, Address0),
    (   is_url(Address)
    ->  fetch_document(Address, Raw, Type)
    ;   atom(Base), is_url(Base)
    ->  uri_resolve(Address, Base, URL),          % a program fetched from a URL
        fetch_document(URL, Raw, Type)
    ;   local_document(Address, Base, Roles, File),
        read_file_to_string(File, Raw, [encoding(utf8)]),
        file_type(File, Type)
    ),
    readable_text(Type, Raw, Text).

is_url(A) :- ( sub_atom(A, 0, _, _, 'http://') ; sub_atom(A, 0, _, _, 'https://') ), !.

fetch_document(URL, Raw, Type) :-
    (   le_network_allowed -> true
    ;   doc_error("outbound requests are disabled on this server")
    ),
    catch(setup_call_cleanup(
              http_open(URL, In, [header(content_type, CT), timeout(30)]),
              ( set_stream(In, encoding(utf8)), read_string(In, _, Raw) ),
              close(In)),
          E, ( message_to_codes_safe(E, Msg), doc_error(Msg) )),
    max_document_bytes(Max),
    ( string_length(Raw, L), L > Max -> doc_error("the document is too large") ; true ),
    content_type(CT, URL, Type).

message_to_codes_safe(E, Msg) :-
    catch(message_to_codes(E, _, Codes), _, fail), !, string_codes(Msg, Codes).
message_to_codes_safe(E, Msg) :- term_string(E, Msg).

content_type(CT, URL, Type) :-
    (   nonvar(CT), sub_atom(CT, _, _, _, json) -> Type = json
    ;   nonvar(CT), sub_atom(CT, _, _, _, html) -> Type = html
    ;   nonvar(CT), sub_atom(CT, _, _, _, pdf) -> Type = pdf
    ;   file_type(URL, Type)
    ).

file_type(Name, Type) :-
    (   file_name_extension(_, Ext0, Name), downcase_atom(Ext0, Ext),
        memberchk(Ext-Type, [json-json, html-html, htm-html, pdf-pdf])
    ->  true
    ;   Type = text
    ).

local_document(Address, Base, Roles, File) :-
    (   ( Base == (-) ; Base == none ; \+ atom(Base) )
    ->  doc_error("a document path needs the program's own folder; open the program as an example")
    ;   absolute_file_name(Base, BaseAbs, [file_type(directory), file_errors(fail)])
    ->  true
    ;   doc_error("the program's folder does not exist")
    ),
    absolute_file_name(Address, File, [relative_to(BaseAbs)]),
    atom_concat(BaseAbs, '/', Prefix),
    (   sub_atom(File, 0, _, _, Prefix)
    ->  true
    ;   doc_error("a document path must stay inside the program's folder")
    ),
    (   exists_file(File) -> true ; doc_error("no such document file") ),
    (   catch(restricted_paths:is_path_allowed(File, Roles), _, true)
    ->  true
    ;   doc_error("access to this document is restricted")
    ).

readable_text(text, Raw, Raw).
readable_text(pdf, _, _) :-
    doc_error("the text of a PDF cannot be read here: give a text or HTML address").
readable_text(json, Raw, Text) :-
    (   catch(atom_json_dict(Raw, Dict, []), _, fail)
    ->  json_text(Dict, Text)
    ;   Text = Raw
    ).
readable_text(html, Raw, Text) :-
    catch(( open_string(Raw, In),
            load_html(stream(In), DOM, [syntax_errors(quiet), max_errors(-1)]) ),
          _, fail),
    !,
    phrase(dom_text(DOM), Parts),
    atomic_list_concat(Parts, Text0),
    collapse_blank_lines(Text0, Text).
readable_text(html, Raw, Raw).

json_text(Dict, Text) :-
    (   is_dict(Dict), get_dict(text, Dict, T), string(T)
    ->  Text = T
    ;   findall(S, json_string(Dict, S), Ss),
        Ss \== []
    ->  max_member([A, B]>>(string_length(A, LA), string_length(B, LB), LA =< LB), Text, Ss)
    ;   atom_json_dict(Text, Dict, [])
    ).

json_string(S, S) :- string(S).
json_string(D, S) :- is_dict(D), get_dict(_, D, V), json_string(V, S).
json_string(L, S) :- is_list(L), member(V, L), json_string(V, S).

% The readable text of an HTML DOM: text nodes, a line break after each block
% element, nothing from script/style/head.
dom_text([]) --> [].
dom_text([H|T]) --> dom_node(H), dom_text(T).

dom_node(Text) --> { atom(Text) ; string(Text) }, !, [Text].
dom_node(element(Tag, _, _)) --> { memberchk(Tag, [script, style, head, noscript]) }, !.
dom_node(element(Tag, _, Children)) -->
    dom_text(Children),
    ( { block_tag(Tag) } -> ["\n"] ; [] ).
dom_node(_) --> [].

block_tag(T) :- memberchk(T, [p, div, br, li, tr, h1, h2, h3, h4, h5, h6, section,
                              article, table, ul, ol, dt, dd, pre, blockquote]).

collapse_blank_lines(Text0, Text) :-
    split_string(Text0, "\n", "", Lines0),
    maplist([L0, L]>>normalize_space(string(L), L0), Lines0, Lines1),
    exclude(==(""), Lines1, Lines),
    atomic_list_concat(Lines, '\n', A),
    atom_string(A, Text).

doc_error(Reason) :- throw(error(document_error(Reason), _)).
