# Medicare DMEPOS coverage in Logical English

When Medicare pays for durable medical equipment, prosthetics, orthotics and
supplies (DMEPOS). The programs encode the coverage criteria of all 58 Local
Coverage Determinations (LCDs) of the four regional Medicare contractors for
that equipment, one per policy on a shared library (`dmepos.le`). They decide
test claims, and they are compared with 36 decisions of the Medicare Appeals
Council, the last level of appeal inside Medicare.

## Start here

- [pmd_cases.le, the coverage desk](pmd_cases.le?view=coverage%20desk&scenario=group_2_complete) — a power wheelchair claim, criterion by criterion, as a reviewer's screen.
- [pmd.le](pmd.le) — the power mobility policy (LCD L33789) itself: every rule quotes its passage.
- [council_pmd.le](council_pmd.le?scenario=11-332&query=rn) — a real appeal, decided by the model and compared with the Council's decision.
- [dmepos.le](dmepos.le) — the library every policy includes: claims, orders, the face-to-face encounter, delivery.

## Try this

1. Open [pmd_cases.le on a complete claim](pmd_cases.le?scenario=group_2_complete&query=pay) and press **Query**. The answer is *claim 1 is payable*.
2. Click the answer. The explanation walks through the criteria of the LCD; the **§** badge of a step opens the LCD at the passage it quotes.
3. Choose the scenario **late_delivery** and run **pay** again. There is no answer: the wheelchair was delivered seven months after the prior authorization. The explanation of a query with no answer shows the condition that failed.
4. Run the query **stage** on the same scenario. The answer, *the query fails at remedy*, says where the claim fails: the device is reasonable and necessary (query **rn** says so), but it cannot be paid.
5. Open [the coverage desk on the late delivery](pmd_cases.le?view=coverage%20desk&scenario=late_delivery). It shows the same decision as a reviewer's screen, with the documents of the claim and, under **Why not**, the condition the claim did not meet.
6. Open [Council decision 11-332](council_pmd.le?scenario=11-332&query=rn) and press **Query**. The model finds the device reasonable and necessary, on condition of a home assessment the record does not establish. The comment above the scenario says what the Council decided and where the two differ.

## More

- [Details](DETAILS.md): the files, how a claim is read, the model, the Council decisions, what the work taught and its known limits.
- [The authoring guide](GUIDE.md): how a policy program of this folder is written.
- The official texts: the [Medicare Coverage Database](https://www.cms.gov/medicare-coverage-database/), for instance [LCD L33789](https://www.cms.gov/medicare-coverage-database/view/lcd.aspx?lcdid=33789), and the [Medicare Appeals Council decisions](https://www.hhs.gov/about/agencies/dab/decisions/council-decisions/index.html).
- The manual: [the executive view](/docs/user/guide/executive-view) and [LE Views](/docs/user/tutorials/views).

## Disclaimer

**These programs are examples of Logical English, provided "as is", without
warranty of any kind**, express or implied, including any warranty that they
are accurate, complete, up to date or fit for a particular purpose. They are
not an official reading of the Medicare texts they cite. They are not a
coverage or payment decision of the Centers for Medicare & Medicaid Services
(CMS) or of any Medicare contractor, and they are not medical, legal, billing
or insurance advice. Their answers may be wrong: do not rely on them for a
real claim, prescription or treatment. Consult the official texts, the
Medicare contractor and a qualified professional. Their authors accept no
liability for any loss or damage arising from their use. Every program of
this directory repeats this notice in its opening comment.
