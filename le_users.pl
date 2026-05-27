:- module(le_users, [add_le_user/3, authenticate_le_user/3, user_roles/2]).

:- use_module(library(crypt)).
:- use_module(library(persistency)).

:- persistent
    le_user(email:atom, hash:atom, roles:list).

:- initialization(db_attach('le_users.db', [])).

%!  add_le_user(+Email:atom, +Password:string, +Roles:list) is det.
add_le_user(Email, Password, Roles) :-
    crypt(Password, HashCodes),
    atom_codes(Hash, HashCodes),
    (   le_user(Email, _, _)
    ->  retract_le_user(Email, _, _),
        assert_le_user(Email, Hash, Roles)
    ;   assert_le_user(Email, Hash, Roles)
    ).

%!  authenticate_le_user(+Email:atom, +Password:string, -Roles:list) is semidet.
authenticate_le_user(Email, Password, Roles) :-
    le_user(Email, Hash, Roles),
    atom_codes(Hash, HashCodes),
    crypt(Password, HashCodes).

%!  user_roles(+Email:atom, -Roles:list) is semidet.
user_roles(Email, Roles) :-
    le_user(Email, _, Roles).

