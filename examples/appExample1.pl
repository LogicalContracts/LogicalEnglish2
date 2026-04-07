:- use_module('../le_kbs').

main :-
    % Load the citizenship knowledge base
    load('moreExamples/citizenship.le', KB),
    format('Loaded KB: ~w~n', [KB]),
    
    % Create a session for this KB
    createSection(KB, Session),
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
    
    % Clear the session
    clearSession(Session),
    format('~nAfter clearing session:~n'),
    printSession(Session),
    
    % Run queries
    format('~nRunning queries:~n'),
    % Query 1: Who acquires British citizenship on which date in scenario 'alice'?
    Template1 = [Who, acquires, British, citizenship, on, When],
    forall(queryScenario(Session, 'alice', Template1, Instance1),
           format('Query 1 Result: ~w~n', [Instance1])),
           
    % Query 2: Who is the mother of whom in scenario 'alice'?
    Template2 = [Mother, is, the, mother, of, Child],
    forall(queryScenario(Session, 'alice', Template2, Instance2),
           format('Query 2 Result: ~w~n', [Instance2])),

    halt.

:- main.
