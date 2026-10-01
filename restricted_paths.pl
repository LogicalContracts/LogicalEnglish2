:- module(restricted_paths, [restricted_access_for/2, is_path_allowed/2]).

:- use_module(library(lists)).

%!  restricted_access_for(?Path:atom, ?Capabilities:list) is nondet.
%
%   A tree, and the capabilities that open it (any one of them). A signed-in
%   user's capabilities come from the licences they hold, which the lpsPlus
%   repository keeps (`accounts/licenses.csv`; `accounts/lc_accounts.pl`
%   says which capabilities each licence gives):
%
%     le_extensions      the licence "InsurLE": InsurLE2's language extensions,
%                        and InsurLE2's own examples, which need them to parse
%     extended_examples  the licence "with extensions": every example
%
%   The InsurLE examples, under the two names they are mounted with.
restricted_access_for('examples/moreExamples/insureLE2', [le_extensions]).
restricted_access_for('examples/moreExamples/InsurLE2', [le_extensions]).
% The lpsPlus tree: the twins of other systems whose sources carry no licence
% that allows publication. (The customs and Medicare models, and the OIPA
% twins, left it for examples/regulatory/ and examples/migration/: public.)
restricted_access_for('examples/moreExamples/lpsPlus', [extended_examples]).
% The test suites' fixtures: shown to licensed users only.
restricted_access_for('testing/fixtures/le', [extended_examples]).

%!  is_path_allowed(+Path:atom, +UserRoles:list) is semidet.
%
%   Succeeds if the Path is allowed for a user with UserRoles (their
%   capabilities). If the path contains a restricted path, the user must have
%   at least one of the capabilities that open it.
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
