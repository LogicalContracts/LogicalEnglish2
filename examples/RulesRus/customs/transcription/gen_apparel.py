"""Generate examples/RulesRus/customs/apparel_cbp.le and apparel_ebti.le from
a transcription of the rulings' facts. Each style: its facts (X = the style),
the office's judgments (full sentences with trailers), the office's code and,
where the model disagrees, the model's answer and a note."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')

# ---------------------------------------------------------------- vocabulary
KNIT = "the fabric construction of X is knitted"
WOVEN = "the fabric construction of X is woven"
UBG = "X is an upper body garment"
US = "X is classified under the US tariff"
EU = "X is classified under the EU tariff"
MEN = "the cut of X indicates men"
WOMEN = "the cut of X indicates women"
LR = "X closes left over right"
RL = "X closes right over left"
SLEEVELESS = "X is sleeveless"
OPENING = "X has an opening starting at the neckline"
POCKETS = "X has pockets below the waist"
TIGHT = "X has a means of tightening at the bottom"
LOOSE = "X is loose-fitting"
COLLAR = "X has a collar"
HIGH = "X has a high neckline"
NAPPED = "X is napped"
TERRY = "the fabric of X is terry"
LIGHT = "the fabric of X is lightweight"
PLAIN = "X is of plain knit fabric"
STRAPS = "X has shoulder straps"
REAR = "the rear neckline of X falls below the nape of the neck"
UNDER = "X is designed to be worn as an undergarment"
METAL = "all the yarn of X is metalized yarn"


def comp(*pairs):
    return ["X contains %s percent of %s" % (n, m) for n, m in pairs]


def claim(kind, office, doc, because):
    return [("X is claimed to belong to %s" % kind, None),
            ("the claim that X belongs to %s is rejected" % kind,
             'according to %s, as stated in %s,\n        because "%s"' % (office, doc, because))]


# ---------------------------------------------------------------- CBP rulings
CBP = [
    dict(id="N362700", date="July 2026", subject="men's upper body garments from Jordan", styles=[
        dict(x="style 1025AD", code="6105.20.2010",
             facts=[UBG, US, KNIT, MEN, OPENING, COLLAR, NAPPED] + comp((92, "polyester"), (8, "spandex")),
             claims=claim("outerwear", "CBP", "ruling NY N362700",
                          "the garment lacks the character of an outerwear jacket designed for wear over all other clothing for protection against the elements")),
        dict(x="style 1000AD", code="6110.30.3053",
             facts=[UBG, US, KNIT, MEN, OPENING, COLLAR, NAPPED] + comp((100, "polyester")),
             judged=[(POCKETS, 'according to CBP, as stated in ruling NY N362700,\n        because "on a mannequin a portion of each side seam pocket is below the waist; per HQ H293112, if any part of a pocket is below the waist it is a pocket below the waist"')]),
    ]),
    dict(id="N362034", date="June 2026", subject="men's upper body garments from Taiwan", styles=[
        dict(x="style TaraNirvana Performance Polo", code="6105.20.2010",
             facts=[UBG, US, KNIT, MEN, COLLAR, OPENING, LR, TERRY] + comp((85, "polyester"), (15, "elastane"))),
        dict(x="style TaraNirvana Performance Tee", code="6110.30.3053",
             facts=[UBG, US, KNIT, MEN, TERRY] + comp((85, "polyester"), (15, "elastane"))),
    ]),
    dict(id="N357552", date="January 2026", subject="a men's upper body garment", styles=[
        dict(x="style 264581", code="6105.10.0010",
             facts=[UBG, US, KNIT, MEN, OPENING, COLLAR] + comp((56, "cotton"), (41, "polyester"), (3, "elastane"))),
    ]),
    dict(id="N339358", date="April 2024", subject="men's upper body garments", styles=[
        dict(x="style MVSW9742", code="6110.30.3053",
             facts=[UBG, US, KNIT, MEN] + comp((92, "polyester"), (8, "spandex"))),
        dict(x="style MVSW9622", code="6110.20.2069",
             facts=[UBG, US, KNIT, MEN, PLAIN] + comp((100, "cotton"))),
        dict(x="style MVQZ9343", anchor="Style MVQZ9343 “Scuttle", code="6105.20.2010",
             facts=[UBG, US, KNIT, MEN, OPENING, COLLAR] + comp((93, "polyester"), (7, "spandex"))),
        dict(x="style MVSW10337", code="6110.30.3053",
             facts=[UBG, US, KNIT, MEN, POCKETS] + comp((57, "polyester"), (33, "viscose"), (5, "spandex"), (5, "nylon"))),
    ]),
    dict(id="N336228", date="2023-2024", subject="a men's upper body garment", styles=[
        dict(x="style TSUBLCK002", code="6105.10.0010",
             facts=[UBG, US, KNIT, MEN, OPENING, LR] + comp((100, "cotton")),
             claims=claim("sleepwear", "CBP", "ruling NY N336228",
                          "garments of this style and construction are multi-use loungewear worn in informal situations in and around the home, not garments designed for wear only to bed")),
    ]),
    dict(id="N362516", date="June 2026", subject="women's blouses from the Dominican Republic", styles=[
        dict(x="style W61383", code="6106.20.2010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE] + comp((84, "modal"), (9, "cashmere"), (7, "elastane")),
             claims=claim("sleepwear", "CBP", "ruling NY N362516",
                          "nothing in the styling, fabric, cut or construction indicates wear primarily to bed; the principal use is home comfort and lounging")),
        dict(x="style W64383", code="6106.20.2010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE] + comp((84, "modal"), (9, "cashmere"), (7, "elastane")),
             claims=claim("sleepwear", "CBP", "ruling NY N362516",
                          "nothing in the styling, fabric, cut or construction indicates wear primarily to bed; the principal use is home comfort and lounging")),
    ]),
    dict(id="N359550", date="March 2026", subject="women's upper body garments from Vietnam", styles=[
        dict(x="style 260309A", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN, LIGHT, NAPPED, OPENING, COLLAR, POCKETS] + comp((67, "cotton"), (33, "polyester")),
             claims=claim("outerwear", "CBP", "ruling NY N359550",
                          "the sample lacks the character of an outerwear jacket designed for wear over all other clothing for protection against the weather")),
        dict(x="style 260309B", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, OPENING] + comp((60, "cotton"), (40, "polyester"))),
        dict(x="style 260309C", code="6109.10.0070",
             facts=[UBG, US, KNIT, WOMEN, OPENING, SLEEVELESS, STRAPS, REAR] + comp((60, "cotton"), (40, "polyester"))),
    ]),
    dict(id="N359021", date="March 2026", subject="upper body garments from South Korea", styles=[
        dict(x="style 260220A", code="6106.10.0030",
             facts=[UBG, US, KNIT, WOMEN, NAPPED, LOOSE, COLLAR] + comp((60, "cotton"), (40, "polyester"))),
        dict(x="style 260220B", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE, OPENING, COLLAR] + comp((95, "cotton"), (5, "spandex"))),
    ]),
    dict(id="N356079", date="November 2025", subject="women's upper body garments from South Korea", styles=[
        dict(x="style 251117A", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE] + comp((58, "cotton"), (38, "polyester"), (4, "spandex"))),
        dict(x="style 251117B", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN] + comp((70, "cotton"), (30, "polyester"))),
        dict(x="style 251117C", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN, HIGH] + comp((70, "cotton"), (30, "polyester"))),
        dict(x="style 251117D", code="6106.20.2010",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, LOOSE] + comp((53, "polyester"), (40, "rayon"), (7, "spandex"))),
    ]),
    dict(id="N342989", date="September 2024", subject="women's knitted blouses", styles=[
        dict(x="style 251952923", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE] + comp((57, "cotton"), (38, "modal"), (5, "spandex"))),
        dict(x="style 251952924", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE] + comp((58, "cotton"), (38, "modal"), (4, "spandex"))),
    ]),
    dict(id="N342552", date="September 2024", subject="a women's blouse", styles=[
        dict(x="style CE309", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE, PLAIN] + comp((100, "cotton"))),
    ]),
    dict(id="N362518", date="May 2026", subject="a woman's singlet", styles=[
        dict(x="style 912222", code="6109.90.1065",
             facts=[UBG, US, KNIT, WOMEN, UNDER, SLEEVELESS, STRAPS] + comp((87, "polyamide"), (13, "elastane")),
             claims=claim("brassieres", "CBP", "ruling NY N362518",
                          "the paramount function of a brassiere is to support the breasts; this item offers minor support as a secondary function and functions as a singlet")),
    ]),
    dict(id="N362151", date="June 2026", subject="women's upper body garments from Vietnam", styles=[
        dict(x="style HEATTECH crew neck", note="style 04276F043A", code="6110.30.3059",
             facts=[UBG, US, KNIT, WOMEN] + comp((33, "polyester"), (31, "acrylic"), (21, "rayon"), (15, "spandex"))),
        dict(x="style CPJ HEATTECH crew neck", note="style 04275F059Q", code="6109.90.1090",
             facts=[UBG, US, KNIT, WOMEN, LIGHT, PLAIN] + comp((57, "acrylic"), (28, "rayon"), (9, "cashmere"), (6, "spandex"))),
        dict(x="style CPJ HEATTECH turtleneck", note="style 04275F060R", code="6110.30.3059",
             facts=[UBG, US, KNIT, WOMEN, PLAIN, HIGH] + comp((57, "acrylic"), (28, "rayon"), (9, "cashmere"), (6, "spandex"))),
        dict(x="style HEATTECH Ultra Warm crew neck", note="style 04275F026R", code="6110.30.3059",
             facts=[UBG, US, KNIT, WOMEN, NAPPED] + comp((35, "acrylic"), (34, "polyester"), (23, "rayon"), (8, "spandex"))),
    ]),
    dict(id="N361928", date="June 2026", subject="a women's tank top", styles=[
        dict(x="style 991177927", code="6109.90.1065",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS, REAR] + comp((64, "polyester"), (29, "viscose"), (7, "elastane"))),
    ]),
    dict(id="N360982", date="April 2026", subject="women's upper body garments", styles=[
        dict(x="style 260421F", code="6109.10.0060",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS, REAR] + comp((57, "cotton"), (39, "modal"), (4, "spandex"))),
        dict(x="style 260421G", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS] + comp((58, "cotton"), (38, "modal"), (4, "spandex"))),
        dict(x="style 260421H", code="6109.10.0060",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS, REAR] + comp((95, "cotton"), (5, "spandex"))),
        dict(x="style 260421I", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS, OPENING, RL] + comp((57, "cotton"), (39, "modal"), (4, "spandex"))),
        dict(x="style 260421J", code="6109.10.0060",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS, REAR] + comp((60, "cotton"), (40, "polyester"))),
    ]),
    dict(id="N356893", date="December 2025", subject="girls' tops from Vietnam", styles=[
        dict(x="style SS27GAA0015", code="6109.90.1070",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS] + comp((95, "polyester"), (5, "elastane")),
             judged=[(REAR, 'as stated in ruling NY N356893,\n        because "the garment has a scooped front and back neckline"')],
             claims=claim("brassieres", "CBP", "ruling NY N356893",
                          "the garments lack the structural features required for classification as a supportive garment and are designed and marketed as outer tank tops")),
        dict(x="style SS27GAA0016", code="6109.90.1070", characterised=True,
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS] + comp((89, "polyester"), (11, "elastane")),
             judged=[("X has a tank silhouette", 'according to CBP, as stated in ruling NY N356893,\n        because "the garment is designed and marketed as an outer tank top; the ruling does not describe its rear neckline"')],
             claims=claim("brassieres", "CBP", "ruling NY N356893",
                          "the garments lack the structural features required for classification as a supportive garment and are designed and marketed as outer tank tops")),
    ]),
    dict(id="N342660", date="2024", subject="a woman's upper body garment from Bangladesh", styles=[
        dict(x="style 473013S", code="6109.90.8030", characterised=True,
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS] + comp((84, "rayon"), (9.5, "polyester"), (6.5, "metalized yarn")),
             judged=[(METAL, 'according to the CBP laboratory, as stated in ruling NY N342660,\n        because "each yarn is four plies twisted together, one of them a metallic strip, so all of it is metalized yarn of heading 5605 (Section XI note 2(B)(a))"'),
                     ("X has a tank silhouette", 'according to CBP, as stated in ruling NY N342660,\n        because "CBP describes a tank-styled top; the ruling does not describe its rear neckline"')]),
    ]),
    dict(id="N361705", date="May 2026", subject="a men's upper body garment", styles=[
        dict(x="style D27", note="style D27-00003", code="6110.30.3053",
             facts=[UBG, US, KNIT, MEN, NAPPED, OPENING, COLLAR, POCKETS] + comp((100, "polyester"))),
    ]),
    dict(id="N348145", date="April 2025", subject="a women's sweater", styles=[
        dict(x="style 239318", code="6110.30.3020",
             facts=[UBG, US, KNIT, WOMEN] + comp((82.9, "nylon"), (17.1, "metalized yarn"))),
    ]),
    dict(id="N351060", date="July 2025", subject="a women's sweater", styles=[
        dict(x="style 261-SW421136", code="6110.90.9030",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS] + comp((58.91, "polyester"), (28.32, "cotton"), (8.54, "nylon"), (2.21, "metalized yarn"), (2.02, "rayon")),
             judged=[(METAL, 'according to the CBP laboratory, as stated in ruling NY N351060,\n        because "the garment is knitted from one six-ply yarn in which all plies are twisted together, including the metallic one: all of it is metalized yarn (Section XI note 2(B)(a))"')]),
    ]),
    dict(id="N361049", date="April 2026", subject="a women's upper body garment", styles=[
        dict(x="style WX6FA129RD", code="6110.20.2046",
             facts=[UBG, US, KNIT, WOMEN, NAPPED, OPENING, COLLAR, POCKETS, TIGHT] + comp((68, "cotton"), (32, "polyester"))),
    ]),
    dict(id="N360338", date="April 2026", subject="a women's upper body garment", styles=[
        dict(x="style A2726-4", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN, OPENING, COLLAR, POCKETS],
             judged=[(c, 'according to the importer, as stated in ruling NY N360338,\n        because "the fibre content of the garment as imported, not of the sample"') for c in comp((96, "cotton"), (4, "spandex"))],
             claims=claim("outerwear", "CBP", "ruling NY N360338",
                          "the sample lacks the character of an outerwear jacket designed for wear over all other clothing for protection against the weather")),
    ]),
    dict(id="N357689", date="January 2026", subject="a girl's upper body garment", styles=[
        dict(x="style 260108A", code="6110.20.2079",
             facts=[UBG, US, KNIT, WOMEN, NAPPED, COLLAR] + comp((55, "cotton"), (45, "polyester"))),
    ]),
    dict(id="N338772", date="March 2024", subject="men's shirts from Guatemala", styles=[
        dict(x="style 789023555314", code="6205.20.2051",
             facts=[UBG, US, WOVEN, MEN, COLLAR, OPENING, LR] + comp((100, "cotton"))),
        dict(x="style 710804257", code="6205.20.2067",
             facts=[UBG, US, WOVEN, MEN, COLLAR, OPENING, LR] + comp((100, "cotton"))),
    ]),
    dict(id="N337141", date="December 2023", subject="a men's dress shirt from Guatemala", styles=[
        dict(x="style PERT003", code="6205.20.2016",
             facts=[UBG, US, WOVEN, MEN, COLLAR, OPENING, LR] + comp((100, "cotton"))),
    ]),
    dict(id="N336500", date="November 2023", subject="a men's dress shirt from Guatemala", styles=[
        dict(x="style BE003", code="6205.20.2016",
             facts=[UBG, US, WOVEN, MEN, COLLAR, OPENING, LR] + comp((100, "cotton"))),
    ]),
    dict(id="N361742", date="May 2026", subject="a woman's blouse from Vietnam", styles=[
        dict(x="style 271-SW222435", code="6206.40.3035", model=None,
             note_disagree="the ruling calls the garment a blouse but records neither a loose fit (Note 4 to Chapter 62) nor an opening at the neckline, so no heading of the model describes it",
             facts=[UBG, US, WOMEN, "X is a composite good",
                    "the knitted back of X is a component of X", "the woven front of X is a component of X",
                    "the fabric construction of the knitted back of X is knitted",
                    "the fabric construction of the woven front of X is woven",
                    "the knitted back of X contains 57 percent of cotton",
                    "the knitted back of X contains 38 percent of modal",
                    "the knitted back of X contains 5 percent of spandex",
                    "the woven front of X contains 85 percent of modal",
                    "the woven front of X contains 15 percent of nylon"],
             judged=[("the essential character of X is given by the woven front of X",
                      'according to CBP, as stated in ruling NY N361742,\n        because "the woven fabric imparts the essential character of the garment"')]),
    ]),
    dict(id="N356781", date="December 2025", subject="girls' upper body garments from Vietnam", styles=[
        dict(x="style BG BEACON MH TOP gauze", note="style PID-E73R1G-C126", code="6206.30.3061", model=None,
             note_disagree="the ruling records elastic shirring and a peplum, non-functional buttons, and no loose fit: neither a shirt nor a blouse of Note 4 to Chapter 62",
             facts=[UBG, US, WOVEN, WOMEN] + comp((96, "cotton"), (4, "polyester"))),
        dict(x="style BG BEACON MH TOP", note="style PID-R6YM91-C126", code="6206.30.3061", model=None,
             note_disagree="as above: elastic shirring across the bodice, no opening, no loose fit recorded",
             facts=[UBG, US, WOVEN, WOMEN] + comp((80, "cotton"), (20, "polyester"))),
    ]),
    dict(id="N342011", date="August 2024", subject="women's blouses from India and Indonesia", styles=[
        dict(x="style Kwitney", note="style 014954", code="6206.30.3045",
             facts=[UBG, US, WOVEN, WOMEN, OPENING, COLLAR] + comp((100, "cotton")),
             claims=claim("swim cover-ups", "CBP", "ruling NY N342011",
                          "the styling, length and coverage allow the wearer to appear in public outside the beach or pool area: casual wear")),
        dict(x="style 1237", note="Natalie", code="6206.40.3035",
             facts=[UBG, US, WOVEN, WOMEN, OPENING, COLLAR] + comp((100, "rayon")),
             claims=claim("swim cover-ups", "CBP", "ruling NY N342011",
                          "the styling, length and coverage allow the wearer to appear in public outside the beach or pool area: casual wear")),
    ]),
]

# ---------------------------------------------------------------- EU BTIs
EBTI = [
    dict(id="FRBTIFR-BTI-2026-04256", office="French customs", date="22/07/2026", subject="men's high-visibility polo", styles=[
        dict(x="the high visibility polo", code="6105.10",
             facts=[UBG, EU, KNIT, MEN, COLLAR, OPENING, LR] + comp((55, "cotton"), (45, "polyester"))),
    ]),
    dict(id="DEBTI22950/25-1", office="Hauptzollamt Hannover", date="26/09/2025", subject="men's knitted shirt", styles=[
        dict(x="the napped knitted shirt", code="6105.20",
             facts=[UBG, EU, KNIT, LR, NAPPED, COLLAR, OPENING] + comp((100, "polyester"))),
    ]),
    dict(id="FRBTIFR-BTI-2026-01958", office="French customs", date="20/05/2026", subject="women's knitted shirt-blouse", styles=[
        dict(x="the printed cotton shirt-blouse", code="6106.10",
             facts=[UBG, EU, KNIT, WOMEN, OPENING, RL, COLLAR] + comp((100, "cotton"))),
    ]),
    dict(id="FRBTIFR-BTI-2025-07379", office="French customs", date="03/07/2026", subject="unisex children's knitted lace blouse", styles=[
        dict(x="the lace blouse", code="6106.20",
             facts=[UBG, EU, KNIT, OPENING] + comp((92, "polyamide"), (8, "elastane"))),
    ]),
    dict(id="DEBTI4593/26-1", office="Hauptzollamt Hannover", date="23/04/2026", subject="fashionable undershirt with feather trim", styles=[
        dict(x="the feather-trimmed undershirt", code="6109.10",
             facts=[UBG, EU, KNIT, LIGHT, UNDER] + comp((100, "cotton"))),
    ]),
    dict(id="DEBTI985/26-1", office="Hauptzollamt Hannover", date="12/03/2026", subject="T-shirt", styles=[
        dict(x="the long-sleeved T-shirt", code="6109.90",
             facts=[UBG, EU, KNIT, LIGHT] + comp((50, "polyester"), (50, "cotton"))),
    ]),
    dict(id="FRBTIFR-BTI-2025-06897", office="French customs", date="10/07/2026", subject="unisex hooded sweatshirt", styles=[
        dict(x="the hooded sweatshirt", code="6110.20",
             facts=[UBG, EU, KNIT, PLAIN, TIGHT] + comp((70, "cotton"), (30, "polyester"))),
    ]),
    dict(id="DEBTI22717/26-1", office="Hauptzollamt Hannover", date="28/07/2026", subject="lightweight under-pullover", styles=[
        dict(x="the mesh under-pullover", code="6110.30",
             facts=[UBG, EU, KNIT, LIGHT, HIGH, COLLAR] + comp((86, "polyester"), (14, "elastane"))),
    ]),
    dict(id="DEBTI17890/26-1", office="Hauptzollamt Hannover", date="14/07/2026", subject="shirt of a two-piece shirt and trousers set", styles=[
        dict(x="the embroidered cotton shirt", code="6205.20",
             facts=[UBG, EU, WOVEN, LR, COLLAR, OPENING] + comp((100, "cotton")),
             claims=claim("sleepwear", "Hauptzollamt Hannover", "BTI DEBTI17890/26-1",
                          "by cut, material and overall impression the garments can be worn in bed or elsewhere alike, so they are not intended to be worn exclusively or essentially as nightwear")),
    ]),
    dict(id="DEBTI9846/26-1", office="Hauptzollamt Hannover", date="05/06/2026", subject="women's woven blouse", styles=[
        dict(x="the sleeveless flounced blouse", code="6206.30", model=None,
             note_disagree="the office finds the garment 'presents itself as a blouse' (the CN Explanatory Note: light, fancy, mostly loose-fitting) but records no loose fit, and sleeveless it is no shirt",
             facts=[UBG, EU, WOVEN, WOMEN, SLEEVELESS, OPENING, LIGHT],
             judged=[("the textile material of X is cotton", 'according to Hauptzollamt Hannover, as stated in BTI DEBTI9846/26-1,\n        because "the yarns are of cotton, which predominates, and of textile yarn combined with metal (metalized yarn of heading 5605); the BTI gives no percentages"')]),
    ]),
    dict(id="FRBTIFR-BTI-2025-07180", office="French customs", date="28/07/2026", subject="women's satin blouse with thin straps", styles=[
        dict(x="the red satin strap blouse", code="6206.40", model=None,
             note_disagree="the office applies the CN Explanatory Note to heading 6206 (light fancy garments, mostly loose-fitting, at least with straps) but records no loose fit",
             facts=[UBG, EU, WOVEN, WOMEN, SLEEVELESS, STRAPS] + comp((80, "polyester"), (19, "viscose"), (1, "elastane"))),
    ]),
]


# ---------------------------------------------------------------- held-out CBP rulings
# Transcribed from the ruling text with the classification sentences removed,
# after the rules were frozen; "model" is filled in from the model's run.
HELDOUT = [
    dict(id="N355325", date="November 2025", subject="a women's upper body garment from South Korea", styles=[
        dict(x="style 251028A", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE, SLEEVELESS, STRAPS, OPENING] + comp((57, "cotton"), (39, "modal"), (4, "spandex")))]),
    dict(id="N355025", date="November 2025", subject="a women's knit blouse from India", styles=[
        dict(x="the terry blouse", note="style 014613", code="6106.10.0010",
             facts=[UBG, US, KNIT, WOMEN, LOOSE, TERRY] + comp((100, "cotton")))]),
    dict(id="N352158", date="September 2025", subject="a men's T-shirt from Haiti", styles=[
        dict(x="style PCTBD542025", code="6109.10.0012",
             facts=[UBG, US, KNIT, MEN, LIGHT, PLAIN] + comp((100, "cotton")))]),
    dict(id="N342008", date="August 2024", subject="a woman's reversible tank top from Taiwan", styles=[
        dict(x="the reversible tank top", note="style 018085", code="6109.90.1065",
             facts=[UBG, US, KNIT, WOMEN, SLEEVELESS, STRAPS, REAR] + comp((80, "nylon"), (20, "spandex")))]),
    dict(id="N348144", date="January 2026", subject="a women's knit sweater from Cambodia", styles=[
        dict(x="style 239752", code="6110.90.9026",
             facts=[UBG, US, KNIT, WOMEN] + comp((47.7, "cotton"), (31.3, "polyester"), (13.7, "nylon"), (6.6, "elastane"), (0.7, "metalized yarn")),
             judged=[(METAL, 'according to the CBP laboratory, as stated in ruling NY N348144,\n        because "the garment is knitted from a single eight-ply yarn with all plies, two of them metallic, twisted together"')])]),
    dict(id="N348143", date="January 2026", subject="a women's knit sweater from Cambodia", styles=[
        dict(x="style 239375", code="6110.90.9030",
             facts=[UBG, US, KNIT, WOMEN] + comp((73.3, "polyester"), (16.7, "wool"), (8.6, "metalized yarn"), (1.4, "elastane")),
             judged=[(METAL, 'according to the CBP laboratory, as stated in ruling NY N348143,\n        because "the garment is knitted from a single ten-ply yarn with all plies, three of them metallic, twisted together"')])]),
    dict(id="N355847", date="November 2025", subject="a men's shirt from Nicaragua", styles=[
        dict(x="style 334171", code="6205.20.2047",
             facts=[UBG, US, WOVEN, MEN, COLLAR, OPENING] + comp((100, "cotton")))]),
    dict(id="N336309", date="May 2024", subject="a men's shirt from Guatemala", styles=[
        dict(x="style PE001", code="6205.20.2051", model="6205.30",
             note_disagree="CBP classifies on the stated composition (98% cotton, 2% spandex) while its own laboratory, testing the fabric for the short-supply claim, reports 96% polyester and 4% spandex; the transcription takes the laboratory's finding",
             facts=[UBG, US, WOVEN, MEN, COLLAR, OPENING, LR],
             judged=[(c, 'according to the CBP laboratory, as stated in ruling NY N336309,\n        because "the laboratory found the fabric to be 96% polyester and 4% spandex, not the stated 98% cotton and 2% spandex"') for c in comp((96, "polyester"), (4, "spandex"))])]),
    dict(id="N350798", date="July 2025", subject="a woman's scrub top from El Salvador", styles=[
        dict(x="style AFMT04CAS", code="6206.40.3033", model=None,
             note_disagree="a pullover woven top with a V-neckline, no opening and no fit recorded: neither a shirt nor a blouse of Note 4 to Chapter 62 (the blouse gap of the in-sample rulings)",
             facts=[UBG, US, WOVEN, WOMEN] + comp((90, "polyester"), (10, "spandex")))]),
    dict(id="N343173", date="October 2024", subject="a woman's blouse from China", styles=[
        dict(x="the wrap blouse", note="style C-RAZY/A167200IKAP", code="6206.40.3035",
             facts=[UBG, US, WOVEN, WOMEN, COLLAR, OPENING] + comp((100, "viscose")))]),
]


import re
import quotes as Q

PATTERNS = {
    UBG: [r"is an? (m[ae]n|wom[ae]n|girl|boy)[’']?s?[’']?\s[^.;,]{0,40}(garment|shirt|blouse|top|singlet|sweater|pullover)",
          r'upper body garment', r'(blouse|shirt|tank top|singlet|sweater|pullover|T-shirt|sweatshirt|Hemd|Bluse|Vêtement|vêtement)'],
    US: ('text', [r'Harmonized\s+Tariff\s+Schedule\s+of\s+the\s+United\s+States']),
    EU: ('text', [r'Issuing country \w+']),
    KNIT: [r'\bknit', r'jersey', r'interlock', r'fleece', r'Gewirk', r'bonneterie', r'terry'],
    WOVEN: [r'woven', r'Geweb', r'tissu'],
    MEN: [r"is an? m[ae]n[’']s\s[^.;,]{0,40}", r"\bm[ae]n[’']s\b", r"\bboy", r"für Männer|Männerkleidung|pour homme"],
    WOMEN: [r"is an? (wom[ae]n|girl)[’']?s?[’']?\s[^.;,]{0,40}", r"\bwom[ae]n[’']s\b", r"\bgirl", r"Frauenkleidung|für Frauen|pour femme|Frauen"],
    LR: [r'left[- ]over[- ]right', r'links auf rechts', r'gauche sur droite'],
    RL: [r'right[- ]over[- ]left', r'rechts auf links', r'droite sur gauche'],
    SLEEVELESS: [r'sleeveless', r'ärmellos', r'sans manches', r'spaghetti straps', r'shoulder straps', r'straps', r'bretelles'],
    OPENING: [r'(full|partial)[^.;]{0,40}opening', r'front opening', r'opening', r'placket', r'Öffnung', r'ouverture'],
    POCKETS: [r'pockets?[^.;]{0,60}below the waist', r'below the waist[^.;]{0,30}pocket', r'kangaroo pocket', r'poche'],
    TIGHT: [r'provides tightening', r'tightening', r'drawstring', r'bords-côtes à la base', r'bords-côtes'],
    LOOSE: [r'loose[- ]fitting', r'ample'],
    COLLAR: [r'collar', r'Kragen', r'\bcol\b'],
    HIGH: [r'turtleneck', r'mock neck', r'high neckline', r'hohen Kragen'],
    NAPPED: [r'napped', r'brushed', r'gerauten', r'fleece'],
    TERRY: [r'terry'],
    LIGHT: [r'lightweight', r'leicht', r'légers?'],
    PLAIN: [r'jersey', r'interlock'],
    STRAPS: [r'spaghetti straps', r'shoulder straps', r'straps', r'bretelles'],
    REAR: [r'(rear|back) neckline[^.;]{0,60}nape', r'below the nape', r'front and back neckline'],
    UNDER: [r'undergarment', r'Unterhemd', r'unmittelbar auf der Haut'],
    METAL: [r'twisted together', r'metalized', r'metallic'],
}
CLAIM_PATTERNS = {
    'outerwear': ([r'bomber', r'heading 6101', r'anoraks', r'outerwear'],
                  [r'lacks the character of an outerwear jacket']),
    'sleepwear': ([r'as sleepwear', r'sleepwear', r'pajamas', r'Schlafanzug'],
                  [r'not classified as sleepwear', r'nothing about the styling', r'kein Schlafanzug', r'loungewear']),
    'brassieres': ([r'brassiere'], [r'paramount function', r'lack the structural features']),
    'swim cover-ups': ([r'swim cover-ups'], [r'casual wear']),
}
EXTRA_PATTERNS = {   # judged or attributed facts, by their first words
    'the essential character': [r'essential'],
    'the textile material': [r'Baumwolle'],
    'X has a tank silhouette': [r'outer tank tops', r'tank-styled top', r'tank'],
    'X has pockets below the waist': [r'portion of each of these pockets is below the waist', r'below the waist'],
}


def source_path(r, us):
    return ('cbp/%s.txt' % r['id']) if us else ('ebti/%s.txt' % r['id'].replace('/', '_').replace('-', '_'))


def anchor_of(s, us):
    if s.get('anchor'):
        return s['anchor']
    if not us:
        return 'Description of goods'
    for cand in (s.get('note'), s['x']):
        if cand and cand.startswith('style '):
            return cand[6:]
    return s['x']


def quote_for(f, x, text, seg):
    """The passage stating fact f (X = the style), or None."""
    if f in PATTERNS:
        spec = PATTERNS[f]
        if spec is None:
            return Q.first_clause(text, seg)
        if isinstance(spec, tuple):
            return Q.find(text, (0, len(text)), spec[1])
        return Q.find(text, seg, spec) or Q.first_clause(text, seg)
    m = re.match(r'X contains ([\d.]+) percent of (.+)$', f)
    if m:
        n = m.group(1)
        pats = [r'(?<![\d.])' + re.escape(n) + r'(?![\d])', r'(?<![\d.])' + re.escape(n.split('.')[0]) + r'(?![\d])']
        return Q.find(text, seg, pats, 70) or Q.find(text, (0, len(text)), pats, 70)
    m = re.match(r'X is claimed to belong to (.+)$', f)
    if m:
        return Q.find(text, (0, len(text)), CLAIM_PATTERNS[m.group(1)][0])
    m = re.match(r'the claim that X belongs to (.+) is rejected$', f)
    if m:
        return Q.find(text, (0, len(text)), CLAIM_PATTERNS[m.group(1)][1])
    for k, pats in EXTRA_PATTERNS.items():
        if f.startswith(k):
            return Q.find(text, seg, pats) or Q.find(text, (0, len(text)), pats)
    return Q.first_clause(text, seg)


def at(quote):
    return (' at "%s"' % quote) if quote else ''


def fact_line(f, x, doc, quote=None):
    return "    %s,\n        as stated in %s%s." % (f.replace("X", x), doc, at(quote)) if quote else \
           "    %s, as stated in %s." % (f.replace("X", x), doc)


def judged_line(f, trailers, x, quote=None):
    t = trailers.replace("X", x)
    if quote:
        t = re.sub(r'(as stated in [^,\n]+)', lambda m: m.group(1) + at(quote), t, count=1)
    return "    %s,\n        %s." % (f.replace("X", x), t)


def six(code):
    return code[:7]


BAD_QUOTES = []


def scenario(r, us):
    doc = ("ruling NY %s" % r["id"]) if us else ("BTI %s" % r["id"])
    name = ("ny_%s" % r["id"]).lower() if us else "bti_" + r["id"].lower().replace("/", "_").replace("-", "_")
    text = Q.load(source_path(r, us))
    anchors = [anchor_of(s, us) for s in r["styles"]]
    Q.MODE['lines'] = not us          # a BTI is one field per line
    out = []
    head = "%% %s %s (%s): %s." % ("NY" if us else "BTI", r["id"], r["date"], r["subject"])
    if not us:
        head = "%% BTI %s, %s, %s: %s." % (r["id"], r["office"], r["date"], r["subject"])
    out.append(head)
    expected = []
    for s in r["styles"]:
        x = s["x"]
        seg = Q.segment(text, anchor_of(s, us), anchors, stops=() if us else ('\nKeywords',))
        if s.get("note"):
            out.append("%% %s is %s." % (x, s["note"]))
        official = six(s["code"])
        model = s.get("model", official)
        if model is None:
            out.append("%% DISAGREES: %s gives %s; the model gives no heading — %s." % (
                "CBP" if us else r["office"], official, s["note_disagree"]))
        elif model != official:
            out.append("%% DISAGREES: %s gives %s; the model gives %s — %s." % (
                "CBP" if us else r["office"], official, model, s["note_disagree"]))
        elif s.get("characterised"):
            out.append("%% Agrees on the strength of a characterisation by the office (see the judged fact).")

        def q(f):
            qq = quote_for(f, x, text, seg)
            if qq and not Q.check(text, qq):
                BAD_QUOTES.append((r["id"], f, qq))
                qq = None
            return qq
        seen = set()
        for f in s["facts"]:
            if f in seen:
                continue
            seen.add(f)
            out.append(fact_line(f, x, doc, q(f)))
        for f, t in s.get("judged", []):
            out.append(judged_line(f, t, x, q(f)))
        for f, t in s.get("claims", []):
            out.append(fact_line(f, x, doc, q(f)) if t is None else judged_line(f, t, x, q(f)))
        if model is not None:
            expected.append('"the subheading of %s is %s"' % (x, model))
    out.append("    subheading expects answers [%s]." % ",\n        ".join(expected))
    unplaced = ['"%s is not placed by the model"' % s["x"] for s in r["styles"] if "model" in s and s["model"] is None]
    if unplaced:
        out.append("    unplaced expects answers [%s]." % ", ".join(unplaced))
    return "scenario %s is:\n" % name + "\n".join(out[1:]), out[0]


def document_facts(rulings, us):
    lines = []
    for r in rulings:
        doc = ("ruling NY %s" % r["id"]) if us else ("BTI %s" % r["id"])
        url = ("https://rulings.cbp.gov/ruling/%s" % r["id"]) if us else \
              "https://ec.europa.eu/taxation_customs/dds2/ebti/ebti_consultation.jsp?Lang=en"
        lines.append('%s is published at "%s".' % (doc, url))
        lines.append('the text of %s is at "sources/%s".' % (doc, source_path(r, us)))
    return "\n".join(lines) + "\n"


HEADER_CBP = """% Apparel rulings of U.S. Customs and Border Protection (CROSS, rulings.cbp.gov)
% run through the apparel model (apparel.le, which includes gri.le).
%
% One scenario per ruling; each style is described by the facts the ruling
% states, each fact citing the ruling ("as stated in ruling NY N362700"); the
% office's judgments carry who made them and why. The ruling's own code is NOT
% a fact: the expectation is the six-digit subheading the model derives, and
% where it differs from the ruling's the comment says so (DISAGREES) and why.
% Selection: the most recent rulings returned by CROSS for each of the
% subheadings 6105.10-20, 6106.10-20, 6109.10-90, 6110.20-90, 6205.20,
% 6206.30-40 (September 2026), keeping every style of each ruling. See
% README.md for the method and the results.

the target language is: prolog.
scenario facts require provenance.

the knowledge base apparel cbp includes these resources:
    apparel.

the knowledge base apparel cbp includes:

query subheading is:
    the subheading of which good is which code.

query heading is:
    the heading of which good is which heading.

query unplaced is:
    which good is not placed by the model.
"""

HEADER_EBTI = HEADER_CBP.replace(
    "% Apparel rulings of U.S. Customs and Border Protection (CROSS, rulings.cbp.gov)\n% run through the apparel model (apparel.le, which includes gri.le).",
    "% Binding Tariff Information of EU customs offices (EBTI,\n% https://ec.europa.eu/taxation_customs/dds2/ebti/) run through the SAME\n% apparel model (apparel.le, with gri.le) as the US rulings.").replace(
    '("as stated in ruling NY N362700")', '("as stated in BTI DEBTI22950/25-1")').replace(
    "% Selection: the most recent rulings returned by CROSS for each of the\n% subheadings 6105.10-20, 6106.10-20, 6109.10-90, 6110.20-90, 6205.20,\n% 6206.30-40 (September 2026), keeping every style of each ruling.",
    "% Selection: the most recent valid BTI (English, French or German) for each\n% of the same subheadings (September 2026). A BTI gives an eight-digit CN code\n% whose first six digits are the HS subheading compared here.").replace(
    "the knowledge base apparel cbp", "the knowledge base apparel ebti")


HEADER_HELDOUT = HEADER_CBP.replace(
    "% Apparel rulings of U.S. Customs and Border Protection (CROSS, rulings.cbp.gov)\n% run through the apparel model (apparel.le, which includes gri.le).",
    "% HELD-OUT apparel rulings of U.S. Customs and Border Protection, run through\n% the apparel model (apparel.le, which includes gri.le) after it was frozen.").replace(
    "% Selection: the most recent rulings returned by CROSS for each of the\n% subheadings 6105.10-20, 6106.10-20, 6109.10-90, 6110.20-90, 6205.20,\n% 6206.30-40 (September 2026), keeping every style of each ruling.",
    "% Selection: for each modelled heading, the two most recent rulings not used\n% to write the rules whose codes (other than Chapter 98/99) all fall in\n% modelled headings (none left for 6105; N341977, which cites a non-existent\n% 6109.00.0012, skipped). Facts were transcribed from the text with its\n% classification sentences removed.").replace(
    "the knowledge base apparel cbp", "the knowledge base heldout apparel cbp")

UNDECIDED = """% The request of NY N362700 before CBP answered it: the importer claims that
% style 1025AD is an outerwear jacket of heading 6101, and nobody has decided.
% The model's answer is conditional on that judgment — the judgment needed is
% the unknown.
scenario request_n362700 is:
    style 1025AD is an upper body garment, as stated in the request of NY N362700.
    style 1025AD is classified under the US tariff, as stated in the request of NY N362700.
    the fabric construction of style 1025AD is knitted, as stated in the request of NY N362700.
    the cut of style 1025AD indicates men, as stated in the request of NY N362700.
    style 1025AD has an opening starting at the neckline, as stated in the request of NY N362700.
    style 1025AD has a collar, as stated in the request of NY N362700.
    style 1025AD contains 92 percent of polyester, as stated in the request of NY N362700.
    style 1025AD contains 8 percent of spandex, as stated in the request of NY N362700.
    style 1025AD is claimed to belong to outerwear, according to the importer, as stated in the request of NY N362700.
    subheading expects answers ["the subheading of style 1025AD is 6105.20"]
        and unknowns ["the claim that style 1025AD belongs to outerwear is rejected"].
"""


def with_documents(header, rulings, us):
    marker = "includes:\n"
    i = header.rindex(marker) + len(marker)
    return header[:i] + "\n% Where each cited ruling is published, and a copy of its text (sources/).\n" + \
        document_facts(rulings, us) + header[i:]


def main():
    for rulings, us, path, header in ((CBP, True, "apparel_cbp.le", HEADER_CBP), (EBTI, False, "apparel_ebti.le", HEADER_EBTI)):
        parts = [with_documents(header, rulings, us)]
        for r in rulings:
            sc, comment = scenario(r, us)
            parts.append(comment + "\n" + sc + "\n")
            if us and r["id"] == "N362700":
                parts.append(UNDECIDED)
        open(OUT + "/" + path, "w").write("\n".join(parts))
    parts = [with_documents(HEADER_HELDOUT, HELDOUT, True)]
    for r in HELDOUT:
        sc, comment = scenario(r, True)
        parts.append(comment + "\n" + sc + "\n")
    open(OUT + "/heldout_apparel_cbp.le", "w").write("\n".join(parts))
    for b in BAD_QUOTES:
        print("QUOTE NOT IN TEXT:", b)


main()
