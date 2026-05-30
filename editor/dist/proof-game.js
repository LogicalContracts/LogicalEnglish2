// src/proof-game.ts
var slots = /* @__PURE__ */ new Map();
var pieces = /* @__PURE__ */ new Map();
var uid = 0;
function nextId(prefix) {
  uid += 1;
  return `${prefix}-${uid}`;
}
function isAdultMode() {
  const modeToggle = document.getElementById("mode-toggle");
  return modeToggle ? modeToggle.checked : true;
}
function normalize(text) {
  return (text || "").toLowerCase().replace(/\.$/, "").replace(/\s+/g, " ").trim();
}
function highlightSource(loc) {
  if (loc && window.opener) {
    window.opener.postMessage({ type: "le-highlight", loc }, "*");
  }
}
function slotEl(id) {
  return document.querySelector(`.pg-slot[data-slot-id="${id}"]`);
}
function pieceEl(id) {
  return document.querySelector(`.pg-piece[data-piece-id="${id}"]`);
}
function trayEl() {
  return document.getElementById("pg-tray-pieces");
}
async function initProofGame(container, gameData) {
  slots.clear();
  pieces.clear();
  uid = 0;
  container.innerHTML = "";
  container.classList.add("pg-root");
  const board = document.createElement("div");
  board.className = "pg-board";
  container.appendChild(board);
  if (gameData.query) {
    const querySection = document.createElement("div");
    querySection.className = "pg-section pg-query-section";
    const title = document.createElement("div");
    title.className = "pg-section-title";
    title.textContent = "Goal";
    querySection.appendChild(title);
    const queryCard = document.createElement("div");
    queryCard.className = "pg-card pg-query-card";
    const queryLabel = document.createElement("div");
    queryLabel.className = "pg-query-label";
    queryLabel.textContent = displayText(gameData.query);
    queryLabel.title = gameData.query;
    queryCard.appendChild(queryLabel);
    queryCard.appendChild(createSlotElement(gameData.query, ""));
    querySection.appendChild(queryCard);
    board.appendChild(querySection);
  }
  const tray = document.createElement("div");
  tray.className = "pg-tray";
  const trayTitle = document.createElement("div");
  trayTitle.className = "pg-section-title";
  trayTitle.textContent = "Pieces \u2014 drag a fact or a rule into a slot";
  tray.appendChild(trayTitle);
  const trayPieces = document.createElement("div");
  trayPieces.className = "pg-tray-pieces";
  trayPieces.id = "pg-tray-pieces";
  tray.appendChild(trayPieces);
  container.appendChild(tray);
  setupTrayDropTarget(trayPieces);
  if (gameData.facts) {
    for (const fact of gameData.facts) {
      const piece = {
        id: nextId("piece"),
        kind: "fact",
        head: fact.fact,
        body: [],
        childSlotIds: [],
        sourceLoc: fact.start !== void 0 && fact.end !== void 0 ? { start: fact.start, end: fact.end } : void 0
      };
      pieces.set(piece.id, piece);
      trayPieces.appendChild(createPieceElement(piece));
    }
  }
  if (gameData.rules) {
    for (const rule of gameData.rules) {
      const piece = {
        id: nextId("piece"),
        kind: "rule",
        head: rule.head,
        body: rule.body || [],
        childSlotIds: [],
        sourceLoc: rule.start !== void 0 && rule.end !== void 0 ? { start: rule.start, end: rule.end } : void 0
      };
      pieces.set(piece.id, piece);
      trayPieces.appendChild(createPieceElement(piece));
    }
  }
  wireControls(gameData);
  updateAllText();
}
function displayText(text) {
  return isAdultMode() ? text : "";
}
function createSlotElement(expected, ownerPieceId) {
  const el = document.createElement("div");
  el.className = "pg-slot";
  const id = nextId("slot");
  el.dataset.slotId = id;
  slots.set(id, { id, expected, placedPieceId: null, ownerPieceId });
  el.addEventListener("dragover", (e) => {
    e.preventDefault();
    e.stopPropagation();
    el.classList.add("pg-slot-over");
    if (e.dataTransfer)
      e.dataTransfer.dropEffect = "move";
  });
  el.addEventListener("dragleave", (e) => {
    e.stopPropagation();
    el.classList.remove("pg-slot-over");
  });
  el.addEventListener("drop", (e) => {
    e.preventDefault();
    e.stopPropagation();
    el.classList.remove("pg-slot-over");
    const draggedId = e.dataTransfer?.getData("text/plain");
    if (draggedId)
      placePieceInSlot(draggedId, id);
  });
  return el;
}
function createPieceElement(piece) {
  const el = document.createElement("div");
  el.dataset.pieceId = piece.id;
  el.draggable = true;
  el.addEventListener("dragstart", (e) => {
    e.stopPropagation();
    el.classList.add("pg-dragging");
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", piece.id);
    }
  });
  el.addEventListener("dragend", (e) => {
    e.stopPropagation();
    el.classList.remove("pg-dragging");
  });
  if (piece.kind === "fact") {
    el.className = "pg-piece pg-piece-fact";
    el.textContent = displayText(piece.head);
    el.title = piece.head;
    el.addEventListener("click", (e) => {
      e.stopPropagation();
      highlightSource(piece.sourceLoc);
    });
    return el;
  }
  el.className = "pg-piece pg-piece-rule";
  const head = document.createElement("div");
  head.className = "pg-rule-head";
  head.textContent = displayText(piece.head);
  head.title = piece.head;
  head.addEventListener("click", (e) => {
    e.stopPropagation();
    highlightSource(piece.sourceLoc);
  });
  el.appendChild(head);
  if (piece.body.length) {
    const ifLabel = document.createElement("div");
    ifLabel.className = "pg-if-label";
    ifLabel.textContent = "if";
    el.appendChild(ifLabel);
    const bodyRow = document.createElement("div");
    bodyRow.className = "pg-body-row";
    piece.body.forEach((cond) => {
      const condWrap = document.createElement("div");
      condWrap.className = "pg-cond";
      const condLabel = document.createElement("div");
      condLabel.className = "pg-cond-label";
      condLabel.textContent = displayText(cond);
      condLabel.title = cond;
      condWrap.appendChild(condLabel);
      const slot = createSlotElement(cond, piece.id);
      piece.childSlotIds.push(slot.dataset.slotId);
      condWrap.appendChild(slot);
      bodyRow.appendChild(condWrap);
    });
    el.appendChild(bodyRow);
  }
  return el;
}
function slotIsInsidePiece(slotId, pieceId) {
  const piece = pieces.get(pieceId);
  if (!piece)
    return false;
  for (const childSlotId of piece.childSlotIds) {
    if (childSlotId === slotId)
      return true;
    const child = slots.get(childSlotId);
    if (child && child.placedPieceId) {
      if (slotIsInsidePiece(slotId, child.placedPieceId))
        return true;
    }
  }
  return false;
}
function placePieceInSlot(pieceId, slotId) {
  const slot = slots.get(slotId);
  const piece = pieces.get(pieceId);
  if (!slot || !piece)
    return;
  const domPiece = pieceEl(pieceId);
  const domSlot = slotEl(slotId);
  if (!domPiece || !domSlot)
    return;
  if (slotIsInsidePiece(slotId, pieceId) || slot.ownerPieceId === pieceId) {
    return;
  }
  slots.forEach((s) => {
    if (s.placedPieceId === pieceId) {
      s.placedPieceId = null;
      clearSlotStatus(s.id);
    }
  });
  if (slot.placedPieceId) {
    const prev = pieceEl(slot.placedPieceId);
    if (prev)
      returnPieceToTray(prev, slot.placedPieceId);
    slot.placedPieceId = null;
  }
  domSlot.appendChild(domPiece);
  slot.placedPieceId = pieceId;
  domSlot.classList.add("pg-slot-filled");
  clearSlotStatus(slotId);
}
function returnPieceToTray(domPiece, pieceId) {
  const tray = trayEl();
  if (tray)
    tray.appendChild(domPiece);
  slots.forEach((s) => {
    if (s.placedPieceId === pieceId) {
      s.placedPieceId = null;
      clearSlotStatus(s.id);
    }
  });
}
function clearSlotStatus(slotId) {
  const el = slotEl(slotId);
  if (!el)
    return;
  el.classList.remove("pg-slot-correct", "pg-slot-wrong");
  if (!slots.get(slotId)?.placedPieceId)
    el.classList.remove("pg-slot-filled");
}
function setupTrayDropTarget(tray) {
  tray.addEventListener("dragover", (e) => {
    e.preventDefault();
    if (e.dataTransfer)
      e.dataTransfer.dropEffect = "move";
  });
  tray.addEventListener("drop", (e) => {
    e.preventDefault();
    const pieceId = e.dataTransfer?.getData("text/plain");
    if (!pieceId)
      return;
    const domPiece = pieceEl(pieceId);
    if (domPiece)
      returnPieceToTray(domPiece, pieceId);
  });
}
function updateAllText() {
  const adult = isAdultMode();
  document.querySelectorAll(".pg-piece-fact").forEach((el) => {
    el.textContent = adult ? el.title : "";
  });
  document.querySelectorAll(".pg-query-label, .pg-rule-head, .pg-cond-label").forEach((el) => {
    el.textContent = adult ? el.title : "";
  });
}
function slotIsCorrect(slot) {
  if (!slot.placedPieceId)
    return false;
  const piece = pieces.get(slot.placedPieceId);
  if (!piece)
    return false;
  if (normalize(piece.head) !== normalize(slot.expected))
    return false;
  for (const childSlotId of piece.childSlotIds) {
    const child = slots.get(childSlotId);
    if (!child || !slotIsCorrect(child))
      return false;
  }
  return true;
}
function checkProof(gameData) {
  let total = 0;
  let correct = 0;
  slots.forEach((slot) => {
    const el = slotEl(slot.id);
    if (!el)
      return;
    total += 1;
    el.classList.remove("pg-slot-correct", "pg-slot-wrong");
    if (!slot.placedPieceId)
      return;
    if (slotIsCorrect(slot)) {
      el.classList.add("pg-slot-correct");
      correct += 1;
    } else {
      el.classList.add("pg-slot-wrong");
    }
  });
  const goalSlot = Array.from(slots.values()).find((s) => s.ownerPieceId === "");
  const proven = goalSlot ? slotIsCorrect(goalSlot) : false;
  const statusEl = document.getElementById("pg-status");
  if (statusEl) {
    if (!goalSlot) {
      statusEl.textContent = "Nothing to prove.";
      statusEl.className = "pg-status";
    } else if (proven) {
      statusEl.textContent = "\u2713 Proof complete! The goal is fully justified.";
      statusEl.className = "pg-status pg-status-success";
    } else {
      statusEl.textContent = `Not proven yet \u2014 ${correct}/${total} placed slots correct. Keep building.`;
      statusEl.className = "pg-status pg-status-progress";
    }
  }
}
function resetBoard() {
  const tray = trayEl();
  Array.from(pieces.values()).forEach((p) => {
    const dom = pieceEl(p.id);
    if (dom && tray && dom.parentElement !== tray)
      tray.appendChild(dom);
  });
  slots.forEach((slot) => {
    slot.placedPieceId = null;
    const el = slotEl(slot.id);
    if (el) {
      el.classList.remove(
        "pg-slot-filled",
        "pg-slot-correct",
        "pg-slot-wrong",
        "pg-slot-over"
      );
    }
  });
  const statusEl = document.getElementById("pg-status");
  if (statusEl) {
    statusEl.textContent = "";
    statusEl.className = "pg-status";
  }
}
function wireControls(gameData) {
  const checkBtn = document.getElementById("btn-check");
  if (checkBtn) {
    const fresh = checkBtn.cloneNode(true);
    checkBtn.parentNode?.replaceChild(fresh, checkBtn);
    fresh.addEventListener("click", () => checkProof(gameData));
  }
  const resetBtn = document.getElementById("btn-reset");
  if (resetBtn) {
    const fresh = resetBtn.cloneNode(true);
    resetBtn.parentNode?.replaceChild(fresh, resetBtn);
    fresh.addEventListener("click", resetBoard);
  }
  const modeToggle = document.getElementById("mode-toggle");
  if (modeToggle) {
    modeToggle.addEventListener("change", updateAllText);
  }
}
export {
  initProofGame
};
