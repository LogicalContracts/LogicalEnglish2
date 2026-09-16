# Logical Thinking in the Age of AI: examples

Working Logical English programs for slides 5 to 8 of the draft presentation
*Logical Thinking in the Age of AI: A Core Competency for Society*. Slide 4
already points to `citizenship` and slide 9 to `cgt_assets`. Every program
here passes its embedded tests (`expects answers ...`), and they run in the
core `runTests` suite, which scans this directory.

| Slide | Program | What it shows |
|---|---|---|
| 5, Medical: *Decision making: which treatment is correct according to this guideline?* | `heart_failure.le` | The three guideline sentences on the slide, plus the few rules they rely on (ACE inhibitors, beta blockers, aldosterone antagonists, sodium restriction, HFrEF). Query `treatments` gives the guideline's recommendations for a patient: one treatment plan, all of them to be given. Queries `alternatives` and `additions` say how they relate: ARBs replace ACE inhibitors for a patient who cannot tolerate them (sentence 1), diuretics are added to ACE inhibitors, beta blockers and aldosterone antagonists (sentence 2). Query `conflicts` checks that no patient is recommended both a treatment and its alternative. Query `withheld` gives the treatments that are indicated but not recommended, and the explanation says why. |
| 6, Medical: *Problem solving: a precise description of a solution* | `heart_failure.le`, scenario `paper_patient` | The patient of the paper (Fig. 2). The explanation of "the guideline recommends ACE inhibitors with class 1 for Ann" is the English counterpart of the answer set on the slide (the paper's Fig. 3): stage C, HFrEF, no contraindication, no history of angioedema, not pregnant. |
| 6 (continued) | `heart_failure_what_if.le` | The paper's abductive query (Fig. 1): "an African American patient with NYHA class III HFrEF, but that is all we know". The answer is conditional: the combination of hydralazine and isosorbide dinitrate is recommended *if* the patient has received standard neurohormonal antagonist therapy. That condition is reported as an unknown, i.e. what is still to be checked. |
| 7, Ethical: *Construction and defense of arguments: what is the reasoning behind this?* | `provocation_transposed.le` | The rapist argument, written as rules. Writing it out exposes the unstated premise that does the work: "the victim shares the responsibility for the crime". No rule mentions rape, so the argument transposes by itself. In scenario `both_cases`, the same rules grant leniency to the murderer, and the two explanations are the same tree apart from the three words the slide changes. |
| 8, Ethical: *Verification of consistency/validity: is there a standard for judgment?* | `standard_for_judgment.le` | Three candidate standards, tested against (1) a settled judgment (no leniency for the transposed murder case) and (2) treating like cases alike. The slide's general principle contradicts the settled judgment. The rape-only version avoids that contradiction but is a double standard. Only "leniency only when the victim's conduct involved actual aggression" passes both tests. |

## Links for the slides

The same form as the slides' existing links. They work once these files are on the
server; replace the host to use a local editor.

- Slide 5: `https://le2.logicalcontracts.com/editor/index.html?example=LogicalThinkingInAgeOfAI/heart_failure&scenario=ace_intolerant_and_pregnant&query=withheld`
  (or `scenario=paper_patient&query=treatments`)
- Slide 6: `https://le2.logicalcontracts.com/editor/index.html?example=LogicalThinkingInAgeOfAI/heart_failure&scenario=paper_patient&query=treatments&answer=1`
  and `https://le2.logicalcontracts.com/editor/index.html?example=LogicalThinkingInAgeOfAI/heart_failure_what_if&scenario=what_we_know&query=combination&answer=1`
- Slide 7: `https://le2.logicalcontracts.com/editor/index.html?example=LogicalThinkingInAgeOfAI/provocation_transposed&scenario=both_cases&query=leniency`
- Slide 8: `https://le2.logicalcontracts.com/editor/index.html?example=LogicalThinkingInAgeOfAI/standard_for_judgment&scenario=three_cases&query=acceptable&answer=1`
  (also `query=contradictions`, `query=double_standards`)

## Excerpts that fit on a slide

Slide 5, the paper's "knowledge patterns", each as one rule:

```
the guideline recommends a treatment with a class for a patient
    if the patient has an indication for the treatment with the class
    and it is not the case that
        the patient has a contraindication to the treatment
    and it is not the case that
        the treatment should not be prescribed without a second treatment for the patient
        and the patient has a contraindication to the second treatment.

a patient has an indication for a second treatment with a class
    if the alternative to a first treatment is the second treatment
    and the patient has an indication for the first treatment with the class
    and the patient is intolerant to the first treatment.

a patient should receive a second treatment with a class instead of a first treatment
    if the alternative to the first treatment is the second treatment
    and the guideline recommends the second treatment with the class for the patient.

a patient should receive a second treatment with a class in addition to a first treatment
    if the first treatment should generally be combined with the second treatment
    and the guideline recommends the first treatment with the class for the patient
    and it is not the case that
        the patient has a contraindication to the second treatment.

beta blockers should not be prescribed without diuretics for a patient
    if the patient has a current or recent history of fluid retention.
```

Slide 6, the explanation (compare with the answer set on the slide):

```
the guideline recommends ACE inhibitors with class 1 for Ann
  Ann has an indication for ACE inhibitors with class 1
    Ann has heart failure with reduced ejection fraction
      Ann has current or prior symptoms of heart failure
        Ann is in stage C
      the ejection fraction of Ann is 35
      35 is less than or equal to 40
  it is not the case that Ann has a contraindication to ACE inhibitors
    (Ann is not intolerant to them, has no history of angioedema, is not pregnant)
```

Slide 7, the reasoning behind the argument:

```
leniency is in order towards a person for a crime
    if the person is less to blame for the crime.

a person is less to blame for a crime
    if the person committed the crime against a victim
    and the victim shares the responsibility for the crime.

a victim shares the responsibility for a crime
    if a person committed the crime against the victim
    and the person felt provoked into the crime by an attitude of the victim
    and the attitude is devoid of actual aggression.
```

Slide 8, the standard and the tests:

```
the provocation standard grants leniency towards a person for a crime
    if the person committed the crime against a victim
    and the person felt provoked into the crime by an attitude of the victim
    and the attitude is devoid of actual aggression.

a standard is acceptable
    if the standard is a standard
    and it is not the case that
        the standard contradicts settled judgment on a person
    and it is not the case that
        the standard treats like cases differently.
```

## Notes

- The medical programs follow Chen, Marple, Salazar, Gupta and Tamil, *A
  Physician Advisory System for Chronic Heart Failure Management Based on
  Knowledge Patterns* (TPLP 2016, <https://arxiv.org/pdf/1610.08115>), and
  quote the 2013 ACCF/AHA guideline sentences they use. The paper's s(ASP)
  code needs stable models for its concomitant and indispensable choice
  patterns (negation through cycles). The LE rules express the same patterns
  without cycles, so the default Prolog engine answers them. The medical content is limited to
  those sentences and is illustrative, not clinical advice.
- The ethical programs model an argument, not the law. The comment on the
  aggression standard mentions the loss-of-control defence of the Coroners
  and Justice Act 2009 (s. 55) only as an example of a real standard of that kind.
- Re-verify from the repository root:
  `./myswipl.sh -g "use_module(le_kbs), runTestsFor('examples/moreExamples/collections/logical-thinking-talk/<FILE>.le', R), print_test_result(R), halt."`
