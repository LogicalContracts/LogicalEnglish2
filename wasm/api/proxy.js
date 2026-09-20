/* api/proxy.js — the one thing on the server side of a serverless deployment.
 *
 * The browser build does everything in the tab, with one exception it cannot
 * argue with: a page may not fetch another origin unless that origin says so,
 * and the origins Logical English wants to reach — an LLM provider, a
 * document somewhere, the model price table — do not. Worse, the ones worth
 * reaching need a key, and a key in a page is a key that has been given away.
 *
 * So this: a Vercel Function, same origin as the page, that forwards a request
 * to an address on a list its operator wrote, adding the key from the
 * environment on the way through. The page never holds a key and can never
 * name a host that is not on the list.
 *
 * It is deliberately small and deliberately suspicious:
 *
 *   * the list is exact hostnames, from LE_PROXY_ALLOW, with a default that
 *     is the LLM providers llm/llm_client.pl knows and the price table;
 *   * http(s) only, and no address that resolves to somewhere private — the
 *     hostname check is the defence, and this is the second one;
 *   * redirects are not followed: a 301 to somewhere else is the classic way
 *     around an allowlist;
 *   * one megabyte and thirty seconds, then it stops;
 *   * nothing is logged but the host and the status. The bodies are the
 *     user's programs and the model's answers, and this is not the place to
 *     keep either.
 *
 * Unset LE_PROXY_ALLOW to an empty string to turn it off: with no hosts
 * allowed, every request is refused and the build is the pure-static one.
 */

const DEFAULT_ALLOW = [
    'api.openai.com',
    'api.anthropic.com',
    'api.groq.com',
    'generativelanguage.googleapis.com',
    'openrouter.ai',
    'api.mistral.ai',
    'api.deepseek.com',
    'raw.githubusercontent.com'
];

/*  Which environment variable carries the key for which host, and the header
 *  it goes in. A host with no key configured is still forwarded to — plenty
 *  of addresses need none — but the header is left off rather than sent
 *  empty. */
const KEYS = {
    'api.openai.com':      { env: 'OPENAI_API_KEY',    header: 'authorization', prefix: 'Bearer ' },
    'api.groq.com':        { env: 'GROQ_API_KEY',      header: 'authorization', prefix: 'Bearer ' },
    'openrouter.ai':       { env: 'OPENROUTER_API_KEY', header: 'authorization', prefix: 'Bearer ' },
    'api.mistral.ai':      { env: 'MISTRAL_API_KEY',   header: 'authorization', prefix: 'Bearer ' },
    'api.deepseek.com':    { env: 'DEEPSEEK_API_KEY',  header: 'authorization', prefix: 'Bearer ' },
    'api.anthropic.com':   { env: 'ANTHROPIC_API_KEY', header: 'x-api-key',     prefix: '' },
    'generativelanguage.googleapis.com': { env: 'GEMINI_API_KEY', header: 'x-goog-api-key', prefix: '' }
};

const MAX_BODY = 1024 * 1024;
const TIMEOUT_MS = 30000;

function allowedHosts() {
    const configured = process.env.LE_PROXY_ALLOW;
    if (configured === undefined) return DEFAULT_ALLOW;
    return configured.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
}

function isPrivateHost(hostname) {
    const h = hostname.toLowerCase();
    if (h === 'localhost' || h.endsWith('.localhost') || h.endsWith('.internal')) return true;
    if (/^\d+\.\d+\.\d+\.\d+$/.test(h)) {
        const [a, b] = h.split('.').map(Number);
        return a === 10 || a === 127 || a === 0 || (a === 172 && b >= 16 && b <= 31)
            || (a === 192 && b === 168) || (a === 169 && b === 254);
    }
    return h.startsWith('[') || h.includes(':');   /* an IPv6 literal: not worth the surface */
}

/*  CommonJS, and deliberately: a Vercel Function is a `.js` file in `api/`,
 *  and without a package.json saying `"type": "module"` beside it — which a
 *  directory of static files has no other reason to carry — Node reads a
 *  `.js` as CommonJS and an `export default` is a syntax error at deploy
 *  time. `module.exports` works under either. */
module.exports = async function handler(request, response) {
    if (request.method !== 'POST') {
        return response.status(405).json({ error: 'POST a request description here' });
    }
    let req = request.body;
    if (typeof req === 'string') { try { req = JSON.parse(req); } catch { req = null; } }
    if (!req || typeof req.url !== 'string') {
        return response.status(400).json({ error: 'expected {url, method, headers, body}' });
    }

    let target;
    try { target = new URL(req.url); } catch {
        return response.status(400).json({ status: 0, headers: {}, body: '', error: 'not a URL' });
    }
    if (target.protocol !== 'https:' && target.protocol !== 'http:') {
        return response.status(400).json({ status: 0, headers: {}, body: '', error: 'only http(s)' });
    }
    const host = target.hostname.toLowerCase();
    if (isPrivateHost(host) || !allowedHosts().includes(host)) {
        /* Said plainly, because the person who meets it is the operator who
         * has to add the host, not an attacker learning anything. */
        return response.status(403).json({
            status: 0, headers: {}, body: '',
            error: `this deployment does not forward requests to ${host}. `
                 + 'Add it to LE_PROXY_ALLOW if it should.'
        });
    }

    const headers = {};
    for (const pair of req.headers || []) {
        if (!Array.isArray(pair) || pair.length !== 2) continue;
        const name = String(pair[0]).toLowerCase();
        /* The page does not get to set these: they are the request's identity. */
        if (['host', 'authorization', 'x-api-key', 'x-goog-api-key', 'cookie'].includes(name)) continue;
        headers[name] = String(pair[1]);
    }
    const key = KEYS[host];
    if (key && process.env[key.env]) headers[key.header] = key.prefix + process.env[key.env];
    if (host === 'api.anthropic.com' && !headers['anthropic-version']) {
        headers['anthropic-version'] = '2023-06-01';
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
        const upstream = await fetch(target.toString(), {
            method: (req.method || 'GET').toUpperCase(),
            headers,
            body: req.body === null || req.body === undefined ? undefined : String(req.body),
            redirect: 'manual',
            signal: controller.signal
        });
        const text = (await upstream.text()).slice(0, MAX_BODY);
        const out = {};
        upstream.headers.forEach((value, name) => {
            if (['content-type', 'content-length', 'retry-after'].includes(name)) out[name] = value;
        });
        console.log(`proxy ${host} → ${upstream.status}`);
        return response.status(200).json({ status: upstream.status, headers: out, body: text, error: null });
    } catch (error) {
        const aborted = error && error.name === 'AbortError';
        console.log(`proxy ${host} → ${aborted ? 'timeout' : 'failed'}`);
        return response.status(200).json({
            status: 0, headers: {}, body: '',
            error: aborted ? 'the request timed out' : 'the request could not be made'
        });
    } finally {
        clearTimeout(timer);
    }
};
