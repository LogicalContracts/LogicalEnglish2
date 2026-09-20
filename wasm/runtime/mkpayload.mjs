/* mkpayload.mjs — the virtual file system, as one file.
 *
 * The browser build needs LE2's Prolog, the i18n dictionaries, the shared LE
 * libraries and the examples inside the worker's file system before it can
 * answer anything. Four hundred-odd fetches would be four hundred round trips
 * and a cache that never quite holds; one file is one request, gzipped here
 * rather than trusting the host to do it, so it behaves the same on Vercel, on
 * GitHub Pages and on `python3 -m http.server`.
 *
 * The layout is as simple as it can be and still be read in one pass:
 *
 *     "LEWP"                     4 bytes, so a wrong file says so immediately
 *     uint32 little-endian       the length of the manifest
 *     manifest                   JSON: {files: [[path, offset, length], ...]}
 *     blob                       the files, end to end, in manifest order
 *
 * Offsets are into the blob, and a file's bytes are its bytes — no encoding,
 * no escaping — because SWI-Prolog will read them back as the UTF-8 they
 * already are.
 *
 * Usage:  node mkpayload.mjs <file-list> <repo-root> <out.bin>
 * where <file-list> is one repository-relative path per line, as
 * wasm/pack.pl's payload_files/1 prints them.
 */
import { readFileSync, writeFileSync, statSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { join } from 'node:path';

const [, , listFile, root, outFile] = process.argv;
if (!listFile || !root || !outFile) {
    console.error('usage: node mkpayload.mjs <file-list> <repo-root> <out.bin>');
    process.exit(2);
}

const paths = readFileSync(listFile, 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
const files = [];
const blobs = [];
let offset = 0;
for (const rel of paths) {
    let bytes;
    try { bytes = readFileSync(join(root, rel)); } catch (e) {
        console.error(`  skipped (unreadable): ${rel}`); continue;
    }
    files.push([rel, offset, bytes.length]);
    blobs.push(bytes);
    offset += bytes.length;
}

const manifest = Buffer.from(JSON.stringify({ files }), 'utf8');
const header = Buffer.alloc(8);
header.write('LEWP', 0, 'ascii');
header.writeUInt32LE(manifest.length, 4);
const raw = Buffer.concat([header, manifest, ...blobs]);
const gz = gzipSync(raw, { level: 9 });
writeFileSync(outFile, gz);

const mb = (n) => (n / 1048576).toFixed(2) + ' MB';
console.log(`  ${files.length} files, ${mb(raw.length)} → ${mb(gz.length)} gzipped`);
