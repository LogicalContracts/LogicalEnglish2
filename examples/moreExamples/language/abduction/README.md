# Abduction in Logical English

Programs that explain an observation by what it assumes. A template declared
`; assumable` (or `; unknown`) may be assumed when the reasoner proves a goal.
Each answer then comes with the assumptions it needs: "the grass is wet, if it
rained". Two programs come from the slides of Kowalski and Calejo, *Teaching
Logical Thinking through Logic Programming using Logical English,
Argumentation Games and Animation* (PEG, Lisbon, 2026); two are our own.

## Start here

- [Why is the grass wet?](grass_is_wet.le?scenario=observation&query=explain) — two explanations of one observation (slide 24).
- [Sunglasses](sunglasses.le?scenario=planning&query=plan) — a plan: an action assumed to reach a goal (slide 25).
- [Diagnosis](diagnosis.le?scenario=checkup&query=diagnose) — several diseases that could explain fever and a rash.
- [Loan approval](loan_approval.le?scenario=application&query=approval) — several sets of assumptions for one decision.

## Try this

1. Open [the grass](grass_is_wet.le?scenario=observation&query=explain) and click **Query**. There are two answers, each with an *unknown*, shown in amber: "it rained", or "the sprinkler was on".
2. Open [the diagnosis](diagnosis.le?scenario=checkup&query=diagnose) and click **Query**. Four explanations of bob's fever and rash come back, each with the diseases it assumes, measles among them.
3. Choose the scenario **vaccinated**, which adds "bob is vaccinated against measles", and click **Query** again. One explanation is left: flu and a food allergy.

## More

- [Details](DETAILS.md) — integrity constraints, and the guards these programs use instead.
- [The language reference](/docs/user/reference/language) — unknowns and integrity constraints, §3.3.
- [The editor's manual](/docs/user/guide/editor) — reading an explanation, and its colours.
