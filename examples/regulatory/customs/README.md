# Customs classification in Logical English: Chapters 39, 61 and 62

The tariff code of a good, worked out as a customs office works it out. The
programs encode the General Rules of Interpretation and three whole chapters
of the Harmonized Tariff Schedule of the United States (HTSUS): 39 (plastics),
61 and 62 (clothing). They run on 225 published rulings of US Customs and
Border Protection (CBP) and 15 European Binding Tariff Information (EBTI)
decisions, and compare the model's code with the office's.

## Start here

- [cbp_62.le, the worksheet](cbp_62.le?view=worksheet&scenario=ny_n346508) — a classification worksheet for silk scarves: the facts as the ruling states them, the code and the steps that reach it.
- [apparel_cbp.le](apparel_cbp.le?scenario=ny_n362700&query=subheading) — men's knitted tops from one ruling, each placed by what the ruling observes (fabric, cut, pockets), with CBP's own judgments marked as such.
- [plastics_cbp.le](plastics_cbp.le?scenario=ny_n363253&query=household) — a flip: which judgment would have moved a bowl clamp to another heading.
- [tariff.le](tariff.le) — the whole modelled tariff, which every scenario program includes.

## Try this

1. Open [cbp_62.le on the silk scarves](cbp_62.le?scenario=ny_n346508&query=subheading) and press **Query**. The answer is subheading 6214.10 (scarves of silk), the code CBP gave.
2. Click the answer. The explanation on the right shows each step, down to the line of the tariff that names the code.
3. Click the **§** badge of a step. The cited text opens with the quoted passage highlighted: the tariff for a rule, the ruling for a fact.
4. Open [the same ruling in the worksheet view](cbp_62.le?view=worksheet&scenario=ny_n346508). It is the screen a customs specialist asked for: facts grouped by article, fabric and composition, then the code, then a draft paragraph of the ruling.
5. Open [plastics_cbp.le on the bowl clamp](plastics_cbp.le?scenario=ny_n363253&query=household) and press **Query**. CBP put the clamp in 3926. The answer is the one change that would have put it in heading 3924: judging its principal use to be household use.
6. In [by_hand.le](by_hand.le), use **Scenario Editor → Add → Write it in English…** to draft the facts of a ruling from its text, then check each drafted fact against its passage.

## More

- [Details](DETAILS.md): the files, how the model reads a good, the method, the results (203 of 229 goods across 125 new CBP rulings get CBP's code), and its limits.
- The official texts: the [HTSUS](https://hts.usitc.gov/), CBP's rulings in [CROSS](https://rulings.cbp.gov/), and the EU's [EBTI database](https://ec.europa.eu/taxation_customs/dds2/ebti/).
- The manual: [the executive view](/docs/user/guide/executive-view) and [LE Views](/docs/user/tutorials/views).

## Disclaimer

**These programs are examples of Logical English, provided "as is", without
warranty of any kind**, express or implied, including any warranty that they
are accurate, complete, up to date or fit for a particular purpose. They are
not an official reading of the tariff or of the rulings they cite. They are
not a binding classification ruling, and they are not legal or customs
advice. Their answers may be wrong: do not rely on them for a real import,
export or customs declaration. Consult the official texts, the customs
authority and a qualified professional. Their authors accept no liability
for any loss or damage arising from their use. Every program of this
directory repeats this notice in its opening comment.
