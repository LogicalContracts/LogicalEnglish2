// Shareable-URL helpers: compress an edited program into a URL fragment
// (#lzp=<base64url deflate>) so a document that only lives in the editor can
// still travel as a link — and, when short enough, as a QR code. LE text
// deflates ~4x, so small programs fit; the QR path refuses over-long URLs.
// Uses the browser's native CompressionStream — no dependencies.

const PARAM = 'lzp';

async function streamBytes(input: Uint8Array, transform: any): Promise<Uint8Array> {
    const stream = new Blob([input as BlobPart]).stream().pipeThrough(transform);
    return new Uint8Array(await new Response(stream).arrayBuffer());
}

function toBase64Url(bytes: Uint8Array): string {
    let bin = '';
    bytes.forEach(b => { bin += String.fromCharCode(b); });
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function fromBase64Url(b64url: string): Uint8Array {
    const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/');
    const bin = atob(b64);
    return Uint8Array.from(bin, c => c.charCodeAt(0));
}

/** Compress program text into the value of the #lzp= fragment parameter. */
export async function compressToParam(text: string): Promise<string> {
    const bytes = await streamBytes(new TextEncoder().encode(text),
        new CompressionStream('deflate-raw'));
    return toBase64Url(bytes);
}

/** Recover the program text from a #lzp= fragment value. */
export async function decompressFromParam(value: string): Promise<string> {
    const bytes = await streamBytes(fromBase64Url(value),
        new DecompressionStream('deflate-raw'));
    return new TextDecoder().decode(bytes);
}

/** The #lzp value of the current location's fragment, or null. */
export function fragmentParam(): string | null {
    const hash = window.location.hash;
    if (!hash) return null;
    return new URLSearchParams(hash.slice(1)).get(PARAM);
}

/**
 * The URL to share for the current state: a server example keeps its plain
 * parameterized URL (minus any stale text param); anything else carries the
 * program compressed in the fragment (the text param is dropped — the
 * compressed form replaces it).
 */
export async function buildShareUrl(programText: string): Promise<string> {
    const url = new URL(window.location.href);
    url.searchParams.delete('line');
    if (url.searchParams.get('example')) {
        url.searchParams.delete('text');
        url.hash = '';
        return url.toString();
    }
    url.searchParams.delete('text');
    url.hash = `${PARAM}=${await compressToParam(programText)}`;
    return url.toString();
}
