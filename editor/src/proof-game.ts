// LE Proof Game - "drag piece into slot" mechanic.
//
// The player assembles the proof by dragging concrete pieces into empty slots:
//   - The Goal (query) has one slot.
//   - Each Rule is itself a draggable piece: a card showing its head plus one
//     empty slot per body condition.
//
// Because rule pieces carry their own body slots, dropping a rule into a slot
// nests it, and the rule's body slots can in turn be filled by facts or by
// other rules. This lets the player build a full proof TREE:
//   fact  -> rule body slot
//   rule  -> rule body slot (its head matches the condition)
//   rule  -> goal slot      (its head matches the query)
//
// The whole proof is validated only when "Check Proof" is pressed: a slot is
// correct when the piece in it has a matching head AND (for rule pieces) all of
// that rule's own body slots are themselves correctly filled.

interface GameRule {
    head: string;
    body: string[];
    start?: number;
    end?: number;
}

interface GameFact {
    fact: string;
    start?: number;
    end?: number;
}

interface GameData {
    query: string;
    rules: GameRule[];
    facts: GameFact[];
}

type PieceKind = 'fact' | 'rule';

interface Piece {
    id: string;
    kind: PieceKind;
    // The text that this piece "proves" (a fact's text, or a rule's head).
    head: string;
    // Body conditions (rules only); each gets its own nested slot.
    body: string[];
    // Slot ids belonging to this piece (rules only).
    childSlotIds: string[];
    sourceLoc?: { start: number; end: number };
}

interface Slot {
    id: string;
    expected: string;
    // The piece id currently placed in the slot (null if empty).
    placedPieceId: string | null;
    // The piece that owns this slot, if it is a rule body slot ('' for the goal).
    ownerPieceId: string;
    sourceLoc?: { start: number; end: number };
}

const slots = new Map<string, Slot>();
const pieces = new Map<string, Piece>();
let uid = 0;

function nextId(prefix: string): string {
    uid += 1;
    return `${prefix}-${uid}`;
}

function isAdultMode(): boolean {
    const modeToggle = document.getElementById('mode-toggle') as HTMLInputElement | null;
    return modeToggle ? modeToggle.checked : true;
}

// Normalise text for matching: lowercase, collapse whitespace, drop a trailing
// period so cosmetic differences don't break a correct placement.
function normalize(text: string): string {
    return (text || '')
        .toLowerCase()
        .replace(/\.$/, '')
        .replace(/\s+/g, ' ')
        .trim();
}

function highlightSource(loc?: { start: number; end: number }) {
    if (loc && window.opener) {
        window.opener.postMessage({ type: 'le-highlight', loc }, '*');
    }
}

function slotEl(id: string): HTMLElement | null {
    return document.querySelector(`.pg-slot[data-slot-id="${id}"]`);
}
function pieceEl(id: string): HTMLElement | null {
    return document.querySelector(`.pg-piece[data-piece-id="${id}"]`);
}
function trayEl(): HTMLElement | null {
    return document.getElementById('pg-tray-pieces');
}

export async function initProofGame(container: HTMLElement, gameData: GameData) {
    slots.clear();
    pieces.clear();
    uid = 0;

    container.innerHTML = '';
    container.classList.add('pg-root');

    // --- Board (the goal) -------------------------------------------------
    const board = document.createElement('div');
    board.className = 'pg-board';
    container.appendChild(board);

    if (gameData.query) {
        const querySection = document.createElement('div');
        querySection.className = 'pg-section pg-query-section';

        const title = document.createElement('div');
        title.className = 'pg-section-title';
        title.textContent = 'Goal';
        querySection.appendChild(title);

        const queryCard = document.createElement('div');
        queryCard.className = 'pg-card pg-query-card';

        const queryLabel = document.createElement('div');
        queryLabel.className = 'pg-query-label';
        queryLabel.textContent = displayText(gameData.query);
        queryLabel.title = gameData.query;
        queryCard.appendChild(queryLabel);

        // The goal slot (ownerPieceId '' marks a top-level/board slot).
        queryCard.appendChild(createSlotElement(gameData.query, ''));
        querySection.appendChild(queryCard);
        board.appendChild(querySection);
    }

    // --- Tray (draggable pieces: facts + rules) ---------------------------
    const tray = document.createElement('div');
    tray.className = 'pg-tray';

    const trayTitle = document.createElement('div');
    trayTitle.className = 'pg-section-title';
    trayTitle.textContent = 'Pieces — drag a fact or a rule into a slot';
    tray.appendChild(trayTitle);

    const trayPieces = document.createElement('div');
    trayPieces.className = 'pg-tray-pieces';
    trayPieces.id = 'pg-tray-pieces';
    tray.appendChild(trayPieces);
    container.appendChild(tray);

    setupTrayDropTarget(trayPieces);

    // Facts become simple pieces.
    if (gameData.facts) {
        for (const fact of gameData.facts) {
            const piece: Piece = {
                id: nextId('piece'),
                kind: 'fact',
                head: fact.fact,
                body: [],
                childSlotIds: [],
                sourceLoc:
                    fact.start !== undefined && fact.end !== undefined
                        ? { start: fact.start, end: fact.end }
                        : undefined
            };
            pieces.set(piece.id, piece);
            trayPieces.appendChild(createPieceElement(piece));
        }
    }

    // Rules become self-contained draggable cards (head + nested body slots).
    if (gameData.rules) {
        for (const rule of gameData.rules) {
            const piece: Piece = {
                id: nextId('piece'),
                kind: 'rule',
                head: rule.head,
                body: rule.body || [],
                childSlotIds: [],
                sourceLoc:
                    rule.start !== undefined && rule.end !== undefined
                        ? { start: rule.start, end: rule.end }
                        : undefined
            };
            pieces.set(piece.id, piece);
            trayPieces.appendChild(createPieceElement(piece));
        }
    }

    wireControls(gameData);
    updateAllText();
}

function displayText(text: string): string {
    return isAdultMode() ? text : '';
}

// Create a slot (drop target). `ownerPieceId` is '' for the goal slot, else the
// id of the rule piece this body slot belongs to.
function createSlotElement(expected: string, ownerPieceId: string): HTMLElement {
    const el = document.createElement('div');
    el.className = 'pg-slot';
    const id = nextId('slot');
    el.dataset.slotId = id;

    slots.set(id, { id, expected, placedPieceId: null, ownerPieceId });

    el.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.stopPropagation();
        el.classList.add('pg-slot-over');
        if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
    });
    el.addEventListener('dragleave', (e) => {
        e.stopPropagation();
        el.classList.remove('pg-slot-over');
    });
    el.addEventListener('drop', (e) => {
        e.preventDefault();
        e.stopPropagation();
        el.classList.remove('pg-slot-over');
        const draggedId = e.dataTransfer?.getData('text/plain');
        if (draggedId) placePieceInSlot(draggedId, id);
    });

    return el;
}

// Build the DOM for a piece. Fact pieces are simple tokens; rule pieces are
// cards with a head (the drag handle) and one nested slot per body condition.
function createPieceElement(piece: Piece): HTMLElement {
    const el = document.createElement('div');
    el.dataset.pieceId = piece.id;
    el.draggable = true;

    el.addEventListener('dragstart', (e) => {
        // Ensure the innermost grabbed piece is the one that moves, not an
        // ancestor rule card.
        e.stopPropagation();
        el.classList.add('pg-dragging');
        if (e.dataTransfer) {
            e.dataTransfer.effectAllowed = 'move';
            e.dataTransfer.setData('text/plain', piece.id);
        }
    });
    el.addEventListener('dragend', (e) => {
        e.stopPropagation();
        el.classList.remove('pg-dragging');
    });

    if (piece.kind === 'fact') {
        el.className = 'pg-piece pg-piece-fact';
        el.textContent = displayText(piece.head);
        el.title = piece.head;
        el.addEventListener('click', (e) => {
            e.stopPropagation();
            highlightSource(piece.sourceLoc);
        });
        return el;
    }

    // Rule piece: a card.
    el.className = 'pg-piece pg-piece-rule';

    const head = document.createElement('div');
    head.className = 'pg-rule-head';
    head.textContent = displayText(piece.head);
    head.title = piece.head;
    head.addEventListener('click', (e) => {
        e.stopPropagation();
        highlightSource(piece.sourceLoc);
    });
    el.appendChild(head);

    if (piece.body.length) {
        const ifLabel = document.createElement('div');
        ifLabel.className = 'pg-if-label';
        ifLabel.textContent = 'if';
        el.appendChild(ifLabel);

        const bodyRow = document.createElement('div');
        bodyRow.className = 'pg-body-row';
        piece.body.forEach((cond) => {
            const condWrap = document.createElement('div');
            condWrap.className = 'pg-cond';

            const condLabel = document.createElement('div');
            condLabel.className = 'pg-cond-label';
            condLabel.textContent = displayText(cond);
            condLabel.title = cond;
            condWrap.appendChild(condLabel);

            const slot = createSlotElement(cond, piece.id);
            piece.childSlotIds.push(slot.dataset.slotId!);
            condWrap.appendChild(slot);

            bodyRow.appendChild(condWrap);
        });
        el.appendChild(bodyRow);
    }

    return el;
}

// Is `slotId` somewhere inside the subtree owned by `pieceId`? Used to prevent
// dropping a rule into one of its own (descendant) body slots.
function slotIsInsidePiece(slotId: string, pieceId: string): boolean {
    const piece = pieces.get(pieceId);
    if (!piece) return false;
    for (const childSlotId of piece.childSlotIds) {
        if (childSlotId === slotId) return true;
        const child = slots.get(childSlotId);
        if (child && child.placedPieceId) {
            if (slotIsInsidePiece(slotId, child.placedPieceId)) return true;
        }
    }
    return false;
}

// Move a piece into a slot. Handles re-parenting, bumping an existing occupant
// back to the tray, and guarding against nesting a rule inside itself.
function placePieceInSlot(pieceId: string, slotId: string) {
    const slot = slots.get(slotId);
    const piece = pieces.get(pieceId);
    if (!slot || !piece) return;

    const domPiece = pieceEl(pieceId);
    const domSlot = slotEl(slotId);
    if (!domPiece || !domSlot) return;

    // Guard: cannot drop a piece into one of its own descendant slots.
    if (slotIsInsidePiece(slotId, pieceId) || slot.ownerPieceId === pieceId) {
        return;
    }

    // Free whatever slot currently holds this piece.
    slots.forEach((s) => {
        if (s.placedPieceId === pieceId) {
            s.placedPieceId = null;
            clearSlotStatus(s.id);
        }
    });

    // If the target slot already had a piece, send the old one back to the tray.
    if (slot.placedPieceId) {
        const prev = pieceEl(slot.placedPieceId);
        if (prev) returnPieceToTray(prev, slot.placedPieceId);
        slot.placedPieceId = null;
    }

    domSlot.appendChild(domPiece);
    slot.placedPieceId = pieceId;
    domSlot.classList.add('pg-slot-filled');
    clearSlotStatus(slotId);
}

function returnPieceToTray(domPiece: HTMLElement, pieceId: string) {
    const tray = trayEl();
    if (tray) tray.appendChild(domPiece);
    // Free any slot that referenced this piece.
    slots.forEach((s) => {
        if (s.placedPieceId === pieceId) {
            s.placedPieceId = null;
            clearSlotStatus(s.id);
        }
    });
}

function clearSlotStatus(slotId: string) {
    const el = slotEl(slotId);
    if (!el) return;
    el.classList.remove('pg-slot-correct', 'pg-slot-wrong');
    if (!slots.get(slotId)?.placedPieceId) el.classList.remove('pg-slot-filled');
}

function setupTrayDropTarget(tray: HTMLElement) {
    tray.addEventListener('dragover', (e) => {
        e.preventDefault();
        if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
    });
    tray.addEventListener('drop', (e) => {
        e.preventDefault();
        const pieceId = e.dataTransfer?.getData('text/plain');
        if (!pieceId) return;
        const domPiece = pieceEl(pieceId);
        if (domPiece) returnPieceToTray(domPiece, pieceId);
    });
}

function updateAllText() {
    const adult = isAdultMode();
    document.querySelectorAll('.pg-piece-fact').forEach((el) => {
        (el as HTMLElement).textContent = adult ? (el as HTMLElement).title : '';
    });
    document
        .querySelectorAll('.pg-query-label, .pg-rule-head, .pg-cond-label')
        .forEach((el) => {
            (el as HTMLElement).textContent = adult ? (el as HTMLElement).title : '';
        });
}

// Recursively decide whether a slot is fully satisfied: a piece is present, its
// head matches the slot's expected condition, and (if it is a rule) all of its
// own body slots are satisfied too.
function slotIsCorrect(slot: Slot): boolean {
    if (!slot.placedPieceId) return false;
    const piece = pieces.get(slot.placedPieceId);
    if (!piece) return false;
    if (normalize(piece.head) !== normalize(slot.expected)) return false;
    for (const childSlotId of piece.childSlotIds) {
        const child = slots.get(childSlotId);
        if (!child || !slotIsCorrect(child)) return false;
    }
    return true;
}

function checkProof(gameData: GameData) {
    // Paint per-slot feedback for every slot currently on the board.
    let total = 0;
    let correct = 0;
    slots.forEach((slot) => {
        const el = slotEl(slot.id);
        if (!el) return; // slot belongs to a piece sitting unused in the tray
        total += 1;
        el.classList.remove('pg-slot-correct', 'pg-slot-wrong');
        if (!slot.placedPieceId) return;
        if (slotIsCorrect(slot)) {
            el.classList.add('pg-slot-correct');
            correct += 1;
        } else {
            el.classList.add('pg-slot-wrong');
        }
    });

    // The proof succeeds only if the goal slot is fully (recursively) correct.
    const goalSlot = Array.from(slots.values()).find((s) => s.ownerPieceId === '');
    const proven = goalSlot ? slotIsCorrect(goalSlot) : false;

    const statusEl = document.getElementById('pg-status');
    if (statusEl) {
        if (!goalSlot) {
            statusEl.textContent = 'Nothing to prove.';
            statusEl.className = 'pg-status';
        } else if (proven) {
            statusEl.textContent = '✓ Proof complete! The goal is fully justified.';
            statusEl.className = 'pg-status pg-status-success';
        } else {
            statusEl.textContent = `Not proven yet — ${correct}/${total} placed slots correct. Keep building.`;
            statusEl.className = 'pg-status pg-status-progress';
        }
    }
}

function resetBoard() {
    const tray = trayEl();
    // Move every placed piece back to the tray, in document order.
    Array.from(pieces.values()).forEach((p) => {
        const dom = pieceEl(p.id);
        if (dom && tray && dom.parentElement !== tray) tray.appendChild(dom);
    });
    slots.forEach((slot) => {
        slot.placedPieceId = null;
        const el = slotEl(slot.id);
        if (el) {
            el.classList.remove(
                'pg-slot-filled',
                'pg-slot-correct',
                'pg-slot-wrong',
                'pg-slot-over'
            );
        }
    });
    const statusEl = document.getElementById('pg-status');
    if (statusEl) {
        statusEl.textContent = '';
        statusEl.className = 'pg-status';
    }
}

function wireControls(gameData: GameData) {
    const checkBtn = document.getElementById('btn-check');
    if (checkBtn) {
        const fresh = checkBtn.cloneNode(true) as HTMLElement;
        checkBtn.parentNode?.replaceChild(fresh, checkBtn);
        fresh.addEventListener('click', () => checkProof(gameData));
    }

    const resetBtn = document.getElementById('btn-reset');
    if (resetBtn) {
        const fresh = resetBtn.cloneNode(true) as HTMLElement;
        resetBtn.parentNode?.replaceChild(fresh, resetBtn);
        fresh.addEventListener('click', resetBoard);
    }

    const modeToggle = document.getElementById('mode-toggle');
    if (modeToggle) {
        modeToggle.addEventListener('change', updateAllText);
    }
}
