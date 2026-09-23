# Resumo da Sintaxe do Português Lógico (LE)

*Tipo: referência · Público: utilizadores, assistentes (lido por inteiro pelas funcionalidades LLM) · Estado: atual (2026-09-16)*

Este documento resume as construções de Logical English (LE) na sua variante
portuguesa — **Português Lógico**. São as construções que o analisador aceita;
o analisador é o programa que lê as frases uma a uma e descobre o que cada uma
diz. O analisador está em `le_grammar.pl` e consulta duas listas de palavras:
`i18n/keywords.csv`, com as palavras-chave, e `i18n/system_templates.csv`, com
os modelos de sistema. Um programa declara a linguagem na sua **primeira
frase**: `a linguagem alvo é: prolog.`

As secções deste documento têm os mesmos números que as secções da referência
inglesa, [language.md](language.md). Assim, uma citação "§" — as mensagens do
verificador usam-nas — vale para as duas referências.

## Índice
- [1. Secções do documento](#1-secções-do-documento)
- [2. Modelos](#2-modelos)
  - [2.1 Modelos preposicionais](#21-modelos-preposicionais)
  - [2.2 Constantes com nome: `as constantes são:`](#22-constantes-com-nome-as-constantes-são)
  - [2.3 Funções: `as funções são:`](#23-funções-as-funções-são)
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

- **Recursos incluídos:** `a base de conhecimento <nome> inclui estes recursos:` ou `o contrato <nome> inclui estes recursos:` — traz para o programa outros ficheiros LE, indicados pelo nome ou por um URL (*Uniform Resource Locator*, um endereço na Internet). Esta secção tem de vir antes do cabeçalho principal.
- **Base de conhecimento:** `a base de conhecimento <nome> inclui:` ou `o contrato <nome> estabelece que:`
- **Cenário:** `cenário <nome> é:` (factos de um caso concreto)
  - Pode incluir expectativas: `<NomeDaConsulta> espera respostas [<lista de strings>] e desconhecidos [<lista de strings>].` (a palavra `respostas` pode omitir-se)
- **Consulta:** `consulta <nome> é:` (os objetivos a provar). O corpo de uma
  consulta pode ser uma **expressão de corpo completa — como o corpo de uma
  regra** — e não apenas uma única instância de modelo. O corpo pode combinar
  condições com `e`, `ou`, negação (`não é o caso que …`) e `para todos os casos em que …` (ver §3.2).
- **Ontologia:** `a ontologia é:` (taxonomia e hierarquias de classes)
- **Modelos:** `os predicados são:` ou `os modelos são:` (padrões de linguagem natural)
- **Constantes:** `as constantes são:` (valores com nome, um por linha: `a taxa é 5.` — §2.2)
- **Bases (alvo lps):** `a base de conhecimento <nome> estende <base>, <base>.` — no alvo lps, isto é, na linguagem LPS (Logic Production System), uma base de conhecimento recebe assim os modelos, leis e restrições das bases que estende, sem a sua instância (`le_lps_surface.md` §1.1)
- **Dinâmica:** `os fluentes são:` ou `os eventos são:` (raciocínio temporal). No alvo lps uma frase só precisa de tempos onde relaciona dois momentos. Uma regra reativa `se … então …` sem tempos lê as suas condições num só momento e começa a sua ação nesse momento; uma lei causal `quando … então …` também dispensa tempos (`le_lps_surface.md` §3.1)
- **Meta:** `a linguagem alvo é: prolog.` (obrigatório; declara a linguagem do programa)

## 2. Modelos
Um modelo (template) liga uma frase de linguagem natural a um predicado Prolog,
ou seja, ao nome interno que o computador dá à relação que a frase exprime.
- **Padrão:** `*uma pessoa* é amiga de *uma outra pessoa*`
- **Variáveis:** palavras entre asteriscos `*...*`.
- **Tipos:** o **substantivo principal** da frase da variável (p.ex. `pessoa`); ver §6.
- **Alcance das variáveis:** várias ocorrências do mesmo nome de variável na
  mesma frase (ou consulta) referem a mesma variável.
  - `qual pessoa é o pai de qual pessoa` só é verdadeira se uma pessoa for pai de si própria.
  - Use `qual pessoa é o pai de qual outra pessoa` para referir duas pessoas diferentes.

### Adições a modelos (depois de `;`)
Uma definição de modelo pode ser seguida de adições, cada uma introduzida por `;`:
- `; oposto: <modelo>` — declara a forma negativa, que o programa usa nas conclusões negativas e nas provas por negação.
  **A forma oposta não é uma negação numa condição.** Escrita como condição,
  `o requerente não tem outro rendimento` é um objetivo do seu próprio
  predicado. Só as regras que concluem esse predicado (uma regra `apenas se`,
  §15.1) o podem provar. Para testar que o modelo positivo não se verifica,
  escreva `não é o caso que o requerente tem outro rendimento`. O verificador
  assinala uma forma oposta usada como condição que nada conclui (`opposite_as_condition`).
- `; sinónimo: <modelo>` (também `sinônimo`) — declara uma **forma equivalente**. O sinónimo aponta para o **mesmo** predicado, pelo que factos, cabeças e corpos de regras e consultas podem usar qualquer das formas. As `*variáveis*` do sinónimo emparelham com as do modelo principal **pela posição**, pelo que ambas as formas devem listar os argumentos pela mesma ordem. Um mesmo modelo pode levar vários `; sinónimo ...` seguidos.
  - Exemplo: `*um pagamento* é relativo a *um sinistro*; sinónimo: *um pagamento* cobre *um sinistro*.`
  - **Apresentação:** por omissão, o sistema usa a forma principal (a primeira). Numa explicação, cada passo aparece na forma usada no seu local de origem, e uma consulta apresenta as suas respostas na forma usada na consulta.
  - **Restrição:** um modelo com sinónimo **não pode ter outras adições** (`oposto`, `preposicional`, `desconhecido`, `indefinido`); senão o verificador assinala o erro `synonym_with_other_additions`.
- `; preposicional` — marca um modelo **preposicional** (ver §2.1). O sinónimo `; composto` (ou `; composta`) é aceite com o mesmo significado.
- `; desconhecido` — marca o modelo como **assumível** (abdutível). Um objetivo deste modelo que o programa não consegue provar é assumido verdadeiro e reportado como desconhecido, na medida em que as restrições de integridade o permitam (§3.3). São aceites os sinónimos `; desconhecida`, `; assumido`, `; assumida` e `; assumível`.
- `; indefinido` — marca o modelo como **elemento de cenário**: os seus factos só devem aparecer em cenários, nunca como factos ou cabeças de regras na base de conhecimento. São aceites os sinónimos `; indefinida` e `; elemento de cenário`.
  - O aviso `undefined_predicate` é **suprimido** para este modelo.
  - É emitido o aviso `defined_scenario_element` se aparecer um facto ou cabeça de regra deste modelo na base de conhecimento.
  - Exemplo: `*uma pessoa* passou no teste; indefinido.`
- `; via serviço <nome>` (também `; através do serviço <nome>`) — um serviço declarado responde às frases deste modelo enquanto o programa corre (§17.6).
- `; <valor> por omissão` (também `por defeito`, `por padrão`) — **só no alvo lps, só em fluentes** (`le_lps_surface.md` §2): o valor que o último argumento do modelo tem para uma chave sem facto guardado. O verificador assinala um valor por omissão declarado noutro modelo (`default_not_lps`).
- `; julgado` — marca um predicado de **textura aberta**: alguém *decide* as suas instâncias, em vez de as regras as derivarem (sinónimos `; julgada`, `; avaliativo`, `; avaliativa`). O programa resolve-o como `; assumível`, com uma diferença: uma vez registado um resultado (o último argumento) para uma questão, não assume mais nenhum resultado para essa questão. Uma regra que conclua um modelo julgado é um erro, e as instâncias do modelo que ficam em aberto aparecem como *julgamento necessário*. Ver §17.1.
- `; memorável` — durante uma consulta, o programa **memoriza** as chamadas ao modelo: calcula cada chamada distinta uma só vez, com as suas respostas e as suas explicações, e repete-as onde quer que a mesma chamada volte a ocorrer (§2.4). São aceites os sinónimos `; memorizável`, `; memorizado` e `; memorizada`.

### 2.1 Modelos preposicionais
Um modelo preposicional é um modelo de dois argumentos que **começa por um
argumento** e serve para estender uma condição anterior. Ao encadear, quem
escreve pode omitir o argumento inicial: o analisador preenche-o com a
variável de tipo compatível da condição anterior.
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
O nome passa a valer pelo valor onde quer que uma regra, um cenário ou uma
consulta o use:
```le
um cliente paga imposto
    se a encomenda de o cliente pesa um número kg
    e o número > o limite isento.
```
Uma explicação mostra o valor como razão.

Cada linha declara o modelo `o valor de <nome> é *um <tipo>*` e enuncia o seu
único facto. Por isso, uma regra também pode ler o valor para uma variável —
`o valor de o limite isento é um limite L`. É assim que se usa uma constante
em aritmética, porque um nome **não** é operando aritmético: compare com o
nome, ou leia primeiro o seu valor para uma variável.

O tipo do valor vem do valor escrito: um número, um texto ou um nome. O nome
da constante pode conter `é`, e nesse caso o valor é o que está depois do
último `é`. O verificador assinala uma constante que nada usa
(`unused_constant`).

Uma constante é o caso particular de uma **função** (§2.3): o valor de uma
constante está escrito, em vez de ser calculado. Um valor que as regras
calculam pede a secção das funções.

### 2.3 Funções: `as funções são:`
Uma **função** é um modelo comum da forma `... é *um valor*` — o seu último
lugar, depois da cópula, é o valor que dá — declarado numa secção própria:
```le
as funções são:
    o preço de uma caneca com capacidade *um número* ml é *um montante*.
```
Declará-la permite escrever a frase **sem esse último lugar** onde quer que se
espere um valor. As duas condições

```le
    e o preço de uma caneca com capacidade a capacidade ml é um preço
    e o preço > 10
```

passam a poder escrever-se como uma só:

```le
    e o preço de uma caneca com capacidade a capacidade ml > 10
```

Nada mais muda. A frase completa continua a funcionar. O que define a função é
uma regra ou um facto comuns. Uma função pode também ser uma relação com
**várias respostas**, e então cada frase que a use tem igualmente várias
respostas. A mesma aplicação escrita duas vezes na mesma frase é perguntada
**uma só vez**, pelo que repetir a frase não multiplica as respostas.

Uma função sem lugar próprio é um valor com um nome — `a nossa apólice é *uma
apólice*` usada como `a nossa apólice`. Era para isso que servia a adição
`; define global`, agora removida. Um valor escrito é uma constante (§2.2), e
um valor que as regras calculam é uma função; o nome de uma função são as
palavras da própria frase, em vez de um nome inventado ao lado. O verificador
avisa nessa linha um programa que ainda traga `; define global`
(`defines_global_removed`).

Pontos a saber:

- **Onde se pode escrever.** Em qualquer lugar onde se espere um valor: uma
  comparação, um `é`, um lugar de outro modelo, o valor da cabeça de uma regra
  (um facto cujo valor é o de uma função é uma regra).
- **Não é operando aritmético**, tal como uma constante não é. Leia primeiro o
  valor para uma variável e faça depois a aritmética.
- **Nada pode seguir-se à frase quando a frase continua com `é`.** `o preço da
  caneca > 10` está bem, e `a etiqueta é a nossa moeda` também. `o preço da
  caneca está em [10, 20]` não está: a frase da própria função corresponde
  desde o início e lê `em [10, 20]` como o seu valor. Nessas formas, ligue o
  valor numa condição própria.
- **A condição vem antes.** O objetivo que pergunta a função fica antes da
  condição que usa o seu valor, e é isso que faz uma comparação funcionar.
- **O verificador confere a forma.** Assinala uma linha da secção que não seja
  `... é *um valor*` (`function_not_is_form`); essa linha continua a valer como
  um modelo comum.
- **LPS.** A mesma secção, e a mesma leitura, em `a linguagem alvo é: lps.`.
  Um fluente, um evento ou uma ação mantém a sua própria secção de declaração,
  que é o que lhe confere o papel em LPS, pelo que o valor de um fluente
  continua a escrever-se por inteiro.
- **O escritor de LE** volta a escrever a secção a partir do item
  `function(F, Text)` da representação intermédia usada nas migrações, e
  escreve o valor de uma função na forma compacta onde ele é usado. É essa
  forma compacta que os tradutores de outros sistemas produzem.

O exemplo trabalhado é
`examples/moreExamples/language/templates/functions.le`.

### 2.4 Modelos memoráveis: `; memorável`
Uma consulta a um programa grande prova muitas vezes a mesma coisa: a mesma
condição, com os mesmos valores, alcançada a partir de várias regras ou de
vários casos de uma regra. A explicação mostra essa repetição depois, juntando
num só as sub-explicações repetidas. A adição `; memorável` evita o próprio
trabalho repetido, nos modelos que o autor escolher:
```le
os modelos são:
    *um antepassado* é antepassado de *uma pessoa*; memorável.
```
- **O que é guardado.** Numa consulta, a primeira chamada de cada chamada
  *distinta* ao modelo calcula **todas** as respostas dessa chamada, cada uma
  com os seus desconhecidos e a sua explicação. Cada chamada posterior que
  seja a mesma a menos do nome das variáveis (uma *variante*) repete essas
  respostas. O programa procura as chamadas já calculadas por um resumo (hash)
  da sua forma.
- **Só as chamadas completas são repetidas.** O programa guarda uma chamada
  quando já calculou todas as suas respostas. Enquanto está a calculá-la,
  resolve como de costume uma variante recursiva dessa chamada que apareça
  dentro do cálculo.
- **As mesmas respostas, as mesmas explicações.** O marcador muda quando o
  trabalho é feito, não o que se conclui: uma chamada repetida dá as respostas
  da primeira, pela mesma ordem, com a mesma sub-prova.
- **Por consulta, não por sessão.** O programa deita fora o que guardou sempre
  que uma consulta começa, porque os factos de uma sessão mudam entre
  consultas. Dentro de uma consulta, cada prova aninhada (porquê-não, secções,
  restrições, inversão) guarda as suas próprias chamadas, e uma prova com
  âmbito (`segundo`, §17.5) fica guardada à parte.
- **Avisos.** `memorable_under_negation` — uma chamada memorável sob `não é o
  caso que`, `a menos que` ou `caso contrário`: a negação para na primeira
  resposta, enquanto a chamada memorável calcula todas. `memorable_calls_prolog`
  — uma regra do predicado memorável executa um objetivo `prolog` embutido
  (§15.6), que poderia mudar os dados em que as respostas já guardadas se
  basearam.

Ver `examples/moreExamples/language/memoization/`.

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
`<nome>`, até ao marcador seguinte. O sistema regista essa correspondência em
`le_source_section/2` (§13). Uma secção não muda o raciocínio: é apenas
informação sobre a origem de cada regra.

Convenções:
- Sem marcadores, ou antes do primeiro marcador, as regras pertencem à secção **`main`**.
- Os nomes **`aplicabilidade`**, **`questão`** e **`remédio`** (ou `reparação`) estão reservados para o esqueleto de decisão (§17.4): não mudam nada na resolução, mas o sistema conta em relação a eles onde uma consulta falhou.

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
`qual dragão é feliz.`) comporta-se como sempre. Quando a consulta tem várias
condições, o sistema apresenta a resposta a partir do objetivo da consulta,
com os valores que as suas variáveis tomaram.

> Aplicam-se as mesmas regras de disposição que nos corpos de regras: o objetivo
> negado e as partes de `para todos os casos em que` vão em linhas próprias
> aninhadas. Uma só linha como `… e não é o caso que a pessoa é triste` **não**
> separa a negação; ponha o objetivo negado na linha seguinte.

### 3.3 Restrições de integridade: `não pode ser verdade que …`
Uma **restrição de integridade** (uma *negação*) diz que certas condições nunca
podem ser verdadeiras em conjunto. Escreva a restrição na base de conhecimento,
como o corpo de uma regra sem cabeça. A frase é a mesma em todas as linguagens
alvo:
```le
não pode ser verdade que
    uma pessoa reside em um país
    e a pessoa reside em um segundo país
    e o país é diferente de o segundo país.
```
- **Alvo prolog** — a restrição verifica o que uma resposta **assume**: os
  modelos `; desconhecido` de §2, os *abdutíveis*, como na programação em
  lógica abdutiva. O sistema só mantém uma resposta obtida com suposições se o
  caso, tomando essas suposições como verdadeiras e não assumindo mais nada,
  não satisfizer as condições de nenhuma restrição. Enquanto verifica uma
  restrição, o sistema toma por falso tudo o que não foi dito nem assumido,
  pelo que uma restrição pode usar `não é o caso que`.
  - Quando uma restrição é violada por causa da negação de algo assumível, o
    sistema salva a resposta **assumindo mais**: com
    ```le
    não pode ser verdade que
        uma pessoa é casada com uma segunda pessoa
        e não é o caso que
            a segunda pessoa é casada com a pessoa.
    ```
    assumir que dan é casada com erin também assume que erin é casada com dan,
    e a resposta lista ambos os desconhecidos.
  - Nos outros casos, o sistema **rejeita** a resposta. Com a primeira
    restrição acima, o sistema não pode assumir que alice (que vive em espanha)
    reside em frança, pelo que não responde que alice paga imposto lá.
  - Um caso cujos **factos**, por si só, violam uma restrição — sem que
    nenhuma suposição o remedeie — é **inconsistente: nada se segue dele**.
    Nenhuma consulta tem resposta, e a explicação da resposta vazia é a
    restrição, com a prova das suas condições ("o caso viola uma restrição …").
  - As restrições não afetam as regras `se` comuns, as consultas nem as
    respostas definitivas de casos consistentes; um programa sem restrições
    comporta-se como antes.
- **Alvo scasp** — o tradutor escreve cada restrição como a restrição global
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
- **Ou:** `ou`, `uma das seguintes`, `alguma das seguintes` (§15.4); `todas as seguintes` agrupa com E
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
Uma frase **definida** (`a pessoa`, `o coelho branco`) nunca introduz nenhuma.
Uma frase definida só é uma variável quando a **mesma frase** já introduziu
uma variável com esse nome. Nos outros casos, a frase definida nomeia uma
**constante global**: o indivíduo que a frase denota, escrito com o artigo
(`o coelho branco`), o mesmo em todas as regras, cenários e consultas do
programa. Ver `examples/moreExamples/language/templates/white_rabbit.le` (em inglês).

Consequências:
- A ordem conta dentro de uma frase: a introdução tem de vir primeiro (as
  cabeças leem-se antes dos corpos, as condições da esquerda para a direita).
- Um erro de escrita numa retoma (`a pesoa`) já não se torna, em silêncio, uma
  variável livre. O erro de escrita torna-se uma constante que mais nada
  menciona, e a regra simplesmente não dispara.
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
verificação **espera que o argumento receba um valor** e só então o examina, e
é **tolerante**: só rejeita um valor perante um conflito claro, e aceita sempre
um argumento cujo tipo não conhece. Para decidir, a verificação consulta os
factos `é um` da sessão (os factos de cenário) e os da base de conhecimento.

- **Valores instância.** Um valor com tipo conhecido — há um facto `é um` para
  ele, p.ex. `este pagamento é um pagamento` — só entra num lugar de tipo `T`
  se *for um* `T`, diretamente, pela taxonomia, ou pelo substantivo principal.
  Um valor sem tipo conhecido não impõe restrição.
- **Valores tipo.** Quando o valor é ele próprio um *tipo* (raciocínio
  taxonómico), a verificação exige que esse valor seja subtipo do tipo do
  lugar — mas só quando o tipo do lugar participa na ontologia.
- **Tipos universais.** `any`, e os tipos universais `thing`, `object`,
  `entity`, `asset`, `element`, aceitam qualquer valor.
- **Regras com o mesmo functor** (o mesmo nome de predicado). Quando as cabeças
  de várias regras partilham um predicado mas declaram **tipos de argumento
  diferentes**, o tipo distingue-as, **apenas nas posições ambíguas** (onde os
  modelos do predicado discordam no tipo).

Numa árvore de explicação, uma verificação de tipo aparece como a afirmação que
confirma, p.ex. `este pagamento é um pagamento`.

- **Constantes:**
  - Nomes próprios: `Alice`, `Bob`
  - Textos entre aspas: `"Olá"`, `'Mundo'`
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
  - `*V1* é *V2* meses depois de *V3*` (meses de calendário, para datas): dados
    V3 e V2, o sistema calcula V1, mantendo o dia do mês quando o mês de
    chegada o tem e usando senão o último dia desse mês (31 de agosto +
    6 meses = 28 de fevereiro). Dadas as duas datas, V2 é o número de meses
    INTEIROS entre elas. Um prazo lê-se
    `um limite é 6 meses depois de a data e a outra data é anterior ou igual a
    o limite` — nunca "183 dias".
  - `*V1* é conhecido` (ou `é conhecida`)
  - `*V1* é o caso` (V1 uma frase: prova a frase que uma variável contém)
  - `*V1* está em *V2*` (pertença a lista)
  - `o mínimo de *V1* e *V2* é *V3*` (números)
  - `o máximo de *V1* e *V2* é *V3*` (números)
- **Não há FUNÇÕES `min`/`max`.** "O menor do limite e do custo" é uma condição,
  não uma expressão: escreva `e o mínimo de L e R é P`, nunca `e P = min(L, R)`
  (o analisador aceita a frase, mas o programa falha quando a executa).

### 7.1 Datas
- **Representação:** o tokenizador — a parte do analisador que parte o texto em palavras e símbolos — reconhece as datas e guarda cada uma como `date(Ano, Mês, Dia)`.
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
- Um modelo cuja `*variável*` final é imediatamente precedida por `que` (ou `diz`) é um **meta-modelo**: o analisador lê esse argumento como uma frase embutida.
- Nota: `que` é muito frequente em português; evite `que` imediatamente antes de uma `*variável*` em modelos que **não** sejam meta-modelos (prefira, p.ex., `é superior a` em comparações).

## 12. Testes e expectativas
Um cenário pode declarar os resultados que espera de uma consulta, e o executor de testes usa-os.
- **Sintaxe:** `<NomeDaConsulta> espera respostas ["Resposta 1", "Resposta 2"] e desconhecidos ["Desconhecido 1"].` (A parte `e desconhecidos [...]` é opcional, e a palavra `respostas` também.)
- A expectativa nomeia a consulta diretamente — **não** a prefixe com `consulta`.
- **Consultas de inversão** (§17.7) declaram os conjuntos mínimos de alterações esperados: `<NomeDaConsulta> espera alterações [["acrescentar: <facto>"], ["retirar: <facto>", "acrescentar: <facto>"]].`
- **Quando correm:** o executor de testes (`runTests`, `runTestsFor/2`) corre
  todas as expectativas. A verificação — cada carregamento no editor — também
  as corre, mas dentro de um tempo limitado (a opção Prolog — uma *flag* —
  `le_verify_tests_seconds`, 5 segundos por omissão). Os testes que ficam por
  correr são reportados uma vez, com o aviso `tests_not_run`.
- **Exemplo:**
  ```le
  cenário alice é:
      John nasceu em o Reino Unido em 2021-10-09.
      um espera respostas ["John adquire cidadania britânica em 2021-10-09"].
  ```

## 13. Predicados de sistema
Pode chamá-los através da palavra-chave `prolog` (§15.6), ou usá-los para que o
programa se examine a si próprio. São os mesmos do LE inglês:
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
- **Comportamento:** o sistema acrescenta à base local as regras, os factos, os modelos e a ontologia do recurso incluído, e ignora os cenários e as consultas desse recurso.
- **Transitividade:** um recurso incluído pode incluir outros, até uma profundidade máxima (a opção Prolog `le_include_max_depth`, 5 por omissão). O sistema deteta repetições e ciclos. Cada caminho resolve-se **relativamente à localização do ficheiro que o inclui**. Os recursos devem estar **na mesma linguagem** do programa que os inclui.
- **Restrição a caminhos locais:** um programa só pode incluir um recurso local que esteja dentro da árvore de diretórios do ficheiro que o inclui, ou que seja um ficheiro do servidor permitido por `restricted_paths`. Os endereços `http(s)` externos não têm restrição.
- **Posições na fonte:** o analisador lê cada recurso `.le` incluído com uma gama própria de posições de caracteres. Assim, nada do que fica registado para o recurso — uma regra, uma condição, um problema, uma proveniência — se confunde com o documento que o inclui. As respostas de `/leapi` marcam uma gama dentro de um recurso com `resource`, `resourceExample`, `resourceLine`, `resourceStart`, `resourceEnd`, e o editor abre então o recurso nessa linha num novo separador.

### 14.1 Recursos Prolog (`.pl`)
Um recurso com extensão explícita `.pl` (um ficheiro ou um endereço na
Internet) é um **recurso Prolog**. É a forma de apoiar uma base de
conhecimento LE num ficheiro Prolog de factos e predicados — por exemplo, uma
tabela grande. Uma *camada fina* de modelos LE com corpos `prolog` (§15.6) dá
acesso a esse ficheiro: o programa principal inclui a camada, e a camada
inclui o `.pl`:
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
- **O carregamento limita-se a acrescentar cláusulas** (nunca usa `consult`):
  o sistema guarda-as num módulo à parte, identificado pelo conteúdo do
  ficheiro. Só respeita três diretivas, `dynamic/1`, `discontiguous/1` e
  `use_module(library(...))`. Retira a diretiva `:- module(...)` com um aviso,
  e ignora as restantes, também com aviso. Assim, um `.pl` de outro sítio não
  consegue executar código só por ser incluído.
- **Segurança em execução:** `library(sandbox)` verifica cada objetivo
  `prolog` antes de o deixar correr; uma instalação de confiança pode desligar
  essa verificação, pondo a opção `le_sandbox_prolog` a `false`.
- **Releitura:** um `.pl` guardado em ficheiro é relido quando muda a sua data
  de modificação; um `.pl` obtido de um endereço na Internet é obtido uma vez
  por cada execução do servidor.
- Ver `examples/moreExamples/language/includes/prolog_resources/` (em inglês).

### 14.2 Bibliotecas incluídas (`lib/`)
Uma biblioteca é um recurso LE comum, guardado em `lib/` e copiado para junto
do programa que a inclui. As bibliotecas estão escritas em **inglês**, e um
recurso tem de estar na linguagem do programa que o inclui (§14):
- **`lib/temporal.le`** (+ `temporal.pl`) — datas, períodos e *lock times*:
  idades, anos/meses/dias inteiros entre datas, pertença a um período, primeiro
  e último dia de um mês, anos bissextos, *lock times* de Bitcoin.
- **`lib/deontic.le`** — obrigações, permissões e proibições: quem está
  obrigado, e o que é violado, num caso.

Ver §14.2 de [language.md](language.md) para os modelos de cada uma.

## 15. Extensões LE
Funcionalidades para além das construções nucleares acima. As construções
marcadas **[requer le_extensions.pl]** dependem do módulo proprietário
`le_extensions.pl` e só existem onde esse módulo está instalado, ou seja, no
serviço alojado. Sem o módulo, o analisador nem sequer lê essas construções,
pelo que convém preferir as formas nucleares.
As regras `apenas se` (§15.1), os rótulos de regras (§15.5) e os
objetivos Prolog embutidos (§15.6) são LE nuclear. A referência inglesa
destas construções é [extensions.md](extensions.md) e, para as nucleares,
[language.md](language.md).

### 15.1 Regras `apenas se` (condições necessárias)
`Cabeça apenas se Corpo.` (sinónimo: `somente se`) diz que Corpo é uma condição
**necessária** para Cabeça. O sistema traduz a regra para *"oposto-da-Cabeça se
não é o caso que Corpo"*:
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
conclusões"), a cabeça fica só com a parte antes do primeiro `qual`. Cada
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
**dentro** de um corpo, na própria linha ou governando um bloco indentado —
equivalente a `e não é o caso que <as condições negadas>`:
```le
pagaremos um sinistro se
    o sinistro é coberto
    e a menos que
        o sinistro é fraudulento.
```

### 15.4 Alternativas agrupadas: `uma das seguintes:` / `alguma das seguintes:` / `pelo menos uma das seguintes:` / `todas as seguintes:` **[requer le_extensions.pl]**
Uma linha do corpo formada por um destes conectivos agrupa as linhas indentadas
por baixo dela. `uma das seguintes`, `alguma das seguintes` e `pelo menos uma
das seguintes` ligam essas linhas com OU; `todas as seguintes` liga-as com E.
(Também nas formas masculinas: `um dos seguintes`, `algum dos seguintes`,
`pelo menos um dos seguintes`, `todos os seguintes`.) Cada linha diretamente
indentada por baixo é uma alternativa com a sua própria estrutura:
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
como seus subitens; um item `todas as seguintes:` agrupa os seus subitens com E.

### 15.5 Rótulos de regras e corpos numerados **[a numeração requer le_extensions.pl]**
Uma regra pode ter rótulo: `regra <nome>: Cabeça se ...` — o rótulo torna-se o
identificador (ID) da regra, visível em `le_source_element/3` e
`le_source_info/4`, §13.
Um rótulo pode também indicar de onde vem a regra (LE nuclear, sem extensão):
um documento e, se possível, um lugar nele:
```le
regra r1 com proveniência a apólice em cláusula 4, confira "pagamos danos acidentais":
um sinistro é pagável
    se o sinistro é por um dano
    e o dano é acidental.
```
`com proveniência <documento>` — um nome, ou um texto entre aspas, como um URL.
Pode seguir-se-lhe `em <localizador>` (também `na`, `no`) ou
`, confira "<passagem>"` (também `confer`; uma citação do documento, §17.1).
Um rótulo aceita também os complementos de um facto (`de acordo com`, `conforme
consta em`, `porque`). O sistema regista a proveniência como
`le_rule_provenance(ID, Prov)`. A proveniência não muda nada na prova, e as
explicações e o editor mostram-na (§17.1,
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
Pode chegar a cada condição numerada pelo seu designador hierárquico, através
de `le_source_element(IdRegra, Designador, Objetivo)`.

### 15.6 Objetivos Prolog embutidos
Uma condição da forma `prolog <objetivo>` chama Prolog diretamente; para
vários objetivos de uma vez, ponha-os entre parênteses (`prolog (g1, g2)`).
Dentro do objetivo, refira as variáveis LE como frases `o <nome>` / `a <nome>`,
como marcadores `*um nome*` ou como identificadores em MAIÚSCULAS. O objetivo
devolve os seus resultados nessas variáveis:
```le
um sinistro tem identificador um id se
    o sinistro está coberto
    e prolog le_my_id(o id).
```
LE nuclear (não requer `le_extensions.pl`). Cada objetivo `prolog` passa pelo
`library(sandbox)` antes de correr (§14.1). O verificador assinala um modelo
memorável (§2.4) cujas regras chamam um objetivo `prolog`
(`memorable_calls_prolog`).
Ver `examples/moreExamples/language/prolog/prolog_call.le`.

### 15.7 Encadeamento preposicional **[requer le_extensions.pl]**
O marcador `; preposicional` e o seu uso encadeado estão descritos em §2.1.
Quem resolve o *encadeamento* em si — omitir o argumento inicial para que uma
frase se expanda numa conjunção de condições — é o módulo de extensões.

## 16. Humanizar o LE
- **Use `apenas se` para condições necessárias**, com a forma `; oposto:` declarada.
- **Use adições preposicionais para encadear numa só frase:** `faremos um pagamento ao abrigo de esta apólice relativo a um sinistro`.
- **Use `qual` para continuar um pensamento** sem repetir variáveis.
- **Use `a menos que` para exceções.**
- **Use blocos `uma das seguintes:` / `todas as seguintes:`** para alternativas enumeradas.
- **Espelhe a estrutura do documento fonte:** rotule regras com `regra <nome>:`, use corpos numerados, agrupe com `secção ... é:` / o cabeçalho de anexos, e cite a cláusula num comentário `%` ou com `com proveniência`.
- **Declare formas `; sinónimo:`** para que factos, cenários e consultas usem a formulação mais natural em cada contexto.
- **Mantenha a redação dos modelos próxima do texto fonte**, deixando as palavras ignoráveis (um/uma/o/a/é/são...) suportar a gramática.
- **Marque de onde vem cada coisa que se sabe** (o estatuto epistémico) com `; assumível` (juízo pericial), `; julgado` (decisão de alguém) e `; indefinido` (dados do caso).
- **Nomeie indivíduos com significado:** constantes descritivas sem determinante (`sinistro um`, `lesão no pulso`, `Reino Unido`).

## 17. Construções para decisões regulatórias
Construções para programas que aplicam regras escritas a casos registados. Uma
decisão regulatória tem sempre a mesma forma: a regra é aplicável, há um
predicado contestado e há um remédio. Cada facto do caso tem uma fonte, e
alguém decide o predicado contestado. Os exemplos, em inglês, estão em
`examples/regulatory/`; `eu261_integration.le` usa todas estas construções em
conjunto. O analisador verificou os exemplos em português que se seguem.

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
Um facto sem complementos toma a proveniência por omissão. Um facto cujos
complementos não nomeiam documento (`confira`, `de acordo com`, `porque`) toma
o documento por omissão. Um facto com o seu próprio `conforme consta em` indica
outro documento. Uma vírgula que *não* é seguida de um complemento continua a
fazer parte do facto.

- **A prova não muda.** O sistema traduz o facto como se ele não tivesse
  complementos. Regista a proveniência à parte (`le_fact_provenance/4`) e dá a
  cada sessão carregada com o cenário `le_provenance(Facto, Fonte, Documento,
  Localizador, Justificação)`, com `none` para uma parte em falta.
- **As explicações** apresentam o facto provado com os seus complementos, tal
  como escritos.
- **`os factos do cenário exigem proveniência.`** (também `os fatos do cenário
  exigem proveniência.`) — frase ao nível do programa (depois da linha da
  linguagem alvo). Cada facto de cenário sem complemento recebe então o aviso
  `fact_without_provenance`.
- **`; julgado`** (adição de modelo, §2): alguém decide o predicado, em vez de
  as regras o derivarem. O resolvedor trata o predicado como `; assumível`
  (ver a regra do resultado abaixo).
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

**Documentos.** Um documento citado é uma constante comum (`a apólice`) ou um
texto entre aspas (um URL). Dois modelos de sistema dizem onde está o
documento:
```le
a apólice está publicada em "https://example.org/apolice".
o texto de a apólice está em "fontes/apolice.txt".
```
(também `está publicado em`). O primeiro facto dá a página que um leitor abre.
O segundo dá o texto simples do documento: um ficheiro junto do programa,
procurado na pasta do programa e nunca fora dela, ou um endereço na Internet.
De um endereço que devolva JSON (*JavaScript Object Notation*, um formato de
texto para dados), o sistema lê o campo `text`; de uma página HTML, lê o texto
da página; um PDF não serve. Nenhum destes dois factos precisa de proveniência
própria. Com eles:
- o verificador confere uma **citação** — `confira "..."`, ou um localizador
  entre aspas — contra o texto do documento, quando esse texto é um ficheiro
  junto do programa. A comparação ignora espaços e maiúsculas, e dá o aviso
  `quote_not_found` quando não encontra a passagem;
- cada passo de explicação provado por um facto citado ou por uma regra com
  rótulo leva consigo a sua proveniência, e o editor marca-o com um distintivo
  **§**. O visualizador mostra o texto do documento com a passagem realçada, e
  *Abrir original* abre o endereço publicado;
- no próprio programa, o menu de contexto do editor oferece **Mostrar o texto
  original** em qualquer linha que cite um documento com endereço.

**Os valores que um lugar lê.** Para cada lugar de um modelo de cenário, o
próprio programa diz que valores importam: são os valores que as suas regras
leem nesse lugar — os factos de um predicado que partilha a variável, os
membros de uma lista com que o lugar é testado, as constantes passadas a uma
conclusão, a coluna de uma tabela. Os formulários de factos do editor (Editor
de cenários, Variações de cenário) oferecem esses valores como sugestões. O
verificador dá o aviso **`unread_value`** quando um facto de cenário põe ali um
valor que nenhuma regra, facto ou linha de tabela menciona, havendo um valor
lido pelas regras que se parece com ele ("Queria dizer …?").

### 17.2 Cascatas `caso contrário`
Uma linha do corpo que **começa** por `caso contrário` (ou `senão`) inicia uma
nova alternativa. `caso contrário` liga com menos força do que `e` e `ou`: tudo
o que vem antes, no mesmo bloco, forma a alternativa anterior.
```le
a taxa de desconto para um cliente é uma taxa
    se o cliente é sócio
    e a taxa é 20
    caso contrário o cliente é estudante
    e a taxa é 10
    senão a taxa é 0.
```
`A caso contrário B` significa `A`, ou então `B`, e `B` só quando `A` falha. O
sistema traduz a frase para `A ou (não é o caso que A, e B)`, pelo que se
aplica exatamente uma alternativa. Detalhes:
- **A guarda são as condições da alternativa anterior.** Um conjunto que só
  atribui uma saída (`e a taxa é 20`, uma variável que nenhum outro conjunto da
  alternativa usa) fica fora da guarda. O sistema decide isso olhando apenas
  para a forma escrita: uma alternativa que acaba por testar uma tal variável
  (`… e o código é igual a "X"`) perde esse teste na guarda seguinte. Escreva a
  constante primeiro (`"X" é igual a o código`).
- **Decida um caso de cada vez.** A guarda é uma negação por falha, pelo que as
  suas variáveis já devem ter valor quando o programa chega à cascata. Encontre
  primeiro o indivíduo, por exemplo numa regra que chama a cascata.
- **Disposição.** Só uma linha que *começa* pela palavra-chave é uma linha de
  cascata. Dentro de um bloco aninhado a cascata tem o âmbito dado pela
  indentação. **Em português, escreva cada condição de uma alternativa na sua
  própria linha**, como acima: uma linha como `o cliente é sócio e a taxa é 20`
  é lida inteira como uma só frase e não é dividida no `e`.
- **As explicações** mostram a guarda falhada como uma negação que aponta para
  a linha `caso contrário`.

### 17.3 Tabelas de decisão
Uma **tabela de decisão** escreve uma relação como uma grelha: uma coluna por
argumento, uma linha por caso. É uma secção própria e pertence ao ÚNICO modelo
cujas palavras a nomeiam — o modelo diz `segundo a tabela <nome>` e a secção
diz `a tabela <nome> é`:

```le
os modelos são:
    o custo de envio para um peso de *um número* kg é *um custo* segundo a tabela envio.

a tabela envio é, com primeira correspondência:
    escalão | peso kg          | custo
    p       | <= 1             | 5
    m       | > 1 e <= 10      | 12
    g       | > 10             | 30
```

Leia-se cada linha como uma regra: a linha `m` diz *o custo de envio para um
peso de um peso kg é 12 se o peso > 1 e o peso <= 10*. É também em regras assim
que a tabela se traduz, pelo que uma consulta, uma explicação e o verificador
vêem regras sobre `o custo de envio …`. O que a grelha acrescenta é o que as
regras não dizem num só lugar: uma ordem pela qual tentar as linhas e o que fazer
quando mais do que uma serve (**política de correspondência**, abaixo).

**Consultar a tabela.** `segundo a tabela envio` faz parte das palavras do
modelo, pelo que uma regra (ou uma consulta) que consulte a tabela também as
escreve:

```le
o custo de envio para um cliente é um custo
    se a encomenda do cliente pesa um número kg
    e o custo de envio para um peso do número kg é o custo segundo a tabela envio.
```

**A linha de cabeçalho.** `a tabela <nome> é` e depois, nesta ordem e cada um
deles opcional:

| Escrito | Significado |
|---|---|
| `carregada de <ficheiro>.csv` | as linhas estão num ficheiro CSV (*comma-separated values*, uma tabela guardada em texto simples), e não na secção (*Linhas num ficheiro*, abaixo); também `carregada a partir de` |
| `, com primeira correspondência` / `, com correspondência única` / `, com todas as correspondências` | a política de correspondência; não dizer nada é o mesmo que dizer `com correspondência única` |
| `, com proveniência <documento>` | o documento que esta tabela codifica, exactamente como numa regra rotulada (§17.1) — e o documento onde estão as passagens de uma coluna `confira` |

e por fim `:`. A proveniência pode trazer a passagem que a tabela como um todo
codifica, como a de uma regra: `, com proveniência <documento>, confira
"<passagem>"`.

**Colunas e argumentos.** As colunas são os argumentos do modelo, **por
ordem**, e a **última** coluna é aquela que a tabela conclui; as outras são as
suas entradas. Duas colunas não são argumentos:

- **O nome da linha**, numa coluna extra à esquerda. As explicações citam então
  a linha por esse nome (`linha m da tabela envio`); sem essa coluna, citam o
  número da linha (`linha 2`).
- **Uma coluna de citação**, em qualquer posição (*Citar uma passagem por
  linha*, abaixo).

`table_arity_mismatch` é reportado quando o que resta não corresponde aos
argumentos do modelo.

**O que uma célula pode dizer.** Uma célula de uma coluna de **entrada** diz o
que esse argumento tem de ser:

| Célula | Corresponde a |
|---|---|
| um valor — `seda`, `5`, `"De seda"`, `2026-08-31` | esse valor, lido exactamente como as mesmas palavras seriam lidas num cenário |
| nada, `-` ou `qualquer` | qualquer coisa: esta coluna nada diz sobre esta linha |
| `seda ou lã ou algodão` | qualquer um desses valores |
| `> 1 e <= 10` | uma condição: `<`, `<=`, `>`, `>=`, `=`, `!=` (`=<` e `==` também são aceites), ligadas por `e` / `ou` |

Uma célula só conta como condição quando *todas* as suas partes o são, pelo que
um valor cujas palavras incluem `e` ou `ou` continua a ser esse valor
(`com bronquite aguda e crónica`).

Uma célula da **última** coluna é a resposta, não um teste: um valor, ou vários
ligados por `ou`, que respondem então um a um. `table_bad_output` é reportado
para qualquer outra coisa.

Uma entrada cuja célula, em alguma linha, é uma **condição** tem de ter valor
quando o programa consulta a tabela: uma condição pode ser verificada contra um
valor, mas não o pode produzir. Perguntar pela tabela com essa entrada ainda
desconhecida dá um erro em execução que nomeia a coluna.

**Políticas de correspondência.** As linhas são tentadas de cima para baixo.

| Política | Quando mais do que uma linha serve | Para |
|---|---|---|
| `com primeira correspondência` | a primeira responde e as restantes não são tentadas | escalões e cascatas, em que as últimas linhas são o caso geral |
| `com correspondência única` (por omissão) | um erro em execução que nomeia as linhas: a tabela afirmava que o caso era inequívoco, e não era | tabelas cujas linhas se pretendem mutuamente exclusivas |
| `com todas as correspondências` | todas as linhas que servem respondem, uma resposta cada | uma relação e não uma função — uma lista de códigos, uma tabela de pares |

`com correspondência única` só se queixa de um caso que lhe foi de facto
perguntado: várias linhas podem servir uma entrada ainda desconhecida.

**Linhas num ficheiro.** Uma tabela longa vive num ficheiro CSV junto do
programa (ou numa pasta dentro dele). A secção passa a ser a linha de
cabeçalho e os nomes das colunas, mais nada:

```le
a tabela códigos é carregada de cp.csv, com correspondência única:
    código postal | região
```

O sistema lê as células como acima, com duas diferenças que contam quando se
trata de dados:

- **A célula de saída de uma linha do CSV é sempre um valor**, mesmo quando o
  seu texto contém `ou` ou `e` (`distrofia de Duchenne ou de Becker` é uma
  resposta, não duas).
- **Os códigos mantêm a sua forma.** Uma célula de texto é re-citada ao ser
  lida, pelo que `012` ou `G71.01` continua a ser esse código em vez de se
  tornar o número 12.

O sistema ignora uma primeira linha do CSV que repita os nomes das colunas.
Guarda as linhas em memória e volta a lê-las quando o ficheiro muda. Uma tabela
carregada não tem coluna de citação, e o sistema reporta `table_csv_missing`
quando o ficheiro não está lá.

**Citar uma passagem por linha.** Uma coluna de uma tabela escrita no programa
pode citar, linha a linha, a passagem que essa linha codifica — a linha da lei
de um escalão, a linha da pauta de uma subposição. O seu cabeçalho é `confira`,
para passagens do documento que o `com proveniência` da tabela nomeia, ou
`conforme consta em <documento>`, para passagens de outro documento. Cada
célula é uma passagem entre aspas, ou vazia:

```le
a tabela escalões é, com primeira correspondência, com proveniência a lei:
    linha | valor  | escalão | confira
    a     | <= 10  | baixo   | "até dez"
    b     | > 10   | alto    | ""
```

O sistema põe esta coluna de lado antes de ligar as outras aos argumentos do
modelo, pelo que a coluna de citação não é um argumento. A passagem de cada
linha torna-se a proveniência dessa linha, exactamente como a de um facto (§17.1): o nó da
explicação para a linha leva-a consigo (o seu selo **§** abre a passagem), *Ver
Texto Original* sobre a linha encontra-a, e o verificador confere a citação
contra o texto do documento (`quote_not_found`).

**Em que se traduz.** O sistema gera uma cláusula do modelo,
`Cabeça :- le_table(Nome, Args)`, e um registo por cada linha (`le_table/6`,
`le_table_row/6`). Uma explicação cita a
linha que respondeu — `linha m da tabela envio` — e, numa tabela escrita no
programa, essa citação aponta para a linha propriamente dita.

O sistema reporta ao carregar o programa: `table_without_template` (nenhum
modelo diz `segundo a tabela <nome>`), `table_arity_mismatch`, `table_row_width` (uma
linha com o número errado de células), `table_bad_cell`, `table_bad_output`,
`table_csv_missing`.

### 17.4 O esqueleto de decisão: aplicabilidade, questão, remédio
Nenhuma palavra-chave nova. Escreva a estrutura geral de uma decisão — *a regra
é aplicável, qual a resposta à questão, o que se segue* — com os marcadores de
secção comuns (§3.1) e três nomes reservados:
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
  seção …` e `a consulta falha em *uma secção*`) — um modelo de sistema. É
  verdadeiro quando a primeira consulta do programa ("a consulta") não tem
  resposta, e nomeia a secção onde a consulta falha. Essa secção é a primeira,
  pela ordem da lista (aplicabilidade, questão, remédio, e depois as outras
  secções com nome, pela ordem da fonte), que tem uma regra para um objetivo
  que a tentativa tentou e não provou.
  `a consulta *um nome* falha na secção *uma secção*` faz o mesmo para uma
  consulta com nome.
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
`G de acordo com S` é verdadeiro exatamente quando G se demonstra com as regras
e os factos do próprio programa, mais apenas os **factos de cenário** cuja
fonte de proveniência é **admissível segundo S**. A fonte de um facto é o seu
`de acordo com` e, na falta dele, o documento do seu `conforme consta em`
(§17.1). Um facto de cenário sem proveniência nunca é admissível numa prova
restrita; os factos da base de conhecimento são sempre admissíveis.
- **Disposição.** Numa linha própria aninhada sob uma condição (restringe essa
  condição), numa linha depois de várias condições do mesmo nível (restringe-as
  a todas), ou no fim da linha da própria condição.
- **Admissibilidade** é o modelo de sistema `*uma fonte* é admissível segundo
  *um âmbito*` (também `é admissível sob`). Por omissão vale a identidade, ou
  seja, cada fonte é admissível segundo si própria; os programas acrescentam
  factos ou regras.
- **O âmbito** é um valor comum: uma constante, uma variável introduzida antes,
  ou uma nova (`de acordo com uma parte` liga a parte cuja evidência estabelece
  a condição).
- **Presunções** não precisam de sintaxe: `G se não é o caso que <não-G> de
  acordo com <a outra parte>`.
- **As explicações** mostram a evidência que não pôde usar:
  `o aviso foi entregue a ana, de acordo com ana, não é admissível segundo o senhorio`.
- Não disponível no motor s(CASP).

### 17.6 Serviços e predicados semânticos sobre texto
As regras não conseguem decidir alguns predicados, porque os argumentos desses
predicados são texto livre. Um programa pode declarar **serviços** e apoiar
modelos neles:
```le
a base de conhecimento semântica inclui estes serviços:
    comparador em stub:matcher como um comparador semântico.

os modelos são:
    a melhor escolha de *um texto* entre *uma lista* é *uma categoria*; via serviço comparador.
```
- **Declaração**: `a base de conhecimento <nome> inclui estes serviços:`
  seguido de `<nome> em <endereço> como um <tipo>`, separados por vírgulas,
  terminando em ponto. Há três tipos de endereço. Um endereço `http(s)://...`
  é um servidor na Internet: o sistema envia-lhe o pedido em JSON e espera a
  resposta `{"answers": [[arg, ...], ...], "rationale": "..."}`. Um endereço
  `llm:<modelo>` é um modelo de linguagem, chamado através de
  `llm/llm_client.pl`. `stub:matcher` e `stub:judge` são os serviços simulados
  que os testes usam, e que respondem sempre o mesmo. O tipo reconhecido é
  `comparador semântico`.
- **`; via serviço <nome>`** (adição de modelo): esse serviço responde aos
  objetivos do modelo. O **último** argumento pode ser desconhecido, e nesse
  caso o serviço preenche-o; todos os outros têm de ter valor quando o programa
  chega ao objetivo. Com todos os argumentos conhecidos, o serviço responde sim
  ou não.
- **Modelos semânticos de sistema**, apoiados no primeiro serviço declarado
  `como um comparador semântico`:
  `*um texto* é semanticamente semelhante a *um segundo texto*`,
  `a melhor correspondência de *um texto* entre *uma lista* é *um item*`,
  `*um texto* satisfaz a descrição *uma descrição*`.
- **Chamar uma vez, guardar.** O sistema faz cada pedido distinto **uma vez por
  sessão**. Quando a opção Prolog `le_service_cache_dir` nomeia uma pasta, as
  respostas ficam também guardadas nessa pasta, identificadas pelo pedido, e
  voltam a ser usadas entre sessões e entre programas.
- **Atribuição.** Uma resposta entra na prova atribuída ao serviço (`de acordo
  com serviço comparador`, com a justificação do serviço), e uma prova restrita
  (§17.5) só a admite segundo esse serviço (ou um âmbito segundo o qual seja
  admissível).
- **Serviço inacessível**: sem nada guardado de uma chamada anterior, o
  objetivo torna-se um desconhecido — uma resposta condicional, não um erro.
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
`não é o caso que G`.) As respostas são os **conjuntos mínimos de alterações**:
o menor número de alterações, e todos os conjuntos desse tamanho que funcionam.
Depois dessas alterações, o objetivo verifica-se sem suposições — ou, quando o
objetivo é `não é o caso que G`, G deixa de ter prova. Uma alteração
**acrescenta** ou **retira** um facto de um modelo elemento de cenário: um
modelo marcado `; indefinido` ou `; julgado` (§17.1) ou, num programa que não
marca nenhum, qualquer modelo que nenhuma regra conclui. Os predicados
derivados nunca mudam.
- Uma resposta apresenta-se como as suas alterações: `acrescentar: rico tem
  baixos rendimentos` (várias ligadas por `e`; `nenhuma alteração é necessária`
  quando o objetivo já se verifica), explicada pela prova do cenário alterado.
- A instância em aberto de um modelo julgado é uma alteração de um passo como
  qualquer outra.
- **Expectativas**: `inverter espera alterações [["acrescentar: rico tem baixos rendimentos"]].`
  (a ordem não conta, dentro e entre conjuntos).
- **A pesquisa** segue a explicação e confirma cada resultado. Os candidatos
  vêm só daquilo que uma tentativa do objetivo tocou, e os conjuntos crescem
  uma alteração de cada vez, aplicada a uma cópia da sessão. Os limites são as
  opções Prolog `le_flip_max_changes` (3 por omissão) e
  `le_flip_max_evaluations` (400).
- **Factos mantidos**: um pedido pode nomear modelos que a inversão deixa como
  estão (campo `keep` de `answeringQuery`; numa vista, `a inversão mantém …`,
  §17.10).
- **Sem escrever a consulta**: a inversão é também uma consulta personalizada.
  O botão **Inverter…** do editor, ao lado de **Consulta**, compõe a consulta
  de inversão a partir da resposta selecionada, negada, ou a partir da própria
  consulta quando esta não tem resposta.

### 17.8 Fatores e precedentes: um padrão, não sintaxe
Decidir uma questão de textura aberta (`; julgado`) a partir de decisões
anteriores — o *result model* de Horty — não precisa de construção própria.
`examples/regulatory/precedent.le` é uma biblioteca em LE simples (em inglês,
pelo que só pode ser incluída por programas em inglês, §14); um programa
fornece **fatores** (regras que os nomeiam, e para que lado apontam), a **base
de casos** (factos sobre cada caso decidido, citados com complementos, §17.1) e
o **gancho**, ou seja, o ponto onde a biblioteca se liga ao programa: uma
cascata `caso contrário` (§17.2) à volta do predicado julgado. Um caso que
decidiu a favor *força a favor* uma situação quando essa situação tem pelo
menos os fatores a favor do caso e, no máximo, os fatores contra do caso; e ao
contrário, do mesmo modo, para *forçada contra*. Ver `examples/regulatory/precedent_pattern.le`.

### 17.9 Factos a partir de um documento
O diálogo *Escreva em Português…* do Editor de cenários também extrai factos de
um documento. Em *A partir de um documento*, dê o nome do documento (a
constante que os factos vão citar) e, se quiser, o endereço do seu texto: um
URL, ou um ficheiro junto do programa — *Obter texto* traz o texto desse
endereço. Cole ou obtenha o texto e carregue em *Gerar*:
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
No servidor, `nl_to_le:english_to_le/8` faz este trabalho, com as opções `document(Nome)` e `base(Pasta)`.

### 17.10 Vistas: como um ecrã mostra um programa
Uma **vista** diz como deve parecer um ecrã que corre o programa a quem o usa:
que factos um caso afirma e como se agrupam, que consulta é o resultado, o que
se mostra ao lado. É uma secção de frases fixas, escrita no programa ou num
recurso que o programa inclui; nenhum raciocínio usa estas frases:
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
A vista executiva (`/executive?program=<programa>&view=<nome>`) apresenta a
vista com elementos de ecrã genéricos. Os factos, perguntas e resultados que uma vista nomeia são
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
- **Porque não.** Para um resultado que falha, o painel das razões lista as
  **condições não cumpridas** (`le_why_not.pl`; `answeringQuery` com
  `whyNot: true` responde `unmet`). O sistema lê essas condições da explicação
  de falha, seguindo só as tentativas que chegaram MAIS PERTO. Cada folha da
  lista — o ponto onde a explicação pára — é `não indicado` (um facto que
  o caso podia afirmar e não afirma) ou `não cumprido` (uma comparação falsa,
  uma negação cujo sujeito se verifica, um facto com outro valor, um juízo
  registado de outra forma, um objetivo que nenhuma regra conclui), com a regra
  que o pede, a sua proveniência e os factos que essa regra comparou.
- **Editar o caso.** Quando alguém altera um facto, o ecrã marca os resultados
  como desatualizados e acende o botão **Reavaliar**. A tecla Enter num campo
  faz o mesmo, e a caixa *automaticamente* reavalia a cada alteração. Depois da
  reavaliação, as respostas que mudaram aparecem realçadas e as que
  desapareceram aparecem riscadas. Um valor que as regras não conseguem ler
  onde ele está é assinalado acima do resultado
  (`valueWarnings`; nos cenários do próprio programa, o aviso `mistyped_value`).
- **O carregamento** devolve cada vista já traduzida (`views`). `answeringQuery`
  acrescenta a lista de secções (`checklist`) e `unmet`. `openQuestions` dá os
  factos que uma prova falhada procurou, e `draftView` rascunha uma vista.
- **A vista automática.** Um programa sem vistas declaradas recebe uma na vista
  executiva (`view=*`), que o sistema só prepara quando alguém a abre (operação
  `automaticView`). Uma vista declarada no programa toma o lugar da automática.
- **Gerar vista LE**, no Assistente LE, acrescenta uma primeira vista rascunhada
  a partir do próprio programa e propõe um pedido para a refinar.

Um tutorial (em inglês) que constrói uma vista passo a passo:
[views.md](../tutorials/views.md).
