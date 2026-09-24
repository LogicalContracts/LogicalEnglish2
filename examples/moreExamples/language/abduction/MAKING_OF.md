# How the examples in this folder were made

Two programs restate slides by Kowalski and Calejo, and two were made up to
go further. Three were committed before commits marked agent work, so the
record does not say who typed them. The fourth, `loan_approval.le`, was
written by an AI agent.

| File | Made by | How |
|---|---|---|
| `grass_is_wet.le`, `sunglasses.le` | Committed by Miguel Calejo, 2026-07-13; the record does not say whether a person or an agent wrote them | Restate slides 24 and 25 of Kowalski and Calejo, *Teaching Logical Thinking through Logic Programming using Logical English, Argumentation Games and Animation* (PEG, Lisbon, 2026). Their opening "Origin:" comments follow the pattern of the agent-drafted programs of `collections/kowalski-book/`. |
| `diagnosis.le` | Committed by Miguel Calejo, 2026-07-13; the record does not say whether a person or an agent wrote it | Made up, combining the ideas of slides 24 to 28. |
| `loan_approval.le` | AI agent (Claude, in Claude Code), 2026-07-21, at Miguel Calejo's request | Made up, as a richer example for the s(CASP) reasoner. |
| `README.md`, `DETAILS.md` | AI agent (Claude, in Claude Code) | The README was first committed on 2026-07-13, and agents rewrote it later. `DETAILS.md` was added on 2026-09-23. |

## The record
- commit `2c3da84` (2026-07-13) "add abduction examples, focus on example sub dir": the first three programs.
- commit `c54363f` (2026-07-21) "s(CASP)", authored "Miguel Calejo (via Claude)": `loan_approval.le`.
