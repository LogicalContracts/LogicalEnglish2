# Importing and exporting: other systems' programs

*Kind: guide · Audience: users · Status: current (2026-09-16)*

The editor opens the files of some other rule systems as Logical English, and
writes some Logical English programs in another system's format. Both
directions are deterministic translations, with no language model involved.
Each says what it could not carry over. Both are in the **File** menu.

Which systems a server translates depends on the translators it has
installed. They are part of the InsurLE extensions (`le_extensions.pl`, which
loads `InsurLE2/migration/le_importers.pl`). The hosted service has them. A
server running this repository alone has none: **File ▸ Import from Another
System…** is then hidden, **File ▸ Open…** offers only `.le` files, and
**File ▸ Export to Another System…** says that no exporter can write the
program.

## Contents

- [Opening another system's file](#opening-another-systems-file)
  - [The importers](#the-importers)
  - [What you get](#what-you-get)
  - [What could not be translated](#what-could-not-be-translated)
- [Show the Original](#show-the-original)
- [Exporting to another system](#exporting-to-another-system)
  - [The exporters](#the-exporters)
  - [When an export is refused](#when-an-export-is-refused)
- [The migration twins among the examples](#the-migration-twins-among-the-examples)

## Opening another system's file

**File ▸ Open…** takes a Logical English file (`.le`) or a file of any system
the server has a translator for. **File ▸ Import from Another System…** is the
same, but offers only the other systems' files. Its tooltip lists the systems
this server translates from.

The file is sent to the server, translated, and opened in a new tab. A note
under the menu bar says which translator was used, how many fragments could
not be translated, and the translator's own remarks (for a migration, the
counts of its ledger). Close the note with its `×`.

### The importers

These are the translators the InsurLE extensions register, with the file
extensions each reads. When several translators read the same extension
(`zip`, `xml`, `json`, `txt`), each one looks at the file and the one that
recognises it translates it.

| System | Files | What you get |
|---|---|---|
| Bitcoin Miniscript policy or descriptor | `.miniscript`, `.ms`, `.policy`, `.desc`, `.txt` | who can spend the coin: one rule per spending path, the policy's satisfaction analysis as scenarios, flip queries, a view |
| Oracle Intelligent Advisor project or rulebase | `.xgen`, `.xml`, `.stxt`, `.zip` | the project's rules as a program |
| Socotra product configuration | `.zip`, `.json` | the product configuration (JSON and Liquid) as a program |
| Solidity contract | `.sol`, `.zip` | an executable program in Logical English for LPS |
| s(CASP) or Prolog program (including LE1's s(CASP) translations) | `.pl`, `.scasp`, `.lp` | the rules as Logical English |
| Blawx project (`.blawx` export or example YAML) | `.blawx`, `.yaml`, `.yml`, `.zip` | the legislation's rules in its own words, each citing its section, with the project's tests as scenarios |
| Drools rule base (DRL) | `.drl` | Logical English for LPS, and a decision service when the rules only insert |
| Epilog program (Stanford's Dynamic Logic Programming) | `.epilog`, `.epi`, `.hrf`, `.txt` | a ruleset, or a game in Logical English for LPS |
| LegalRuleML document (OASIS) | `.lrml`, `.xml` | obligations, permissions and prohibitions as Logical English |
| Oracle Insurance Policy Administration transaction (Rules Palette XML) | `.xml` | the transaction and its attached rules as a program |
| Daml source (Daml 3, Canton) | `.daml`, `.zip` | templates, choices and scripts as Logical English for LPS |

A zipped project is extracted on the server. An archive holding a single
folder is read as that folder.

Programs in **Logical English for LPS** (`the target language is: lps.`) run in
time rather than answering queries. The editor shows **Run in LPS** and
**Legal View** for them, and running needs the LPS2 server; see
[the editor guide](editor.md#advanced-features).

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
else, then run the program's tests on the result ([assistants](assistants.md#the-contract-assistant)).

A file that no translator recognises still opens, as a program holding the
file's text in a TODO comment with the reason. An archive that no translator
recognises is refused.

## Show the Original

**File ▸ Show the Original…** shows the files a program was converted from, in
the source viewer. By convention they are kept in a `sources/` folder beside
the program. File ▸ Open keeps the upload there, and the migration twins among
the examples keep their originals there too: a Solidity twin's contract, a
Socotra product's configuration files, an OIA project's rule documents. When
there is one file, it opens directly. When there are several, they are listed
first. A program with no `sources/` folder says that no original is kept.
Binary files (PDF, images, archives) are not listed, because the viewer shows
text only.

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

### The exporters

| Target | Offered for | Notes |
|---|---|---|
| Bitcoin Miniscript policy (with its Miniscript and a Minsc link) | spending-policy programs, like the Miniscript twins | a **Try it in Minsc** button opens the policy in the Minsc playground |
| LegalRuleML (OASIS): rules, obligations and their sources | ordinary rule programs | scenarios' facts are exported as Statements blocks; queries and expected answers are not, since LegalRuleML has no queries |
| Daml (Canton): the program as one State contract, each action a choice, with its scenario as a Daml Script | Logical English for LPS programs | |

For example, `migration/miniscript/core_2of3_multisig` is offered both
Miniscript and LegalRuleML. `citizenship` is offered LegalRuleML and exports
with the note above.

### When an export is refused

An exporter first checks whether it can write the program *faithfully*. If
the program uses something the target cannot express, the export is
**refused**: nothing is written, since a translation that silently meant
something else would be worse than none. The window, titled *Not translated
to …*, says how many problems were found and lists each one. Where the problem
has a place in the program, the list gives its line as a link that takes you
there, the program's own words at that line, and what the target lacks.

Two refusals you can reproduce with the examples:

- `regulatory/eu261_integration` to LegalRuleML: a rule uses `it is not the
  case that` (negation), and the program has a decision table. LegalRuleML
  cannot state either.
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
examples of LPS2.

How the translators work, the ledger and the residue are documented for
developers in [migration](../../dev/migration.md).
