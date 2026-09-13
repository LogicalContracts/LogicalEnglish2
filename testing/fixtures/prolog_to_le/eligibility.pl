% An s(CASP)-style program with #pred annotations — the template dictionary
% a Blawx or s(CASP) source already carries (§5.7).

#pred eligible(X) :: '@(X) is eligible for the benefit'.
#pred resident(X) :: '@(X) is a resident'.
#pred income(X, Y) :: 'the income of @(X) is @(Y)'.
#pred excluded(X) :: '@(X) is excluded'.

eligible(Claimant) :- resident(Claimant), income(Claimant, Amount), Amount < 20000, not excluded(Claimant).

excluded(Claimant) :- convicted(Claimant).

resident(ann). resident(bob). resident(cy).
income(ann, 15000). income(bob, 25000). income(cy, 1000).
convicted(cy).
