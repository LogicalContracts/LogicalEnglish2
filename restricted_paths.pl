:- module(restricted_paths, [restricted_access_for/2, is_path_allowed/2, open_to_everyone/1]).

:- use_module(library(lists)).

%!  restricted_access_for(?Path:atom, ?RolesList:list) is nondet.
restricted_access_for('examples/moreExamples/insureLE2', [insurLE2]).
% The same InsurLE examples, where they are mounted as a directory of their own.
restricted_access_for('examples/moreExamples/InsurLE2', [insurLE2]).
% The lpsPlus tree: the domain models and the twins of other systems.
restricted_access_for('examples/moreExamples/lpsPlus', [insurLE2]).
% The test suites' fixtures: shown to the team's logged-in users only.
restricted_access_for('testing/fixtures/le', [insurLE2, developer]).

%!  open_to_everyone(?File:atom) is nondet.
%
%   Files inside a restricted tree that anyone may open, logged in or not:
%   what a public page links to (LPS2's /insurance, the insurance leaflet).
%   A program is named without its `.le`, as examples are; a cited text by
%   its full name. It is the file that opens, not its folder: the tree stays
%   out of the examples list, and its other programs stay closed — so a
%   program goes here together with what it includes and the texts it cites,
%   or its visitors get a program whose citations do not open.
%
%   Medicare power mobility devices (LCD L33789): the policy, the library
%   every Medicare policy includes, its test claims with the coverage desk,
%   and the public CMS texts those three cite.
open_to_everyone('examples/moreExamples/lpsPlus/medicare/pmd_cases').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/pmd').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/dmepos').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/lcd/L33789.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/article/A52498.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/article/A55426.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/ncd/NCD_280.3.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/cfr/42_CFR_410.38.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/cfr/CMS_required_f2f_wopd_list_2026-04-13.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/cfr/CMS_required_prior_authorization_list_2026-07-29.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/history/L33718.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/manuals/BPM_100-02_ch15.txt').
open_to_everyone('examples/moreExamples/lpsPlus/medicare/sources/manuals/PIM_100-08_ch5.txt').

%   Path names one of those files: it ends in the file's name (or in that
%   name and `.le`), whatever directory the server runs in, and goes nowhere
%   else on the way ("pmd.le/../oxygen.le" ends in a closed file, and a path
%   with `..` in it is not looked at).
open_path(LowPath) :-
    \+ sub_atom(LowPath, _, _, _, '..'),
    open_to_everyone(File),
    downcase_atom(File, LowFile),
    (   Tail = LowFile
    ;   \+ file_name_extension(_, txt, LowFile), atom_concat(LowFile, '.le', Tail)
    ),
    atom_concat(Before, Tail, LowPath),
    ( Before == '' ; sub_atom(Before, _, 1, 0, '/') ),
    !.

%!  is_path_allowed(+Path:atom, +UserRoles:list) is semidet.
%
%   Succeeds if the Path is allowed for a user with UserRoles.
%   If the path contains a restricted path, the user must have at least one
%   of the required roles — unless the file is open_to_everyone/1.
is_path_allowed(_Path, _UserRoles) :- getenv('NO_RESTRICTIONS',true), !.
is_path_allowed(Path, _UserRoles) :-
    downcase_atom(Path, LowPath),
    open_path(LowPath),
    !.
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
