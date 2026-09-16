# Resumo da Sintaxe do Português Lógico (LE)

*Tipo: referência · Público: utilizadores, assistentes (lido por inteiro pelas funcionalidades LLM) · Estado: atual (2026-09-16)*

Este documento resume as construções de Logical English (LE) na sua variante
portuguesa — **Português Lógico** — tal como suportadas pelo analisador em
`le_grammar.pl` com o léxico `i18n/keywords.csv` (palavras-chave) e
`i18n/system_templates.csv` (modelos de sistema). Um programa declara a
linguagem na sua **primeira frase**: `a linguagem alvo é: prolog.`

As secções têm os mesmos números que as da referência inglesa,
[language.md](language.md), para que as citações "§" (p.ex. nas mensagens do
verificador) valham para ambas.

## Índice
- [1. Secções do documento](#1-secções-do-documento)
- [2. Modelos](#2-modelos)
  - [2.1 Modelos preposicionais](#21-modelos-preposicionais)
  - [2.2 Constantes com nome: `as constantes são:`](#22-constantes-com-nome-as-constantes-são)
- [3. Regras e factos](#3-regras-e-factos)
  - [3.1 Secções de regras](#31-secções-de-regras)
  - [3.2 Corpos de consultas](#32-corpos-de-consultas)
  - [3.3 Restrições de integridade: `não pode ser verdade que …`](#33-restrições-de-integridade-não-pode-ser-verdade-que-)
- [4. Operadores lógicos](#4-operadores-lógicos)
- [5. Agregações](#5-agregações)
- [6. Variáveis e constantes](#6-variáveis-e-constantes)
- [7. Aritmética e comparações](#7-aritmética-e-comparações)
- [8. Taxonomia (ontologia)](#8-taxonomia-ontologia)
- [9. Palavras ignoráveis](#9-palavras-ignoráveis)
- [10. Comentários](#10-comentários)
- [11. Meta-modelos](#11-meta-modelos)
- [12. Testes e expectativas](#12-testes-e-expectativas)
- [13. Predicados de sistema](#13-predicados-de-sistema)
- [14. Recursos incluídos](#14-recursos-incluídos)
- [15. Extensões LE](#15-extensões-le)
- [16. Humanizar o LE](#16-humanizar-o-le)
- [17. Construções para decisões regulatórias](#17-construções-para-decisões-regulatórias)

## 1. Secções do documento
Cada cabeçalho de secção termina com dois pontos `:`.

- **Recursos incluídos:** `a base de conhecimento <nome> inclui estes recursos:` ou `o contrato <nome> inclui estes recursos:` (para incluir outros ficheiros LE ou URLs; deve preceder o cabeçalho principal).
- **Base de conhecimento:** `a base de conhecimento <nome> inclui:` ou `o contrato <nome> estabelece que:`
- **Cenário:** `cenário <nome> é:` (factos de um caso concreto)
  - Pode incluir expectativas: `<NomeDaConsulta> espera respostas [<lista de strings>] e desconhecidos [<lista de strings>].` (a palavra `respostas` pode omitir-se)
- **Consulta:** `consulta <nome> é:` (os objetivos a provar). O corpo de uma
  consulta pode ser uma **expressão de corpo completa — como o corpo de uma
  regra** — e não apenas uma única instância de modelo: pode combinar condições
  com `e`, `ou`, negação (`não é o caso que …`) e `para todos os casos em que …` (ver §3.2).
- **Ontologia:** `a ontologia é:` (taxonomia e hierarquias de classes)
- **Modelos:** `os predicados são:` ou `os modelos são:` (padrões de linguagem natural)
- **Constantes:** `as constantes são:` (valores com nome, um por linha: `a taxa é 5.` — §2.2)
- **Bases (alvo lps):** `a base de conhecimento <nome> estende <base>, <base>.` — os modelos, leis e restrições das bases, sem a sua instância (`le_lps_surface.md` §1.1)
- **Dinâmica:** `os fluentes são:` ou `os eventos são:` (raciocínio temporal). No alvo lps uma frase só precisa de tempos onde relaciona dois momentos: uma regra reativa `se … então …` sem tempos lê as suas condições num só momento e começa a sua ação nesse momento, e uma lei causal `quando … então …` também dispensa tempos (`le_lps_surface.md` §3.1)
- **Meta:** `a linguagem alvo é: prolog.` (obrigatório; declara a linguagem do programa)

## 2. Modelos
Os modelos (templates) associam frases de linguagem natural a predicados Prolog.
- **Padrão:** `*uma pessoa* é amiga de *uma outra pessoa*`
- **Variáveis:** palavras entre asteriscos `*...*`.
- **Tipos:** o **substantivo principal** da frase da variável (p.ex. `pessoa`); ver §6.
- **Alcance das variáveis:** várias ocorrências do mesmo nome de variável na
  mesma frase (ou consulta) referem a mesma variável.
  - `qual pessoa é o pai de qual pessoa` só é verdadeira se uma pessoa for pai de si própria.
  - Use `qual pessoa é o pai de qual outra pessoa` para referir duas pessoas diferentes.

### Adições a modelos (depois de `;`)
Uma definição de modelo pode ser seguida de adições, cada uma introduzida por `;`:
- `; oposto: <modelo>` — declara a forma negativa, usada em conclusões negativas e provas por negação.
  **A forma oposta não é uma negação numa condição.** Escrita como condição,
  `o requerente não tem outro rendimento` é um objetivo do seu próprio
  predicado, que só as regras que o concluem (uma regra `apenas se`, §15.1)
  podem provar; para testar que o modelo positivo não se verifica, escreva
  `não é o caso que o requerente tem outro rendimento`. O verificador assinala
  uma forma oposta usada como condição que nada conclui (`opposite_as_condition`).
- `; sinónimo: <modelo>` (também `sinônimo`) — declara uma **forma equivalente**. O sinónimo aponta para o **mesmo** predicado, pelo que factos, cabeças e corpos de regras e consultas podem usar qualquer das formas; as suas `*variáveis*` emparelham **posicionalmente** com as do modelo principal, pelo que ambas as formas devem listar os argumentos pela mesma ordem. Podem encadear-se vários `; sinónimo ...`.
  - Exemplo: `*um pagamento* é relativo a *um sinistro*; sinónimo: *um pagamento* cobre *um sinistro*.`
  - **Apresentação:** por omissão usa-se a forma principal (a primeira). Numa explicação, cada nó é apresentado na forma usada no seu local de origem; uma consulta apresenta as suas respostas na forma usada na consulta.
  - **Restrição:** um modelo com sinónimo **não pode ter outras adições** (`define global`, `oposto`, `preposicional`, `desconhecido`, `indefinido`); caso contrário é assinalado o erro `synonym_with_other_additions`.
- `; define global <nome>` — declara uma abreviatura global (podem encadear-se vários).
- `; preposicional` — marca um modelo **preposicional** (ver §2.1). O sinónimo `; composto` (ou `; composta`) é aceite com o mesmo significado.
- `; desconhecido` — marca o modelo como **assumível** (abdutível): objetivos que não se conseguem provar são assumidos verdadeiros e reportados como desconhecidos, na medida em que as restrições de integridade o permitam (§3.3). São aceites os sinónimos `; desconhecida`, `; assumido`, `; assumida` e `; assumível`.
- `; indefinido` — marca o modelo como **elemento de cenário**: os seus factos só devem aparecer em cenários, nunca como factos ou cabeças de regras na base de conhecimento. São aceites os sinónimos `; indefinida` e `; elemento de cenário`.
  - O aviso `undefined_predicate` é **suprimido** para este modelo.
  - É emitido o aviso `defined_scenario_element` se aparecer um facto ou cabeça de regra deste modelo na base de conhecimento.
  - Exemplo: `*uma pessoa* passou no teste; indefinido.`
- `; via serviço <nome>` (também `; através do serviço <nome>`) — o modelo é respondido em tempo de execução por um serviço declarado (§17.6).
- `; <valor> por omissão` (também `por defeito`, `por padrão`) — **só no alvo lps, só em fluentes** (`le_lps_surface.md` §2): o valor que o último argumento do modelo tem para uma chave sem facto guardado. Um valor por omissão noutro modelo é assinalado (`default_not_lps`).
- `; julgado` — marca um predicado de **textura aberta** cujas instâncias são *decididas*, não derivadas (sinónimos `; julgada`, `; avaliativo`, `; avaliativa`). É resolvido como `; assumível`, exceto que, uma vez registado um resultado (o último argumento) para uma questão, nenhum outro resultado é assumido; uma regra que o conclua é um erro, e as suas instâncias em aberto aparecem como *julgamento necessário*. Ver §17.1.

### 2.1 Modelos preposicionais
Um modelo preposicional é um modelo binário que **começa por um argumento** e
serve para estender uma condição anterior. Ao encadear, o argumento inicial
pode ser omitido e é preenchido automaticamente a partir da variável de tipo
compatível da condição anterior.
- **Declaração:**
  ```le
  *um pagamento* ao abrigo de *uma apólice*; preposicional.
  ```
- **Restrições:** exatamente dois argumentos `*variável*`, e o primeiro elemento do modelo tem de ser uma `*variável*` (senão: `prepositional_arity` / `prepositional_first_arg`).
- **Uso encadeado** (omitindo o primeiro argumento; o encadeamento é resolvido pelo módulo de extensões, §15.7):
  ```le
  faremos um pagamento ao abrigo de esta apólice relativo a um sinistro
  ```
  expande para a conjunção
  ```le
  faremos um pagamento
  e o pagamento ao abrigo de esta apólice
  e o pagamento relativo a um sinistro
  ```
  Os objetivos dos modelos preposicionais tornam-se **condições adicionais** no corpo Prolog (tanto em cabeças como em corpos de regras).
- **Uso isolado** continua permitido: `o pagamento ao abrigo de esta apólice`.

### 2.2 Constantes com nome: `as constantes são:`
Uma secção de valores com nome, uma linha cada, `<nome> é <valor>.`:
```le
as constantes são:
    o limite isento é 10.
```
Cada linha abrevia um modelo com um nome global e um facto — `o valor de o
limite isento é *um número*; define global o limite isento.` e `o valor de o
limite isento é 10.` — pelo que o nome é um global (§6.0) onde quer que uma
regra, cenário ou consulta o use:
```le
um cliente paga imposto
    se a encomenda de o cliente pesa um número kg
    e o número > o limite isento.
```
Uma explicação mostra o valor como razão. O tipo do valor vem do literal (um
número, um texto ou um nome); o nome pode conter `é` (o valor é o que está
depois do último). O verificador assinala uma constante que nada usa
(`unused_constant`). Como qualquer global, um nome não é operando aritmético:
compare com ele, ou leia-o primeiro para uma variável.

## 3. Regras e factos
- **Facto:** uma frase simples terminada em ponto.
  - `Alice é uma pessoa.`
- **Regra:** uma frase com cabeça e corpo.
  - `Cabeça se Corpo.`
  - `uma pessoa é elegível se a pessoa é cidadã.`
- **Facto desconhecido:** declara que certa instância de um modelo é desconhecida; pode aparecer na base de conhecimento (valendo para todos os cenários) ou num cenário.
  - `é desconhecido se um pagamento é relativo ao sinistro 01.` (São aceites `é assumido se ...` e `é assumível se ...`.)

### 3.1 Secções de regras
As regras de uma base de conhecimento podem agrupar-se em **secções** nomeadas:
```le
secção <nome> é:
```
(também `seção`). Cada regra (ou facto) que segue o marcador pertence à secção
`<nome>`, até ao marcador seguinte. A correspondência é registada em
`le_source_section/2` (§13) e não muda o raciocínio — é metadado.

Convenções:
- Sem marcadores, ou antes do primeiro marcador, as regras pertencem à secção **`main`**.
- Os nomes **`aplicabilidade`**, **`questão`** e **`remédio`** (ou `reparação`) estão reservados para o esqueleto de decisão (§17.4): nada mudam na resolução, mas uma consulta falhada é reportada em relação a eles.

Abreviatura para a secção `annexes`:
```le
os anexos ao contrato são:
```
(sinónimo: `os anexos à base de conhecimento são:`), exatamente equivalente a `secção annexes é:`.

### 3.2 Corpos de consultas
O corpo de `consulta <nome> é:` analisa-se **exatamente como o corpo de uma
regra**:
- **Conjunção / disjunção** com `e` / `ou`, partilhando variáveis:
  ```le
  consulta ambas é:
      uma pessoa é feliz
      e a pessoa é saudável.
  ```
- **Negação** com `não é o caso que …`, com o objetivo negado em linha aninhada:
  ```le
  consulta segura é:
      uma pessoa é feliz
      e não é o caso que
          a pessoa é triste.
  ```
- **Universais** com `para todos os casos em que … é o caso que …`:
  ```le
  consulta todos_felizes é:
      para todos os casos em que
          uma pessoa é um dragão
          é o caso que
          a pessoa é feliz.
  ```

Uma consulta que é uma só instância de modelo (o caso comum, p.ex.
`qual dragão é feliz.`) comporta-se como sempre. Uma resposta com várias
condições é apresentada a partir do objetivo da consulta com as suas ligações.

> Aplicam-se as mesmas regras de disposição que nos corpos de regras: o objetivo
> negado e as partes de `para todos os casos em que` vão em linhas próprias
> aninhadas. Uma só linha como `… e não é o caso que a pessoa é triste` **não**
> separa a negação; ponha o objetivo negado na linha seguinte.

### 3.3 Restrições de integridade: `não pode ser verdade que …`
Uma **restrição de integridade** (uma *negação*) diz que certas condições nunca
podem ser verdadeiras em conjunto. Escreve-se como o corpo de uma regra sem
cabeça, na base de conhecimento, e é a mesma frase em todas as linguagens alvo:
```le
não pode ser verdade que
    uma pessoa reside em um país
    e a pessoa reside em um segundo país
    e o país é diferente de o segundo país.
```
- **Alvo prolog** — a restrição verifica o que uma resposta **assume** (os
  modelos `; desconhecido` de §2, os *abdutíveis*), como na programação em
  lógica abdutiva. Cada resposta obtida assumindo algo só é mantida se o caso,
  com essas suposições tomadas como verdadeiras e nada mais assumido, não
  satisfizer as condições de nenhuma restrição. O que não é dito nem assumido é
  falso enquanto uma restrição é verificada, pelo que uma restrição pode usar
  `não é o caso que`.
  - Uma restrição violada por causa da negação de algo assumível é **mantida
    assumindo mais**: com
    ```le
    não pode ser verdade que
        uma pessoa é casada com uma segunda pessoa
        e não é o caso que
            a segunda pessoa é casada com a pessoa.
    ```
    assumir que dan é casada com erin também assume que erin é casada com dan,
    e a resposta lista ambos os desconhecidos.
  - Caso contrário a resposta é **rejeitada**. Com a primeira restrição acima,
    não se pode assumir que alice (que vive em espanha) reside em frança, pelo
    que não é respondido que ela paga imposto lá.
  - Um caso cujos **factos**, por si só, violam uma restrição (sem suposição
    que o remedeie) é **inconsistente: nada se segue dele**, nenhuma consulta
    tem resposta, e a explicação da resposta vazia é a restrição e a prova das
    suas condições ("o caso viola uma restrição …").
  - Regras `se` comuns, consultas e respostas definitivas de casos consistentes
    não são afetadas; um programa sem restrições comporta-se como antes.
- **Alvo scasp** — cada restrição é escrita como a restrição global
  `false :- Condições.`, que todo o modelo, e portanto todo o conjunto de
  abdutíveis (`#abducible`), tem de satisfazer. (s(CASP) 1.1.4 não é correto
  para uma restrição *não fechada* que use `é diferente de` juntamente com
  abdutíveis; restrições fechadas são tratadas corretamente.)
- **Alvo lps** — a mesma frase é uma restrição LPS sobre ações e estados
  (`d_pre/1`, `le_lps_surface.md` §3.7): as ações e eventos são os abdutíveis
  do LPS, e nem o motor reativo nem o planeador escolhem uma ação que viole
  uma restrição.

Ver `examples/pt/desconhecidos.le` e, em inglês,
`examples/moreExamples/language/unknowns/assumption_constraints.le`. Os
tradutores a partir de s(CASP) e Prolog leem uma negação `:- Corpo.` /
`false :- Corpo.` como uma destas restrições.

## 4. Operadores lógicos
- **E:** `e` (ou nova linha com a mesma indentação)
- **Ou:** `ou`, `uma das seguintes`, `alguma das seguintes`, `todas as seguintes` (§15.4)
- **Caso contrário:** uma linha que começa por `caso contrário` (ou `senão`) inicia uma nova alternativa, aplicada só quando todas as anteriores falham (§17.2).
- **De acordo com:** `<condição> de acordo com <fonte>` (ou `segundo <fonte>`) prova a condição só com a evidência dessa fonte (§17.5).
- **Negação:** `não é o caso que` ou `não se verifica que`
- **Negação condicional:** `a menos que` (ou `salvo se`)
  - `Cabeça se Corpo a menos que Condição.` (≡ `Cabeça se Corpo e não é o caso que Condição.`)
- **Quantificação universal:**
  ```le
  para todos os casos em que
      <condição 1>
      <condição 2>
  é o caso que
      <consequência>
  ```
  (`é o caso que` tem o sinónimo `verifica-se que`.)

## 5. Agregações
Cálculos sobre conjuntos de resultados.
- **Operadores:** `soma`, `contagem`, `média`, `mínimo` (`mín`), `máximo` (`máx`)
- **Sintaxe:** `<Resultado> é a <op> de cada <Var> tal que` seguido das condições em linhas aninhadas (também `é o <op>`, `tais que`)
- **Exemplo** (`examples/pt/despesas.le`):
  ```le
  o montante é a soma de cada quantia tal que
      a pessoa gastou a quantia em uma outra coisa.
  ```

## 6. Variáveis e constantes
- **Variáveis:**
  - Explícitas: `*a minha variável*`
  - Implícitas: `uma pessoa`, `alguma pessoa`, `cada pessoa`, `qual pessoa` — e
    `a pessoa`, mas **apenas como retoma**: ver §6.0.
  - Especiais: `quem`, `quê`, `quando`, `onde`

### 6.0 Frases definidas: retoma ou constante global
Uma frase **indefinida** (`uma pessoa`, `um montante`) *introduz* uma variável.
Uma frase **definida** (`a pessoa`, `o coelho branco`) nunca introduz: só é uma
variável quando a **mesma frase** já introduziu uma variável com esse nome; caso
contrário nomeia uma **constante global** — o indivíduo que a frase denota,
escrito com o artigo (`o coelho branco`), o mesmo em todas as regras, cenários e
consultas do programa. Ver `examples/moreExamples/language/templates/white_rabbit.le` (em inglês).

Consequências:
- A ordem conta dentro de uma frase: a introdução tem de vir primeiro (as
  cabeças leem-se antes dos corpos, as condições da esquerda para a direita).
- Um erro de escrita numa retoma (`a pesoa`) já não se torna uma variável
  silenciosamente livre; torna-se uma constante que nada mais menciona, e a
  regra simplesmente não dispara.
- Para usar como variável uma frase definida que nada introduz, nomeie-a
  explicitamente: `*o coelho branco*` (§6.1).

### 6.1 Nomes e tipos de variáveis
- **Tipo** = o **substantivo principal** da frase; a frase completa é o **nome** da variável (identidade e apresentação).
- **Qualificador inicial:** um ordinal (`primeiro/primeira`, …, `décimo/décima`) ou `outro, outra, novo, nova, anterior, próximo, próxima, atual, último, última, mesmo, mesma, original, único, única, dado, dada`, antes do substantivo, distingue variáveis do mesmo tipo: `uma primeira pessoa` e `uma segunda pessoa` são **duas variáveis do tipo `pessoa`**.
- **Convenção de identificadores maiúsculos:** um identificador final (letra maiúscula única ou token curto em MAIÚSCULAS) é o nome da variável e o substantivo anterior é o tipo: `uma pessoa X`, `um número N`, `uma data D`.
- **Tipos multi-palavra genuínos** mantêm-se inteiros: `um dano corporal` tem o tipo `dano corporal`.
- Ocorrências repetidas da mesma frase co-referem (`uma primeira pessoa` … `a primeira pessoa`).
- **Cenários:** um determinante indefinido (`um/uma`) introduz uma variável; uma frase definida (`o pão`, `a casa`) é uma **constante**.

### 6.2 Verificação de tipos
O **tipo** de um argumento variável rejeita valores que não lhe pertencem. A
verificação é **preguiçosa** (dispara quando o argumento fica ligado) e
**tolerante** (só rejeita perante conflito claro; um argumento de tipo
desconhecido é sempre aceite). Consulta os factos `é um` da sessão (factos de
cenário) e da base de conhecimento.

- **Valores instância.** Um valor com tipo conhecido (há um facto `é um` para
  ele, p.ex. `este pagamento é um pagamento`) só é aceite num lugar de tipo `T`
  se *for um* `T` (diretamente, pela taxonomia, ou pelo substantivo principal).
  Um valor sem tipo conhecido não impõe restrição.
- **Valores tipo.** Quando o valor é ele próprio um *tipo* (raciocínio
  taxonómico), exige-se que seja subtipo do tipo do lugar — mas só quando esse
  tipo participa na ontologia.
- **Tipos universais.** `any`, e os tipos universais `thing`, `object`,
  `entity`, `asset`, `element`, aceitam qualquer valor.
- **Regras com o mesmo functor.** Regras cujas cabeças partilham um predicado
  mas declaram **tipos de argumento diferentes** são distinguidas pelo tipo,
  **apenas nas posições ambíguas** (onde os modelos do predicado discordam no
  tipo).

Numa árvore de explicação, uma verificação de tipo aparece como a asserção que
verifica, p.ex. `este pagamento é um pagamento`.

- **Constantes:**
  - Nomes próprios: `Alice`, `Bob`
  - Strings: `"Olá"`, `'Mundo'`
  - Números: `42`, `3,14` (vírgula decimal; ver §7)
  - Datas: `2023-10-27`

## 7. Aritmética e comparações
- **Matemática:** `+`, `-`, `*`, `/`, `( )`, divisão inteira `//` e resto `mod` (`R = N // 3 + N mod 3`)
- **Funções:** `ceiling`, `floor`, `round`, `truncate`, `integer`, `abs`, `sign`, `sqrt`, aplicadas a um argumento entre parênteses; avaliadas por `is/2` do Prolog.
- **Comparação:** `=`, `>`, `<`, `>=`, `<=`, `==`, `!=`
- **Números:** em Português Lógico o separador decimal é a **vírgula** (`1,5`) e o separador de milhares é o **ponto** (`1.234.567`). Uma vírgula imediatamente entre dígitos é decimal; nas listas escreva `[1, 5]` (vírgula seguida de espaço). As datas mantêm o formato ISO (`2026-07-15`).
- **Nomes de variáveis em expressões:** numa expressão aritmética, uma palavra só é reconhecida como variável se for um **identificador** (letra maiúscula única ou token curto em MAIÚSCULAS), p.ex. `ENT = ETI * ATR - TO`. Uma palavra descritiva como `montante` é tratada como parte de um tipo e não co-refere com a variável da cabeça.
- **Modelos de sistema:**
  - `*V1* é igual a *V2*`
  - `*V1* não é igual a *V2*` / `*V1* é diferente de *V2*`
  - `*V1* é superior ou igual a *V2*` (números)
  - `*V1* é inferior ou igual a *V2*` (números)
  - `*V1* é superior a *V2*` (números)
  - `*V1* é inferior a *V2*` (números)
  - `*V1* é posterior ou igual a *V2*` (datas)
  - `*V1* é anterior ou igual a *V2*` (datas)
  - `*V1* é posterior a *V2*` (datas)
  - `*V1* é anterior a *V2*` (datas)
  - `*V1* é *V2* dias depois de *V3*` (datas e números)
  - `*V1* é *V2* meses depois de *V3*` (meses de calendário, para datas): com V3
    e V2 dados, V1 é calculado, mantendo o dia quando o mês o tem e senão o
    último dia do mês (31 de agosto + 6 meses = 28 de fevereiro); com as duas
    datas dadas, V2 é o número de meses INTEIROS entre elas. Um prazo lê-se
    `um limite é 6 meses depois de a data e a outra data é anterior ou igual a
    o limite` — nunca "183 dias".
  - `*V1* é conhecido` (ou `é conhecida`)
  - `*V1* é o caso` (V1 uma frase: prova a frase que uma variável contém)
  - `*V1* está em *V2*` (pertença a lista)
  - `o mínimo de *V1* e *V2* é *V3*` (números)
  - `o máximo de *V1* e *V2* é *V3*` (números)
- **Não há FUNÇÕES `min`/`max`.** "O menor do limite e do custo" é uma condição,
  não uma expressão: escreva `e o mínimo de L e R é P`, nunca `e P = min(L, R)`
  (analisa-se, mas falha em tempo de execução).

### 7.1 Datas
- **Representação:** as datas são analisadas pelo tokenizador e representadas como `date(Ano, Mês, Dia)`.
- **Comparações:** cronológicas, através dos modelos de sistema acima (`é posterior a`, `é anterior a`, …), que correspondem às comparações de termos do Prolog (`@>`, `@<`, `@>=`, `@=<`) e ordenam corretamente os termos `date(A, M, D)`.

## 8. Taxonomia (ontologia)
- **Hierarquia é-um:** `<Subtipo> é um <Supertipo>` ou `<Subtipo> é uma <Supertipo>`
- **Exemplo:** `um estudante é uma pessoa.`

## 9. Palavras ignoráveis
O analisador ignora certas palavras "de enchimento" ao emparelhar modelos:
- `um`, `uma`, `o`, `a`, `os`, `as`
- `são`, `era`, `eram`, `foi`, `foram`
- `tem`, `têm`, `tinha`, `tinham`, `sido`

## 10. Comentários
- **De linha:** `%`
- **De bloco:** `/* ... */`

## 11. Meta-modelos
O Português Lógico suporta meta-predicados que recebem outras frases como argumentos.
- **Palavras-chave:** `diz`, `que`
- **Exemplo:** `*a lei* diz que *a pessoa* é responsável.`
- Um modelo cuja `*variável*` final é imediatamente precedida por `que` (ou `diz`) é um **meta-modelo**: esse argumento é interpretado como uma frase embutida.
- Nota: `que` é muito frequente em português; evite `que` imediatamente antes de uma `*variável*` em modelos que **não** sejam meta-modelos (prefira, p.ex., `é superior a` em comparações).

## 12. Testes e expectativas
Os cenários podem declarar resultados esperados para consultas, usados pelo executor de testes.
- **Sintaxe:** `<NomeDaConsulta> espera respostas ["Resposta 1", "Resposta 2"] e desconhecidos ["Desconhecido 1"].` (A parte `e desconhecidos [...]` é opcional, e a palavra `respostas` também.)
- A expectativa nomeia a consulta diretamente — **não** a prefixe com `consulta`.
- **Consultas de inversão** (§17.7) declaram os conjuntos mínimos de alterações esperados: `<NomeDaConsulta> espera alterações [["acrescentar: <facto>"], ["retirar: <facto>", "acrescentar: <facto>"]].`
- **Quando correm:** o executor de testes (`runTests`, `runTestsFor/2`) corre
  todas as expectativas. A verificação — cada carregamento no editor — também
  as corre, dentro de um orçamento de tempo (flag Prolog
  `le_verify_tests_seconds`, 5 segundos por omissão): os testes que sobram são
  reportados uma vez, com o aviso `tests_not_run`.
- **Exemplo:**
  ```le
  cenário alice é:
      John nasceu em o Reino Unido em 2021-10-09.
      um espera respostas ["John adquire cidadania britânica em 2021-10-09"].
  ```

## 13. Predicados de sistema
Acessíveis via a palavra-chave `prolog` (§15.6) ou usados para introspeção — os
mesmos do LE inglês:
- **`le_my_kb(KB)`**: o nome do módulo da base de conhecimento atual.
- **`le_my_id(ID)`**: o identificador da regra ou facto atual.
- **`le_type(Tipo)`**: verdadeiro se `Tipo` é um tipo conhecido.
- **`is_a(Subtipo, Supertipo)`**: verdadeiro se `Subtipo` descende de `Supertipo` na taxonomia.
- **`le_source_element(IdRegra, Designador, Objetivo)`**: associa designadores hierárquicos (p.ex. `1.1.a`) aos objetivos de uma regra numerada.
- **`le_source_section(Secção, IdRegra)`**: a secção de cada regra (§3.1); `main` sem marcador.
- **`le_source_info(Ref, Início, Fim, ID)`**: localização na fonte e ID de uma cláusula.
- **`le_issue(Gravidade, Tipo, Descrição, Correção, Início, Fim)`**: um problema de análise ou verificação.
- **`le_dict(dict(FunctorArgs, TiposComNome, PalavrasEVariáveis))`**: a representação interna de um modelo.
- **`le_kb(Nome)`**: o nome da base de conhecimento tal como escrito.
- **`scenario(Nome, Factos)`**, **`query_info(Nome, Objetivo, Itens)`**, **`le_expected(Consulta, Cenário, Respostas)`**, **`ontology(Conteúdo)`**: cenários, consultas, expectativas e ontologia do programa.

## 14. Recursos incluídos
```le
a base de conhecimento minhaBC inclui estes recursos:
    Recurso1, Recurso2.
```
- **Recursos:** caminhos relativos (p.ex. `familia_real`) ou URLs; a extensão `.le` é implícita.
- **Comportamento:** regras, factos, modelos e ontologia incluídos são adicionados à base local; cenários e consultas dos recursos incluídos são ignorados.
- **Transitividade:** as inclusões seguem-se transitivamente até uma profundidade máxima (flag Prolog `le_include_max_depth`, 5 por omissão); repetições e ciclos são detetados; cada caminho resolve-se **relativamente à localização do ficheiro que o inclui**. Os recursos devem estar **na mesma linguagem** do programa que os inclui.
- **Restrição a caminhos locais:** um recurso local só pode ser incluído se estiver dentro da árvore de diretórios do ficheiro que o inclui (ou for um ficheiro do servidor permitido por `restricted_paths`). URLs `http(s)` externos não têm restrição.
- **Posições na fonte:** cada recurso `.le` incluído é analisado com os seus deslocamentos de caracteres numa gama própria, pelo que nada registado para ele (regra, condição, problema, proveniência) se confunde com o documento que o inclui. As respostas de `/leapi` anotam uma gama dentro de um recurso com `resource`, `resourceExample`, `resourceLine`, `resourceStart`, `resourceEnd`; o editor abre então o recurso nessa linha num novo separador.

### 14.1 Recursos Prolog (`.pl`)
Um recurso com extensão explícita `.pl` (ficheiro ou URL) é um **recurso
Prolog** — uma forma de apoiar uma base de conhecimento LE num ficheiro de
factos/predicados Prolog (p.ex. uma grande tabela) exposto por uma *camada
fina* de modelos LE com corpos `prolog` (§15.6). O programa principal inclui a
camada, e a camada inclui o `.pl`:
```le
a linguagem alvo é: prolog.
a base de conhecimento camada inclui estes recursos:
    codigos_postais.pl.
os modelos são:
    *um código postal* fica em *uma região*.
a base de conhecimento camada inclui:
    um código postal fica em uma região se
        prolog codigo_regiao(o código postal, a região).
```
- **O carregamento só faz asserções** (nunca `consult`): as cláusulas são
  asseridas num módulo de cache endereçado pelo conteúdo. As únicas diretivas
  honradas são `dynamic/1`, `discontiguous/1` e `use_module(library(...))`; uma
  diretiva `:- module(...)` é retirada (com aviso) e as outras são ignoradas com
  aviso. Um `.pl` remoto não pode executar código só por ser incluído.
- **Segurança em execução:** cada objetivo `prolog` é verificado por
  `library(sandbox)` antes de correr; instalações de confiança podem
  desligá-lo com a flag `le_sandbox_prolog` a `false`.
- **Cache:** um `.pl` em ficheiro recarrega quando muda a data de modificação;
  um `.pl` por URL é obtido uma vez por execução do servidor.
- Ver `examples/moreExamples/language/includes/prolog_resources/` (em inglês).

### 14.2 Bibliotecas incluídas (`lib/`)
As bibliotecas são recursos LE comuns guardados em `lib/` e copiados para junto
do programa que as inclui. Estão escritas em **inglês** (um recurso tem de
estar na linguagem do programa que o inclui, §14):
- **`lib/temporal.le`** (+ `temporal.pl`) — datas, períodos e *lock times*:
  idades, anos/meses/dias inteiros entre datas, pertença a um período, primeiro
  e último dia de um mês, anos bissextos, *lock times* de Bitcoin.
- **`lib/deontic.le`** — obrigações, permissões e proibições: quem está
  obrigado, e o que é violado, num caso.

Ver §14.2 de [language.md](language.md) para os modelos de cada uma.

## 15. Extensões LE
Funcionalidades para além das construções nucleares acima. As marcadas
**[requer le_extensions.pl]** dependem do módulo proprietário
`le_extensions.pl` e só estão disponíveis onde ele está instalado (o serviço
alojado); sem ele não são analisadas, pelo que convém preferir as formas
nucleares. A referência inglesa destas construções é
[extensions.md](extensions.md).

### 15.1 Regras `apenas se` (condições necessárias)
`Cabeça apenas se Corpo.` (sinónimo: `somente se`) diz que Corpo é uma condição
**necessária** para Cabeça. Compila para *"oposto-da-Cabeça se não é o caso que
Corpo"*:
- Se o modelo da Cabeça declara `; oposto:`, essa forma é a conclusão da regra
  derivada.
- Sem oposto declarado, a conclusão é a negação simples da Cabeça.
```le
os modelos são:
    casarei com *uma mulher*; oposto: não casarei com *uma mulher*.
    amo *uma mulher*.

casarei com uma mulher se a mulher é "Alice".        % condição suficiente
casarei com uma mulher apenas se amo a mulher.       % condição necessária
```
As regras `se` dão condições suficientes; as regras `apenas se` funcionam como
restrições que produzem conclusões negativas.

### 15.2 Orações relativas com `qual` **[requer le_extensions.pl]**
`qual` continua uma condição com uma oração sobre a **última variável** da
condição anterior, evitando repetir um nome:
```le
uma pessoa é antepassado de uma outra pessoa
    se a pessoa é progenitor de um filho
    qual é antepassado de a outra pessoa.
```
(`qual` = `o filho`.) Em **cabeças de regras e factos** ("grandes
conclusões"), a cabeça fica só com a parte antes do primeiro `qual`; cada
oração `qual` torna-se uma condição do corpo:
```le
cobriremos um custo
    qual é relativo a um dano
    qual é causado por um cano rebentado
se não é o caso que
    o dano é causado por desgaste.
```

### 15.3 `a menos que` dentro de corpos **[requer le_extensions.pl]**
As formas nucleares são `Cabeça se Corpo a menos que Condição.` (§4). A extensão
permite também `a menos que` (ou `e a menos que`, `salvo se`, `e salvo se`)
**dentro** de um corpo, inline ou governando um bloco indentado — equivalente a
`e não é o caso que <as condições negadas>`:
```le
pagaremos um sinistro se
    o sinistro é coberto
    e a menos que
        o sinistro é fraudulento.
```

### 15.4 Alternativas agrupadas: `uma das seguintes:` / `alguma das seguintes:` / `pelo menos uma das seguintes:` / `todas as seguintes:` **[requer le_extensions.pl]**
Uma linha do corpo formada por um destes conectivos agrupa os seus filhos
indentados: `uma das seguintes`, `alguma das seguintes` e `pelo menos uma das
seguintes` ligam-nos com OU; `todas as seguintes` liga-os com E. (Também nas
formas masculinas: `um dos seguintes`, `algum dos seguintes`, `pelo menos um
dos seguintes`, `todos os seguintes`.) Cada filho direto é uma alternativa com
a sua própria estrutura:
```le
um requerente é elegível se
    uma das seguintes
        o requerente é pobre
        todas as seguintes
            o requerente está doente
            não é o caso que
                o requerente tem outro rendimento.
```
Num corpo numerado (§15.5) um item pode ser uma negação — `3. não é o caso que
o requerente tem outro rendimento.` — com o objetivo negado na linha do item ou
como seus subitens. Nota: num corpo **numerado**, o item `todas as seguintes:`
não é reconhecido atualmente em português (o analisador procura a palavra `de`,
que esta forma não tem); `uma das seguintes:` funciona. Use um corpo não
numerado para um grupo `todas as seguintes`.

### 15.5 Rótulos de regras e corpos numerados **[a numeração requer le_extensions.pl]**
Uma regra pode ter rótulo: `regra <nome>: Cabeça se ...` — o rótulo torna-se o
ID da regra (visível em `le_source_element/3` e `le_source_info/4`, §13).
Um rótulo pode também indicar de onde vem a regra (LE nuclear, sem extensão):
um documento e, se possível, um lugar nele:
```le
regra r1 com proveniência a apólice em cláusula 4, confira "pagamos danos acidentais":
um sinistro é pagável
    se o sinistro é por um dano
    e o dano é acidental.
```
`com proveniência <documento>` — um nome, ou uma string entre aspas como um URL
— opcionalmente seguido de `em <localizador>` (também `na`, `no`) ou de
`, confira "<passagem>"` (também `confer`; uma citação do documento, §17.1).
Aceitam-se também os complementos de um facto (`de acordo com`, `conforme
consta em`, `porque`). Fica registado como `le_rule_provenance(ID, Prov)` e não
muda nada na prova; as explicações e o editor mostram-no (§17.1,
*Documentos*). O cabeçalho de uma tabela de decisão aceita a mesma adição:
`a tabela escalões é, com primeira correspondência, com proveniência a lei:`.

Com a extensão, um corpo introduzido por `se:` pode ser escrito como um esboço
numerado que espelha uma cláusula de lei ou contrato, com `; e` / `; ou` no fim
de cada item:
```le
regra jd:
um requerente é elegível se:
1. uma das seguintes:
1.1. o requerente é pobre; ou
1.2. o requerente está doente; e
2. não é o caso que o requerente tem outro rendimento.
```
Cada condição numerada é endereçável pelo seu designador hierárquico através de
`le_source_element(IdRegra, Designador, Objetivo)`.

### 15.6 Objetivos Prolog embutidos **[a resolução requer le_extensions.pl]**
Uma condição da forma `prolog <objetivo>` (conjunções entre parênteses:
`prolog (g1, g2)`) chama Prolog diretamente. As variáveis LE referem-se dentro
do objetivo como frases `o <nome>` / `a <nome>`, marcadores `*um nome*` ou
identificadores em MAIÚSCULAS, e ficam ligadas aos resultados:
```le
um sinistro tem identificador um id se
    o sinistro está coberto
    e prolog le_my_id(o id).
```

### 15.7 Encadeamento preposicional **[requer le_extensions.pl]**
O marcador `; preposicional` e o seu uso encadeado estão descritos em §2.1; o
*encadeamento* em si (omitir o argumento inicial para que uma frase se expanda
numa conjunção de condições) é resolvido pelo módulo de extensões.

## 16. Humanizar o LE
- **Use `apenas se` para condições necessárias**, com a forma `; oposto:` declarada.
- **Use adições preposicionais para encadear numa só frase:** `faremos um pagamento ao abrigo de esta apólice relativo a um sinistro`.
- **Use `qual` para continuar um pensamento** sem repetir variáveis.
- **Use `a menos que` para exceções.**
- **Use blocos `uma das seguintes:` / `todas as seguintes:`** para alternativas enumeradas.
- **Espelhe a estrutura do documento fonte:** rotule regras com `regra <nome>:`, use corpos numerados, agrupe com `secção ... é:` / o cabeçalho de anexos, e cite a cláusula num comentário `%` ou com `com proveniência`.
- **Declare formas `; sinónimo:`** para que factos, cenários e consultas usem a formulação mais natural em cada contexto.
- **Mantenha a redação dos modelos próxima do texto fonte**, deixando as palavras ignoráveis (um/uma/o/a/é/são...) suportar a gramática.
- **Marque o estatuto epistémico** com `; assumível` (juízo pericial), `; julgado` (decisão de alguém) e `; indefinido` (dados do caso).
- **Nomeie indivíduos com significado:** constantes descritivas sem determinante (`sinistro um`, `lesão no pulso`, `Reino Unido`).

## 17. Construções para decisões regulatórias
Construções para programas que aplicam regras escritas a casos registados — a
forma de uma decisão regulatória (aplicabilidade, um predicado contestado,
remédio), onde cada facto tem uma fonte e o predicado contestado é decidido
por alguém. Os exemplos, em inglês, estão em `examples/regulatory/`;
`eu261_integration.le` usa-os todos em conjunto. Os exemplos em português
abaixo foram verificados com o analisador.

### 17.1 Complementos de proveniência e modelos julgados
Qualquer facto de cenário (ou da base de conhecimento) pode ter
**complementos**, cada um depois de uma vírgula, por qualquer ordem:

| Complemento | Significado |
|---|---|
| `de acordo com <fonte>` (ou `segundo <fonte>`) | quem afirma o facto — uma parte, uma testemunha, um tipo de documento, um serviço, um tribunal. `<fonte>` é uma constante comum. |
| `conforme consta em <documento> em <localizador>` (também `conforme consta no`/`na`; localizador `em`/`na`/`no`) | onde está escrito (o localizador é opcional). Sem `de acordo com`, o documento é a fonte. |
| `porque "<texto>"` | a justificação. |
| `confira "<passagem>"` (ou `confer`) | uma citação da passagem do documento que afirma o facto (o documento é o de `conforme consta em`, ou o do cenário). |

```le
cenário decidido é:
    o sinistro um é por o cano rebentado, conforme consta em o formulário em secção 2.
    o cano rebentado é acidental,
        de acordo com o perito, conforme consta em relatório LA-17 em página 3,
        porque "não havia corrosão visível".
```
Os complementos podem começar na linha do facto ou na seguinte (a linha acaba
então com a vírgula).

**A proveniência por omissão de um cenário.** O cabeçalho diz uma vez de que
documento vêm os factos, e cada facto aponta só a sua passagem:
```le
cenário por_decidir é, conforme consta em o formulário:
    o sinistro um é por o cano rebentado, confira "o cano rebentou".
    o cano rebentado foi comunicado dentro do prazo.
```
Um facto sem complementos toma a proveniência por omissão; um cujos
complementos não nomeiam documento (`confira`, `de acordo com`, `porque`) toma
o documento por omissão; um com o seu próprio `conforme consta em`
redefine-o. Uma vírgula que *não* é seguida de um complemento continua a fazer
parte do facto.

- **A prova não muda.** O facto é compilado como sem complementos. A
  proveniência é registada ao lado (`le_fact_provenance/4`) e cada sessão
  carregada com o cenário recebe `le_provenance(Facto, Fonte, Documento,
  Localizador, Justificação)` (`none` para uma parte em falta).
- **As explicações** apresentam o facto provado com os seus complementos, tal
  como escritos.
- **`os factos do cenário exigem proveniência.`** (também `os fatos do cenário
  exigem proveniência.`) — frase ao nível do programa (depois da linha da
  linguagem alvo). Cada facto de cenário sem complemento recebe então o aviso
  `fact_without_provenance`.
- **`; julgado`** (adição de modelo, §2): o predicado é decidido, não derivado.
  O resolvedor trata-o como `; assumível` (ver a regra do resultado abaixo).
  Efeitos:
  - uma regra cuja conclusão é um modelo julgado é um **erro**
    (`judged_with_rules`);
  - um facto julgado num cenário sem `de acordo com` nem `porque` recebe o
    aviso `judgment_without_provenance`;
  - uma instância em aberto (assumida) aparece nas explicações como
    `o cano rebentado é acidental (julgamento necessário)`; a lista de
    desconhecidos da resposta não muda (`"o cano rebentado é acidental"`);
  - **o último argumento é o resultado** quando o modelo tem dois ou mais
    (como para um serviço, §17.6): uma vez registado um resultado para uma
    questão, nenhum outro é assumido; uma questão sem nada registado fica em
    aberto, um julgamento necessário por cada resultado que as regras tentem.
    Por isso formule um modelo julgado com o resultado no fim.

**Documentos.** Um documento citado é uma constante comum (`a apólice`) ou uma
string entre aspas (um URL). Dois modelos de sistema dizem onde está:
```le
a apólice está publicada em "https://example.org/apolice".
o texto de a apólice está em "fontes/apolice.txt".
```
(também `está publicado em`). O primeiro é a página que um leitor abre; o
segundo é o texto simples do documento — um ficheiro junto do programa
(resolvido na pasta do programa, nunca fora dela) ou um URL (JSON: o seu campo
`text`; HTML: o texto da página; não PDF). Estes factos não precisam de
proveniência própria. Com eles:
- uma **citação** — `confira "..."`, ou um localizador entre aspas — é
  verificada contra o texto do documento quando esse texto é um ficheiro junto
  do programa, ignorando espaços e maiúsculas (aviso `quote_not_found` caso
  contrário);
- cada nó de explicação provado por um facto citado ou por uma regra com
  rótulo leva a sua proveniência, e o editor mostra nele um distintivo **§**:
  o visualizador mostra o texto do documento com a passagem realçada, e
  *Abrir original* abre o endereço publicado;
- no próprio programa, o menu de contexto do editor oferece **Mostrar o texto
  original** em qualquer linha que cite um documento com endereço.

**Os valores que um lugar lê.** Para cada lugar de um modelo de cenário, o
próprio programa diz que valores importam: os que as suas regras leem aí (os
factos de um predicado que partilha a variável, os membros de uma lista com que
é testado, as constantes passadas a uma conclusão, a coluna de uma tabela). Os
formulários de factos do editor (Editor de cenários, Variações de cenário)
oferecem-nos como sugestões, e o verificador avisa **`unread_value`** quando um
facto de cenário põe aí um valor que nenhuma regra, facto ou linha de tabela
menciona e um valor lido pelas regras está próximo dele ("Queria dizer …?").

### 17.2 Cascatas `caso contrário`
Uma linha do corpo que **começa** por `caso contrário` (ou `senão`) inicia uma
nova alternativa. Tem precedência inferior a `e`/`ou`: tudo o que vem antes (no
mesmo bloco) é a alternativa anterior.
```le
a taxa de desconto para um cliente é uma taxa
    se o cliente é sócio
    e a taxa é 20
    caso contrário o cliente é estudante
    e a taxa é 10
    senão a taxa é 0.
```
`A caso contrário B` significa `A`, ou então — só quando `A` falha — `B`;
compila para `A ou (não é o caso que A, e B)`, pelo que exatamente uma
alternativa se aplica. Detalhes:
- **A guarda são as condições da alternativa anterior.** Um conjunto que só
  atribui uma saída (`e a taxa é 20`, uma variável que nenhum outro conjunto da
  alternativa usa) fica fora da guarda. O teste é sintático: uma alternativa
  que acaba testando uma tal variável (`… e o código é igual a "X"`) perde esse
  teste na guarda seguinte; escreva a constante primeiro (`"X" é igual a o
  código`).
- **Decida um caso de cada vez.** A guarda é uma negação por falha: as suas
  variáveis devem estar conhecidas quando a cascata é alcançada (encontre
  primeiro o indivíduo, p.ex. numa regra que chama a cascata).
- **Disposição.** Só uma linha que *começa* pela palavra-chave é uma linha de
  cascata. Dentro de um bloco aninhado a cascata tem o âmbito dado pela
  indentação. **Em português, escreva cada condição de uma alternativa na sua
  própria linha**, como acima: uma linha como `o cliente é sócio e a taxa é 20`
  é lida inteira como uma só frase e não é dividida no `e`.
- **As explicações** mostram a guarda falhada como uma negação que aponta para
  a linha `caso contrário`.

### 17.3 Tabelas de decisão
Uma **tabela de decisão** é uma secção própria, ligada ao ÚNICO modelo cujas
palavras a nomeiam (`... segundo a tabela envio` — as palavras do modelo acabam
em `tabela <nome>`):
```le
os modelos são:
    o custo de envio para um peso de *um número* kg é *um custo* segundo a tabela envio.

a tabela envio é, com primeira correspondência:
    escalão | peso kg          | custo
    p       | <= 1             | 5
    m       | > 1 e <= 10      | 12
    g       | > 10             | 30
```
- **Colunas ↔ argumentos, por ordem.** Quando a tabela tem uma coluna a mais do
  que o modelo tem argumentos, a primeira coluna é o **id da linha** (citado nas
  explicações); senão as linhas são numeradas. A **última** coluna é a saída; as
  outras são entradas.
- **Células:** uma constante (lida como um valor de cenário), `qualquer` ou `-`
  (sem condição), uma lista de constantes ligadas por `ou`, ou uma condição —
  comparações `<`, `<=`, `>`, `>=`, `=`, `!=` ligadas por `e`/`ou`
  (`> 1 e <= 10`). Uma entrada com uma célula-condição tem de estar conhecida
  quando a tabela é consultada.
- **Políticas de correspondência** (DMN): `com primeira correspondência` (a
  primeira linha cujas entradas correspondem), `com correspondência única` (por
  omissão: duas linhas correspondentes são um erro em execução),
  `com todas as correspondências` (todas as linhas — para uma relação como uma
  lista de códigos).
- **Tabelas carregadas:** `a tabela códigos é carregada de cp.csv, com todas as correspondências:`
  (também `carregada a partir de`) seguida da linha de cabeçalho; o CSV (junto
  do programa ou numa pasta dentro dele) fornece as linhas. Uma primeira linha
  do CSV que repete o cabeçalho é ignorada. As linhas são guardadas em cache e
  relidas quando o ficheiro muda.
- **As explicações** citam a linha: `linha g da tabela envio`.
- **Uma coluna de citação.** Uma coluna de uma tabela inline pode citar, linha
  a linha, a passagem que cada linha codifica. O cabeçalho é `confira` (as
  passagens estão no documento que o `com proveniência` da tabela nomeia) ou
  `conforme consta em <documento>` (outro documento); cada célula é uma passagem
  entre aspas, ou vazia:
  ```le
  a tabela escalões é, com primeira correspondência, com proveniência a lei:
      linha | valor  | escalão | confira
      a     | <= 10  | baixo   | "até dez"
      b     | > 10   | alto    | ""
  ```
  A coluna não é um argumento do modelo. A passagem de cada linha torna-se a
  proveniência da linha, como a de um facto (§17.1). Tabelas carregadas (CSV)
  não têm coluna de citação.
- A tabela compila para uma cláusula do seu modelo, `Cabeça :- le_table(Nome,
  Args)`, mais registos de linhas. Erros no carregamento:
  `table_without_template`, `table_arity_mismatch`, `table_row_width`,
  `table_bad_cell`, `table_bad_output`, `table_csv_missing`.

### 17.4 O esqueleto de decisão: aplicabilidade, questão, remédio
Nenhuma palavra-chave nova: a macro-estrutura de uma decisão — *a regra é
aplicável, qual a resposta à questão, o que se segue* — escreve-se com os
marcadores de secção comuns (§3.1) e três nomes reservados:
```le
secção aplicabilidade é:
uma pessoa está abrangida se a pessoa é residente.

secção questão é:
uma pessoa é elegível
    se a pessoa está abrangida
    e a pessoa tem baixos rendimentos.

secção remédio é:
uma pessoa recebe ajuda se a pessoa é elegível.
```
(`reparação` é sinónimo de `remédio`.) A resolução não muda. O que os nomes
acrescentam é a leitura de uma consulta **falhada**:
- **`a consulta falha na secção *uma secção*`** (também `a consulta falha na
  seção …` e `a consulta falha em *uma secção*`) — um modelo de sistema,
  verdadeiro quando a primeira consulta do programa ("a consulta") não tem
  resposta, nomeando a secção onde falha: a primeira, pela ordem da lista
  (aplicabilidade, questão, remédio, depois as outras secções com nome pela
  ordem da fonte), que tem uma regra para um objetivo que a tentativa tentou e
  não provou. `a consulta *um nome* falha na secção *uma secção*` faz o mesmo
  para uma consulta com nome.
  ```le
  consulta etapa é:
      a consulta falha em qual secção.
  ```
  responde `a consulta falha em aplicabilidade` para um não residente.
- **As explicações de falha começam pela lista**:
  `lista de secções: aplicabilidade passou, questão falhou, remédio não alcançada`.
  Programas que não usam os nomes reservados não são afetados.

### 17.5 Prova restrita a uma fonte: `de acordo com` numa regra
Num corpo de regra (ou consulta), `de acordo com <âmbito>` (ou `segundo
<âmbito>`) restringe a prova da(s) condição(ões) anterior(es) à evidência de
uma fonte — o ónus da prova:
```le
um inquilino deve a multa por atraso
    se a renda de o inquilino está em atraso
    e o aviso foi entregue a o inquilino
        de acordo com o senhorio.

o estafeta é admissível segundo o senhorio.
```
`G de acordo com S` é verdadeiro sse G é demonstrável com as regras e factos do
próprio programa mais só os **factos de cenário** cuja fonte de proveniência
(§17.1: o seu `de acordo com`, senão o documento de `conforme consta em`) é
**admissível segundo S**. Um facto de cenário sem proveniência nunca é
admissível numa prova restrita; os factos da base de conhecimento são-no sempre.
- **Disposição.** Numa linha própria aninhada sob uma condição (restringe essa
  condição), numa linha depois de várias condições do mesmo nível (restringe-as
  a todas), ou no fim da linha da própria condição.
- **Admissibilidade** é o modelo de sistema `*uma fonte* é admissível segundo
  *um âmbito*` (também `é admissível sob`), por omissão a identidade; os
  programas acrescentam factos ou regras.
- **O âmbito** é um valor comum: uma constante, uma variável introduzida antes,
  ou uma nova (`de acordo com uma parte` liga a parte cuja evidência estabelece
  a condição).
- **Presunções** não precisam de sintaxe: `G se não é o caso que <não-G> de
  acordo com <a outra parte>`.
- **As explicações** mostram a evidência que não pôde usar:
  `o aviso foi entregue a ana, de acordo com ana, não é admissível segundo o senhorio`.
- Não disponível no motor s(CASP).

### 17.6 Serviços e predicados semânticos sobre texto
Alguns predicados não podem ser decididos por regras porque os seus argumentos
são texto livre. Um programa pode declarar **serviços** e apoiar modelos neles:
```le
a base de conhecimento semântica inclui estes serviços:
    comparador em stub:matcher como um comparador semântico.

os modelos são:
    a melhor escolha de *um texto* entre *uma lista* é *uma categoria*; via serviço comparador.
```
- **Declaração**: `a base de conhecimento <nome> inclui estes serviços:`
  seguido de `<nome> em <endereço> como um <tipo>`, separados por vírgulas,
  terminando em ponto. Endereços: `http(s)://...` (o pedido é enviado por POST
  em JSON, a resposta é `{"answers": [[arg, ...], ...], "rationale": "..."}`),
  `llm:<modelo>` (um modelo de linguagem através de `llm/llm_client.pl`), ou
  `stub:matcher` / `stub:judge` (os stubs determinísticos de teste). O tipo
  reconhecido é `comparador semântico`.
- **`; via serviço <nome>`** (adição de modelo): os objetivos do modelo são
  respondidos por esse serviço. O **último** argumento pode ser desconhecido (o
  serviço preenche-o); todos os outros têm de estar conhecidos quando o objetivo
  é alcançado. Com todos conhecidos, o serviço responde sim ou não.
- **Modelos semânticos de sistema**, apoiados no primeiro serviço declarado
  `como um comparador semântico`:
  `*um texto* é semanticamente semelhante a *um segundo texto*`,
  `a melhor correspondência de *um texto* entre *uma lista* é *um item*`,
  `*um texto* satisfaz a descrição *uma descrição*`.
- **Chamar uma vez, guardar.** Cada pedido distinto é feito **uma vez por
  sessão**; quando a flag Prolog `le_service_cache_dir` nomeia uma pasta, as
  respostas ficam também aí, endereçadas pelo pedido, e são reutilizadas entre
  sessões e programas.
- **Atribuição.** Uma resposta entra na prova atribuída ao serviço (`de acordo
  com serviço comparador`, com a justificação do serviço), e uma prova restrita
  (§17.5) só a admite segundo esse serviço (ou um âmbito segundo o qual seja
  admissível).
- **Serviço inacessível**: sem nada em cache, o objetivo torna-se um
  desconhecido — uma resposta condicional, não um erro.
- **Materializar**: `le_services:service_materialise(Sessão, KB, Linhas)`
  escreve as respostas que uma sessão usou como factos de cenário comuns.
- Verificador: `service_undeclared` (erro) para `; via serviço X` sem X
  declarado, ou um modelo semântico de sistema sem comparador semântico.

### 17.7 Consultas de inversão: que alteração mínima inverte o resultado
```le
consulta inverter é:
    que alteração mínima ao cenário faz com que
        rico recebe ajuda.
```
(também `que alterações mínimas ao cenário fazem com que`; o objetivo pode ser
`não é o caso que G`.) As respostas são os **conjuntos mínimos de alterações** —
o menor número de alterações, e todos os conjuntos desse tamanho que funcionam
— depois das quais o objetivo se verifica sem suposições, ou, para `não é o
caso que G`, G deixa de ter prova. Uma alteração **acrescenta** ou **retira** um
facto de um modelo elemento de cenário: um marcado `; indefinido` ou `; julgado`
(§17.1) — ou, num programa que não marca nenhum, qualquer modelo que nenhuma
regra conclui. Predicados derivados nunca mudam.
- Uma resposta apresenta-se como as suas alterações: `acrescentar: rico tem
  baixos rendimentos` (várias ligadas por `e`; `nenhuma alteração é necessária`
  quando o objetivo já se verifica), explicada pela prova do cenário alterado.
- A instância em aberto de um modelo julgado é uma alteração de um passo como
  qualquer outra.
- **Expectativas**: `inverter espera alterações [["acrescentar: rico tem baixos rendimentos"]].`
  (a ordem não conta, dentro e entre conjuntos).
- **A pesquisa** é guiada pela explicação e verificada: os candidatos vêm só do
  que uma tentativa do objetivo tocou; os conjuntos crescem uma alteração de
  cada vez, aplicada a uma cópia da sessão. Limites: flags Prolog
  `le_flip_max_changes` (3 por omissão) e `le_flip_max_evaluations` (400).
- **Factos mantidos**: um pedido pode nomear modelos que a inversão deixa como
  estão (campo `keep` de `answeringQuery`; numa vista, `a inversão mantém …`,
  §17.10).
- **Sem escrever a consulta**: a inversão é também uma consulta personalizada;
  o botão **Inverter…** do editor, ao lado de **Consulta**, compõe-na a partir
  da resposta selecionada, negada, ou da própria consulta quando não tem
  resposta.

### 17.8 Fatores e precedentes: um padrão, não sintaxe
Decidir uma questão de textura aberta (`; julgado`) a partir de decisões
anteriores — o *result model* de Horty — não precisa de construção própria.
`examples/regulatory/precedent.le` é uma biblioteca em LE simples (em inglês,
pelo que só pode ser incluída por programas em inglês, §14); um programa
fornece **fatores** (regras que os nomeiam, e para que lado apontam), a **base
de casos** (factos sobre cada caso decidido, citados com complementos, §17.1) e
o **gancho**, uma cascata `caso contrário` (§17.2) à volta do predicado julgado.
Uma situação é *forçada a favor* de uma questão por um caso que decidiu a favor
quando tem pelo menos os fatores a favor do caso e no máximo os seus fatores
contra (e simetricamente *contra*). Ver `examples/regulatory/precedent_pattern.le`.

### 17.9 Factos a partir de um documento
O diálogo *Escreva em Português…* do Editor de cenários também extrai factos de
um documento. Em *A partir de um documento*, dê o nome do documento (a
constante que os factos vão citar) e, opcionalmente, o endereço do seu texto
(um URL, ou um ficheiro junto do programa — *Obter texto* carrega-o); cole ou
obtenha o texto e carregue em *Gerar*:
- os factos são instâncias dos modelos do programa — incluindo os dos recursos
  que inclui — e cada um cita a passagem que o afirma (`<facto>, confira
  "<passagem>"` sob um cenário cujo cabeçalho nomeia o documento);
- quando o programa marca os seus modelos de cenário (`; indefinido` ou
  `; julgado`), só esses são oferecidos, cada um com os valores que as regras
  leem em cada lugar; senão todos os modelos são oferecidos;
- um modelo `; julgado` só é escrito quando o texto relata a decisão de alguém
  (`de acordo com <quem>`, `porque "..."`); um modelo que as regras concluem
  nunca é escrito;
- cada passagem é verificada contra o texto (aviso `quote_not_in_text` quando
  o modelo parafraseou), e os factos são verificados contra o programa;
- com um endereço, são acrescentados também os factos que dizem onde está o
  documento (§17.1, *Documentos*).
Backend: `nl_to_le:english_to_le/8` com as opções `document(Nome)` e `base(Pasta)`.

### 17.10 Vistas: como um ecrã mostra um programa
Uma **vista** diz como deve parecer um ecrã que corre o programa a quem o usa:
que factos um caso afirma e como se agrupam, que consulta é o resultado, o que
se mostra ao lado. É uma secção de frases fixas — nada raciocina com elas —
escrita no programa (ou num recurso que ele inclui):
```le
a vista processo é:
    o título é "Processo de sinistro".
    o caso é um cenário, com os documentos em que consta.
    os factos sobre "o sinistro" são
        um sinistro é por um dano,
        um dano foi comunicado dentro do prazo.
    os juízos são
        um dano é acidental.
    cada facto mostra quem o afirma.
    o resultado é a resposta à consulta pagáveis.
    o resultado mostra as suas citações.
    o resultado pergunta o que falta.
    o resultado pode ser invertido.
    os documentos do caso são mostrados ao lado dos factos.
    os casos são listados com os seus resultados.
```
A vista executiva (`/executive?program=<programa>&view=<nome>`) apresenta-a com
widgets genéricos. Os factos, perguntas e resultados que uma vista nomeia são
**instâncias dos modelos do programa**, escritas como as condições de uma
regra. As frases (categoria `view` de `i18n/keywords.csv`; onde há variantes,
`factos`/`fatos` e `secção`/`seção` são ambas aceites):

| Frase | O que o ecrã mostra |
|---|---|
| `o título é "<texto>"` | o título do ecrã |
| `o caso é um cenário[, com os documentos em que consta]` | um seletor dos cenários do programa (ou um caso novo); os documentos que os seus factos citam |
| `o caso é sobre <constante>` | o sujeito dos factos que as respostas de uma entrevista afirmam |
| `os factos sobre "<título>" são <instância>, <instância>, …` | um grupo de linhas de factos, editáveis, cada uma com a sua citação |
| `os juízos são <instância>, …` | os factos `; julgado` à parte |
| `os outros factos podem ser acrescentados` / `… não podem ser acrescentados` | se o caso pode afirmar factos de outros modelos |
| `cada facto mostra quem o afirma` | o `de acordo com` de cada facto |
| `o resultado é a resposta à consulta <nome>[, encabeçado por <a palavra>][, em <unidade>]` | as respostas da consulta, o valor do seu `qual <palavra>` em destaque |
| `o resultado é se <instância>` | um resultado sim/não, a consulta escrita na vista |
| `o resultado diz "<texto>" quando se verifica` / `… quando não se verifica` | o resultado nas palavras da vista |
| `o resultado mostra as suas citações` | os passos citados da prova, cada um abrindo a sua passagem |
| `o resultado mostra as suas razões` | os factos em que o resultado assenta; para um resultado que FALHA, **porque não**: as condições não cumpridas (abaixo) |
| `o resultado mostra a etapa que alcança` | a lista das secções aplicabilidade / questão / remédio (§17.4) |
| `o resultado pergunta o que falta` | os factos do caso que a prova falhada procurou, cada um a um clique |
| `os factos são perguntados um de cada vez` | uma entrevista: cada pergunta só enquanto a resposta ainda pode depender dela |
| `a pergunta para <instância> é "<texto>"` | a pergunta para um facto |
| `o resultado pode ser invertido[, como "<texto>"]` | as alterações mínimas que mudariam o resultado (§17.7) |
| `a inversão mantém <instância>, <instância>, …` | factos que a inversão nunca acrescenta, retira ou muda: os que definem o caso |
| `a secção <nome> diz "<texto>"` | a lista de etapas e o "falha em" nas palavras da vista |
| `as respostas a "<corpo de consulta>" são listadas como "<título>"` | uma tabela das respostas de outra consulta, uma coluna por `qual` |
| `o resultado é comparado com o cenário <nome>` | o resultado de outro cenário, e onde falha |
| `os documentos do caso são mostrados ao lado dos factos` | os documentos citados, os do caso abertos com as passagens marcadas |
| `os casos são listados com os seus resultados` | cada cenário, o seu resultado e a sua expectativa, um após outro |
| `o caso é assinalado como "<rótulo>" quando "<corpo de consulta>"` / `… quando a consulta <nome> tem uma resposta` | um aviso acima de tudo sempre que a consulta tem resposta para o caso (uma recusa, um encaminhamento) |
| `os números são mostrados com <N> casas decimais` | os números do ecrã com N casas decimais |
| `o rascunho diz "<texto com {the result}, {the answer}, {the answers}, {the facts}, {the citations}, {the reasons}, {the missing}, {the case}>"` | um texto preenchido a partir do resultado, para copiar |
| `o rascunho diz "<texto>" quando se verifica` / `… quando não se verifica` | um texto para cada resultado: uma aprovação e uma recusa |

Os marcadores do rascunho (`{the result}`, `{the reasons}`, …) escrevem-se em
inglês em todas as linguagens.

- **Verificados pelo verificador** (erros): uma frase que nenhuma forma de
  vista lê (`view_unknown_sentence`), uma instância de nenhum modelo
  (`view_unknown_template`), uma consulta ou cenário que o programa não tem
  (`view_unknown_query`, `view_unknown_scenario`), uma pergunta de tabela que
  não é uma consulta (`view_bad_question`), duas vistas com o mesmo nome
  (`view_duplicate_name`); (avisos) um juízo cujo modelo não é `; julgado`
  (`view_not_judged`), um facto a afirmar que as regras concluem
  (`view_derived_fact`), nenhum resultado (`view_no_result`), uma frase dita
  duas vezes (`view_said_twice`), um cabeçalho que a consulta não pede
  (`view_headed_by_unknown`), a etapa de um programa sem as secções reservadas
  (`view_stage_without_sections`), citações ou documentos de um programa que
  nada cita (`view_nothing_cited`), uma secção que o programa não tem
  (`view_unknown_section`), um facto mantido que as regras concluem
  (`view_keeps_derived`).
- **Porque não.** Para um resultado que falha, o widget de razões lista as
  **condições não cumpridas** (`le_why_not.pl`; `answeringQuery` com
  `whyNot: true` responde `unmet`), lidas da explicação de falha seguindo só as
  tentativas que chegaram MAIS PERTO. Cada folha é `não indicado` (um facto que
  o caso podia afirmar e não afirma) ou `não cumprido` (uma comparação falsa,
  uma negação cujo sujeito se verifica, um facto com outro valor, um juízo
  registado de outra forma, um objetivo que nenhuma regra conclui), com a regra
  que o pede, a sua proveniência e os factos que essa regra comparou.
- **Editar o caso.** Uma alteração a um facto marca os resultados como
  desatualizados e acende o botão **Reavaliar** (Enter num campo faz o mesmo, e
  a caixa *automaticamente* reavalia a cada alteração); depois, as respostas
  que mudaram são realçadas e as que desapareceram aparecem riscadas. Um valor
  que as regras não conseguem ler onde está é assinalado acima do resultado
  (`valueWarnings`; nos cenários do próprio programa, o aviso `mistyped_value`).
- **O carregamento** devolve cada vista compilada (`views`); `answeringQuery`
  acrescenta a lista de secções (`checklist`) e `unmet`; `openQuestions` dá os
  factos que uma prova falhada procurou; `draftView` rascunha uma vista.
- **A vista automática.** Um programa sem vistas declaradas recebe uma na vista
  executiva (`view=*`), compilada só quando é aberta (operação `automaticView`).
  Uma vista declarada substitui-a.
- **Gerar vista LE**, no Assistente LE, acrescenta uma primeira vista rascunhada
  a partir do próprio programa e propõe um pedido para a refinar.

Um tutorial (em inglês) que constrói uma vista passo a passo:
[views.md](../tutorials/views.md).
