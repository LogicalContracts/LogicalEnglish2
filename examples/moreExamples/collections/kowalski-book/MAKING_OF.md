# How the examples in this folder were made

These twenty-two programs were drafted by AI agents from the examples of
Robert Kowalski's book *Computational Logic and Human Thinking* (Cambridge
University Press, 2011). The agents worked from a shared brief. Kowalski
wrote the examples in the book, in English and in logic. The agents wrote the
Logical English programs, their scenarios and their expected answers.

| File | Made by | How |
|---|---|---|
| every `*.le` | AI agents, 2026-06-12, at Miguel Calejo's request | Each program restates one example of the book, and its opening comment names the chapter and section. The agents followed the brief `docs/project/research/rk-book/vibingExamples/.AGENT_BRIEF.md`. They checked each program with the scripts beside it (`.le_check.pl` and `.le_query.pl`). The examples to draft were chosen in `docs/project/research/rk-book/bookExamples.md`. The record does not name the AI model. |
| `README.md`, `DETAILS.md` | First written with the programs; rewritten by AI agents (Claude, in Claude Code) in four later commits | Say which example of the book each program renders. |

Later agent edits to the programs were small, such as renamed folders and fixes of a few lines.

## The record
- commit `9c747e0` (2026-06-12) "First stab at Bob's book examples": all the programs, with the agents' brief and checking scripts.
- The book itself: [draft PDF on the author's site](https://www.doc.ic.ac.uk/~rak/papers/newbook.pdf).
- The book's chapters on time and agents are programs of LPS2 (Logic Production Systems), in its own `examples/collections/kowalski-book/`.
