/* LE Contract Assistant UI. Talks to the /leapi operations
   contract_start / contract_status / contract_result / contract_interrupt
   (see le_contract_assistant.pl). No build step. */

const TOKEN = 'myToken123';
const TEXT_EXTS = ['md', 'txt', 'le', 'text', 'markdown'];
const PROVIDERS = ['openai', 'anthropic', 'groq', 'together', 'gemini'];

const $ = (id) => document.getElementById(id);
let pollTimer = null;
let logSince = 0;
let result = null;

// ------------------------------- helpers ------------------------------------

async function leapi(operation, payload) {
    const response = await fetch('/leapi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(Object.assign({ token: TOKEN, operation }, payload))
    });
    if (!response.ok) throw new Error(`Server error ${response.status}`);
    return response.json();
}

function show(screen) {
    for (const s of ['setup', 'run', 'result'])
        $('screen-' + s).classList.toggle('hidden', s !== screen);
}

function ext(name) {
    const m = /\.([A-Za-z0-9]+)$/.exec(name || '');
    return m ? m[1].toLowerCase() : '';
}

function fileToUpload(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        if (TEXT_EXTS.includes(ext(file.name))) {
            reader.onload = () => resolve({ name: file.name, text: reader.result });
            reader.onerror = reject;
            reader.readAsText(file);
        } else {
            reader.onload = () => {
                const b64 = btoa(String.fromCharCode(...new Uint8Array(reader.result)));
                resolve({ name: file.name, data: b64 });
            };
            reader.onerror = reject;
            reader.readAsArrayBuffer(file);
        }
    });
}

// ------------------------------- setup screen -------------------------------

function wireUploads() {
    const nameFor = (input, span, none) => {
        const files = Array.from(input.files || []);
        span.textContent = files.length ? files.map(f => f.name).join(', ') : none;
        $('btn-start').disabled = !$('file-wording').files.length;
    };
    $('file-wording').addEventListener('change', () => nameFor($('file-wording'), $('name-wording'), 'no file selected'));
    $('file-schedule').addEventListener('change', () => nameFor($('file-schedule'), $('name-schedule'), 'no file selected'));
    $('file-cases').addEventListener('change', () => nameFor($('file-cases'), $('name-cases'), 'no files selected'));
}

async function loadModels() {
    try {
        const data = await leapi('list_models', {});
        const models = data.models || [];
        const serverKeys = data.server_keys || [];
        for (const sel of [$('model'), $('judge-model')]) {
            sel.innerHTML = '';
            for (const m of models) {
                const opt = document.createElement('option');
                opt.value = m.short;
                opt.textContent = `${m.short} (${m.provider})`;
                sel.appendChild(opt);
            }
        }
        // Key inputs for providers without a server-side key, prefilled from
        // localStorage (same names the editor uses: le-<provider>-key).
        const keysDiv = $('keys');
        keysDiv.innerHTML = '';
        for (const p of PROVIDERS) {
            if (serverKeys.includes(p)) continue;
            const label = document.createElement('label');
            label.className = 'field';
            label.innerHTML = `<span>${p} API key</span>`;
            const input = document.createElement('input');
            input.type = 'password';
            input.id = `key-${p}`;
            input.title = `${p} API key — kept only in this browser's localStorage (shared with the LE editor) and sent only with your requests. Not needed for providers the server already has a key for.`;
            input.value = localStorage.getItem(`le-${p}-key`) || '';
            const warn = document.createElement('span');
            warn.className = 'error';
            warn.style.fontSize = '12px';
            const check = () => {
                const looks = keyLooksLike(input.value);
                warn.textContent = (looks && looks !== p)
                    ? `\u26a0 this looks like a ${looks} key (${input.value.slice(0, 7)}\u2026), not an ${p} key`
                    : '';
            };
            input.addEventListener('change', () => { localStorage.setItem(`le-${p}-key`, input.value); check(); });
            input.addEventListener('input', check);
            check();   // stale localStorage values get flagged on load
            label.appendChild(input);
            label.appendChild(warn);
            keysDiv.appendChild(label);
        }
        const preferred = localStorage.getItem('le-assistant-model');
        if (preferred) { $('model').value = preferred; $('judge-model').value = preferred; }
    } catch (e) {
        $('setup-error').textContent = 'Could not load the model list: ' + e.message;
    }
}

function collectBudget() {
    const preset = document.querySelector('input[name=preset]:checked').value;
    const budget = { preset };
    for (const [id, key] of [['adv-k', 'k'], ['adv-w', 'w'], ['adv-repairs', 'repairs'], ['adv-minutes', 'minutes']]) {
        const v = $(id).value;
        if (v !== '') budget[key] = Number(v);
    }
    return budget;
}

function collectFeatures() {
    const features = {};
    if ($('feat-probes').value !== '') features.probes = Number($('feat-probes').value);
    if ($('feat-holdout').value !== '') features.holdout = $('feat-holdout').value === 'true';
    features.interrogation_repair = $('feat-interrogation-repair').checked;
    // Checkboxes whose unchecked state is the preset default are only sent when
    // they deviate from it, so presets keep working.
    if ($('feat-paraphrase').checked) features.paraphrase = true;
    if ($('feat-clausewise').checked) features.clausewise = true;
    if (!$('feat-diff').checked) features.diff_repairs = false;
    return features;
}

// Which provider a key's prefix belongs to (null when unrecognised).
function keyLooksLike(v) {
    if (!v) return null;
    if (v.startsWith('sk-ant-')) return 'anthropic';
    if (v.startsWith('gsk_')) return 'groq';
    if (v.startsWith('AIza')) return 'gemini';
    if (v.startsWith('sk-')) return 'openai';
    return null;
}

function collectKeys() {
    const keys = {};
    for (const p of PROVIDERS) {
        const input = $(`key-${p}`);
        if (input && input.value) keys[p] = input.value;
    }
    return keys;
}

async function start() {
    $('btn-start').disabled = true;
    $('setup-error').textContent = '';
    try {
        const wording = await fileToUpload($('file-wording').files[0]);
        const payload = {
            wording,
            model: $('model').value,
            judge_model: $('judge-model').value,
            api_keys: collectKeys(),
            budget: collectBudget(),
            features: collectFeatures(),
            target: $('target').value.trim()
        };
        if ($('adv-maxtokens').value !== '') payload.max_tokens = Number($('adv-maxtokens').value);
        if ($('adv-reasoning').value !== '') payload.reasoning = $('adv-reasoning').value;
        if ($('file-schedule').files.length)
            payload.schedule = await fileToUpload($('file-schedule').files[0]);
        payload.cases = await Promise.all(Array.from($('file-cases').files).map(fileToUpload));

        const data = await leapi('contract_start', payload);
        if (data.error) throw new Error(data.error);
        localStorage.setItem('le-assistant-model', $('model').value);
        attach(data.job);
    } catch (e) {
        $('setup-error').textContent = e.message;
        $('btn-start').disabled = false;
    }
}

// -------------------------------- run screen --------------------------------

function attach(job) {
    location.hash = job;
    logSince = 0;
    $('log').textContent = '';
    $('branches').innerHTML = '';
    $('run-title-text').textContent = 'Generating\u2026';
    $('run-elapsed').textContent = '';
    $('run-summary').textContent = '';
    $('btn-cancel').disabled = false;
    $('btn-run-back').classList.add('hidden');
    show('run');
    poll(job);
    pollTimer = setInterval(() => poll(job), 2000);
}

const STAGE_MAX = 6;

function fmtElapsed(sec) {
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    const mm = String(m).padStart(2, '0'), ss = String(s).padStart(2, '0');
    return h > 0 ? `${h}:${mm}:${ss}` : `${m}:${ss}`;
}

// The user's choices and the elapsed time, echoed by every status poll (so a
// reloaded tab shows them too).
let lastRunHeader = null;   // last {config, elapsed} seen — shown on the Result screen too

function summaryBits(c) {
    return [
        `model ${c.model}`,
        c.judge_model && c.judge_model !== c.model ? `judge ${c.judge_model}` : null,
        `K=${c.k} W=${c.w} repairs=${c.repairs}`,
        `probes ${c.probes}`,
        `holdout ${c.holdout}`,
        c.paraphrase === true ? 'paraphrase check' : null,
        c.clausewise === true ? 'clause-wise' : null,
        c.diff_repairs === false ? 'full-file repairs' : 'diff repairs',
        `max ${c.minutes} min`,
        `${c.max_tokens} tokens/call`,
        c.reasoning === 'minimal' ? 'minimal reasoning' : null
    ].filter(Boolean);
}

function renderRunHeader(data) {
    if (typeof data.elapsed === 'number')
        $('run-elapsed').textContent = `\u2014 ${fmtElapsed(data.elapsed)} elapsed`;
    const c = data.config || {};
    if (c.model) {
        lastRunHeader = { config: c, elapsed: data.elapsed };
        $('run-summary').textContent = summaryBits(c).join(' \u00b7 ');
        $('run-summary').title = 'Your choices for this job, echoed by the server with every status poll (so they survive a page reload).';
    }
}

async function poll(job) {
    let data;
    try {
        data = await leapi('contract_status', { job, since: logSince });
    } catch (e) {
        return; // transient network error: keep polling
    }
    if (data.error && data.status === undefined) {
        stopPolling();
        $('run-title-text').textContent = 'Error';
        $('log').textContent += '\n' + data.error;
        return;
    }
    $('stage-label').textContent = `Stage ${data.stage}/${STAGE_MAX}: ${data.stage_label}`;
    $('stage-fill').style.width = `${Math.round(100 * data.stage / STAGE_MAX)}%`;
    try { renderRunHeader(data); } catch (e) { console.error('run header render failed', e); }
    if (data.log && data.log.length) {
        $('log').textContent += data.log.join('\n') + '\n';
        $('log').scrollTop = $('log').scrollHeight;
        logSince = data.next_seq;
    }
    renderBranches(data.branches || []);
    if (data.status === 'finished') {
        stopPolling();
        showResult(job);
    } else if (data.status === 'error') {
        terminalRun('Failed', 'Job failed: ' + (data.error || 'unknown error'));
    } else if (data.status === 'interrupted') {
        terminalRun('Cancelled', '');
    }
}

function renderBranches(branches) {
    const div = $('branches');
    div.innerHTML = '';
    for (const b of branches) {
        const card = document.createElement('div');
        card.className = 'branch';
        card.innerHTML = `<b>Branch ${b.branch}</b> <span class="state">${b.state || ''}</span><br>` +
            (b.summary ? `<small>${b.summary}${b.iteration !== undefined ? ` (iteration ${b.iteration})` : ''}</small>` : '');
        div.appendChild(card);
    }
}

function stopPolling() {
    if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
}

// The job is over (failed or cancelled): Cancel can do nothing any more.
function terminalRun(title, logLine) {
    stopPolling();
    $('run-title-text').textContent = title;
    if (logLine) {
        $('log').textContent += '\n' + logLine + '\n';
        $('log').scrollTop = $('log').scrollHeight;
    }
    $('btn-cancel').disabled = true;
    $('btn-run-back').classList.remove('hidden');
}

async function cancel() {
    const job = location.hash.slice(1);
    if (!job) return;
    const resp = await leapi('contract_interrupt', { job });
    if (resp && resp.ok === false) {
        // Nothing to interrupt: the job already ended. Say so instead of
        // silently ignoring the click.
        $('log').textContent += '\n' + (resp.error || 'The job is not running.') + '\n';
        $('btn-cancel').disabled = true;
        $('btn-run-back').classList.remove('hidden');
    } else {
        $('run-hint').textContent = 'Cancelling\u2026 the job stops at the next step boundary (an in-flight LLM call finishes first).';
    }
}

// ------------------------------ result screen -------------------------------

async function showResult(job) {
    const data = await leapi('contract_result', { job });
    if (data.error) {
        $('run-title-text').textContent = 'Error';
        $('log').textContent += '\n' + data.error;
        return;
    }
    result = data;
    if (lastRunHeader && lastRunHeader.config) {
        const bits = summaryBits(lastRunHeader.config);
        if (typeof lastRunHeader.elapsed === 'number')
            bits.push(`finished in ${fmtElapsed(lastRunHeader.elapsed)}`);
        $('result-summary').textContent = bits.join(' \u00b7 ');
    }
    $('result-le').textContent = data.le || '';
    $('result-ledger').textContent = data.ledger || '(no ledger)';
    const scores = $('scores');
    scores.innerHTML = '';
    if (data.final_score) {
        const el = document.createElement('div');
        el.className = 'branch winner';
        el.innerHTML = `<b>Delivered program</b><br><small>${data.final_score.summary || ''}</small>`;
        scores.appendChild(el);
    }
    for (const s of data.scores || []) {
        const el = document.createElement('div');
        el.className = 'branch' + (s.branch === data.winner ? ' winner' : '');
        const holdout = (s.holdout_passed !== undefined && (s.holdout_passed + s.holdout_failed) > 0)
            ? `<br><small>held-out: ${s.holdout_passed}/${s.holdout_passed + s.holdout_failed}</small>` : '';
        el.innerHTML = `<b>Branch ${s.branch}${s.branch === data.winner ? ' — winner' : ''}</b><br><small>${s.summary || ''}</small>${holdout}`;
        scores.appendChild(el);
    }
    renderReports(data);
    show('result');
}

function renderReports(data) {
    const div = $('reports');
    div.innerHTML = '';
    const inter = data.interrogation;
    if (inter && inter.enabled) {
        const el = document.createElement('div');
        el.className = 'branch' + (inter.disagreed > 0 ? ' warn' : ' winner');
        let open = '';
        if (inter.disagreed > 0 && (inter.open || []).length) {
            open = '<br><small>Open disagreements (twin wrong, or contract ambiguous):</small>' +
                (inter.open || []).map(o =>
                    `<br><small>• ${o.query} / ${o.scenario}: expected ${o.expected}, got ${o.actual}</small>`).join('');
        }
        el.innerHTML = `<b>Interrogation</b><br><small>${inter.agreed} probe(s) agree, ${inter.disagreed} disagree` +
            `${inter.initially_disagreed > inter.disagreed ? ` (${inter.initially_disagreed - inter.disagreed} adjudicated)` : ''}</small>${open}`;
        div.appendChild(el);
    }
    const para = data.paraphrase;
    if (para && para.enabled) {
        const el = document.createElement('div');
        el.className = 'branch' + (para.stability >= 70 ? ' winner' : ' warn');
        el.innerHTML = `<b>Paraphrase invariance</b><br><small>stability ${para.stability}%</small>`;
        el.title = para.report || '';
        div.appendChild(el);
    }
}

function copyResult() {
    navigator.clipboard.writeText(result.le).then(
        () => { $('result-note').textContent = 'Copied.'; },
        () => { $('result-note').textContent = 'Copy failed — select the text manually.'; });
}

function downloadResult() {
    const blob = new Blob([result.le], { type: 'text/plain' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = result.filename || 'contract.le';
    a.click();
    URL.revokeObjectURL(a.href);
}

function openInEditor() {
    // The editor accepts initial content via the ?text= URL parameter.
    const url = '/editor/index.html?text=' + encodeURIComponent(result.le);
    if (url.length > 60000) {
        $('result-note').textContent = 'Program too large for a URL — use Download and open the file in the editor.';
        return;
    }
    window.open(url, '_blank');
}

// --------------------------------- wiring -----------------------------------

document.addEventListener('DOMContentLoaded', () => {
    wireUploads();
    loadModels();
    $('btn-start').addEventListener('click', start);
    $('btn-cancel').addEventListener('click', cancel);
    $('btn-copy').addEventListener('click', copyResult);
    $('btn-download').addEventListener('click', downloadResult);
    $('btn-editor').addEventListener('click', openInEditor);
    $('btn-again').addEventListener('click', () => { location.hash = ''; show('setup'); $('btn-start').disabled = false; });
    $('btn-run-back').addEventListener('click', () => { location.hash = ''; show('setup'); $('btn-start').disabled = false; });

    // Reattach to a running job after a reload: the job ID lives in the hash.
    const job = location.hash.slice(1);
    if (job) attach(job);
});
