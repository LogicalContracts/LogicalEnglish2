// src/le-templates.ts
function splitTemplate(label) {
  const segs = [];
  const re = /\*([^*]+)\*/g;
  let last = 0;
  let m;
  while ((m = re.exec(label)) !== null) {
    const lit = label.slice(last, m.index).trim();
    if (lit)
      segs.push({ kind: "literal", text: lit });
    segs.push({ kind: "field", text: m[1].trim() });
    last = m.index + m[0].length;
  }
  const tail = label.slice(last).trim();
  if (tail)
    segs.push({ kind: "literal", text: tail });
  return segs;
}
function parseTemplateDefs(source) {
  const defs = [];
  const sectionHeader = /^(?:the\s+knowledge\s+base|the\s+contract|the\s+ontology|the\s+predicates|the\s+templates|the\s+fluents|the\s+events|the\s+target\s+language|scenario|query)\b/im;
  const templateHeader = /the\s+(predicates|templates|fluents|events)\s+are\s*:/gi;
  let m;
  while ((m = templateHeader.exec(source)) !== null) {
    const remaining = source.substring(m.index + m[0].length);
    const next = remaining.match(sectionHeader);
    const sectionText = next ? remaining.substring(0, next.index) : remaining;
    for (const line of sectionText.split("\n")) {
      const t2 = line.trim();
      if (!t2 || t2.startsWith("%"))
        continue;
      const semi = t2.indexOf(";");
      const annotation = semi >= 0 ? t2.slice(semi + 1) : "";
      const isUndefined = /\b(undefined|scenario\s+element)\b/i.test(annotation);
      const main = (semi >= 0 ? t2.slice(0, semi) : t2).replace(/[.,]\s*$/, "").trim();
      if (main)
        defs.push({ label: main, isUndefined });
      const opp = annotation.match(/opposite:\s*([^;]+)/i);
      if (opp) {
        const o = opp[1].replace(/[.,;]\s*$/, "").trim();
        if (o)
          defs.push({ label: o, isUndefined });
      }
      for (const sm of annotation.matchAll(/\bsynonym\s+([^;]+)/gi)) {
        const s = sm[1].replace(/[.,;]\s*$/, "").trim();
        if (s)
          defs.push({ label: s, isUndefined });
      }
    }
  }
  return defs;
}
function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
function templateRegex(label) {
  const segs = splitTemplate(label);
  if (!segs.some((s) => s.kind === "field"))
    return null;
  const pieces = segs.map((s) => {
    if (s.kind === "field")
      return "(.+?)";
    const lit = escapeRegex(s.text).replace(/\s+/g, "\\s+").replace(/,/g, ",(?!\\d)");
    const lb = /^\w/.test(s.text) ? "\\b" : "";
    const rb = /\w$/.test(s.text) ? "\\b" : "";
    return lb + lit + rb;
  });
  try {
    return new RegExp("^\\s*" + pieces.join("\\s*") + "\\s*$", "i");
  } catch {
    return null;
  }
}
function literalLength(label) {
  return splitTemplate(label).filter((s) => s.kind === "literal").reduce((n, s) => n + s.text.length, 0);
}
function matchFact(fact, templates) {
  const f = fact.trim().replace(/\.\s*$/, "");
  const norm = (s) => s.replace(/\s+/g, " ").trim().toLowerCase();
  const fNorm = norm(f);
  const sorted = [...templates].sort((a, b) => literalLength(b) - literalLength(a));
  for (const label of sorted) {
    const segs = splitTemplate(label);
    if (!segs.some((s) => s.kind === "field")) {
      const lit = segs.map((s) => s.text).join(" ");
      if (norm(lit) === fNorm)
        return { label, values: [] };
      continue;
    }
    const re = templateRegex(label);
    if (!re)
      continue;
    const m = re.exec(f);
    if (m)
      return { label, values: m.slice(1).map((v) => (v || "").trim()) };
  }
  return null;
}
function scanBlocks(source, headerRe) {
  const blocks = [];
  const lines = source.split("\n");
  const offsets = [];
  let off = 0;
  for (const ln of lines) {
    offsets.push(off);
    off += ln.length + 1;
  }
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(headerRe);
    if (!m)
      continue;
    const name = m[1].trim();
    const start = offsets[i];
    const bodyLines = [];
    let j = i + 1;
    let lastContent = i;
    while (j < lines.length) {
      const ln = lines[j];
      const t2 = ln.trim();
      if (t2 === "") {
        bodyLines.push(ln);
        j++;
        continue;
      }
      if (t2.startsWith("%")) {
        bodyLines.push(ln);
        lastContent = j;
        j++;
        continue;
      }
      if (/^\s/.test(ln)) {
        bodyLines.push(ln);
        lastContent = j;
        j++;
        continue;
      }
      break;
    }
    const end = offsets[lastContent] + lines[lastContent].length;
    blocks.push({ name, start, end, bodyLines });
  }
  return blocks;
}
function parseQueryBlocks(source) {
  return scanBlocks(source, /^query\s+(.+?)\s+is\s*:/i).map((b) => {
    const bodyLines = b.bodyLines.map((l) => stripInlineComment(l).replace(/\s+$/, "")).filter((l) => l.trim() !== "");
    const body = bodyLines.map((l) => l.trim()).join(" ").replace(/\.\s*$/, "").trim();
    return { name: b.name, start: b.start, end: b.end, body, bodyLines };
  });
}
function stripInlineComment(line) {
  let inStr = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"')
      inStr = !inStr;
    else if (c === "%" && !inStr)
      return line.slice(0, i);
  }
  return line;
}

// src/generated/i18nData.ts
var uiCatalog = {
  "en": {},
  "pt": {
    "+ Add": "+ Adicionar",
    "+ Add Query": "+ Adicionar consulta",
    "A hands-on tutorial: write, query and debug three small LE programs.": "Um tutorial pr\xE1tico: escrever, consultar e depurar tr\xEAs pequenos programas LE.",
    "API Keys &amp; Assistant Settings": "Chaves de API e defini\xE7\xF5es do Assistente",
    "API Keys &amp; Assistant Settings...": "Chaves de API e defini\xE7\xF5es do Assistente...",
    "Add condition": "Adicionar condi\xE7\xE3o",
    "Add fact": "Adicionar facto",
    "Add query": "Adicionar consulta",
    "Anthropic API Key:": "Chave de API Anthropic:",
    "Ask the assistant (e.g., 'Fix indentation', 'Draft a program for...')": "Pe\xE7a ao assistente (p.ex., 'Corrige a indenta\xE7\xE3o', 'Esbo\xE7a um programa para...')",
    "Assistant Max Steps (1-50):": "Passos m\xE1ximos do Assistente (1-50):",
    "Assistant Model:": "Modelo do Assistente:",
    "Assume fact": "Assumir facto",
    "Auto Layout": "Arranjo autom\xE1tico",
    "Cancel": "Cancelar",
    "Center": "Centrar",
    "Choose a program": "Escolha um programa",
    "Choose a program to explore.": "Escolha um programa para explorar.",
    "Circle": "C\xEDrculo",
    "Clone Tool": "Ferramenta de clonagem",
    "Clone tool: click a node to duplicate it (needed when the proof uses the same rule more than once)": "Ferramenta de clonagem: clique num n\xF3 para o duplicar (necess\xE1rio quando a prova usa a mesma regra mais de uma vez)",
    "Close this panel": "Fechar este painel",
    "Collapse All": "Recolher tudo",
    "Continue": "Continuar",
    "Continue (F5) \u2014 resume running until the next answer is found (or the query finishes). If more solutions remain, stepping/continuing again explores them.": "Continuar (F5) \u2014 retoma a execu\xE7\xE3o at\xE9 encontrar a pr\xF3xima resposta (ou a consulta terminar). Se restarem solu\xE7\xF5es, avan\xE7ar/continuar de novo explora-as.",
    "Copy": "Copiar",
    "Copy Answer": "Copiar resposta",
    "Copy Explanation": "Copiar explica\xE7\xE3o",
    "Copy Mermaid": "Copiar Mermaid",
    "Copy Node": "Copiar n\xF3",
    "Copy Scenario": "Copiar cen\xE1rio",
    "Copy URL": "Copiar URL",
    "Copy as Mermaid diagram": "Copiar como diagrama Mermaid",
    "Copy the visible graph as a Mermaid diagram (text), pasteable into GitHub, Obsidian, mermaid.live\u2026": "Copiar o grafo vis\xEDvel como diagrama Mermaid (texto), col\xE1vel no GitHub, Obsidian, mermaid.live\u2026",
    "Custom Query:": "Consulta personalizada:",
    "Custom Scenario Facts:": "Factos de cen\xE1rio personalizados:",
    "Cut": "Cortar",
    "Dagre (Hierarchical)": "Dagre (hier\xE1rquico)",
    "Dark": "Escuro",
    "Dark Theme": "Tema escuro",
    "Detailed failure explanations (per-rule nodes)": "Explica\xE7\xF5es de falha detalhadas (n\xF3s por regra)",
    "Direction": "Dire\xE7\xE3o",
    "ELK (Layered)": "ELK (em camadas)",
    "Edge Types": "Tipos de arestas",
    "Edit": "Editar",
    "Edit Queries\u2026": "Editar consultas\u2026",
    "Edit Scenarios\u2026": "Editar cen\xE1rios\u2026",
    "Enter facts here...": "Escreva factos aqui...",
    "Enter query here...": "Escreva a consulta aqui...",
    "Expand All": "Expandir tudo",
    "Explanation Drill": "Explora\xE7\xE3o da explica\xE7\xE3o",
    "Explanation Drill\u2026": "Explora\xE7\xE3o da explica\xE7\xE3o\u2026",
    "Explanations Preferences": "Prefer\xEAncias das explica\xE7\xF5es",
    "File": "Ficheiro",
    "Filter programs": "Filtrar programas",
    "Filter\u2026": "Filtrar\u2026",
    "Find": "Procurar",
    "Fit View": "Ajustar vista",
    "Fit to Screen": "Ajustar ao ecr\xE3",
    "Go to full sub-explanation": "Ir para a sub-explica\xE7\xE3o completa",
    "Google API Key:": "Chave de API Google:",
    "Grid": "Grelha",
    "Groq API Key:": "Chave de API Groq:",
    "Help": "Ajuda",
    "Hide repeated explanations": "Ocultar explica\xE7\xF5es repetidas",
    "High Contrast": "Alto contraste",
    "Home": "In\xEDcio",
    "Horizontal (L\u2192R)": "Horizontal (E\u2192D)",
    "Insert into Editor": "Inserir no editor",
    "Interrupt": "Interromper",
    "Introduction to Logical English (tutorial)": "Introdu\xE7\xE3o ao Logical English (tutorial)",
    "Keys and preferences are stored in your browser's local storage.": "As chaves e prefer\xEAncias ficam guardadas no armazenamento local do seu navegador.",
    "LE Debugger": "Depurador LE",
    "LE Proof Game": "Jogo da Prova LE",
    "Large": "Grande",
    "Layout": "Arranjo",
    "Light": "Claro",
    "Light Mode": "Modo leve",
    "Light Mode runs a fast, in-process Prolog loop. Uncheck for Deep Mode (full opencode agent with file/web/shell tools).": "O Modo leve corre um ciclo Prolog r\xE1pido em processo. Desmarque para o Modo profundo (agente opencode completo com ficheiros/web/terminal).",
    "Light Theme": "Tema claro",
    "Load": "Carregar",
    "Loading models...": "A carregar modelos...",
    "Logical English": "Logical English",
    "Logical English syntax (reference)": "Sintaxe do Logical English (refer\xEAncia)",
    "Medium": "M\xE9dio",
    "Misc": "Diversos",
    "Name": "Nome",
    "New": "Novo",
    "New from URL": "Novo a partir de URL",
    "New from URL...": "Novo a partir de URL...",
    "Node Types": "Tipos de n\xF3s",
    "None": "Nenhum",
    "Open Scenario Variations: alter the selected scenario and run one or more queries against the variation, in a separate window": "Abrir Varia\xE7\xF5es de Cen\xE1rio: altere o cen\xE1rio selecionado e corra uma ou mais consultas sobre a varia\xE7\xE3o, numa janela separada",
    "Open copy from server...": "Abrir c\xF3pia do servidor...",
    "Open from Server": "Abrir do servidor",
    "Open the Proof Game: interactively build a proof of the selected query by connecting its facts and rules": "Abrir o Jogo da Prova: construa interativamente uma prova da consulta selecionada ligando os seus factos e regras",
    "Open...": "Abrir...",
    "OpenAI API Key:": "Chave de API OpenAI:",
    "PROLOG Equivalent": "Equivalente PROLOG",
    "Paste": "Colar",
    "Patch scenario": "Ajustar cen\xE1rio",
    "Predicates Legend": "Legenda de predicados",
    "Preferences...": "Prefer\xEAncias...",
    "Prefix for failed nodes:": "Prefixo para n\xF3s falhados:",
    "Proof Game": "Jogo da Prova",
    "Query": "Consulta",
    "Query Editor": "Editor de consultas",
    "Query:": "Consulta:",
    "Redraw from here": "Redesenhar a partir daqui",
    "Refresh": "Atualizar",
    "Replace": "Substituir",
    "Save": "Guardar",
    "Save As...": "Guardar como...",
    "Scenario": "Cen\xE1rio",
    "Scenario Editor": "Editor de cen\xE1rios",
    "Scenario Variations": "Varia\xE7\xF5es de cen\xE1rio",
    "Scenario:": "Cen\xE1rio:",
    "Search nodes...": "Procurar n\xF3s...",
    "Select a query...": "Selecione uma consulta...",
    "Select a scenario...": "Selecione um cen\xE1rio...",
    "Send": "Enviar",
    "Send command to the LE Assistant": "Enviar comando ao Assistente LE",
    "Show Proof": "Mostrar prova",
    "Show important reason": "Mostrar raz\xE3o importante",
    "Small": "Pequeno",
    "Step": "Avan\xE7ar",
    "Step (F11) \u2014 advance one step to the next goal being proved. The call stack and the VARIABLES panel update to show the new position and any bindings made so far.": "Avan\xE7ar (F11) \u2014 avan\xE7a um passo at\xE9 ao pr\xF3ximo objetivo a provar. A pilha de chamadas e o painel VARI\xC1VEIS atualizam-se com a nova posi\xE7\xE3o e as liga\xE7\xF5es feitas at\xE9 a\xED.",
    "Stop": "Parar",
    "Stop \u2014 end the trace and detach the debugger. The query keeps running to completion in the background.": "Parar \u2014 termina o rastreio e desliga o depurador. A consulta continua a correr at\xE9 ao fim em segundo plano.",
    "The editor manual: files, queries, scenario/query editors, explanations.": "O manual do editor: ficheiros, consultas, editores de cen\xE1rios/consultas, explica\xE7\xF5es.",
    "The language reference: every LE construct.": "A refer\xEAncia da linguagem: todas as constru\xE7\xF5es LE.",
    "This prefix is prepended to failed nodes when copying explanations to plain text or HTML.": "Este prefixo \xE9 anteposto aos n\xF3s falhados ao copiar explica\xE7\xF5es para texto simples ou HTML.",
    "Together API Key:": "Chave de API Together:",
    "Trace": "Rastrear",
    "Type Hierarchy": "Hierarquia de tipos",
    "URL of a Logical English program:": "URL de um programa Logical English:",
    "Using this editor (manual)": "Usar este editor (manual)",
    "Vertical (T\u2192B)": "Vertical (C\u2192B)",
    "View Source Graph": "Ver grafo do programa",
    "Visualize the program's templates, rules, facts, scenarios and queries as a dependency graph, in a new browser tab": "Visualizar os modelos, regras, factos, cen\xE1rios e consultas do programa como um grafo de depend\xEAncias, num novo separador",
    "When on (the default), a sub-explanation that occurs several times in a success or failure explanation is shown once and tagged with its count. Turn off to see every occurrence in full (larger trees).": "Quando ativo (predefini\xE7\xE3o), uma sub-explica\xE7\xE3o que ocorre v\xE1rias vezes numa explica\xE7\xE3o \xE9 mostrada uma vez com a sua contagem. Desative para ver todas as ocorr\xEAncias por extenso (\xE1rvores maiores).",
    "When on, a failed predicate with several rules shows an intermediate node per rule (navigable to that rule), with each rule's failed sub-goals beneath it. Slower; off by default.": "Quando ativo, um predicado falhado com v\xE1rias regras mostra um n\xF3 interm\xE9dio por regra (naveg\xE1vel at\xE9 \xE0 regra), com os sub-objetivos falhados por baixo. Mais lento; desativado por predefini\xE7\xE3o.",
    "Zoom In": "Ampliar",
    "Zoom Out": "Reduzir",
    "and": "e",
    "fCoSE (Default)": "fCoSE (predefini\xE7\xE3o)",
    "not": "n\xE3o",
    "or": "ou",
    "query name": "nome da consulta",
    "scenario name": "nome do cen\xE1rio",
    "Are you sure you want to miss the excitement of finding the proof yourself?": "Tem a certeza de que quer perder a emo\xE7\xE3o de encontrar a prova por si mesmo?",
    "No proof found for this query.": "Nenhuma prova encontrada para esta consulta.",
    "(empty)": "(vazio)",
    "A query name must be a single word or number (no spaces).": "O nome de uma consulta tem de ser uma \xFAnica palavra ou n\xFAmero (sem espa\xE7os).",
    "A scenario name must be a single word (no spaces).": "O nome de um cen\xE1rio tem de ser uma \xFAnica palavra (sem espa\xE7os).",
    "Accept?": "Aceitar?",
    "Add a query first.": "Adicione primeiro uma consulta.",
    "Add at least one condition to the query.": "Adicione pelo menos uma condi\xE7\xE3o \xE0 consulta.",
    "Another...": "Outra...",
    "Answer the highlighted question, or revise an earlier one.": "Responda \xE0 pergunta destacada, ou reveja uma anterior.",
    "Click to show this in the editor": "Clique para mostrar no editor",
    "Configure an LLM model first: in the main editor, Misc \u2192 API Keys\u2026": "Configure primeiro um modelo LLM: no editor principal, Diversos \u2192 Chaves de API\u2026",
    "Connecting to debugger...": "A ligar ao depurador...",
    "Copied to clipboard": "Copiado para a \xE1rea de transfer\xEAncia",
    "Copied!": "Copiado!",
    "Copied": "Copiado",
    "Copy URL is only available for existing examples.": "Copiar URL s\xF3 est\xE1 dispon\xEDvel para exemplos existentes.",
    "Copy the query text:": "Copie o texto da consulta:",
    "Copy the scenario text:": "Copie o texto do cen\xE1rio:",
    "Could not load the program on the server.": "N\xE3o foi poss\xEDvel carregar o programa no servidor.",
    "Could not reach the server.": "N\xE3o foi poss\xEDvel contactar o servidor.",
    "Debugger connected. Initializing...": "Depurador ligado. A inicializar...",
    "Debugger disconnected.": "Depurador desligado.",
    "Delete condition": "Eliminar condi\xE7\xE3o",
    "Delete this question": "Eliminar esta pergunta",
    "Delete": "Eliminar",
    "Discard unsaved changes and load the selected query?": "Descartar altera\xE7\xF5es n\xE3o guardadas e carregar a consulta selecionada?",
    "Discard unsaved changes and load the selected scenario?": "Descartar altera\xE7\xF5es n\xE3o guardadas e carregar o cen\xE1rio selecionado?",
    "Done": "Conclu\xEDdo",
    "Download": "Transferir",
    "Error connecting to server for game data.": "Erro ao ligar ao servidor para obter os dados do jogo.",
    "Error executing query.": "Erro ao executar a consulta.",
    "Error loading module: ": "Erro ao carregar o m\xF3dulo: ",
    "Error: ": "Erro: ",
    "Explanation": "Explica\xE7\xE3o",
    "Failed to get game data from server.": "Falha ao obter os dados do jogo do servidor.",
    "Failed to load example from server.": "Falha ao carregar o exemplo do servidor.",
    "Generate": "Gerar",
    "Generating and verifying\u2026": "A gerar e verificar\u2026",
    "Indent (nest this condition to bind tighter)": "Indentar (aninhar esta condi\xE7\xE3o para ligar mais estreitamente)",
    "Insert anyway": "Inserir mesmo assim",
    "Inserted into editor": "Inserido no editor",
    "Interrupting\u2026": "A interromper\u2026",
    "Loading module on server...": "A carregar o m\xF3dulo no servidor...",
    "Loading\u2026": "A carregar\u2026",
    "Mermaid diagram copied to clipboard": "Diagrama Mermaid copiado para a \xE1rea de transfer\xEAncia",
    "New query": "Nova consulta",
    "New scenario": "Novo cen\xE1rio",
    "New\u2026": "Novo\u2026",
    "No answers (false)": "Sem respostas (falso)",
    "No conditions yet \u2014 pick a template below and click \u201CAdd\u201D.": "Ainda sem condi\xE7\xF5es \u2014 escolha um modelo abaixo e clique em \u201CAdicionar\u201D.",
    "No explanation to drill.": "Nenhuma explica\xE7\xE3o para explorar.",
    "No facts yet \u2014 pick a template below and click \u201CAdd\u201D.": "Ainda sem factos \u2014 escolha um modelo abaixo e clique em \u201CAdicionar\u201D.",
    "No model configured": "Nenhum modelo configurado",
    "No results returned.": "Nenhum resultado devolvido.",
    "No variables for this call.": "Sem vari\xE1veis nesta chamada.",
    "Node copied to clipboard": "N\xF3 copiado para a \xE1rea de transfer\xEAncia",
    "Nothing else to show. Feel free to alter your choices above.": "Nada mais a mostrar. Pode alterar as escolhas acima.",
    "Please enter a custom query.": "Introduza uma consulta personalizada.",
    "Please give the query a name.": "D\xEA um nome \xE0 consulta.",
    "Please give the scenario a name.": "D\xEA um nome ao cen\xE1rio.",
    "Please select a query for the Proof Game.": "Selecione uma consulta para o Jogo da Prova.",
    "Please select a query.": "Selecione uma consulta.",
    "Please wait for the module to load.": "Aguarde o carregamento do m\xF3dulo.",
    "Progress": "Progresso",
    "Query failed.": "A consulta falhou.",
    "Query finished.": "Consulta terminada.",
    "Query interrupted.": "Consulta interrompida.",
    "Ready": "Pronto",
    "Regenerate": "Regenerar",
    "Remove query": "Remover consulta",
    "Results": "Resultados",
    "Running queries\u2026": "A correr consultas\u2026",
    "Scenario copied to clipboard": "Cen\xE1rio copiado para a \xE1rea de transfer\xEAncia",
    "Write it in English": "Escreva em Portugu\xEAs",
    "Write it in English\u2026": "Escreva em Portugu\xEAs\u2026",
    "You have unsaved changes. Create new file anyway?": "Tem altera\xE7\xF5es n\xE3o guardadas. Criar um ficheiro novo mesmo assim?",
    "You have unsaved changes. Load from URL anyway?": "Tem altera\xE7\xF5es n\xE3o guardadas. Carregar do URL mesmo assim?",
    "You have unsaved changes. Open another file anyway?": "Tem altera\xE7\xF5es n\xE3o guardadas. Abrir outro ficheiro mesmo assim?",
    "You have unsaved changes. Open from server anyway?": "Tem altera\xE7\xF5es n\xE3o guardadas. Abrir do servidor mesmo assim?",
    "the LLM request failed.": "o pedido ao LLM falhou.",
    "Important reason: ": "Raz\xE3o importante: ",
    "repeated sub-explanations": "sub-explica\xE7\xF5es repetidas",
    "assumed": "assumido",
    "FAIL": "FALHA",
    "STOP": "PARAR",
    "Unindent": "Desindentar",
    "Language": "L\xEDngua",
    "Answers": "Respostas",
    "Unknowns": "Desconhecidos",
    "Scenarios": "Cen\xE1rios",
    "Queries": "Consultas",
    "Templates": "Modelos",
    "Run": "Correr",
    "Back": "Voltar",
    "Question": "Pergunta",
    "Logged in as: ": "Sess\xE3o iniciada como: ",
    "Login": "Iniciar sess\xE3o",
    "Logout": "Terminar sess\xE3o",
    "Login Failed": "Falha no in\xEDcio de sess\xE3o",
    "Invalid email or password.": "Email ou palavra-passe inv\xE1lidos.",
    "Try again": "Tentar novamente",
    "Edit and Query: ": "Editar e consultar: ",
    "[New Document]": "[Novo documento]",
    "expand all": "expandir tudo",
    "collapse all": "recolher tudo",
    "[show all]": "[mostrar tudo]",
    "Just run a program: ": "Apenas correr um programa: ",
    "[Executive view]": "[Vista executiva]",
    "A minimalist, mobile-friendly way to pick a program, choose a scenario and question, and see the answer \u2014 no editing.": "Uma forma minimalista e amiga do telem\xF3vel de escolher um programa, um cen\xE1rio e uma pergunta, e ver a resposta \u2014 sem edi\xE7\xE3o.",
    "GitHub Repository": "Reposit\xF3rio GitHub",
    "Documentation": "Documenta\xE7\xE3o",
    "A Gentle Introduction to Logical English 2": "Uma introdu\xE7\xE3o suave ao Logical English 2",
    "How to use the LE2 web application": "Como usar a aplica\xE7\xE3o web LE2",
    "Logical English syntax summary": "Resumo da sintaxe do Logical English",
    "Test Suite": "Bateria de testes",
    "Run All Tests": "Correr todos os testes",
    "Email: ": "Email: ",
    "Password: ": "Palavra-passe: ",
    "Start here: a hands-on tutorial that builds three small programs \u2014 a tea party, a flying dragon, and a slice of British nationality law \u2014 teaching how to write, query and debug LE in the editor.": "Comece aqui: um tutorial pr\xE1tico que constr\xF3i tr\xEAs pequenos programas \u2014 uma festa de ch\xE1, um drag\xE3o voador e um peda\xE7o da lei de nacionalidade brit\xE2nica \u2014 ensinando a escrever, consultar e depurar LE no editor.",
    "The editor manual: opening and saving files, running queries, the scenario and query editors, scenario variations, and reading the explanation trees.": "O manual do editor: abrir e guardar ficheiros, correr consultas, os editores de cen\xE1rios e consultas, varia\xE7\xF5es de cen\xE1rio e a leitura das \xE1rvores de explica\xE7\xE3o.",
    "The language reference: every construct \u2014 templates, rules, operators, aggregates, variables and types, dates, ontology, extensions \u2014 for looking things up as you write.": "A refer\xEAncia da linguagem: todas as constru\xE7\xF5es \u2014 modelos, regras, operadores, agrega\xE7\xF5es, vari\xE1veis e tipos, datas, ontologia, extens\xF5es \u2014 para consultar enquanto escreve."
  },
  "es": {},
  "fr": {},
  "it": {}
};
var languages = [
  {
    "code": "en",
    "autonym": "Logical English",
    "opener": "the target language is",
    "decimalSep": ".",
    "thousandsSep": ",",
    "listSep": ",",
    "status": "core"
  },
  {
    "code": "pt",
    "autonym": "Portugu\xEAs L\xF3gico",
    "opener": "a linguagem alvo \xE9",
    "decimalSep": ",",
    "thousandsSep": ".",
    "listSep": ",",
    "status": "pilot"
  }
];

// src/i18n.ts
var STORAGE_KEY = "le-ui-lang";
function uiLang() {
  try {
    const l = localStorage.getItem(STORAGE_KEY);
    if (l && languages.some((x) => x.code === l))
      return l;
  } catch (e) {
  }
  return "en";
}
function t(key) {
  const lang = uiLang();
  if (lang === "en")
    return key;
  const cat = uiCatalog[lang];
  return cat && cat[key] || key;
}
var AUTO_SELECTOR = [
  "button",
  "label",
  "option",
  "h1",
  "h2",
  "h3",
  "h4",
  "th",
  "summary",
  "legend",
  ".dropdown-item",
  ".menu-item",
  "[data-i18n]"
].join(",");
function translateFirstTextNode(el) {
  for (const node of Array.from(el.childNodes)) {
    if (node.nodeType === Node.TEXT_NODE) {
      const raw = node.textContent ?? "";
      const trimmed = raw.trim();
      if (trimmed) {
        const tr = t(trimmed);
        if (tr !== trimmed)
          node.textContent = raw.replace(trimmed, tr);
        return;
      }
    }
  }
}
function applyI18nDom(root = document) {
  if (uiLang() === "en")
    return;
  root.querySelectorAll(AUTO_SELECTOR).forEach((el) => translateFirstTextNode(el));
  root.querySelectorAll("[title]").forEach((el) => {
    const v = el.getAttribute("title");
    if (v) {
      const tr = t(v.trim());
      if (tr !== v.trim())
        el.setAttribute("title", tr);
    }
  });
  root.querySelectorAll("[placeholder]").forEach((el) => {
    const v = el.getAttribute("placeholder");
    if (v) {
      const tr = t(v.trim());
      if (tr !== v.trim())
        el.setAttribute("placeholder", tr);
    }
  });
}
function installLeApiLang() {
  if (uiLang() === "en")
    return;
  const origFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    try {
      const url = typeof input === "string" ? input : input.url ?? String(input);
      if (/^\/(leapi|query|verify|list_examples|example_details)\b/.test(url) && !/[?&]lang=/.test(url)) {
        const sep = url.includes("?") ? "&" : "?";
        const newUrl = `${url}${sep}lang=${encodeURIComponent(uiLang())}`;
        if (typeof input === "string")
          return origFetch(newUrl, init);
        return origFetch(new Request(newUrl, input), init);
      }
    } catch (e) {
    }
    return origFetch(input, init);
  };
}

// src/nl-input.ts
var TOKEN = "myToken123";
function assistantModel() {
  return localStorage.getItem("le-assistant-model") || "";
}
function assistantKeys() {
  return {
    openai: localStorage.getItem("le-openai-key"),
    anthropic: localStorage.getItem("le-anthropic-key"),
    google: localStorage.getItem("le-google-key"),
    groq: localStorage.getItem("le-groq-key"),
    together: localStorage.getItem("le-together-key")
  };
}
function ensureStyles() {
  if (document.getElementById("nl-input-styles"))
    return;
  const style = document.createElement("style");
  style.id = "nl-input-styles";
  style.textContent = `
        .nl-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex;
            align-items: center; justify-content: center; z-index: 1000; }
        .nl-dialog { background: var(--panel-bg, #252526); color: var(--text-color, #d4d4d4);
            border: 1px solid var(--border-color, #444); border-radius: 8px; width: min(640px, 92vw);
            max-height: 90vh; overflow: auto; padding: 18px 20px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
        .nl-dialog h2 { margin: 0 0 8px 0; font-size: 16px; cursor: move; user-select: none; }
        .nl-instruction { color: var(--muted, #888); font-size: 12px; margin: 0 0 12px 0; line-height: 1.5; }
        .nl-dialog textarea { width: 100%; min-height: 96px; resize: vertical; font-family: inherit;
            font-size: 14px; background: var(--field-bg, #2d2d30); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 8px; box-sizing: border-box; }
        .nl-status { font-size: 12px; margin: 10px 0 0 0; min-height: 16px; white-space: pre-line; }
        .nl-status.error { color: #f48771; }
        .nl-status.warn { color: #e2b93d; }
        .nl-actions { display: flex; gap: 10px; align-items: center; justify-content: flex-end; margin-top: 14px; }
        .nl-actions .spacer { flex: 1; }
        .nl-model { color: var(--muted, #888); font-size: 11px; }
        .nl-dialog button { background: var(--input-bg, #3c3c3c); color: var(--input-text, #d4d4d4);
            border: 1px solid var(--input-border, #555); border-radius: 4px; padding: 6px 12px; font: inherit; cursor: pointer; }
        .nl-dialog button.primary { background: var(--accent, #0e639c); color: #fff; border-color: var(--accent, #0e639c); }
        .nl-dialog button:disabled { opacity: 0.5; cursor: default; }
    `;
  document.head.appendChild(style);
}
function makeDraggable(box, handle) {
  let dx = 0, dy = 0;
  let startX = 0, startY = 0, ox = 0, oy = 0, dragging = false;
  const onMove = (e) => {
    if (!dragging)
      return;
    dx = ox + (e.clientX - startX);
    dy = oy + (e.clientY - startY);
    box.style.transform = `translate(${dx}px, ${dy}px)`;
  };
  const onUp = () => {
    dragging = false;
    document.removeEventListener("mousemove", onMove);
    document.removeEventListener("mouseup", onUp);
    document.body.style.userSelect = "";
  };
  handle.addEventListener("mousedown", (e) => {
    dragging = true;
    startX = e.clientX;
    startY = e.clientY;
    ox = dx;
    oy = dy;
    document.body.style.userSelect = "none";
    document.addEventListener("mousemove", onMove);
    document.addEventListener("mouseup", onUp);
    e.preventDefault();
  });
}
function openNlInput(opts) {
  ensureStyles();
  const overlay = document.createElement("div");
  overlay.className = "nl-overlay";
  const dialog = document.createElement("div");
  dialog.className = "nl-dialog";
  overlay.appendChild(dialog);
  const h = document.createElement("h2");
  h.textContent = opts.title;
  const instr = document.createElement("p");
  instr.className = "nl-instruction";
  instr.textContent = opts.instruction;
  const textarea = document.createElement("textarea");
  textarea.placeholder = opts.placeholder || "Type your sentence(s) here\u2026";
  const status = document.createElement("div");
  status.className = "nl-status";
  const actions = document.createElement("div");
  actions.className = "nl-actions";
  const model = assistantModel();
  const modelLabel = document.createElement("span");
  modelLabel.className = "nl-model";
  modelLabel.textContent = model ? `Model: ${model}` : "No model configured";
  const spacer = document.createElement("span");
  spacer.className = "spacer";
  const cancel = document.createElement("button");
  cancel.textContent = t("Cancel");
  const regenerate = document.createElement("button");
  regenerate.textContent = t("Regenerate");
  regenerate.style.display = "none";
  const generate = document.createElement("button");
  generate.className = "primary";
  generate.textContent = t("Generate");
  actions.appendChild(modelLabel);
  actions.appendChild(spacer);
  actions.appendChild(cancel);
  actions.appendChild(regenerate);
  actions.appendChild(generate);
  dialog.appendChild(h);
  dialog.appendChild(instr);
  dialog.appendChild(textarea);
  dialog.appendChild(status);
  dialog.appendChild(actions);
  document.body.appendChild(overlay);
  makeDraggable(dialog, h);
  setTimeout(() => textarea.focus(), 0);
  const close = () => {
    overlay.remove();
    document.removeEventListener("keydown", onKey);
  };
  const onKey = (e) => {
    if (e.key === "Escape")
      close();
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      generate.click();
    }
  };
  document.addEventListener("keydown", onKey);
  cancel.addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay)
      close();
  });
  if (!model) {
    status.className = "nl-status warn";
    status.textContent = t("Configure an LLM model first: in the main editor, Misc \u2192 API Keys\u2026");
    generate.disabled = true;
  }
  let primaryMode = "generate";
  let pendingLe = "";
  function toGenerateMode() {
    primaryMode = "generate";
    generate.textContent = t("Generate");
    regenerate.style.display = "none";
  }
  textarea.addEventListener("input", () => {
    if (primaryMode === "insert")
      toGenerateMode();
  });
  async function run() {
    const sentence = textarea.value.trim();
    if (!sentence) {
      textarea.focus();
      return;
    }
    if (!assistantModel())
      return;
    generate.disabled = true;
    cancel.disabled = true;
    regenerate.disabled = true;
    status.className = "nl-status";
    status.textContent = t("Generating and verifying\u2026");
    const templates = [...new Set(parseTemplateDefs(opts.source).map((d) => d.label))];
    try {
      const res = await fetch("/leapi", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: TOKEN,
          operation: "nl_to_le",
          kind: opts.kind,
          sentence,
          templates,
          content: opts.source,
          // the program, for baseline-diff verification
          model: assistantModel(),
          api_keys: assistantKeys()
        })
      }).then((r) => r.json());
      generate.disabled = false;
      cancel.disabled = false;
      regenerate.disabled = false;
      if (res && res.result === "ok" && typeof res.le === "string" && res.le.trim()) {
        const warnings = Array.isArray(res.warnings) ? res.warnings : [];
        if (warnings.length === 0) {
          opts.onResult(res.le);
          close();
        } else {
          pendingLe = res.le;
          primaryMode = "insert";
          generate.textContent = t("Insert anyway");
          regenerate.style.display = "";
          status.className = "nl-status warn";
          status.textContent = `Verification found ${warnings.length} new issue${warnings.length === 1 ? "" : "s"} vs. your program:
` + warnings.map((w) => `\u2022 ${w}`).join("\n") + "\nYou can insert it anyway, or rephrase and regenerate.";
        }
      } else if (res && res.result === "ok") {
        toGenerateMode();
        status.className = "nl-status warn";
        status.textContent = t("The model returned nothing that matches your templates. Try rephrasing.");
      } else {
        toGenerateMode();
        status.className = "nl-status error";
        status.textContent = t("Error: ") + (res && res.error || "the LLM request failed.");
      }
    } catch {
      generate.disabled = false;
      cancel.disabled = false;
      regenerate.disabled = false;
      toGenerateMode();
      status.className = "nl-status error";
      status.textContent = t("Could not reach the server.");
    }
  }
  generate.addEventListener("click", () => {
    if (primaryMode === "insert") {
      opts.onResult(pendingLe);
      close();
    } else
      run();
  });
  regenerate.addEventListener("click", run);
}

// src/query-editor.ts
var WRITE_IN_ENGLISH = "__write_in_english__";
var CHANNEL = "le-query-editor";
var NEG_PREFIX = /^it is not the case that\s+/i;
function initQueryEditor(data) {
  const source = data.source || "";
  const templates = parseTemplateDefs(source).map((d) => d.label);
  const addable = [...new Set(templates)];
  const blocks = parseQueryBlocks(source);
  const blockByName = /* @__PURE__ */ new Map();
  blocks.forEach((b) => blockByName.set(b.name, b));
  const channel = new BroadcastChannel(CHANNEL);
  const $ = (id) => document.getElementById(id);
  const picker = $("query-picker");
  const nameInput = $("query-name");
  const rowsEl = $("rows");
  const addSelect = $("add-template");
  const statusEl = $("status");
  let loadedName = "";
  let dirty = false;
  let rows = [];
  const setStatus = (text) => {
    statusEl.textContent = text;
  };
  const markDirty = () => {
    dirty = true;
    setStatus(t("Unsaved changes"));
  };
  addSelect.innerHTML = "";
  for (const label of addable) {
    const o = document.createElement("option");
    o.value = label;
    o.textContent = label.replace(/\*/g, "");
    addSelect.appendChild(o);
  }
  const nlOpt = document.createElement("option");
  nlOpt.value = WRITE_IN_ENGLISH;
  nlOpt.textContent = t("Write it in English");
  addSelect.appendChild(nlOpt);
  $("btn-add").addEventListener("click", () => {
    const val = addSelect.value;
    if (!val)
      return;
    if (val === WRITE_IN_ENGLISH) {
      writeInEnglish();
      return;
    }
    const indent = rows.length ? rows[rows.length - 1].indent : 0;
    rows.push({ templateLabel: val, values: [], raw: "", negated: false, connective: "and", indent });
    markDirty();
    render();
    rowsEl.lastElementChild?.querySelector("input.field, input.raw")?.focus();
  });
  function writeInEnglish() {
    openNlInput({
      kind: "query",
      source,
      title: "Add conditions \u2014 write it in English",
      instruction: "Type one or more sentences describing the query to build (a question, and its conditions). The query must respect the predicates (templates) already in your program; if you need to expand these first, use the editor or the LE Assistant.",
      placeholder: "e.g. which person is happy and is not the brother of Bob",
      onResult: (leText) => {
        const lines = leText.split(/\r?\n/).filter((l) => l.trim() !== "");
        const added = parseBody(lines);
        rows.push(...added);
        normalizeIndents();
        markDirty();
        render();
        setStatus(`Added ${added.length} condition${added.length === 1 ? "" : "s"} from English`);
      }
    });
  }
  picker.innerHTML = "";
  const newOpt = document.createElement("option");
  newOpt.value = "__new__";
  newOpt.textContent = t("New\u2026");
  picker.appendChild(newOpt);
  blocks.forEach((b) => {
    const o = document.createElement("option");
    o.value = b.name;
    o.textContent = b.name;
    picker.appendChild(o);
  });
  function leadWidth(s) {
    let w = 0;
    for (const ch of s) {
      if (ch === " ")
        w++;
      else if (ch === "	")
        w += 4;
      else
        break;
    }
    return w;
  }
  function normalizeIndents() {
    let prev = -1;
    for (const r of rows) {
      r.indent = Math.max(0, Math.min(r.indent, prev + 1));
      prev = r.indent;
    }
  }
  function parseBody(bodyLines2) {
    if (bodyLines2.length === 0)
      return [];
    const conds = [];
    for (const raw of bodyLines2) {
      const trimmed = raw.trim();
      const cm = trimmed.match(/^(and|or)\b\s*/i);
      if (conds.length === 0) {
        conds.push({ width: leadWidth(raw), connective: "and", text: trimmed });
      } else if (cm) {
        conds.push({ width: leadWidth(raw), connective: cm[1].toLowerCase(), text: trimmed.slice(cm[0].length) });
      } else {
        conds[conds.length - 1].text += " " + trimmed;
      }
    }
    conds[conds.length - 1].text = conds[conds.length - 1].text.replace(/\.\s*$/, "").trim();
    const widths = [...new Set(conds.map((c) => c.width))].sort((a, b) => a - b);
    const wholeBody = bodyLines2.map((l) => l.trim()).join(" ").replace(/\.\s*$/, "").trim();
    const parsed = [];
    for (const c of conds) {
      const negated = NEG_PREFIX.test(c.text);
      const inner = negated ? c.text.replace(NEG_PREFIX, "").trim() : c.text.trim();
      const m = matchFact(inner, templates);
      if (!m)
        return [{ templateLabel: null, values: [], raw: wholeBody, negated: false, connective: "and", indent: 0 }];
      parsed.push({ templateLabel: m.label, values: m.values, raw: "", negated, connective: c.connective, indent: widths.indexOf(c.width) });
    }
    return parsed;
  }
  function loadQuery(name) {
    const block = blockByName.get(name);
    loadedName = block ? block.name : "";
    nameInput.value = block ? block.name : "";
    rows = block ? parseBody(block.bodyLines) : [];
    normalizeIndents();
    dirty = false;
    render();
    setStatus(block ? `Loaded query "${name}"` : "");
  }
  function newQuery() {
    loadedName = "";
    nameInput.value = "";
    rows = [];
    dirty = false;
    render();
    setStatus(t("New query"));
  }
  function sizeField(input) {
    const n = Math.max((input.value || input.placeholder).length + 1, 6);
    input.size = Math.min(n, 80);
  }
  function render() {
    rowsEl.innerHTML = "";
    if (rows.length === 0) {
      const hint = document.createElement("div");
      hint.className = "empty-hint";
      hint.textContent = t("No conditions yet \u2014 pick a template below and click \u201CAdd\u201D.");
      rowsEl.appendChild(hint);
      return;
    }
    rows.forEach((row, idx) => rowsEl.appendChild(renderRow(row, idx)));
  }
  function indentRow(idx, delta) {
    rows[idx].indent = Math.max(0, rows[idx].indent + delta);
    normalizeIndents();
    markDirty();
    render();
  }
  function renderRow(row, idx) {
    const el = document.createElement("div");
    el.className = "fact-row";
    if (row.negated)
      el.classList.add("negated");
    el.style.marginLeft = `${row.indent * 28}px`;
    if (row.indent > 0)
      el.classList.add("indented");
    const maxIndent = idx > 0 ? rows[idx - 1].indent + 1 : 0;
    const indentTools = document.createElement("div");
    indentTools.className = "indent-tools";
    const outdent = document.createElement("button");
    outdent.className = "indent-btn";
    outdent.textContent = t("\u21E4");
    outdent.title = t("Unindent (widen this condition\u2019s scope)");
    outdent.disabled = row.indent === 0;
    outdent.addEventListener("click", () => indentRow(idx, -1));
    const indent = document.createElement("button");
    indent.className = "indent-btn";
    indent.textContent = t("\u21E5");
    indent.title = t("Indent (nest this condition to bind tighter)");
    indent.disabled = row.indent >= maxIndent;
    indent.addEventListener("click", () => indentRow(idx, 1));
    indentTools.appendChild(outdent);
    indentTools.appendChild(indent);
    el.appendChild(indentTools);
    if (idx > 0) {
      const conn = document.createElement("select");
      conn.className = "connective";
      for (const c of ["and", "or"]) {
        const o = document.createElement("option");
        o.value = c;
        o.textContent = c;
        conn.appendChild(o);
      }
      conn.value = row.connective;
      conn.addEventListener("change", () => {
        row.connective = conn.value;
        markDirty();
      });
      el.appendChild(conn);
    } else {
      const spacer = document.createElement("span");
      spacer.className = "connective-spacer";
      el.appendChild(spacer);
    }
    if (row.negated) {
      const neg = document.createElement("span");
      neg.className = "neg-phrase";
      neg.textContent = t("it is not the case that");
      el.appendChild(neg);
    }
    if (row.templateLabel === null) {
      const input = document.createElement("input");
      input.type = "text";
      input.className = "raw";
      input.value = row.raw;
      input.placeholder = t("condition");
      input.size = Math.min(Math.max(row.raw.length + 1, 20), 80);
      input.addEventListener("input", () => {
        row.raw = input.value;
        input.size = Math.min(Math.max(input.value.length + 1, 20), 80);
        markDirty();
      });
      el.appendChild(input);
    } else {
      const segs = splitTemplate(row.templateLabel);
      let fieldIdx = 0;
      for (const seg of segs) {
        if (seg.kind === "literal") {
          const span = document.createElement("span");
          span.className = "word";
          span.textContent = seg.text;
          el.appendChild(span);
        } else {
          const fi = fieldIdx++;
          const input = document.createElement("input");
          input.type = "text";
          input.className = "field";
          input.placeholder = seg.text;
          input.title = `${seg.text} \u2014 a value, or a query variable like "which ${seg.text.replace(/^(a|an|the)\s+/i, "")}"`;
          input.value = row.values[fi] ?? "";
          sizeField(input);
          input.addEventListener("input", () => {
            row.values[fi] = input.value;
            sizeField(input);
            markDirty();
          });
          el.appendChild(input);
        }
      }
    }
    const tools = document.createElement("div");
    tools.className = "row-tools";
    const negLabel = document.createElement("label");
    negLabel.className = "negate";
    negLabel.title = t('Wrap this condition in "it is not the case that \u2026"');
    const check = document.createElement("input");
    check.type = "checkbox";
    check.checked = row.negated;
    check.addEventListener("change", () => {
      row.negated = check.checked;
      markDirty();
      render();
    });
    negLabel.appendChild(check);
    negLabel.appendChild(document.createTextNode(" not"));
    tools.appendChild(negLabel);
    const del = document.createElement("button");
    del.textContent = t("\u2715");
    del.title = t("Delete condition");
    del.addEventListener("click", () => {
      rows.splice(idx, 1);
      markDirty();
      render();
    });
    tools.appendChild(del);
    el.appendChild(tools);
    return el;
  }
  function condBase(row) {
    if (row.templateLabel === null)
      return row.raw.trim().replace(/\.\s*$/, "").trim();
    const segs = splitTemplate(row.templateLabel);
    let fi = 0;
    const out = segs.map((s) => {
      if (s.kind === "literal")
        return s.text;
      const v = (row.values[fi++] ?? "").trim();
      return v || s.text;
    }).join(" ");
    return out.replace(/\s+/g, " ").trim();
  }
  function condText(row) {
    const base = condBase(row);
    if (!base)
      return "";
    return row.negated ? `it is not the case that ${base}` : base;
  }
  function bodyLines() {
    const out = [];
    rows.forEach((row) => {
      const c = condText(row);
      if (!c)
        return;
      const conn = out.length === 0 ? "" : `${row.connective} `;
      out.push(`${" ".repeat(4 + row.indent * 4)}${conn}${c}`);
    });
    return out;
  }
  function blockText(name) {
    const lines = bodyLines();
    const body = lines.length ? lines.join("\n") : "    ";
    return `query ${name} is:
${body}.`;
  }
  function requireName() {
    const name = nameInput.value.trim();
    if (!name) {
      alert(t("Please give the query a name."));
      nameInput.focus();
      return null;
    }
    if (/\s/.test(name)) {
      alert(t("A query name must be a single word or number (no spaces)."));
      nameInput.focus();
      return null;
    }
    if (bodyLines().length === 0) {
      alert(t("Add at least one condition to the query."));
      return null;
    }
    return name;
  }
  $("btn-copy").addEventListener("click", async () => {
    const name = requireName();
    if (!name)
      return;
    const text = blockText(name);
    try {
      await navigator.clipboard.writeText(text);
      dirty = false;
      setStatus(t("Copied to clipboard"));
    } catch {
      window.prompt(t("Copy the query text:"), text);
      dirty = false;
      setStatus(t("Copied"));
    }
  });
  $("btn-insert").addEventListener("click", () => {
    const name = requireName();
    if (!name)
      return;
    channel.postMessage({ type: "insert-query", name, blockText: blockText(name), replaceName: loadedName });
    dirty = false;
    setStatus(t("Inserted into editor"));
    setTimeout(() => window.close(), 100);
  });
  picker.addEventListener("change", () => {
    if (dirty && !confirm(t("Discard unsaved changes and load the selected query?"))) {
      picker.value = loadedName || "__new__";
      return;
    }
    if (picker.value === "__new__")
      newQuery();
    else
      loadQuery(picker.value);
  });
  nameInput.addEventListener("input", markDirty);
  window.addEventListener("beforeunload", (e) => {
    if (dirty) {
      e.preventDefault();
      e.returnValue = "";
      return "";
    }
  });
  picker.value = "__new__";
  newQuery();
}
installLeApiLang();
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => applyI18nDom());
} else {
  applyI18nDom();
}
export {
  initQueryEditor
};
