# LogicalEnglish2 documentation

| Folder | What | Published |
|---|---|---|
| [`user/`](user/) | the user documentation: tutorials, guides, references, the API. [`user/nav.json`](user/nav.json) is its table of contents, from which the editor's Help menu, the landing page and the documentation viewer are built | yes, at `/docs/user/…` |
| [`dev/`](dev/) | how the system is built: architecture, the assistants, migration, the debugger, the graph, telemetry | no |
| [`project/`](project/) | plans, papers, research material, and an archive of superseded documents | no |

The viewer's shared script, `web_extras/docsview/docs-extras.js` (identical in LE2 and LPS2:
keep the copies equal), gives every document three things. **Search**:
`/docs/search?q=…` searches the documents of `nav.json`, section by section,
deterministically; a document not in `nav.json` is not searched. **Links to
the other IDE**: write them as `https://lps2.logicalcontracts.com/docs/user/…`
(from LE2) or `https://le2.logicalcontracts.com/docs/user/…` (from LPS2); the
viewer rewrites them to wherever the other IDE is (le2.DOMAIN ↔ lps2.DOMAIN; on
localhost ports 3000 ↔ 3060; `?peer=<origin>` overrides). **Diagrams**:
`mermaid` code blocks are drawn with the local `mermaid.min.js`, and their
`click` links are rewritten the same way.

Every document says under its title what kind of document it is, for whom,
and whether it is current. A plan that has been implemented says where its
result is documented.

**User documentation** (`user/`)

- Tutorials: [Introduction to Logical English](user/tutorials/intro-to-le/intro-to-le.md), [querying a program](user/tutorials/querying-a-program.md), [LE Views](user/tutorials/views.md)
- Guides: [the editor](user/guide/editor.md), [the executive view](user/guide/executive-view.md), [the assistants](user/guide/assistants.md), [the Proof Game](user/guide/proof-game.md), [the verifier's warnings](user/guide/warnings.md)
- Reference: [the language](user/reference/language.md) (and [em português](user/reference/language.pt.md)), [the extensions](user/reference/extensions.md) (the hosted service), [s(CASP)](user/reference/scasp.md), Logical English for LPS (in LPS2: `docs/user/reference/le-for-lps.md`)
- Other systems: [the map, importing and exporting](user/integrations/index.md), and a document per system: [Bitcoin Miniscript](user/integrations/miniscript.md), [LegalRuleML](user/integrations/legalruleml.md), [s(CASP), Prolog and LE1](user/integrations/scasp.md), [Blawx](user/integrations/blawx.md), [Oracle Intelligent Advisor](user/integrations/oia.md), [Socotra](user/integrations/socotra.md), [OIPA](user/integrations/oipa.md), [Epilog](user/integrations/epilog.md); Drools, Solidity, Daml, PDDL, Inform 7 and the original LPS are in LPS2's `docs/user/integrations/`
- API: [the web API](user/api/web-api.md), [MCP](user/api/mcp.md)

**Developer documentation** (`dev/`): [architecture](dev/architecture.md), [the LE Assistant](dev/assistant.md), [the Contract Assistant](dev/contract-assistant.md), [LE Views](dev/views.md), [migration](dev/migration.md), [debugger](dev/debugger.md), [graph](dev/graph.md), [telemetry](dev/telemetry.md), [deploying as a static site](dev/deploy-vercel.md) (the WebAssembly build: LE2 in the browser, on Vercel), [i18n](../i18n/README.md), the LE2↔LPS2 interface (in LPS2: `docs/dev/le-lps-interface.md`).

**Project documents** (`project/`): [plans](project/plans/), [papers](project/papers/), [research](project/research/), [archive](project/archive/).

The LLM features read documents by path — the language reference in
particular (`le_assistant_light.pl`, `le_contract_assistant.pl`,
`AGENTS_LE_template*.md`, `llm/mcp.pl`): move one only together with them.
`vibeCodingNotes.md` is private notes, not served and not in the image.
