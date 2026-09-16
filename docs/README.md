# LogicalEnglish2 documentation

| Folder | What | Published |
|---|---|---|
| [`user/`](user/) | the user documentation: tutorials, guides, references, the API. [`user/nav.json`](user/nav.json) is its table of contents, from which the editor's Help menu, the landing page and the documentation viewer are built | yes, at `/docs/user/…` |
| [`dev/`](dev/) | how the system is built: architecture, the assistants, migration, the debugger, the graph, telemetry | no |
| [`project/`](project/) | plans, papers, research material, and an archive of superseded documents | no |

Every document says under its title what kind of document it is, for whom,
and whether it is current. A plan that has been implemented says where its
result is documented.

**User documentation** (`user/`)

- Tutorials: [Introduction to Logical English](user/tutorials/intro-to-le/intro-to-le.md), [LE Views](user/tutorials/views.md)
- Guides: [the editor](user/guide/editor.md), [the Proof Game](user/guide/proof-game.md), [the verifier's warnings](user/guide/warnings.md)
- Reference: [the language](user/reference/language.md) (and [em português](user/reference/language.pt.md)), [s(CASP)](user/reference/scasp.md), Logical English for LPS (in LPS2: `docs/user/reference/le-for-lps.md`)
- API: [the web API](user/api/web-api.md)

**Developer documentation** (`dev/`): [architecture](dev/architecture.md), [the assistant](dev/assistant.md) and [its light mode](dev/assistant-light.md), [migration](dev/migration.md), [debugger](dev/debugger.md), [graph](dev/graph.md), [telemetry](dev/telemetry.md), [i18n](../i18n/README.md), the LE2↔LPS2 interface (in LPS2: `docs/dev/le-lps-interface.md`).

**Project documents** (`project/`): [plans](project/plans/), [papers](project/papers/), [research](project/research/), [archive](project/archive/).

The LLM features read documents by path — the language reference in
particular (`le_assistant_light.pl`, `le_contract_assistant.pl`,
`AGENTS_LE_template*.md`, `llm/mcp.pl`): move one only together with them.
`vibeCodingNotes.md` is private notes, not served and not in the image.
