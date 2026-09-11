// Source ranges inside INCLUDED resources.
//
// The server parses each included .le resource with its offsets moved into a
// range of its own (a multiple of RESOURCE_OFFSET_UNIT, see le_grammar.pl), so
// a range the server sends — an explanation node, an issue, a rule — is either
// an offset of the document on screen (below the unit) or one of an included
// resource. The server annotates the latter with the resource's name, the
// example name it can be opened under and the line (le_kbs.pl,
// annotate_resource_ranges/2). Such a range must never be read as an offset of
// the document on screen: this module decides which is which and opens the
// resource instead.

import { t } from './i18n';

export const RESOURCE_OFFSET_UNIT = 1000000000;

export interface ResourceRangeInfo {
    resource?: string;          // file name of the resource
    resourcePath?: string;      // its full path or URL on the server
    resourceExample?: string | null;  // the example name to open it under, if any
    resourceLine?: number;      // 1-based line within the resource
    resourceStart?: number;     // offsets within the resource
    resourceEnd?: number;
}

// An offset that belongs to an included resource, not to the document on screen.
export function isForeignOffset(offset: unknown): boolean {
    return typeof offset === 'number' && offset >= RESOURCE_OFFSET_UNIT;
}

// "apparel.le, line 112" — for tooltips and messages.
export function describeResourceRange(info: ResourceRangeInfo): string {
    const name = info.resource || info.resourcePath || '';
    return info.resourceLine ? `${name}, ${t('line')} ${info.resourceLine}` : name;
}

// Opens the included resource at the range's line, in a new editor tab (the
// document on screen stays as it is). A resource that is not one of the
// server's examples (a URL, a file elsewhere) cannot be opened from here: the
// user is told where the range is instead.
export function openIncludedResource(info: ResourceRangeInfo): void {
    if (!info.resourceExample) {
        alert(`${t('This is defined in the included resource')} ${describeResourceRange(info)}.`);
        return;
    }
    const url = new URL(window.location.href);
    url.search = '';
    url.hash = '';
    url.searchParams.set('example', info.resourceExample);
    if (info.resourceLine) url.searchParams.set('line', String(info.resourceLine));
    const theme = new URLSearchParams(window.location.search).get('theme');
    if (theme) url.searchParams.set('theme', theme);
    window.open(url.toString(), '_blank');
}
