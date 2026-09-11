"""Generate examples/RulesRus/customs/plastics_cbp.le and plastics_ebti.le."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

MA = "X is a manufactured article"
PL = "X is made of plastics"


def use(u, office, doc, because):
    return ("the principal use of X is %s" % u,
            'according to %s, as stated in %s,\n        because "%s"' % (office, doc, because))


def claim(kind, office, doc, because):
    return [("X is claimed to belong to %s" % kind, None),
            ("the claim that X belongs to %s is rejected" % kind,
             'according to %s, as stated in %s,\n        because "%s"' % (office, doc, because))]


def essential(component, office, doc, because):
    return ("the essential character of X is given by %s" % component,
            'according to %s, as stated in %s,\n        because "%s"' % (office, doc, because))


PHONE_ANCHOR = {"G10": "The first style", "aluminium": "the second style",
                "stainless steel": "the third style", "titanium": "the fourth style"}


def phone_case(bezel):
    d = "ruling NY N363522"
    return dict(x="the %s bezel case" % bezel, anchor=PHONE_ANCHOR[bezel], code="3926.90.9989",
                facts=[MA, "X is a composite good", "the G10 rear housing of X is a component of X",
                       "the %s bezel of X is a component of X" % bezel,
                       "the G10 rear housing of X is made of plastics"],
                judged=[essential("the G10 rear housing of X", "CBP", d,
                                  "the plastic provides the impact protection and predominates over the bezel materials (GRI 3(b))"),
                        use("protecting a mobile phone", "CBP", d, "a fitted protective case for a mobile phone")],
                claims=claim("cases of heading 4202", "CBP", d,
                             "per HQ H297451 such cellphone cases are not classified under heading 4202 but by their constituent materials"))


def kit(n, piece):
    d = "ruling NY N362269"
    return dict(x="kit %s" % n, anchor=n, code="3926.40.0090",
                facts=[MA, "X is a set put up for retail sale", "%s of X is a component of X" % piece,
                       "the crystal diamonds of X is a component of X", "%s of X is made of plastics" % piece],
                judged=[essential("%s of X" % piece, "CBP", d, "the decorative plastic components impart the essential character (GRI 3(b))"),
                        use("ornament", "CBP", d, "the finished charm is an ornamental article")])


def bag(ruling, country):
    d = "ruling NY %s" % ruling
    return dict(id=ruling, date="March 2026", subject="a plastic bag from %s" % country, styles=[
        dict(x="the reclosable bag", code="3923.21.0030",
             facts=[MA, PL, "X is shaped as sack", "X contains 80 percent of polyethylene"],
             judged=[use("packing of goods", "CBP", d, "the bag is intended for supplementary packaging")])])


CBP = [
    dict(id="N363384", date="July 2026", subject="a men's faux leather jacket from China", styles=[
        dict(x="style CB81426", code="3926.20.9050",
             facts=[MA],
             judged=[("X is of cellular plastics reinforced by a textile fabric",
                      'according to CBP, as stated in ruling NY N363384,\n        because "the outer shell is cellular polyurethane with a polyester woven backing present merely for reinforcement purposes"'),
                     use("apparel", "CBP", "ruling NY N363384", "a men's jacket")],
             claims=claim("garments of heading 6210", "CBP", "ruling NY N363384",
                          "the textile fabric backing is present merely for reinforcing the cellular plastic (Chapter 59 note 2(a)(5)): the jacket is apparel of plastic material of Chapter 39"))]),
    dict(id="N363522", date="July 2026", subject="four cellphone cases from Canada",
         styles=[phone_case("G10"), phone_case("aluminium"), phone_case("stainless steel"), phone_case("titanium")]),
    dict(id="N363173", date="July 2026", subject="collectible miniature studio equipment from Belgium", styles=[
        dict(x="the miniature studio replicas", code="3926.40.0090",
             facts=[MA, PL],
             judged=[use("ornament", "CBP", "ruling NY N363173", "static display pieces intended to serve as collectible decorations")])]),
    dict(id="N363253", date="July 2026", subject="a bowl clamp from China", styles=[
        dict(x="the self-feeding bowl clamp", code="3926.90.9989",
             facts=[MA, PL],
             judged=[use("securing a feeding bowl", "CBP", "ruling NY N363253",
                         "the clamp is not of the same class or kind as the tableware and kitchenware exemplars of EN 39.24 because it functions as a clamp (as in N269773)")],
             extra=['    household expects changes [["add: the principal use of the self-feeding bowl clamp is household use"],',
                    '        ["add: the principal use of the self-feeding bowl clamp is kitchen use"],',
                    '        ["add: the principal use of the self-feeding bowl clamp is table use"],',
                    '        ["add: the principal use of the self-feeding bowl clamp is toilet use"]].'])]),
    dict(id="N362836", date="July 2026", subject="a plastic cartridge from China", styles=[
        dict(x="the printing cartridge", code="3926.90.2100",
             facts=[MA, PL],
             judged=[use("dispensing paste in a 3D printer", "CBP", "ruling NY N362836",
                         "a graduated syringe used as the material reservoir of an additive-manufacturing system, not for medical use")])]),
    dict(id="N362269", date="June 2026", subject="ornamental craft kits from China", styles=[
        kit("DS0031003", "the acetate candle piece"), kit("DS0031006", "the acetate dog piece"),
        kit("DS0031007", "the acetate croissant piece"), kit("DS0042003", "the polyurethane charm")]),
    dict(id="N362002", date="June 2026", subject="a plastic foam pad from China", styles=[
        dict(x="the reticulated foam pad", code="3926.90.9989",
             facts=[MA, PL],
             judged=[use("splash suppression in an oil drain container", "CBP", "ruling NY N362002",
                         "a component permanently incorporated in an oil drain container to suppress splashing; not a filter")])]),
    dict(id="N363254", date="July 2026", subject="a plastic rake from China", styles=[
        dict(x="the Leafinator", code="3924.90.5650",
             facts=[MA, "X is a composite good", "the polypropylene panels of X is a component of X",
                    "the aluminium pole of X is a component of X", "the polypropylene panels of X is made of plastics"],
             judged=[essential("the polypropylene panels of X", "CBP", "ruling NY N363254",
                               "the polypropylene components make up most of the weight and bulk and perform the principal function of raking"),
                     use("household use", "CBP", "ruling NY N363254", "a garden rake used in household yards")])]),
    dict(id="N362334", date="June 2026", subject="a plastic laundry bin from China", styles=[
        dict(x="the laundry bin GS750", code="3924.90.5650",
             facts=[MA, PL],
             judged=[use("household use", "CBP", "ruling NY N362334", "designed to be used in the home to hold and store laundry, toys and other household items")])]),
    dict(id="N360630", date="April 2026", subject="a plastic shoe tree from China", styles=[
        dict(x="the Fresh Flow shoe tree", code="3924.90.5650",
             facts=[MA, PL],
             judged=[use("household use", "CBP", "ruling NY N360630", "classified with household articles following NY A81381, N086500 and N302876")],
             claims=claim("parts of footwear of heading 6406", "CBP", "ruling NY N360630", "the article is not a complete shoe or a part of a shoe"))]),
    dict(id="N360066", date="March 2026", subject="a cat toy from China", styles=[
        dict(x="the Pom Pom Launcher", code="3924.90.5650",
             facts=[MA, "X is a set put up for retail sale", "the launcher of X is a component of X",
                    "the pom pom balls of X is a component of X", "the launcher of X is made of plastics"],
             judged=[essential("the launcher of X", "CBP", "ruling NY N360066", "the launcher gives the essential character by bulk, weight, value and importance to the set"),
                     use("household use", "CBP", "ruling NY N360066", "plastic pet toys used by domestic animals are household articles (Hartz Mountain Corp. v. United States, 19 CIT 1149)")],
             claims=claim("toys of heading 9503", "CBP", "ruling NY N360066",
                          "Chapter 95 note 5: heading 9503 does not cover articles identifiable as intended exclusively for animals"))]),
    dict(id="N357351", date="December 2025", subject="a plastic scrub sponge", styles=[
        dict(x="the scrub sponge", code="3924.90.5650",
             facts=[MA, PL],
             judged=[use("household use", "CBP", "ruling NY N357351", "the scrub sponge is intended for household cleaning")])]),
    dict(id="N356689", date="December 2025", subject="plastic picture frames from China", styles=[
        dict(x="the Fitm picture frames", code="3924.90.2000",
             facts=[MA, PL],
             judged=[use("household use", "CBP", "ruling NY N356689", "frames for household display of photographs or artwork")])]),
    dict(id="N340223", date="May 2024", subject="a plastic mat from China", styles=[
        dict(x="the kitchen rug M516", code="3924.90.1050",
             facts=[MA, "X is a composite good", "the coated nonwoven layer of X is a component of X",
                    "the rubber foam back of X is a component of X"],
             judged=[("the coated nonwoven layer of X is made of plastics",
                      'according to the CBP laboratory, as stated in ruling NY N340223,\n        because "a man-made nonwoven fabric coated, covered, impregnated or laminated with poly(ether-ester urethane)"'),
                     essential("the coated nonwoven layer of X", "CBP", "ruling NY N340223",
                               "the coated layer performs the primary role of cushioning; the rubber back only prevents sliding"),
                     use("household use", "CBP", "ruling NY N340223", "the mat is designed and marketed for household use")])]),
    dict(id="N363423", date="July 2026", subject="polyethylene foam packaging inserts from China", styles=[
        dict(x="the foam packaging inserts", code="3923.90.0080",
             facts=[MA, PL],
             judged=[use("packing of goods", "CBP", "ruling NY N363423", "inserts used to protect a robotic arm during shipment")])]),
    bag("N360189", "Malaysia"), bag("N360191", "Turkey"), bag("N360188", "China"), bag("N360190", "Thailand"),
    dict(id="N358771", date="February 2026", subject="a lipstick container from South Korea", styles=[
        dict(x="the lipstick container LPNR001", code="3923.90.0080",
             facts=[MA, PL],
             judged=[use("packing of goods", "CBP", "ruling NY N358771", "the container protects the lipstick from impact and contamination and serves its transport, storage and use"),
                     ("X is shaped as cylindrical container",
                      'according to CBP, as stated in ruling NY N358771,\n        because "a cylindrical round container is not a box, case, crate or similar article"')])]),
    dict(id="N342911", date="September 2024", subject="WPP/BOPP bags from Dominican Republic-Central America", styles=[
        dict(x="the WPP BOPP bag", code="3923.29.0000",
             facts=[MA, PL, "X is shaped as sack", "X contains 100 percent of polypropylene"],
             judged=[use("packing of goods", "CBP", "ruling NY N342911", "bags used for packaging animal feed, cat litter, home and garden products and charcoal")])]),
]

EBTI = [
    dict(id="DEBTI19479/26-1", office="Hauptzollamt Hannover", date="09/07/2026", subject="dog waste bags", styles=[
        dict(x="the dog waste bags", code="3923.21",
             facts=[MA, PL, "X is shaped as sack", "X contains 100 percent of polyethylene", "X is printed with motifs"],
             judged=[use("packing of goods", "Hauptzollamt Hannover", "BTI DEBTI19479/26-1", "bags of welded HDPE film classified as articles for the conveyance or packing of goods"),
                     ("the printing of X is merely subsidiary",
                      'according to Hauptzollamt Hannover, as stated in BTI DEBTI19479/26-1,\n        because "the BTI cites Section VII note 2 and keeps the printed bags in Chapter 39"')])]),
    dict(id="DEBTI22676/26-1", office="Hauptzollamt Hannover", date="26/06/2026", subject="foam packaging insert", styles=[
        dict(x="the foam packaging insert", code="3923.90",
             facts=[MA, PL],
             judged=[use("packing of goods", "Hauptzollamt Hannover", "BTI DEBTI22676/26-1", "a transport packaging for parts of dial gauges")],
             claims=claim("sheets of heading 3921", "Hauptzollamt Hannover", "BTI DEBTI22676/26-1",
                          "the block has been worked further (specific cut-outs), so it is not a good of heading 3921 (Chapter 39 note 10)"))]),
    dict(id="DEBTI41932/25-1", office="Hauptzollamt Hannover", date="11/11/2025", subject="drinking bottle", styles=[
        dict(x="the drinking bottle", code="3924.90",
             facts=[MA, "X is a composite good", "the plastic body and lid of X is a component of X",
                    "the silicone seal of X is a component of X", "the carrying strap of X is a component of X",
                    "the plastic body and lid of X is made of plastics"],
             judged=[essential("the plastic body and lid of X", "Hauptzollamt Hannover", "BTI DEBTI41932/25-1",
                               "by their extent and their importance for the use, the plastics give the character"),
                     use("household use", "Hauptzollamt Hannover", "BTI DEBTI41932/25-1",
                         "a bottle for carrying drinks, used in the household, outdoors and when travelling; not tableware or kitchenware of subheading 3924.10")])]),
    dict(id="DEBTI47170/25-1", office="Hauptzollamt Hannover", date="14/01/2026", subject="system tool crate", styles=[
        dict(x="the system tool crate", code="3926.90",
             facts=[MA, PL],
             judged=[use("carrying tools", "Hauptzollamt Hannover", "BTI DEBTI47170/25-1",
                         "an open crate of a modular tool-case system for transporting and storing tools of all kinds; not an article for the packing of goods (Explanatory Note to heading 3923)")],
             claims=claim("containers of heading 4202", "Hauptzollamt Hannover", "BTI DEBTI47170/25-1",
                          "the crate is not fitted to hold particular tools, so it is neither named in heading 4202 nor similar to the goods named there"))]),
]

HEADER_CBP = """% Plastics rulings of U.S. Customs and Border Protection (CROSS, rulings.cbp.gov)
% run through the plastics model (plastics.le, which includes gri.le).
%
% One scenario per ruling; each article is described by the facts the ruling
% states, citing it; the office's judgments — the principal use, the essential
% character of a composite good or set, the answer to a claim that the article
% belongs to a heading outside the model — carry who made them and why. The
% ruling's code is NOT a fact: the expectation is the six-digit subheading the
% model derives from them.
% Selection: the most recent rulings returned by CROSS for 3923.21-90,
% 3924.10-90 and 3926.20-90 (September 2026). Rulings N360188-N360191 are one
% bag imported from four countries. See README.md for the method and results.

the target language is: prolog.
scenario facts require provenance.

the knowledge base plastics cbp includes these resources:
    plastics.

the knowledge base plastics cbp includes:

query subheading is:
    the subheading of which good is which code.

query heading is:
    the heading of which good is which heading.

query unplaced is:
    which good is not placed by the model.

% The bowl clamp turns on CBP's judgment of its principal use: which judgment
% would have put it in heading 3924, as the importer asked?
query household is:
    which minimal change to the scenario makes it the case that
        the heading of the self-feeding bowl clamp is 3924.
"""

HEADER_EBTI = HEADER_CBP.replace(
    "% Plastics rulings of U.S. Customs and Border Protection (CROSS, rulings.cbp.gov)\n% run through the plastics model (plastics.le, which includes gri.le).",
    "% Binding Tariff Information of EU customs offices (EBTI,\n% https://ec.europa.eu/taxation_customs/dds2/ebti/) run through the SAME\n% plastics model (plastics.le, with gri.le) as the US rulings.").replace(
    "% Selection: the most recent rulings returned by CROSS for 3923.21-90,\n% 3924.10-90 and 3926.20-90 (September 2026). Rulings N360188-N360191 are one\n% bag imported from four countries. See README.md for the method and results.",
    "% Selection: the most recent valid German BTI for 3923.21, 3923.90, 3924.90\n% and 3926.90 (September 2026); the first six digits of the BTI's CN code are\n% the HS subheading compared. See README.md for the method and results.").replace(
    "the knowledge base plastics cbp", "the knowledge base plastics ebti")


HELDOUT = [
    dict(id="N362285", date="July 2026", subject="a shower vinyl curtain", styles=[
        dict(x="the shower vinyl curtain", code="3924.90.1010",
             facts=[MA, PL, "X contains 100 percent of polyvinyl chloride"],
             judged=[use("household use", "CBP", "ruling NY N362285", "a 72 by 72 inch shower curtain of PVC sheet")])]),
    dict(id="N358418", date="February 2026", subject="a plastic bowl from China", styles=[
        dict(x="the ghost ramekin", code="3924.10.2000",
             facts=[MA, PL],
             judged=[use("table use", "CBP", "ruling NY N358418", "a food-safe plastic bowl, not heatproof, so not a ramekin for the oven")],
             claims=claim("festive articles of heading 9505", "CBP", "ruling NY N358418",
                          "a Halloween motif on a functional bowl does not make it a festive article (Park B. Smith Ltd. v. United States, 347 F.3d 922)"))]),
    dict(id="N361986", date="June 2026", subject="vinyl record sleeves from China", styles=[
        dict(x="the record sleeves", code="3926.90.9989",
             facts=[MA, PL],
             judged=[use("protecting vinyl records", "CBP", "ruling NY N361986", "outer sleeves to store, protect and preserve vinyl records and their jackets during storage, handling, display and transport")])]),
    dict(id="N361872", date="June 2026", subject="plastic rebar from China", styles=[
        dict(x="the LiteBar rebar", code="3926.90.9989",
             facts=[MA, PL],
             judged=[use("reinforcing concrete", "CBP", "ruling NY N361872", "a fiberglass-reinforced plastic substitute for steel rebar in concrete")])]),
    dict(id="N361443", date="May 2026", subject="plastic letter charms from China", styles=[
        dict(x="the letter charms", code="3926.40.0090",
             facts=[MA, PL],
             judged=[use("ornament", "CBP", "ruling NY N361443", "molded plastic letters with loops to be strung, for home craft projects")])]),
]

HEADER_HELDOUT = HEADER_CBP.replace(
    "% Plastics rulings of U.S. Customs and Border Protection (CROSS, rulings.cbp.gov)\n% run through the plastics model (plastics.le, which includes gri.le).",
    "% HELD-OUT plastics rulings of U.S. Customs and Border Protection, run through\n% the plastics model (plastics.le, which includes gri.le) after it was frozen.").replace(
    "% Selection: the most recent rulings returned by CROSS for 3923.21-90,\n% 3924.10-90 and 3926.20-90 (September 2026). Rulings N360188-N360191 are one\n% bag imported from four countries. See README.md for the method and results.",
    "% Selection: the two (for 3926 three) most recent rulings not used to write\n% the rules whose codes (other than Chapter 98/99) all fall in 3923, 3924 or\n% 3926 (none left for 3923). Facts transcribed with the classification\n% sentences removed; the principal use is as the ruling describes it. See\n% README.md.").replace(
    "the knowledge base plastics cbp", "the knowledge base heldout plastics cbp").replace(
    """
% The bowl clamp turns on CBP's judgment of its principal use: which judgment
% would have put it in heading 3924, as the importer asked?
query household is:
    which minimal change to the scenario makes it the case that
        the heading of the self-feeding bowl clamp is 3924.
""", "")


import re
import quotes as Q

USE_PATTERNS = {
    'household use': [r'household', r'in the home', r'Haushalt', r'home'],
    'packing of goods': [r'packag', r'packing', r'conveyance', r'Verpackung', r'shipment', r'Transport'],
    'ornament': [r'ornament', r'decorat', r'charm'],
    'apparel': [r'jacket'],
    'table use': [r'food-safe', r'bowl'],
}
CLAIM_PATTERNS = {
    'cases of heading 4202': ([r'4202'], [r'not classified under heading 4202', r'4202']),
    'containers of heading 4202': ([r'4202'], [r'4202']),
    'parts of footwear of heading 6406': ([r'6406'], [r'not a complete shoe']),
    'toys of heading 9503': ([r'9503'], [r'exclusively for animals', r'Note 5']),
    'garments of heading 6210': ([r'6210'], [r'merely for reinforcing']),
    'sheets of heading 3921': ([r'3921'], [r'3921']),
    'festive articles of heading 9505': ([r'Halloween'], [r'Park B\. Smith', r'Halloween']),
}
PLASTIC = [r'plastic', r'polypropylene', r'polyethylene', r'\bABS\b', r'polyurethane', r'\bPLA\b', r'PVC',
           r'melamine', r'polyvinyl', r'Kunststoff', r'polyether', r'Polyethylen', r'Polypropylen']


def source_path(r, us):
    return ('cbp/%s.txt' % r['id']) if us else ('ebti/%s.txt' % r['id'].replace('/', '_').replace('-', '_'))


def component_patterns(c):
    words = [w for w in re.sub(r'^the ', '', c).split() if w not in ('of', 'and')]
    pats = [r'\s+'.join(map(re.escape, words))]
    if len(words) > 1:
        pats.append(re.escape(words[-1]))
        pats.append(re.escape(words[0]))
    return pats


def patterns_for(f):
    """(patterns, where): where is 'seg' (the good's own passage first) or 'text'."""
    m = re.match(r'the principal use of X is (.+)$', f)
    if m:
        u = m.group(1)
        stems = [re.escape(w[:5]) for w in u.split() if len(w) > 4]
        return USE_PATTERNS.get(u, stems), 'use'
    m = re.match(r'X is claimed to belong to (.+)$', f)
    if m:
        return CLAIM_PATTERNS[m.group(1)][0], 'text'
    m = re.match(r'the claim that X belongs to (.+) is rejected$', f)
    if m:
        return CLAIM_PATTERNS[m.group(1)][1], 'text'
    m = re.match(r'X contains ([\d.]+) percent of (.+)$', f)
    if m:
        n, mat = m.groups()
        return [r'(?<![\d.])' + re.escape(n) + r'(?![\d])\s*(percent|%)', re.escape(mat), r'HDPE', r'polypropylene'], 'seg'
    m = re.match(r'the essential character of X is given by (.+)$', f)
    if m:
        return [r'essential character', r'charakterverleihend', r'essential'], 'seg'
    m = re.match(r'(.+) of X is a component of X$', f)
    if m:
        return component_patterns(m.group(1)), 'seg'
    m = re.match(r'(.+) of X is made of plastics$', f)
    if m:
        return [p + r'[^.;]{0,60}(' + '|'.join(PLASTIC) + ')' for p in component_patterns(m.group(1))] + PLASTIC, 'seg'
    table = [
        ('X is a manufactured article', [r'is an? [^.;,]{3,60}', r'described as', r'handelt es sich um']),
        ('X is made of plastics', PLASTIC),
        ('X is a composite good', [r'composite', r'consists of', r'two-part', r'besteht aus']),
        ('X is a set put up for retail sale', [r'sets? for', r'packaged together', r'components', r'kits?']),
        ('X is shaped as sack', [r'\bbags?\b', r'Beutel', r'\bsacks?\b']),
        ('X is shaped as cylindrical container', [r'cylindrical']),
        ('X is printed with motifs', [r'bedruckt', r'printed']),
        ('X is of cellular plastics', [r'cellular']),
        ('the printing of X', [r'Anm 2 ABS VII', r'bedruckt']),
    ]
    for k, pats in table:
        if f.startswith(k):
            return pats, 'seg'
    return None, 'seg'


BAD_QUOTES = []

# Passages chosen by hand where the patterns find the wrong one (a use is
# quoted from the ruling's description, never from its classification).
OVERRIDES = {'style CB81426': {'X is a manufactured article': 'Style CB81426 is a men’s faux leather jacket', 'the principal use of X': 'Style CB81426 is a men’s faux leather jacket'}, 'the miniature studio replicas': {'the principal use of X': 'These articles are intended to serve as collectible decorations'}, 'KIT': {'the principal use of X': 'then will assemble the other kit elements to create the finished charm'}, 'the Fresh Flow shoe tree': {'X is a manufactured article': 'The merchandise under consideration is identified as a shoe tree', 'the principal use of X': 'Please see NY ruling A81381, dated April 16, 1996, N086500, dated December 18, 2009, and N302876'}, 'the lipstick container LPNR001': {'X is a manufactured article': 'described as a lipstick container, model number LPNR001, constructed from an injection-molded plastic', 'the principal use of X': 'designed to protect the contents from external impact and contamination, and to facilitate its transport, storage, and use'}, 'the Fitm picture frames': {'X is a manufactured article': 'The merchandise under consideration is plastic picture frames'}, 'the foam packaging inserts': {'X is a manufactured article': 'The products under consideration are polyethylene foam packaging inserts used to protect a robotic arm during shipment'}, 'the shower vinyl curtain': {'X is a manufactured article': 'The item under consideration is identified as a shower vinyl curtain', 'the principal use of X': 'The item under consideration is identified as a shower vinyl curtain'}, 'the letter charms': {'the principal use of X': 'to be used for home craft projects'}, 'the laundry bin GS750': {'the principal use of X': 'The article is designed to be used in the home to hold and store assorted items'}}


def quote_for(f, text, seg, body, x=None):
    ov = OVERRIDES.get('KIT' if x and x.startswith('kit ') else x, {})
    for k, qq in ov.items():
        if f.startswith(k):
            if not Q.check(text, qq):
                BAD_QUOTES.append((f, qq))
                return None
            return qq
    pats, where = patterns_for(f)
    if not pats:
        q = Q.first_clause(text, seg)
    elif where == 'text':
        q = Q.find(text, body, pats)
    elif where == 'use':
        # a use is quoted only where the ruling states it
        q = Q.find(text, seg, pats) or Q.find(text, body, pats)
    else:
        q = Q.find(text, seg, pats) or Q.find(text, body, pats) or Q.first_clause(text, seg)
    if q and not Q.check(text, q):
        BAD_QUOTES.append((f, q))
        q = None
    return q


def at(quote):
    return (' at "%s"' % quote) if quote else ''


def fact_line(f, x, doc, quote=None):
    return "    %s,\n        as stated in %s%s." % (f.replace("X", x), doc, at(quote))


def judged_line(f, trailers, x, quote=None):
    t = trailers.replace("X", x)
    if quote:
        t = re.sub(r'(as stated in [^,\n]+)', lambda m: m.group(1) + at(quote), t, count=1)
    return "    %s,\n        %s." % (f.replace("X", x), t)


def scenario(r, us):
    doc = ("ruling NY %s" % r["id"]) if us else ("BTI %s" % r["id"])
    name = ("ny_%s" % r["id"]).lower() if us else "bti_" + r["id"].lower().replace("/", "_").replace("-", "_")
    text = Q.load(source_path(r, us))
    Q.MODE['lines'] = not us
    stops = () if us else ('\nKeywords',)
    body = Q.segment(text, None, [], stops=stops)
    if not us:
        body = Q.segment(text, 'Description of goods', [], stops=stops)
    anchors = [s.get('anchor') for s in r["styles"] if s.get('anchor')]
    if us:
        head = "%% NY %s (%s): %s." % (r["id"], r["date"], r["subject"])
    else:
        head = "%% BTI %s, %s, %s: %s." % (r["id"], r["office"], r["date"], r["subject"])
    out, expected = [], []
    for s in r["styles"]:
        x = s["x"]
        seg = Q.segment(text, s['anchor'], anchors, stops=stops) if s.get('anchor') else body
        for f in s["facts"]:
            out.append(fact_line(f, x, doc, quote_for(f, text, seg, body, x)))
        for f, t in s.get("judged", []):
            out.append(judged_line(f, t, x, quote_for(f, text, seg, body, x)))
        for f, t in s.get("claims", []):
            q = quote_for(f, text, seg, body, x)
            out.append(fact_line(f, x, doc, q) if t is None else judged_line(f, t, x, q))
        expected.append('"the subheading of %s is %s"' % (x, s["code"][:7]))
    out.append("    subheading expects answers [%s]." % ",\n        ".join(expected))
    for s in r["styles"]:
        out.extend(s.get("extra", []))
    return head + "\nscenario %s is:\n" % name + "\n".join(out) + "\n"


def document_facts(rulings, us):
    lines = []
    for r in rulings:
        doc = ("ruling NY %s" % r["id"]) if us else ("BTI %s" % r["id"])
        url = ("https://rulings.cbp.gov/ruling/%s" % r["id"]) if us else \
              "https://ec.europa.eu/taxation_customs/dds2/ebti/ebti_consultation.jsp?Lang=en"
        lines.append('%s is published at "%s".' % (doc, url))
        lines.append('the text of %s is at "sources/%s".' % (doc, source_path(r, us)))
    return "\n".join(lines) + "\n"


def with_documents(header, rulings, us):
    marker = "includes:\n"
    i = header.rindex(marker) + len(marker)
    return header[:i] + "\n% Where each cited ruling is published, and a copy of its text (sources/).\n" + \
        document_facts(rulings, us) + header[i:]


def main():
    for rulings, us, path, header in ((CBP, True, "plastics_cbp.le", HEADER_CBP), (EBTI, False, "plastics_ebti.le", HEADER_EBTI)):
        parts = [with_documents(header, rulings, us)] + [scenario(r, us) for r in rulings]
        open(OUT + "/" + path, "w").write("\n".join(parts))
    parts = [with_documents(HEADER_HELDOUT, HELDOUT, True)] + [scenario(r, True) for r in HELDOUT]
    open(OUT + "/heldout_plastics_cbp.le", "w").write("\n".join(parts))
    for b in BAD_QUOTES:
        print("QUOTE NOT IN TEXT:", b)


main()
