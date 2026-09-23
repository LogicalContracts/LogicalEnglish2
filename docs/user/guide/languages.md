# Logical English in other languages

Logical English can be written in five natural languages. Each language has
its own version of Logical English:

| Language | Name of its Logical English | First sentence of a program | How complete |
|---|---|---|---|
| English | Logical English | `the target language is: prolog.` | complete |
| Portuguese | Português Lógico | `a linguagem alvo é: prolog.` | pilot |
| Spanish | Español Lógico | `el lenguaje objetivo es: prolog.` | draft |
| French | Français Logique | `la langue cible est: prolog.` | draft |
| Italian | Italiano Logico | `il linguaggio obiettivo è: prolog.` | draft |

A program means the same thing in every language. Only the words change: the
keywords (*if*, *and*, *it is not the case that* …), the headings of the
sections, and the built-in sentences such as *is greater than*. The program's
own words are whatever its author writes.

*Complete* means that the whole system works in the language. *Pilot* means
that Portuguese is tested with its own example programs and has its own
language reference and its own instructions for the assistants. *Draft* means
that the keywords were translated first by machine and are still being
reviewed. A draft language has a few example programs, and the assistants use
their English instructions for the draft languages.

## Choosing the language of a program

The first sentence of a program says which language the program is written
in. The editor reads that sentence and then reads the rest of the program in
that language. The editor also colours the keywords of that language. A
program without such a first sentence is read as English.

Here is the start of the classic example about British citizenship, in
Español Lógico. A *template* is the pattern of a sentence, with a slot for
each thing that varies, such as *\*una persona\**:

```
el lenguaje objetivo es: prolog.

las plantillas son:
*una persona* adquiere ciudadanía británica en *una fecha*.
*una persona* nació en *un lugar* en *una fecha*,
*una persona* es la madre de *una persona*,
*una persona* es ciudadana británica en *una fecha*.

la base de conocimiento ciudadania incluye:

una persona adquiere ciudadanía británica en una fecha
si la persona nació en el Reino Unido en la fecha
	y una otra persona es la madre de la persona
	y la otra persona es ciudadana británica en la fecha.
```

The same rule in English reads *a person acquires British citizenship on a
date if the person is born in the UK on the date and …*. A *scenario* is a
named set of facts that describes one case, and a *query* is a question put
to the program. The words for those two, like every keyword, change with the
language:

| English | Português | Español | Français | Italiano |
|---|---|---|---|---|
| the templates are | os modelos são | las plantillas son | les modèles sont | i modelli sono |
| the knowledge base … includes | a base de conhecimento … inclui | la base de conocimiento … incluye | la base de connaissances … comprend | la base di conoscenza … include |
| if | se | si | si | se |
| and | e | y | et | e |
| or | ou | o | ou | o |
| it is not the case that | não é o caso que | no es el caso que | il est faux que | non è il caso che |
| scenario … is | cenário … é | escenario … es | scénario … est | scenario … è |
| query … is | consulta … é | consulta … es | requête … est | interrogazione … è |
| expects | espera | espera | attend | attende |

The [language reference](../reference/language.md) describes every construct
in English. A Portuguese translation of the reference is also available:
[Resumo da sintaxe do Português Lógico](../reference/language.pt.md).

## Numbers and dates

In Portuguese, Spanish, French and Italian a comma between two digits is the
decimal comma: `o custo é 1,5` means one and a half. A point groups the
thousands, in groups of exactly three digits: `1.234.567`. Write a comma that
separates the items of a list with a space after it, as in `[1, 5]`, so that
the comma is not read as a decimal comma. Dates are written the same way in
every language, year first: `2026-07-15`.

## Where to find the programs of each language

The landing page of the editor has a line *Other languages*, with one link per
language. Each link opens a landing page of its own, which lists only the
example programs of that language and has its words in that language. The same
pages are reached from the address `/multilingual`, which lists the
languages.

A click on an example opens the example in the editor, as on the English
landing page.

## The language of the menus

The language of the menus, the buttons and the messages of the editor is a
separate choice from the language of the program. A reader whose browser is
set to English can edit a program in Español Lógico with the menus in English.
A reader in Lisbon can edit an English program with the menus in Portuguese.

The first time the editor opens in a browser, the editor uses the browser's
preferred language when Logical English has that language, and English
otherwise. To change the language of the menus, open the **Misc** menu and
choose a language under **MENU LANGUAGE**. The editor reloads the page in the
chosen language. The browser remembers the choice for the next visit. Opening
a program in another language never changes the language of the menus, and
neither do the landing pages of the other languages.

The language of the menus also decides three other things:

- the login page and the executive view (the page that runs a program without
  showing its text, described in [the executive view](executive-view.md)) show
  their words in that language;
- **File ▸ New** starts a new program with the first sentence of that
  language, so a reader with Portuguese menus starts a program in Português
  Lógico;
- the LE Assistant answers in that language while the open program is empty.

## The assistants

The assistants follow the language of the program, not the language of the
menus. The LE Assistant, the chat panel of the editor, writes the program in
the program's own language. The command in the Scenario Editor and the Query
Editor that turns ordinary sentences into facts or a query (**Write it in
English…** in the English menus, **Escreva em Português…** in the Portuguese
ones) also writes in the program's language. The guide
[the assistants](assistants.md) describes both.

## Improving a language

The words of every language are kept in a set of tables, one column per
language, in the `i18n` folder of the source code of Logical English 2. The
file `i18n/README.md` in that folder explains how to correct a translation or
add a language. A correction to a keyword changes what the editor accepts, so
each change is followed by the test programs of every language.
