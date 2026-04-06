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
    
    halt.

:- main.
