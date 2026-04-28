# British Royal Family — Logical English Program

## Program Text

```logical-english
the templates are:
  *a person* is a parent of *a child*,
  *a person* was born in *a year*,
  *a person* is an ancestor of *a descendant*,
  *a person* is a sibling of *a other person*,
  *a person* is a cousin of *a other person*,
  *a person* is a grandparent of *a grandchild*.

the knowledge base royal_family includes:

% Rule 1 — Ancestor (direct parent)
a person is an ancestor of a descendant
if the person is a parent of the descendant.

% Rule 2 — Ancestor (transitive)
a person is an ancestor of a descendant
if the person is a parent of a child
and the child is an ancestor of the descendant.

% Rule 3 — Sibling (share a parent, different person)
a person is a sibling of a other person
if a child is a parent of the person
and the child is a parent of the other person
and it is not the case that
  the person = the other person.

% Rule 4 — Cousin (parents are siblings)
a person is a cousin of a other person
if a child is a parent of the person
and a descendant is a parent of the other person
and the child is a sibling of the descendant.

% Rule 5 — Grandparent (parent of parent)
a person is a grandparent of a grandchild
if the person is a parent of a child
and the child is a parent of the grandchild.

% --- Queries ---

% Q1: All ancestors of Elizabeth (II)
query q1 is:
  a person is an ancestor of elizabeth.

% Q2: All siblings of Alfred
query q2 is:
  a person is a sibling of alfred.

% Q3: All cousins of George (V)
query q3 is:
  a person is a cousin of george.

% Q4: All grandparents of George (V)
query q4 is:
  a person is a grandparent of george.

% Q5: Boolean — is Queen Victoria an ancestor of Elizabeth?
query q5 is:
  queen victoria is an ancestor of elizabeth.

% Q6: Boolean — is Wilhelm a cousin of George?
query q6 is:
  wilhelm is a cousin of george.

% Q7: All grandparents of Wilhelm
query q7 is:
  a person is a grandparent of wilhelm.

% Q8: Edward VIII's siblings
query q8 is:
  a person is a sibling of edward viii.

% --- Scenario with facts and expected answers ---

scenario family is:
  queen victoria was born in 1819.
  prince albert was born in 1819.
  queen victoria is a parent of vicky.
  prince albert is a parent of vicky.
  vicky was born in 1840.
  queen victoria is a parent of edward.
  prince albert is a parent of edward.
  edward was born in 1841.
  queen victoria is a parent of alice.
  prince albert is a parent of alice.
  alice was born in 1843.
  queen victoria is a parent of alfred.
  prince albert is a parent of alfred.
  alfred was born in 1844.
  queen victoria is a parent of helena.
  prince albert is a parent of helena.
  helena was born in 1846.
  queen victoria is a parent of louise.
  prince albert is a parent of louise.
  louise was born in 1848.
  queen victoria is a parent of arthur.
  prince albert is a parent of arthur.
  arthur was born in 1850.
  queen victoria is a parent of leopold.
  prince albert is a parent of leopold.
  leopold was born in 1853.
  queen victoria is a parent of beatrice.
  prince albert is a parent of beatrice.
  beatrice was born in 1857.
  vicky is a parent of wilhelm.
  wilhelm was born in 1859.
  vicky is a parent of charlotte.
  charlotte was born in 1860.
  edward is a parent of albert victor.
  albert victor was born in 1864.
  edward is a parent of george.
  george was born in 1865.
  alice is a parent of irene.
  irene was born in 1866.
  alice is a parent of alix.
  alix was born in 1872.
  george is a parent of edward viii.
  edward viii was born in 1894.
  george is a parent of george vi.
  george vi was born in 1895.
  george vi is a parent of elizabeth.
  elizabeth was born in 1926.
  q1 expects answers [george vi is an ancestor of elizabeth, george is an ancestor of elizabeth, edward is an ancestor of elizabeth, queen victoria is an ancestor of elizabeth, prince albert is an ancestor of elizabeth].
  q2 expects answers [vicky is a sibling of alfred, edward is a sibling of alfred, alice is a sibling of alfred, helena is a sibling of alfred, louise is a sibling of alfred, arthur is a sibling of alfred, leopold is a sibling of alfred, beatrice is a sibling of alfred].
  q3 expects answers [wilhelm is a cousin of george, charlotte is a cousin of george, irene is a cousin of george, alix is a cousin of george].
  q4 expects answers [queen victoria is a grandparent of george, prince albert is a grandparent of george].
  q5 expects answers [queen victoria is an ancestor of elizabeth].
  q6 expects answers [wilhelm is a cousin of george].
  q7 expects answers [queen victoria is a grandparent of wilhelm, prince albert is a grandparent of wilhelm].
  q8 expects answers [george vi is a sibling of edward viii].
```

---

## Naming Conventions

Since Logical English parses Roman numerals as numbers, short names are used:

| Short name | Historical figure |
|---|---|
| queen victoria | Queen Victoria (1819–1901) |
| prince albert | Prince Albert (1819–1861) |
| vicky | Victoria, Princess Royal (1840–1901) |
| edward | King Edward VII (1841–1910) |
| alice | Princess Alice (1843–1878) |
| alfred | Prince Alfred (1844–1900) |
| helena | Princess Helena (1846–1923) |
| louise | Princess Louise (1848–1939) |
| arthur | Prince Arthur (1850–1942) |
| leopold | Prince Leopold (1853–1884) |
| beatrice | Princess Beatrice (1857–1944) |
| wilhelm | Kaiser Wilhelm II (1859–1941) |
| charlotte | Princess Charlotte of Prussia (1860–1919) |
| albert victor | Prince Albert Victor (1864–1892) |
| george | King George V (1865–1936) |
| irene | Princess Irene of Hesse (1866–1953) |
| alix | Tsarina Alexandra / Alix of Hesse (1872–1918) |
| edward viii | King Edward VIII / Duke of Windsor (1894–1972) |
| george vi | King George VI (1895–1952) |
| elizabeth | Queen Elizabeth II (1926–2022) |

---

## Family Tree Encoded

```
Queen Victoria ─┬─ Prince Albert
                │
  ┌─────┬───────┼───────┬────────┬────────┬───────┬─────────┬──────────┐
Vicky  Edward  Alice  Alfred  Helena  Louise  Arthur  Leopold  Beatrice
  │      │       │
  ├──    ├──     ├──
Wilhelm  A.V.   Irene
Charlotte George  Alix
           │
           ├──
         Ed.VIII
         George VI
           │
         Elizabeth
```

---

## Verification Results

The program was verified by the Logical English engine with **no errors and no warnings**.

All 8 test queries passed:

| Query | Description | Status |
|---|---|---|
| q1 | Ancestors of Elizabeth | **pass** |
| q2 | Siblings of Alfred | **pass** |
| q3 | Cousins of George | **pass** |
| q4 | Grandparents of George | **pass** |
| q5 | Victoria ancestor of Elizabeth (boolean) | **pass** |
| q6 | Wilhelm cousin of George (boolean) | **pass** |
| q7 | Grandparents of Wilhelm | **pass** |
| q8 | Siblings of Edward VIII | **pass** |
