:- module(restricted_paths, [restricted_access_for/2, is_path_allowed/2]).

:- use_module(library(lists)).

%!  restricted_access_for(?Path:atom, ?RolesList:list) is nondet.
restricted_access_for('examples/moreExamples/insureLE2', [insurLE2]).

%!  is_path_allowed(+Path:atom, +UserRoles:list) is semidet.
%
%   Succeeds if the Path is allowed for a user with UserRoles.
%   If the path contains a restricted path, the user must have at least one
%   of the required roles.
is_path_allowed(Path, UserRoles) :-
    (   restricted_access_for(RestrictedPath, RequiredRoles),
        sub_atom(Path, _, _, _, RestrictedPath)
    ->  intersection(UserRoles, RequiredRoles, SharedRoles),
        SharedRoles \= []
    ;   true
    ).
