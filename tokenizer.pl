/** <module> Logical English Tokenizer
    
    This module provides predicates for converting Logical English source text
    into a list of tokens. It handles indentation, words, numbers, dates,
    quoted strings, and comments.
*/

:- module(tokenizer,[tokenize/2, tokenize_file/2, tokens_to_string/2]).

:- use_module(library(dcg/basics)).

%!  tokenize_file(+File:atom, -Tokens:list) is det.
%
%   Reads the content of File and converts it into a list of tokens.
tokenize_file(File,Tokens) :-
    read_file_to_string(File, String, []),
    tokenize(String, Tokens).

%!  tokenize(+String:string, -Tokens:list) is det.
%
%   Converts a string into a list of Logical English tokens.
tokenize(String, Tokens) :-
    string_codes(String, Codes),
    phrase(tokens(0, 1, Tokens), Codes).

%!  tokens_to_string(+Tokens:list, -String:string) is det.
%
%   Converts a list of tokens back into a string representation,
%   preserving relative spacing and indentation.
tokens_to_string([],"") :- !.
tokens_to_string(Tokens,String) :-
    tokens_to_string_(Tokens,0,Strings),
    atomic_list_concat(Strings,String).

% tokens_to_string_(Tokens,EndPositionOfPrevious,Strings)
tokens_to_string_([],_,[]).
tokens_to_string_([T|Tokens],LastEnd,[S|Strings]) :-
    arg(2,T,loc(Begin,NewEnd)),
    AdvanceN is Begin-LastEnd,
    spaces(AdvanceN,Advance),
    (   T=indent(N,_) -> spaces(N,Spaces), format(string(S_),"\n~a",[Spaces])
        ; T=line_comment(X,_) -> format(string(S_),"%~a",[X])
        ; T=multi_comment(X,_) -> format(string(S_),"/*~a*/",[X])
        ; T=quoteString(X,_) -> format(string(S_),"'~a'",[X])
        ; T=doubleQuoteString(X,_) -> format(string(S_),'"~a"',[X])
        ; arg(1,T,X) -> S_=X
    ),
    atomic_list_concat([Advance,S_],S),
    tokens_to_string_(Tokens,NewEnd,Strings).


% --- The Main DCG Loop ---

tokens(_, _, []) --> [].

% 1. Handle Newlines: Reset LineStart flag
% Support Windows (\r\n), Unix (\n), and old Mac (\r) line endings
tokens(Idx, _, Ts) -->
    "\r\n", !,
    { NewIdx is Idx + 2 },
    tokens(NewIdx, 1, Ts).
tokens(Idx, _, Ts) -->
    "\n", !,
    { NewIdx is Idx + 1 },
    tokens(NewIdx, 1, Ts).
tokens(Idx, _, Ts) -->
    "\r", !,
    { NewIdx is Idx + 1 },
    tokens(NewIdx, 1, Ts).

% 2. Indent: Triggered only at LineStart
tokens(Idx, 1, [indent(N, loc(Idx, End))|Ts]) -->
    white_prefix(N),
    { End is Idx + N },
    tokens(End, 0, Ts).

% 3. SKIP WHITESPACE (Space/Tab)
tokens(Idx, 0, Ts) -->
    [C], { code_type(C, white) }, !,
    { NewIdx is Idx + 1 },
    tokens(NewIdx, 0, Ts).

% 4. Identify specific tokens (Comments, Dates, Words, Numbers)
% Because we skipped whitespace in step 3, we are now looking exactly at the start of a token.
tokens(Idx, 0, [T|Ts]) -->
    token_match(Idx, T, NextIdx), !,
    tokens(NextIdx, 0, Ts).

% 5. FALLBACK: Single Punctuation
% If no complex token matches (like a lone '/' that isn't '/*'), catch it here.
tokens(Idx, 0, [punctuation(A, loc(Idx, End))|Ts]) -->
    [C], { code_type(C, punct) }, !,
    { atom_codes(A, [C]), End is Idx + 1 },
    tokens(End, 0, Ts).

% --- Token Definitions (Priority Order) ---

% Multi-character Punctuation
token_match(Idx, punctuation(A, loc(Idx, End)), End) -->
    ">=", !, { A = '>=', End is Idx + 2 }.
token_match(Idx, punctuation(A, loc(Idx, End)), End) -->
    "<=", !, { A = '<=', End is Idx + 2 }.
token_match(Idx, punctuation(A, loc(Idx, End)), End) -->
    "=<", !, { A = '=<', End is Idx + 2 }.
token_match(Idx, punctuation(A, loc(Idx, End)), End) -->
    "==", !, { A = '==', End is Idx + 2 }.
token_match(Idx, punctuation(A, loc(Idx, End)), End) -->
    "!=", !, { A = '!=', End is Idx + 2 }.

% Multi-line Comment: /* ... */
token_match(Idx, multi_comment(Content, loc(Idx, End)), End) -->
    "/*", !,
    string_until_ending("*/", Codes),
    % "*/",
    { string_codes(Content, Codes),
      length(Codes, L),
      End is Idx + L + 4 }.

% Single-line Comment: % ...
token_match(Idx, line_comment(Content, loc(Idx, End)), End) -->
    "%", !,
    string_until_newline(Codes),
    { string_codes(Content, Codes),
      length(Codes, L),
      End is Idx + L + 1 }.

% Date: YYYY-MM-DD
token_match(Idx, date(date(Y, M, D), loc(Idx, End)), End) -->
    digits_strict(Yc), "-", digits_strict(Mc), "-", digits_strict(Dc), !,
    { number_codes(Y, Yc), number_codes(M, Mc), number_codes(D, Dc),
      length(Yc, Ly), length(Mc, Lm), length(Dc, Ld),
      End is Idx + Ly + Lm + Ld + 2 }.

% Quoted String: "..."
token_match(Idx, doubleQuoteString(S, loc(Idx, End)), End) -->
    "\"", !,
    string_until_ending("\"", Codes),
    { string_codes(S, Codes),
      length(Codes, L),
      End is Idx + L + 2 }.

% Quoted String: '...'
token_match(Idx, quoteString(S, loc(Idx, End)), End) -->
    "'", !,
    string_until_ending("'", Codes),
    { string_codes(S, Codes),
      length(Codes, L),
      End is Idx + L + 2 }.

% Number
token_match(Idx, number(N, loc(Idx, End)), End) -->
    digits_strict(Codes), 
    (   (".", digits_strict(Fraction)) ->  
        { append(Codes, [0'.|Fraction], AllCodes),
          number_codes(N, AllCodes),
          length(AllCodes, L),
          End is Idx + L }
        ;   
        { number_codes(N, Codes),
          length(Codes, L),
          End is Idx + L }
    ).

% Word
token_match(Idx, word(A, loc(Idx, End)), End) -->
    [C], { code_type(C, alpha) }, !,
    word_remainder(Rest),
    { atom_codes(A, [C|Rest]),
      length([C|Rest], L),
      End is Idx + L }.

% --- Helpers ---

% Match characters, consuming the delimiter
string_until_ending(Delimiter, []) --> Delimiter, !.
string_until_ending(Delimiter, [C|Cs]) --> [C], string_until_ending(Delimiter, Cs).

string_until_newline([]) --> peek_newline, !.
string_until_newline([]) --> eos, !.
string_until_newline([C|Cs]) --> [C], string_until_newline(Cs).

% Lookahead for newline without consuming
peek_newline, [10] --> [10].

digits_strict([C|Cs]) --> [C], { code_type(C, digit) }, !, digits_maybe(Cs).
digits_maybe([C|Cs])  --> [C], { code_type(C, digit) }, !, digits_maybe(Cs).
digits_maybe([])      --> [].

white_prefix(N) --> [C], { code_type(C, white), C \== 10 }, !, 
    { ( C == 9 -> Inc = 8; Inc = 1) },
    white_prefix(N1), { N is N1 + Inc }.
white_prefix(0) --> [].

word_remainder([C|Cs]) --> [C], { code_type(C, csym) }, !, word_remainder(Cs).
word_remainder([])     --> [].

spaces(N) --> {nonvar(N), N>0, N1 is N-1}, " ", !, spaces(N1).
spaces(N) --> {var(N)}, " ", !, spaces(N1), { N is N1 + 1 }.
spaces(0) --> "".

spaces(N,Spaces) :-
    spaces(N,Spaces_,[]),
    atom_codes(Spaces,Spaces_).
