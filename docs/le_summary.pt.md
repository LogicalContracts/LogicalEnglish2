# Resumo da Sintaxe do Português Lógico (LE)

Este documento resume as construções de Logical English (LE) na sua variante
portuguesa — **Português Lógico** — tal como suportadas pelo analisador em
`le_grammar.pl` com o léxico `i18n/keywords.csv`. Um programa declara a
linguagem na sua **primeira frase**: `a linguagem alvo é: prolog.`

## 1. Secções do documento
Cada cabeçalho de secção termina com dois pontos `:`.

- **Recursos incluídos:** `a base de conhecimento <nome> inclui estes recursos:` ou `o contrato <nome> inclui estes recursos:` (para incluir outros ficheiros LE ou URLs; deve preceder o cabeçalho principal).
- **Base de conhecimento:** `a base de conhecimento <nome> inclui:` ou `o contrato <nome> estabelece que:`
- **Cenário:** `cenário <nome> é:` (factos de um caso concreto)
  - Pode incluir expectativas: `<NomeDaConsulta> espera respostas [<lista de strings>] e desconhecidos [<lista de strings>].`
- **Consulta:** `consulta <nome> é:` (os objetivos a provar). O corpo de uma
  consulta pode ser uma **expressão de corpo completa — como o corpo de uma
  regra** — e não apenas uma única instância de modelo: pode combinar condições
  com `e`, `ou`, negação (`não é o caso que …`) e `para todos os casos em que …` (ver §3.2).
- **Ontologia:** `a ontologia é:` (taxonomia e hierarquias de classes)
- **Modelos:** `os predicados são:` ou `os modelos são:` (padrões de linguagem natural)
- **Dinâmica:** `os fluentes são:` ou `os eventos são:` (raciocínio temporal)
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
- `; sinónimo: <modelo>` — declara uma **forma equivalente**. O sinónimo aponta para o **mesmo** predicado; as suas `*variáveis*` emparelham **posicionalmente** com as do modelo principal. Podem encadear-se vários `; sinónimo ...`.
  - Exemplo: `*um pagamento* é relativo a *um sinistro*; sinónimo: *um pagamento* cobre *um sinistro*.`
  - **Restrição:** um modelo com sinónimo **não pode ter outras adições**; caso contrário é assinalado o erro `synonym_with_other_additions`.
- `; define global <nome>` — declara uma abreviatura global (podem encadear-se vários).
- `; preposicional` — marca um modelo **preposicional** (ver §2.1). O sinónimo `; composto` (ou `; composta`) é aceite com o mesmo significado.
- `; desconhecido` — marca o modelo como **assumível** (abdutível): objetivos que não se conseguem provar são assumidos verdadeiros e reportados como desconhecidos. São aceites os sinónimos `; assumido` e `; assumível`.
- `; indefinido` — marca o modelo como **elemento de cenário**: os seus factos só devem aparecer em cenários, nunca na base de conhecimento. É aceite o sinónimo `; elemento de cenário`.
  - O aviso `undefined_predicate` é **suprimido** para este modelo.
  - É emitido o aviso `defined_scenario_element` se aparecer um facto ou cabeça de regra deste modelo na base de conhecimento.
  - Exemplo: `*uma pessoa* passou no teste; indefinido.`

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
- **Uso encadeado** (omitindo o primeiro argumento):
  ```le
  faremos um pagamento ao abrigo de esta apólice relativo a um sinistro
  ```
  expande para a conjunção
  ```le
  faremos um pagamento
  e o pagamento ao abrigo de esta apólice
  e o pagamento relativo a um sinistro
  ```
- **Uso isolado** continua permitido: `o pagamento ao abrigo de esta apólice`.

## 3. Regras e factos
- **Facto:** uma frase simples terminada em ponto.
  - `Alice é uma pessoa.`
- **Regra:** uma frase com cabeça e corpo.
  - `Cabeça se Corpo.`
  - `uma pessoa é elegível se a pessoa é cidadã.`
- **Facto desconhecido:** declara que certa instância de um modelo é desconhecida; pode aparecer na base de conhecimento ou num cenário.
  - `é desconhecido se um pagamento é relativo ao sinistro 01.` (São aceites `é assumido se ...` e `é assumível se ...`.)

### 3.1 Secções de regras
As regras de uma base de conhecimento podem agrupar-se em **secções** nomeadas:
```le
secção <nome> é:
```
Cada regra que segue o marcador pertence à secção `<nome>`, até ao marcador
seguinte. Sem marcadores, as regras pertencem à secção `main`.

Abreviatura para a secção `annexes`:
```le
os anexos ao contrato são:
```
(sinónimo: `os anexos à base de conhecimento são:`).

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

## 4. Operadores lógicos
- **E:** `e` (ou nova linha com a mesma indentação)
- **Ou:** `ou`, `uma das seguintes`, `alguma das seguintes`, `todas as seguintes`
- **Negação:** `não é o caso que` ou `não se verifica que`
- **Negação condicional:** `a menos que` (ou `salvo se`)
  - `Cabeça se Corpo a menos que Condição.` (≡ `Cabeça se Corpo e não Condição.`)
- **Quantificação universal:**
  ```le
  para todos os casos em que
      <condição 1>
      <condição 2>
  é o caso que
      <consequência>
  ```

## 5. Agregações
Cálculos sobre conjuntos de resultados.
- **Operadores:** `soma`, `contagem`, `média`, `mínimo`, `máximo`
- **Sintaxe:** `<Resultado> é a <op> de cada <Var> tal que` seguido das condições em linhas aninhadas
- **Exemplo:**
  ```le
  o total é a soma de cada montante tal que
      a conta tem o montante.
  ```

## 6. Variáveis e constantes
- **Variáveis:**
  - Explícitas: `*a minha variável*`
  - Implícitas: `uma pessoa`, `a pessoa`, `alguma pessoa`, `cada pessoa`, `qual pessoa`
  - Especiais: `quem`, `quê`, `quando`, `onde`

### 6.1 Nomes e tipos de variáveis
- **Tipo** = o **substantivo principal** da frase; a frase completa é o **nome** da variável (identidade e apresentação).
- **Qualificador inicial:** um ordinal (`primeiro/primeira`, …, `décimo/décima`) ou `outro, outra, novo, nova, anterior, próximo, atual, último, mesmo, original, único, dado`, antes do substantivo, distingue variáveis do mesmo tipo: `uma primeira pessoa` e `uma segunda pessoa` são **duas variáveis do tipo `pessoa`**.
- **Convenção de identificadores maiúsculos:** um identificador final (letra maiúscula única ou token curto em MAIÚSCULAS) é o nome da variável e o substantivo anterior é o tipo: `uma pessoa X`, `um número N`, `uma data D`.
- **Tipos multi-palavra genuínos** mantêm-se inteiros: `um dano corporal` tem o tipo `dano corporal`.
- Ocorrências repetidas da mesma frase co-referem (`uma primeira pessoa` … `a primeira pessoa`).
- **Cenários:** um determinante indefinido (`um/uma`) introduz uma variável; uma frase definida (`o pão`, `a casa`) é uma **constante**.

### 6.2 Verificação de tipos
O **tipo** de um argumento variável rejeita valores que não lhe pertencem. A
verificação é **preguiçosa** (dispara quando o argumento fica ligado) e
**tolerante** (só rejeita perante conflito claro). Consulta os factos `é um`
da sessão (factos de cenário) e da base de conhecimento. Os tipos universais
`any` e afins aceitam qualquer valor. Numa árvore de explicação, uma
verificação de tipo aparece como a asserção que verifica, p.ex. `este
pagamento é um pagamento`.

- **Constantes:**
  - Nomes próprios: `Alice`, `Bob`
  - Strings: `"Olá"`, `'Mundo'`
  - Números: `42`, `3,14` (vírgula decimal; ver §7)
  - Datas: `2023-10-27`

## 7. Aritmética e comparações
- **Matemática:** `+`, `-`, `*`, `/`, `( )`
- **Funções:** `ceiling`, `floor`, `round`, `truncate`, `integer`, `abs`, `sign`, `sqrt`, aplicadas a um argumento entre parênteses.
- **Comparação:** `=`, `>`, `<`, `>=`, `<=`, `==`, `!=`
- **Números:** em Português Lógico o separador decimal é a **vírgula** (`1,5`) e o separador de milhares é o **ponto** (`1.234.567`). Uma vírgula imediatamente entre dígitos é decimal; nas listas escreva `[1, 5]` (vírgula seguida de espaço). As datas mantêm o formato ISO (`2026-07-15`).
- **Nomes de variáveis em expressões:** numa expressão aritmética, uma palavra só é reconhecida como variável se for um **identificador** (letra maiúscula única ou token curto em MAIÚSCULAS), p.ex. `ENT = ETI * ATR - TO`.
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
  - `*V1* é conhecido`
  - `*V1* está em *V2*` (pertença a lista)

### 7.1 Datas
- **Representação:** as datas são analisadas pelo tokenizador e representadas como `date(Ano, Mês, Dia)`.
- **Comparações:** cronológicas, através dos modelos de sistema acima (`é posterior a`, `é anterior a`, …).

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
- **Sintaxe:** `<NomeDaConsulta> espera respostas ["Resposta 1", "Resposta 2"] e desconhecidos ["Desconhecido 1"].` (A parte `e desconhecidos [...]` é opcional.)
- **Exemplo:**
  ```le
  cenário alice é:
      John nasceu em o Reino Unido em 2021-10-09.
      um espera respostas ["John adquire cidadania britânica em 2021-10-9T0:0:0.0"].
  ```

## 13. Predicados de sistema
Acessíveis via a palavra-chave `prolog` ou usados para introspeção — os mesmos
do LE inglês: `le_my_kb/1`, `le_my_id/1`, `le_type/1`, `is_a/2`,
`le_source_element/3`, `le_source_section/2`, `le_source_info/4`, `le_issue/6`,
`le_dict/1`, `le_kb/1`, `scenario/2`, `query_info/3`, `le_expected/3`,
`ontology/1`.

## 14. Recursos incluídos
```le
a base de conhecimento minhaBC inclui estes recursos:
    Recurso1, Recurso2.
```
- Os recursos podem ser caminhos relativos ou URLs; a extensão `.le` é implícita. Regras, factos, modelos e ontologia incluídos são adicionados à base local; cenários e consultas dos recursos incluídos são ignorados. As inclusões são transitivas até uma profundidade máxima; os recursos devem estar **na mesma linguagem** do programa que os inclui (decisão O-10).
- Um recurso com extensão `.pl` é um **recurso Prolog** (tabela de factos exposta por uma camada fina de modelos LE com corpos `prolog`; ver o resumo inglês §14.1 para os detalhes de segurança e cache).

## 15. Extensões LE
- **Regras `apenas se` (condições necessárias):** `Cabeça apenas se Corpo.` compila para *"oposto-da-Cabeça se não é o caso que Corpo"*; com `; oposto:` declarado, a conclusão negativa usa essa forma. (Sinónimo: `somente se`.)
- **Orações relativas com `qual`** *(requer le_extensions.pl)*: `qual` continua uma condição sobre a **última variável** da condição anterior.
- **`a menos que` dentro de corpos** *(requer le_extensions.pl)*: inline ou governando um bloco indentado — equivalente a `e não é o caso que ...`:
  ```le
  pagaremos um sinistro se
      o sinistro é coberto
      e a menos que
          o sinistro é fraudulento.
  ```
- **Alternativas agrupadas:** `uma das seguintes:` / `alguma das seguintes:` / `pelo menos uma das seguintes:` agrupam os filhos com OU; `todas as seguintes:` agrupa-os com E.
- **Regras com rótulo e corpos numerados:** `regra <nome>: Cabeça se: 1. ... ; e 2. ...` — cada condição numerada é endereçável pelo seu designador hierárquico via `le_source_element/3`.
- **Objetivos Prolog embutidos:** `prolog <objetivo>` chama Prolog diretamente; as variáveis LE referem-se como frases `o <nome>`, marcadores `*um nome*` ou identificadores em MAIÚSCULAS.
- **Encadeamento preposicional:** ver §2.1.

## 16. Humanizar o LE
- **Use `apenas se` para condições necessárias**, com a forma `; oposto:` declarada.
- **Use adições preposicionais para encadear numa só frase:** `faremos um pagamento ao abrigo de esta apólice relativo a um sinistro`.
- **Use `qual` para continuar um pensamento** sem repetir variáveis.
- **Use `a menos que` para exceções.**
- **Use blocos `uma das seguintes:` / `todas as seguintes:`** para alternativas enumeradas.
- **Espelhe a estrutura do documento fonte:** rotule regras com `regra <nome>:`, use corpos numerados, agrupe com `secção ... é:` / o cabeçalho de anexos, e cite a cláusula num comentário `%`.
- **Declare formas `; sinónimo:`** para que factos, cenários e consultas usem a formulação mais natural em cada contexto.
- **Mantenha a redação dos modelos próxima do texto fonte**, deixando as palavras ignoráveis (um/uma/o/a/é/são...) suportar a gramática.
- **Marque o estatuto epistémico** com `; assumível` (juízo pericial) e `; indefinido` (dados do caso).
- **Nomeie indivíduos com significado:** constantes descritivas sem determinante (`sinistro um`, `lesão no pulso`, `Reino Unido`).
