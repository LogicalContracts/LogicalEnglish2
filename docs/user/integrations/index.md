# Other systems: importing and exporting

*Kind: integration guide · Audience: users · Status: current (2026-09-16)*

The editor opens the files of other rule and contract systems as Logical
English. It also writes some Logical English programs in another system's
format. Both directions are deterministic translations, with no language model
involved, and each says what it could not carry over. This page is the map:
which systems, which ways, and how importing and exporting work in general.
Each system has a document of its own, linked below.

Which systems a server translates depends on the translators it has
installed. They are part of the InsurLE extensions, which the hosted service
has. A server running the Logical English repository alone has none:
**File ▸ Import from Another System…** is then hidden, **File ▸ Open…** offers
only `.le` files, and **File ▸ Export to Another System…** says that no
exporter can write the program.

## Contents

- [The map](#the-map)
- [The systems](#the-systems)
- [Opening another system's file](#opening-another-systems-file)
  - [What you get](#what-you-get)
  - [What could not be translated](#what-could-not-be-translated)
- [Show the Original](#show-the-original)
- [Exporting to another system](#exporting-to-another-system)
  - [When an export is refused](#when-an-export-is-refused)
- [The migration twins among the examples](#the-migration-twins-among-the-examples)
- [See also](#see-also)

## The map

Every system below has a translator. An arrow into Logical English is an
importer; a double arrow means the way back exists too. **LE for LPS** is
Logical English with `the target language is: lps.`: programs that run in time,
in the LPS2 IDE. The systems drawn on its side are documented there. Click a
system for its document.

```mermaid
flowchart LR
  subgraph ins["Insurance products"]
    SO["Socotra"]
    OP["OIPA"]
  end

  subgraph rac["Rules as code"]
    OIA["Oracle Intelligent Advisor"]
    BX["Blawx"]
    EP["Epilog"]
  end

  subgraph core["Logical English"]
    LE(["<b>LE</b><br/>timeless rules, scenarios,<br/>explanations, views"])
    LPS(["<b>LE for LPS</b> · in LPS2<br/>actions, fluents, causal laws,<br/>a timeline"])
    LE <-- "one language,<br/>target lps" --> LPS
  end

  subgraph both["Both ways"]
    SC["s(CASP) · Prolog · LE1"]
    LR["LegalRuleML"]
    MS["Bitcoin Miniscript"]
  end

  subgraph lpsside["On the LPS2 side"]
    DR["Drools DRL"]
    SOL["Solidity / EVM"]
    DA["Daml / Canton"]
  end

  SO --> LE
  OP --> LE
  OIA --> LE
  BX --> LE
  EP -- "rulesets" --> LE
  EP -- "games" --> LPS
  DR -- "decision services" --> LE
  DR -- "stateful rules" --> LPS

  LE <--> SC
  LE <--> LR
  LE <--> MS
  LPS <--> SOL
  LPS -- "as norms" --> LR
  LPS <--> DA

  click SO "socotra" "Socotra and Logical English"
  click OP "oipa" "OIPA and Logical English"
  click OIA "oia" "Oracle Intelligent Advisor and Logical English"
  click BX "blawx" "Blawx and Logical English"
  click EP "epilog" "Epilog and Logical English"
  click SC "scasp" "s(CASP), Prolog and LE1"
  click LR "legalruleml" "LegalRuleML and Logical English"
  click MS "miniscript" "Bitcoin Miniscript and Logical English"
  click LE "../reference/language" "The Logical English reference"
  click LPS "https://lps2.logicalcontracts.com/docs/user/integrations/index" "LPS2: other systems"
  click DR "https://lps2.logicalcontracts.com/docs/user/integrations/drools" "Drools and LPS (LPS2 documentation)"
  click SOL "https://lps2.logicalcontracts.com/docs/user/integrations/solidity" "Solidity and LPS (LPS2 documentation)"
  click DA "https://lps2.logicalcontracts.com/docs/user/integrations/daml" "Daml and LPS (LPS2 documentation)"
```

The LPS2 IDE has a map of its own, with the systems only it reads (PDDL,
Inform 7):
[other systems in LPS2](https://lps2.logicalcontracts.com/docs/user/integrations/index).

## The systems

| System | Ways | Document |
|---|---|---|
| Bitcoin Miniscript policy or descriptor | import, export | [Bitcoin Miniscript](miniscript.md) |
| LegalRuleML (OASIS) | import, export | [LegalRuleML](legalruleml.md) |
| s(CASP), Prolog, LE1's s(CASP) translations | import; See s(CASP), the s(CASP) engine, the Prolog equivalent | [s(CASP), Prolog and LE1](scasp.md) |
| Blawx project | import | [Blawx](blawx.md) |
| Oracle Intelligent Advisor project or rulebase | import | [Oracle Intelligent Advisor](oia.md) |
| Socotra product configuration | import | [Socotra](socotra.md) |
| Oracle Insurance Policy Administration transaction | import | [OIPA](oipa.md) |
| Epilog program | import (rulesets as LE, games as LE for LPS) | [Epilog](epilog.md) |
| Drools rule base (DRL) | import (LE for LPS, and a decision service in LE) | [Drools, in the LPS2 documentation](https://lps2.logicalcontracts.com/docs/user/integrations/drools) |
| Solidity contract | import (LE for LPS); Deploy as Solidity in LPS2 | [Solidity, in the LPS2 documentation](https://lps2.logicalcontracts.com/docs/user/integrations/solidity) |
| Daml (Canton) | import, export (LE for LPS) | [Daml, in the LPS2 documentation](https://lps2.logicalcontracts.com/docs/user/integrations/daml) |

## Opening another system's file

**File ▸ Open…** takes a Logical English file (`.le`) or a file of any system
the server has a translator for. **File ▸ Import from Another System…** is the
same, but offers only the other systems' files. Its tooltip lists the systems
this server translates from.

The file is sent to the server, translated, and opened in a new tab. A note
under the menu bar says which translator was used, how many fragments could
not be translated, and the translator's own remarks (for a migration, the
counts of its ledger). Close the note with its `×`.

When several translators read the same file extension (`zip`, `xml`, `json`,
`txt`), each one looks at the file and the one that recognises it translates
it. A zipped project is extracted on the server. An archive holding a single
folder is read as that folder.

Programs in **Logical English for LPS** (`the target language is: lps.`) run in
time rather than answering queries. The editor shows **Run in LPS** and
**Legal View** for them, and running needs the LPS2 server; see
[the editor guide](../guide/editor.md#advanced-features).

### What you get

The translation is an ordinary Logical English program. You can query it,
edit it and save it with **File ▸ Save As…**. When the source has tests, a
translator writes them as scenarios with `expects answers` lines.
**Misc ▸ Run the Program's Tests…** then shows which the program reproduces.
A migration also writes a *ledger* beside the program (`<name>.ledger.md`),
with one row per element of the source. Each row says whether the element was
*encoded*, *approximated* (with a note on how its meaning changed) or left as
*residue*, and the ledger gives how many source tests the program passes.

The server keeps the upload and its translation for a day, in a folder of its
own. The program's includes and the documents it cites are found there, so
citations and **Show the Original** work while you work on it. Save the program
if you want to keep it.

### What could not be translated

A translator never fails the whole file because of one fragment it cannot
read. Such a fragment is written into the program as a comment whose first line
starts with `% TODO`, followed by the fragment verbatim. A migration marks the
fragment as a *residue block*:

```le
% RESIDUE r3 BEGIN: the collision rating plugin
%   source: plugins/rating.js lines 40-61
%   ...
% RESIDUE r3 END
```

You can translate a residue block by hand. The Contract Assistant's
*Migration residue* mode can also translate the residue blocks and nothing
else, then run the program's tests on the result ([assistants](../guide/assistants.md#the-contract-assistant)).

A file that no translator recognises still opens, as a program holding the
file's text in a TODO comment with the reason. An archive that no translator
recognises is refused.

## Show the Original

**File ▸ Show the Original…** shows the files a program was converted from, in
the source viewer. By convention they are kept in a `sources/` folder beside
the program. File ▸ Open keeps the upload there, and the migration twins among
the examples keep their originals there too. When there is one file, it opens
directly. When there are several, they are listed first. A program with no
`sources/` folder says that no original is kept. Binary files (PDF, images,
archives) are not listed, because the viewer shows text only.

A program can also cite one of those files as the text of a document
(`the text of the policy file is at "sources/…"`). A right-click on the
citation in the editor offers **Show original text**. In an explanation, the
§ badge of a cited step opens the passage in that text.

## Exporting to another system

**File ▸ Export to Another System…** writes the program in the tab in front in
another system's format. The menu offers only the exporters that apply to the
program. With one exporter it runs straight away; with several it asks which
to use. The result opens in a window with:

- its notes: what was not carried over, although nothing of the program's
  meaning is lost (comments, queries and expected answers, layout);
- **Copy** and **Save…**;
- a button for each public sandbox the result can be opened in, when the
  exporter has one;
- the exported text.

The exporters are Bitcoin Miniscript (for spending-policy programs), LegalRuleML
(for ordinary rule programs) and Daml (for LE for LPS programs). For example,
`migration/miniscript/core_2of3_multisig` is offered both Miniscript and
LegalRuleML. The LPS2 IDE has the same exporters under **Misc ▸ Export to
another system…**, and **Misc ▸ Deploy as Solidity…** of its own.

### When an export is refused

An exporter first checks whether it can write the program *faithfully*. If
the program uses something the target cannot express, the export is
**refused**: nothing is written, since a translation that silently meant
something else would be worse than none. The window, titled *Not translated
to …*, says how many problems were found and lists each one. Where the problem
has a place in the program, the list gives its line as a link that takes you
there, the program's own words at that line, and what the target lacks.

Two refusals you can reproduce with the examples:

- `regulatory/eu261_integration` to LegalRuleML: the program has a decision
  table, which LegalRuleML cannot state, and a rule cites a source (`according
  to`) inside `it is not the case that`. The window gives the table's line,
  and reports the second as the use of `according to`, at the line of the
  `according to` itself: negation alone exports, so the problem names the
  construct inside it.
- `migration/miniscript/core_2of3_multisig` to LegalRuleML: its spending rule
  counts signatures (`a number N is the count of each K such that …`), and
  LegalRuleML has no aggregates. The Miniscript exporter writes the same
  program.

An integrity constraint (`it must not be true that …`) is a problem for any
target that has no constraints.

The editor refuses in the same way wherever it translates a program into
another language. **See s(CASP)** (right-click in the editor) and the s(CASP)
engine show the same list when the program uses a construct s(CASP) cannot
state (see [s(CASP)](../reference/scasp.md)).

## The migration twins among the examples

The translators have been run on published programs of their source systems.
The results, called *twins*, are among the examples: open them with **File ▸
Open copy from server…**, or from the landing page. Each twin comes with its
ledger, its source tests as scenarios, and its `sources/` folder.

- `migration/blawx/…`: Blawx encodings;
- `migration/legalruleml/…`: the examples of the LegalRuleML specification;
- `migration/miniscript/…`: Bitcoin spending policies, each with a custody
  view, flip queries for lost keys, and scenarios confirmed by a recorded
  run on the public Tape network;
- `migration/scasp/…`: s(CASP) programs, including LE1's.

The twins in Logical English for LPS (Daml, Drools, Solidity) are among the
examples of LPS2. The twins of Oracle Intelligent Advisor, OIPA, Socotra and
Epilog are only on installations with the InsurLE examples (under
`insureLE2/migration/`), for users with access.

## See also

- [The editor guide](../guide/editor.md), [the language reference](../reference/language.md).
- [Logical English for LPS](../reference/lps-target.md), and in LPS2:
  [the LE for LPS reference](https://lps2.logicalcontracts.com/docs/user/reference/le-for-lps)
  and [other systems in LPS2](https://lps2.logicalcontracts.com/docs/user/integrations/index).
- How the translators work, the ledger and the residue, for developers:
  [migration](../../dev/migration.md).
