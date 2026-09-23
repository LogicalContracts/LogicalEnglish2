# Kowalski's book: Computational Logic and Human Thinking, in Logical English

Twenty-two short programs, one for each example of Robert Kowalski's book
*Computational Logic and Human Thinking* (Cambridge University Press, 2011)
that Logical English can already state. The book's chapters on time and
agents are programs of LPS2 (Logic Production Systems), not here. Each
program's opening comment names its chapter and section.

## Start here

- [The fox and the crow](fox_and_crow.le?scenario=story&query=possession) — chapter 3: goals and beliefs.
- [The party, with negation as failure](party_naf.le?scenario=no_bob&query=who_goes) — chapter 5: adding a fact removes a conclusion.
- [British citizenship, subsection 1.1](bna_citizenship_1_1.le?scenario=mother_citizen&query=acquisition) — chapter 6: a law as rules.
- [Why is the grass wet?](grass_wet_abduction.le?scenario=observed&query=observe) — chapter 10: explanations by assumption.

## Try this

1. Open [the fox and the crow](fox_and_crow.le?scenario=story&query=possession) and click **Query**. The answers are "crow has cheese" and "fox has cheese".
2. Click the answer "fox has cheese" to see its explanation. The fox is near the cheese because the crow holds it and sings. The crow sings because the fox praises it. The fox then picks the cheese up.
3. Open [the party](party_naf.le?scenario=no_bob&query=who_goes) and click **Query**: john and mary will go, because nothing says that bob will go.
4. Choose the scenario **bob_goes**, which adds the fact "bob will go", and click **Query** again. Now only bob goes: one more fact, fewer conclusions.
5. Open [the grass](grass_wet_abduction.le?scenario=observed&query=observe) and click **Query**. The two answers each come with an *unknown*, shown in amber: "it rained" or "the sprinkler was on".

## More

- [Details](DETAILS.md) — which chapter and section each program comes from.
- [The editor's manual](/docs/user/guide/editor) — scenarios, queries and explanations.
- [The language reference](/docs/user/reference/language) — negation (§4) and unknowns (§3.3).
- [The book, as a draft PDF on the author's site](https://www.doc.ic.ac.uk/~rak/papers/newbook.pdf).
