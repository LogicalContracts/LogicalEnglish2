// Explanation Drill window. A non-modal helper that walks the user through the
// explanation as a "suspects tree": it repeatedly asks about the strongest reason
// within the current region ("Understood?"); answering "Yes" removes that subtree,
// "Not yet" descends into it. The state machine (TOP / UNDERSTOOD) lives on the Prolog
// side; this window keeps the ordered answers and the initial node count, renders the
// questions with retained Yes / Not-yet state, a progress bar, and highlights each
// question's source in the editor that opened it.

interface DrillData {
    source?: string;        // the program, so the window loads its own session
    sessionModule?: string; // legacy fallback
    kbName?: string;
    why?: any;
}

interface Question { path: string; text: string; start: number; end: number; answer?: string; }
interface DrillResponse {
    ok?: boolean; error?: string; session_expired?: boolean;
    initialCount?: number; progress?: number;
    questions?: Question[]; pending?: Question | null; topPath?: string;
}

const TOKEN = 'myToken123';

const leapi = (body: any) => fetch('/leapi', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ token: TOKEN, ...body }),
}).then(r => r.json()).catch(() => null);

export async function initExplanationDrill() {
    const $ = (id: string) => document.getElementById(id)!;
    const ls: DrillData = JSON.parse(localStorage.getItem('le_explanation_drill_data') || '{}');
    const source = ls.source || '';
    const why = ls.why;

    ($('title') as HTMLElement).textContent = `Explanation Drill${ls.kbName ? ` — ${ls.kbName}` : ''}`;

    // "Understanding why <explanation tree root>:" — the goal being explained.
    const root = Array.isArray(why) ? why[0] : why;
    const rootLiteral = (root && root.literal) ? String(root.literal) : 'this answer';
    $('drill-title').textContent = `Understanding why ${rootLiteral}:`;

    let answers: string[] = [];   // "yes" | "not_yet", in order
    let initialCount = 0;         // total node weight (kept on the window)
    let sentWhy = false;          // the tree is uploaded once; kept in the session after

    // This window runs its OWN reasoning session (loaded from the program source), so
    // the editor's session expiring/reloading never breaks the drill.
    let sessionModule: string | null = null;
    let sessionLoad: Promise<void> | null = null;
    function startSessionLoad(): Promise<void> {
        if (!sessionLoad) {
            sessionLoad = (source ? leapi({ operation: 'load', le: source }) : Promise.resolve(null))
                .then((r: any) => { if (r && r.sessionModule) sessionModule = r.sessionModule; })
                .catch(() => { /* reported on the next drill call */ });
        }
        return sessionLoad;
    }
    async function ensureSession(): Promise<boolean> {
        if (sessionModule) return true;
        await startSessionLoad();
        if (!sessionModule && ls.sessionModule) sessionModule = ls.sessionModule;   // legacy fallback
        return !!sessionModule;
    }

    const setStatus = (t: string) => { $('status').textContent = t; };

    async function drill(): Promise<DrillResponse> {
        if (!(await ensureSession())) return { error: 'Could not load the program on the server.' };
        const req = () => {
            const b: any = { operation: 'explanationDrill', sessionModule, answers };
            if (!sentWhy) b.why = why;   // upload the tree once; it is kept in our session
            return b;
        };
        let res: DrillResponse = await leapi(req()) || { error: 'network' };
        if (res && res.session_expired) {          // our session was reclaimed — reload and resend the tree
            sessionModule = null; sessionLoad = null; sentWhy = false;
            if (await ensureSession()) res = await leapi(req()) || { error: 'network' };
        }
        if (res && res.ok) sentWhy = true;
        return res;
    }

    // Highlight a node's source in the opener's editor WITHOUT stealing focus.
    function highlight(q: Question | null | undefined) {
        if (!q || q.start < 0) return;
        window.opener?.postMessage({ type: 'le-highlight', loc: { start: q.start, end: q.end }, noFocus: true }, '*');
    }

    // Clicking answer `val` on the question at index `i`. On the pending question this
    // appends; on an answered one it changes it (dropping any later answers, since they
    // were about nodes chosen under the old answer), and clicking the already-selected
    // answer clears it back to "no answer".
    function answer(i: number, val: string) {
        if (i < answers.length && answers[i] === val) answers = answers.slice(0, i);
        else answers = answers.slice(0, i).concat([val]);
        refresh();
    }

    // Delete an answered question (its ✕): drop just that answer and KEEP the rest, then
    // let the drill re-derive the remaining questions and the next one.
    function deleteQuestion(i: number) {
        if (i < 0 || i >= answers.length) return;
        answers = answers.slice(0, i).concat(answers.slice(i + 1));
        refresh();
    }

    function questionCard(q: Question, i: number, isPending: boolean, isTopFinal: boolean): HTMLElement {
        const card = document.createElement('div');
        card.className = 'q-card' + (isTopFinal ? ' top-final' : '');

        // Answered questions carry a ✕ to delete them (keeping the other answers).
        if (!isPending) {
            const del = document.createElement('button');
            del.className = 'q-del';
            del.textContent = '✕';
            del.title = 'Delete this question';
            del.addEventListener('click', () => deleteQuestion(i));
            card.appendChild(del);
        }

        const node = document.createElement('div');
        node.className = 'q-node';
        node.textContent = q.text;
        card.appendChild(node);

        const row = document.createElement('div');
        row.className = 'q-row';
        const label = document.createElement('span');
        label.className = 'q-label';
        label.textContent = 'Accept?';
        row.appendChild(label);

        const mkBtn = (val: 'yes' | 'not_yet', text: string) => {
            const b = document.createElement('button');
            b.className = `q-btn ${val === 'yes' ? 'yes' : 'notyet'}` + (q.answer === val ? ' on' : '');
            b.textContent = text;
            b.addEventListener('click', () => answer(i, val));
            return b;
        };
        row.appendChild(mkBtn('yes', 'Yes'));
        row.appendChild(mkBtn('not_yet', 'Not yet'));
        card.appendChild(row);
        return card;
    }

    function render(res: DrillResponse) {
        const container = $('questions');
        container.innerHTML = '';
        const questions = res.questions || [];
        const pending = res.pending || null;

        questions.forEach((q, i) => {
            const isTopFinal = !pending && q.path === res.topPath;
            container.appendChild(questionCard(q, i, false, isTopFinal));
        });
        if (pending) {
            container.appendChild(questionCard(pending, questions.length, true, false));
        }

        // Progress bar — a plain visual fill, no counts or percentage (just a label).
        if (typeof res.initialCount === 'number' && res.initialCount > 0) initialCount = res.initialCount;
        const progress = res.progress || 0;
        const pct = initialCount > 0 ? Math.round((progress / initialCount) * 100) : 0;
        ($('progress-fill') as HTMLElement).style.width = `${pct}%`;
        $('progress-label').textContent = 'Progress';

        // Final message when the drill is complete.
        const final = $('final');
        if (!pending) {
            final.style.display = '';
            final.textContent = 'Nothing else to show. Feel free to alter your choices above.';
            // Keep the source of the deepest (TOP) question in view.
            highlight(questions.find(q => q.path === res.topPath) || questions[questions.length - 1]);
            setStatus('Done');
        } else {
            final.style.display = 'none';
            highlight(pending);   // reveal the current question's source
            setStatus('Answer the highlighted question, or revise an earlier one.');
        }
    }

    async function refresh() {
        const res = await drill();
        if (res && res.session_expired) { setStatus('The session has expired — reopen the Explanation Drill.'); return; }
        if (!res || !res.ok) { setStatus('Error: ' + ((res && res.error) || 'no response')); return; }
        render(res);
    }

    if (!why) { setStatus('No explanation to drill.'); return; }
    startSessionLoad();   // establish our own session in the background
    refresh();
}
