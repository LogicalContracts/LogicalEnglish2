% A Prolog *resource* included by a Logical English program (see
% postcodes_layer.le). Loaded assert-only into a content-addressed cache
% module — never consulted — so it is safe to fetch from a URL. Typically a
% large facts file (here just a handful of rows); plain helper predicates are
% allowed too.
%
% Only dynamic/1, discontiguous/1 and use_module(library(...)) directives run
% at load time; anything else is skipped with a warning.

% postcode_region(Postcode, Region).
postcode_region(ec1a, london).
postcode_region(w1,   london).
postcode_region(sw1,  london).
postcode_region(m1,   manchester).
postcode_region(m60,  manchester).
postcode_region(eh1,  edinburgh).
postcode_region(eh8,  edinburgh).
postcode_region(cf10, cardiff).

% region_country(Region, Country).
region_country(london,     england).
region_country(manchester, england).
region_country(edinburgh,  scotland).
region_country(cardiff,    wales).

% A helper predicate (not just facts): the country a postcode is in, via its
% region. Demonstrates that ordinary Prolog rules load and run too.
postcode_country(Postcode, Country) :-
    postcode_region(Postcode, Region),
    region_country(Region, Country).
