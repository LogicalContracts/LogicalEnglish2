# Homeowners underwriting in Logical English

Underwriting is an insurer's decision to take a risk or not. An insurer's
*underwriting guidelines* say which risks it will not write (they are
*ineligible*) and which an underwriter, a person, must look at first (they
must be *referred to underwriting*). The programs of this folder turn such
guidelines into rules: each rule is one guideline, and quotes it. A
*proposal* (one application for insurance) is a *scenario*: the facts of the
house and the applicant, each with who states it. The decision is a *query*.

The folder holds two modern guides, from published copies, and a
reconstruction of the rules of the first American fire insurer, the
Philadelphia Contributionship (founded in 1752), tried on its own surveys.

## Start here

- [arkansas_cases.le, the underwriting desk](arkansas_cases.le?view=underwriting%20desk&scenario=knob_and_tube) — one proposal as an underwriter's screen: the facts, the decision, the guideline it rests on, the filed text, a draft letter.
- [arkansas.le](arkansas.le) — the Arkansas homeowners guidelines of Auto Club Family Insurance Company (an AAA insurer), Rule 05.2 of 2021: 40 numbered items, each a rule quoting its item.
- [california.le](california.le) — the California homeowners guide of National General (2020), with its wildfire ("brush") grid as a decision table.
- [homeowners.le](homeowners.le) — the library both include: the words of a proposal, the three outcomes, the decision.
- [contributionship.le](contributionship.le) — the Philadelphia Contributionship's rules of 1752 to 1810, each dated, applied to surveys of the time.

## Try this

1. Open [arkansas_cases.le on the proposal two_reasons](arkansas_cases.le?scenario=two_reasons&query=decision) and press **Query**. The answer is *the decision on application 101 is decline*.
2. Choose the query **ineligible** and press **Query** again. There are two answers: item 34 (knob and tube wiring) and item 18 (a trampoline). Click one: the explanation shows each step, and who stated each fact.
3. Choose the scenario **dog_open**, query **ineligible**. The answer carries a question mark: the proposal is ineligible *only if* an underwriter finds that the dog is of a dangerous nature. The explanation marks that finding *judgment needed*.
4. Choose **missing_roof** and the query **referred**. The application does not say what the roof is made of, so it goes to an underwriter for *missing information* instead of being accepted by default.
5. Choose **knob_and_tube** and the query **flip**. The answer is the smallest change that would make the proposal eligible: remove the wiring.
6. **Misc ▸ Run the Program's Tests…** runs every expected answer of the 34 proposals.
7. Open [california_cases.le on brush_gap](california_cases.le?scenario=brush_gap&query=referred). The guide's wildfire grid has no row for a FireLine score of 3 with a WillisRe score of exactly 1.00; the proposal is referred.
8. Open [contributionship_surveys.le on the sample](contributionship_surveys.le?scenario=sample&query=conflicts): 150 real surveys of 1752 to 1810. The query **conflicts** lists pairs of the Board's rates that the features the surveys record cannot both justify; City Tavern paid 30 shillings per 100 pounds in 1773 and 47 shillings 6 pence in 1785, on the same walls.

## More

- [Details](DETAILS.md): the sources, how a guideline is written, what could and could not be encoded, the test results, the historical part and its coherence test, and the side-by-side of 1752 and today.
- The plan this implements: `docs/strategy/UnderwritingExperiments.md` of the lpsPlus repository.
- The manual: [the language reference, §17](/docs/user/reference/language), [LE Views](/docs/user/tutorials/views).

## Disclaimer

**These programs are examples of Logical English, provided "as is", without
warranty of any kind**, express or implied, including any warranty that they
are accurate, complete, up to date or fit for a particular purpose. They are
not an official reading of the underwriting guidelines or of the historical
records they cite. They are not an underwriting decision of any insurer, and
they are not legal or insurance advice. Their answers may be wrong: do not
rely on them for a real application. Consult the insurer and a licensed
agent. Their authors accept no liability for any loss or damage arising from
their use. Every program of this directory repeats this notice in its
opening comment.
