:- use_module('../le_kbs').
:- use_module(library(pprint)).

main :-
    % Load the citizenship knowledge base
    load('examples/moreExamples/citizenship.le', KB),
    format('Loaded KB: ~w~n', [KB]),
    
    % Create a session for this KB
    createSession(KB, Session),
    format('Created Session: ~w~n', [Session]),
    
    % Set a scenario
    setScenarion(Session, 'alice'),
    
    % Add a custom fact
    addSessionFact(Session, is_a('Alice', 'person')),
    
    % Print the session state
    printSession(Session),
    
    % Negate a fact
    negateSessionFact(Session, is_a('Alice', 'person')),
    format('~nAfter negating Alice is a person:~n'),
    printSession(Session),
        
    % Run queries
    format('~nRunning queries with explanations:~n'),
    % Query 1: Who acquires British citizenship on which date in scenario 'alice'?
    setScenarion(Session, 'alice'),
    Template1 = "which person acquires British citizenship on which date",
    forall(query(Session, Template1, Instance1, _Unknowns1, Why1),
           ( format('Query 1 Result: ~w~nExplanation Tree:~n', [Instance1]),
             print_term(Why1, [indent_step(4)]), nl )),
            
    % Query 2: Who is the mother of whom in scenario 'alice'?
    Template2 = "which person is the mother of which other person",
    forall(query(Session, Template2, Instance2, _Unknowns2, Why2),
           ( format('Query 2 Result: ~w~nExplanation Tree:~n', [Instance2]),
             print_term(Why2, [indent_step(4)]), nl )),

    % Negative Explanation Example
    format('~nNegative Explanation Example:~n'),
    % Query: it is not the case that Harry acquires British citizenship on 2021-10-09
    % We manually construct the goal for demonstration
    GoalNeg = not(KB:acquires_British_citizenship_on('Harry', date(2021,10,9))),
    (   reasoner:i(GoalNeg, Session, _UnknownsNeg, WhyNeg) ->  
        format('Negative Query Result: ~w~nExplanation Tree (Failure Tree):~n', [GoalNeg]),
        print_term(WhyNeg, [indent_step(4)]), nl
        ;   
        format('Negative query failed.~n')
    ),

    % Clear the session
    clearSession(Session),
    format('~nSession cleared.~n').

