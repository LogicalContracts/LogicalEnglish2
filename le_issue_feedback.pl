/** <module> Turning verifier issues into a working set for an LLM repair round

    Two features in this repository ask a model to fix Logical English against
    the verifier's own complaints: the LE Contract Assistant, which repairs a
    whole generated program, and the English→LE conversion behind the Scenario
    and Query editors, which repairs a fragment spliced into a program the user
    already has. Both learned the same lesson, and it lives here rather than
    twice.

    The lesson: an undifferentiated dump of every issue is worse than a short
    ordered list. A program at "0 errors, 59 warnings, 0/25 tests" produced 134
    lines of identical complaint every round, in which the two things that
    actually blocked it were indistinguishable from thirty repetitions of one
    warning — and models answered it by rewriting the program instead of fixing
    the two things.

    So an issue reaches a repair round with:

      - a RANK: errors, then failing tests, then MODELLING warnings (see
        modelling_warning/1 — the ones that say the program means something
        other than the text does), then cosmetic warnings. A warning cannot
        matter while the program does not load.
      - a LOCATION: line number and the offending source line, which is what a
        SEARCH/REPLACE block has to match, plus the verifier's own suggested
        fix. All three used to be dropped, and a round was told "Missing
        template for '...'" and left to find it.
      - a CAP: at most a few examples of any one type, since they repeat, and a
        bounded list overall — followed by a line naming exactly what was left
        out, so a short list does not read as "nearly done".

    Nothing is lost by omitting an issue: the caller re-verifies after every
    reply, and whatever is still wrong comes back in the next round's set.

    An "issue" here is any dict with (some of) the keys severity, type,
    message, fix, line, source — the shape both callers already build from
    KB:le_issue/6.
*/

:- module(le_issue_feedback, [
    modelling_warning/1,
    count_modelling_warnings/2,
    issue_line/3,
    select_feedback/4,
    omitted_note/2,
    feedback_type_name/2,
    line_start_offsets/2,
    issue_location/5,
    truncated/3
]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(yall)).

%!  modelling_warning(+Type) is semidet.
%
%   The warnings that are about MEANING, not tidiness. Each one is a way for a
%   program to load cleanly, pass every test, and still not say what its source
%   text says:
%
%   - unconsumed_facts: a limit, an excess or an exclusion is stated and no rule
%     reads it, so the rules it should bound compute unbounded answers. (The
%     warning this list was written for: a payment limit sat in a scenario in
%     plain sight while the payment rules capped nothing.)
%   - untested_predicate: a rule no query reaches decides nothing — it is either
%     an unasked question or a rule the decision surface forgot to consult.
%   - suspicious_is / suspicious_is_a: a whole predicate was swallowed into a
%     constant, leaving a condition that can never succeed, silently making its
%     rule unprovable.
%   - unmarked_meta_template: the sentence parsed into a shape the author did
%     not write, so the rule is about something else.
%   - single_variable_fact: an article turned an individual into a universal —
%     the fact holds of everyone. In a generated SCENARIO this is the single
%     commonest way for a plausible-looking fact to mean something else
%     entirely ("a payment is 500" makes every payment 500).
%
%   Callers refuse to call a program (or a fragment) finished while any of these
%   is left, bounded by their patience, and one of them outranks every cosmetic
%   warning in a round's working set. Everything else — dead vocabulary, ground
%   rules, facts/rules ratios — is tidiness, and may not change what the program
%   decides.
modelling_warning("unconsumed_facts").
modelling_warning("untested_predicate").
modelling_warning("suspicious_is").
modelling_warning("suspicious_is_a").
modelling_warning("unmarked_meta_template").
modelling_warning("single_variable_fact").

%!  count_modelling_warnings(+Issues, -Count) is det.
%
%   How many of Issues are warnings about meaning. Callers use it as a gate:
%   zero errors and every test passing is not "done" while one of these is
%   waiting.
count_modelling_warnings(Issues, Count) :-
    findall(1, ( member(I, Issues),
                 get_dict(severity, I, "warning"),
                 get_dict(type, I, Ty), modelling_warning(Ty) ),
            L),
    length(L, Count).

%!  issue_line(+Issue, -Type, -Line) is det.
%
%   One issue as the line a repair round reads: severity, where it is, what is
%   wrong, the offending source text and the verifier's remedy.
issue_line(I, Type, Line) :-
    ( get_dict(type, I, Type) -> true ; Type = "issue" ),
    ( get_dict(message, I, Msg0) -> true ; Msg0 = "" ),
    truncated(Msg0, 400, Msg),
    ( get_dict(severity, I, Sev) -> true ; Sev = "warning" ),
    (   get_dict(line, I, N), integer(N), N > 0
    ->  format(string(Where), " (line ~w)", [N])
    ;   Where = ""
    ),
    (   get_dict(source, I, Src), Src \== ""
    ->  format(string(SrcPart), "~n    in: ~w", [Src])
    ;   SrcPart = ""
    ),
    (   get_dict(fix, I, Fix), Fix \== "", Fix \== "''", Fix \== null
    ->  truncated(Fix, 300, F), format(string(FixPart), "~n    fix: ~w", [F])
    ;   FixPart = ""
    ),
    format(string(Line), "- [~w]~w ~w~w~w", [Sev, Where, Msg, SrcPart, FixPart]).

%!  select_feedback(+Caps, +Items, -Shown, -Omitted) is det.
%
%   Take from Items — a list of item(Rank, Type, Line), already in rank order —
%   the ones this round is asked to fix, and return the rest for the closing
%   note. Caps is caps(MaxItems, ErrorCap, TypeCap): at most MaxItems in all, at
%   most ErrorCap of any one error type and TypeCap of anything else.
%
%   Errors get the bigger share on purpose: they block the load and each one
%   carries its own location, so five instances of one error type are five
%   repairs — not one complaint five times.
select_feedback(Caps, Items, Shown, Omitted) :-
    Caps = caps(Max, _, _),
    select_feedback_(Items, Caps, [], 0, Max, Shown, Omitted).

select_feedback_([], _, _, _, _, [], []).
select_feedback_([item(R, Type, L)|Rest], Caps, Counts0, N, Max, Shown, Omitted) :-
    Caps = caps(_, ErrorCap, TypeCap),
    (   N < Max,
        ( memberchk(Type-C, Counts0) -> true ; C = 0 ),
        ( Type = error(_) -> Cap = ErrorCap ; Cap = TypeCap ),
        C < Cap
    ->  C1 is C + 1,
        ( selectchk(Type-C, Counts0, Counts1) -> true ; Counts1 = Counts0 ),
        N1 is N + 1,
        Shown = [item(R, Type, L)|Shown1],
        select_feedback_(Rest, Caps, [Type-C1|Counts1], N1, Max, Shown1, Omitted)
    ;   Omitted = [item(R, Type, L)|Omitted1],
        select_feedback_(Rest, Caps, Counts0, N, Max, Shown, Omitted1)
    ).

%!  omitted_note(+Omitted, -Lines) is det.
%
%   What is NOT in the list, by kind and count. Without it the model reads a
%   short list as "the program is nearly done" and stops looking.
omitted_note([], []) :- !.
omitted_note(Omitted, [Line]) :-
    length(Omitted, N),
    findall(Type, member(item(_, Type, _), Omitted), Types),
    msort(Types, Sorted),
    clumped(Sorted, Clumped),                       % Type-Count, one per kind
    findall(C-T, member(T-C, Clumped), Counted),
    sort(0, @>=, Counted, Ranked),                  % the commonest kinds first
    findall(S, ( member(C, Ranked), C = Cn-T, feedback_type_name(T, TN),
                 format(string(S), "~w ~w", [Cn, TN]) ),
            Parts),
    atomic_list_concat(Parts, ", ", Summary),
    format(string(Line),
           "- ... and ~w more not listed (~w). Fix what is above; the result is re-verified after every reply and whatever is still wrong will be listed next round.",
           [N, Summary]).

feedback_type_name(test(Q), Name) :- !,
    format(string(Name), "failing test(s) of query '~w'", [Q]).
feedback_type_name(error(T), Name) :- !,
    format(string(Name), "~w error(s)", [T]).
feedback_type_name(T, T).

%!  line_start_offsets(+Lines, -Starts) is det.
%!  issue_location(+Starts, +Lines, +Offset, -LineNo, -SourceLine) is det.
%
%   The verifier reports a character OFFSET; a repair round needs a line.
%
%   Where an issue is, in terms a repair can act on: the line number, and the
%   line itself — which is what a SEARCH block has to match.
line_start_offsets(Lines, Starts) :-
    foldl([L, S0-Acc, S1-[S0|Acc]]>>( string_length(L, Len), S1 is S0 + Len + 1 ),
          Lines, 0-[], _-Rev),
    reverse(Rev, Starts).

issue_location(Starts, Lines, Offset, LineNo, SourceLine) :-
    (   integer(Offset), Offset >= 0
    ->  offset_line_no(Starts, Offset, 1, 1, LineNo),
        (   nth1(LineNo, Lines, L0)
        ->  normalize_space(string(L1), L0), truncated(L1, 200, SourceLine)
        ;   SourceLine = ""
        )
    ;   LineNo = 0, SourceLine = ""
    ).

offset_line_no([], _, _, Best, Best).
offset_line_no([S|Ss], Offset, N, Best0, Best) :-
    (   S =< Offset
    ->  N1 is N + 1, offset_line_no(Ss, Offset, N1, N, Best)
    ;   Best = Best0
    ).

%!  truncated(+Text, +Max, -Out) is det.
%
%   Text, capped at Max characters with an ellipsis. Everything here ends up in
%   a prompt or a browser log, and an LLM reply — or an exception carrying one
%   in a stack frame — can be 90 kB.
truncated(S0, Max, Out) :-
    ( atomic(S0) -> text_to_string(S0, S) ; term_string(S0, S) ),
    string_length(S, L),
    (   L =< Max
    ->  Out = S
    ;   Keep is Max - 3,
        sub_string(S, 0, Keep, _, Head),
        string_concat(Head, "...", Out)
    ).
