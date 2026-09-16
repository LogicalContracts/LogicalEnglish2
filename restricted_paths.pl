:- module(restricted_paths, [restricted_access_for/2, is_path_allowed/2]).

:- use_module(library(lists)).

%!  restricted_access_for(?Path:atom, ?RolesList:list) is nondet.
restricted_access_for('examples/moreExamples/insureLE2', [insurLE2]).
% The same InsurLE examples, where they are mounted as a directory of their own.
restricted_access_for('examples/moreExamples/InsurLE2', [insurLE2]).
% The test suites' fixtures: shown to the team's logged-in users only.
restricted_access_for('testing/fixtures/le', [insurLE2, developer]).

%!  is_path_allowed(+Path:atom, +UserRoles:list) is semidet.
%
%   Succeeds if the Path is allowed for a user with UserRoles.
%   If the path contains a restricted path, the user must have at least one
%   of the required roles.
is_path_allowed(_Path, _UserRoles) :- getenv('NO_RESTRICTIONS',true), !.
is_path_allowed(Path, UserRoles) :-
    %  Case-insensitively: on a case-insensitive file system another spelling
    %  of a restricted directory reaches the same tree.
    downcase_atom(Path, LowPath),
    (   restricted_access_for(RestrictedPath, RequiredRoles),
        downcase_atom(RestrictedPath, LowRestricted),
        sub_atom(LowPath, _, _, _, LowRestricted)
    ->  intersection(UserRoles, RequiredRoles, SharedRoles),
        SharedRoles \= []
    ;   true
    ).
