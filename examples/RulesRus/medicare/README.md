# Medicare DMEPOS coverage in Logical English

Step 4 of the plan in RulesRUs §8 (§2.1 of that report): the coverage
criteria of the DME MAC policies — Local Coverage Determinations, their Policy
Articles and the National Coverage Determinations they rest on — as Logical
English, run on claims and on the published appeal decisions. Work in
progress (September 2026); this README grows with the model.

| File | What it is |
|---|---|
| `dmepos.le` | The library every policy includes: the claim and the item, the benefit category and the home, the standard written order, the written order prior to delivery and the face-to-face encounter (42 CFR 410.38, article A55426, the CMS Required Lists), proof of delivery, prior authorization, continued need and use, refills. Sections `applicability` and `remedy`; the policies supply `question`. |
| `pap.le` | Positive airway pressure devices for obstructive sleep apnea (LCD L33718, Policy Article A52467, NCD 240.4): initial criteria A–D, continued coverage after the third month, accessories and their usual maximum quantities. |
| `pap_cases.le` | Synthetic claims, one or two per criterion and per audit error category. |
| `sources/` | The cited texts: `lcd/`, `article/`, `ncd/` from the Medicare Coverage Database export (12 September 2026); `cfr/` the regulations and the CMS Required Lists; `manuals/` PIM chapter 5 and BPM chapter 15; `council/` the Medicare Appeals Council's published DME and supplier decisions. |

Run a program's tests the usual way:

```
./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/RulesRus/medicare/pap_cases.le', R), print_test_result(R), halt."
```

Queries: `pay` (which claim is payable), `rn` (which claim is reasonable and
necessary — the question the appeal record decides), `stage` (at which
section a claim fails: applicability, question, remedy), `flip` (the minimal
change that would make a claim payable).
