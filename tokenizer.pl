/** <module> Logical English Tokenizer
    
    This module provides predicates for converting Logical English source text
    into a list of tokens. It handles indentation, words, numbers, dates,
    quoted strings, and comments. It also provides a way to convert tokens
    back into a string.
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
tokens_to_string([T|Ts],String) :-
    ( arg(2, T, loc(Start, _)) -> true ; Start = 0 ),
    tokens_to_string_([T|Ts],Start,Strings),
    atomic_list_concat(Strings,String).

% tokens_to_string_(Tokens,EndPositionOfPrevious,Strings)
tokens_to_string_([],_,[]).
tokens_to_string_([T|Tokens],LastEnd,[S|Strings]) :-
    ( arg(2,T,loc(Begin,NewEnd)) ->
        Gap is Begin-LastEnd,
        (Gap > 0 -> Advance = " " ; Advance = ""),
        (   T=indent(_,_) -> S_ = "", Advance_ = Advance
            ; T=line_comment(_,_) -> S_ = "", Advance_ = Advance
            ; T=multi_comment(_,_) -> S_ = "", Advance_ = Advance
            ; T=quoteString(X,_) -> format(string(S_),"'~a'",[X]), Advance_ = Advance
            ; T=doubleQuoteString(X,_) -> format(string(S_),'"~a"',[X]), Advance_ = Advance
            ; T=var(Words,_) -> 
                atomic_list_concat(Words, ' ', WordsStr),
                format(string(S_), "*~w*", [WordsStr]),
                Advance_ = Advance
            ; arg(1,T,X) -> 
                ( X = date(Y,M,D) -> format(string(S_), "~w-~|~`0t~w~2|-~|~`0t~w~2|", [Y,M,D])
                ; (atom(X); string(X); number(X)) -> S_=X
                ; term_string(X, S_)
                ),
                Advance_ = Advance
            ; S_ = "", Advance_ = ""
        ),
        atomic_list_concat([Advance_,S_],S),
        tokens_to_string_(Tokens,NewEnd,Strings)
    ;   % Fallback for tokens without location info
        ( arg(1,T,X) -> S_ = X ; S_ = "" ),
        ( Strings == [] -> S = S_ ; atomic_list_concat([' ', S_], S) ),
        tokens_to_string_(Tokens, LastEnd, Strings)
    ).


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
tokens(Idx, 1, [indent(VW, loc(Idx, End))|Ts]) -->
    white_prefix(VW, CC),
    { End is Idx + CC },
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

% 5. FALLBACK: Any other character as punctuation
tokens(Idx, 0, [punctuation(A, loc(Idx, End))|Ts]) -->
    [C], !,
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
% Accepts an optional integer part with thousands separators (e.g. 10,000,000),
% which are stripped from the numeric value but counted towards the token length.
token_match(Idx, number(N, loc(Idx, End)), End) -->
    digits_strict(Lead),
    thousands_groups(GroupCodes, SepCount),
    { append(Lead, GroupCodes, IntCodes) },
    (   (".", digits_strict(Fraction)) ->
        { append(IntCodes, [0'.|Fraction], AllCodes),
          number_codes(N, AllCodes),
          length(IntCodes, IL), length(Fraction, FL),
          End is Idx + IL + SepCount + 1 + FL }
        ;
        { number_codes(N, IntCodes),
          length(IntCodes, IL),
          End is Idx + IL + SepCount }
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
peek_newline, [10] --> [10], !.
peek_newline, [13] --> [13], !.

digits_strict([C|Cs]) --> [C], { code_type(C, digit) }, !, digits_maybe(Cs).
digits_maybe([C|Cs])  --> [C], { code_type(C, digit) }, !, digits_maybe(Cs).
digits_maybe([])      --> [].

% Thousands separators: zero or more groups of a comma followed by exactly
% three digits (e.g. ",000"). A group only matches when those three digits are
% NOT immediately followed by another digit, so e.g. "1,2345" stays as the
% number 1 followed by a comma, never an invalid grouping. The collected codes
% exclude the commas; SepCount counts the commas consumed.
thousands_groups(Codes, Count) -->
    thousand_group(Group), !,
    thousands_groups(Rest, Count0),
    { append(Group, Rest, Codes), Count is Count0 + 1 }.
thousands_groups([], 0) --> [].

thousand_group([D1,D2,D3]) -->
    ",", digit_code(D1), digit_code(D2), digit_code(D3),
    not_followed_by_digit.

digit_code(C) --> [C], { code_type(C, digit) }.

% Lookahead: succeeds (without consuming) at end of input or when the next
% character is not a digit. The pushback re-publishes the peeked character.
not_followed_by_digit, [C] --> [C], { \+ code_type(C, digit) }, !.
not_followed_by_digit --> eos.

white_prefix(VW, CC) --> [C], { code_type(C, white), C \== 10, C \== 13 }, !, 
    { ( C == 9 -> VInc = 8; VInc = 1), CInc = 1 },
    white_prefix(VW1, CC1), { VW is VW1 + VInc, CC is CC1 + CInc }.
white_prefix(0, 0) --> [].

word_remainder([C|Cs]) --> [C], { code_type(C, csym) }, !, word_remainder(Cs).
word_remainder([])     --> [].

spaces(N) --> {nonvar(N), N>0, N1 is N-1}, " ", !, spaces(N1).
spaces(N) --> {var(N)}, " ", !, spaces(N1), { N is N1 + 1 }.
spaces(0) --> "".

spaces(N,Spaces) :-
    spaces(N,Spaces_,[]),
    atom_codes(Spaces,Spaces_).
