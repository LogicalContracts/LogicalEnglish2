"""Find, in a source text, the passage that states a fact: a clause of the
good's own description paragraph matching a pattern for the fact's kind."""
import re

import os

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'sources')


def load(path):
    return open('%s/%s' % (SRC, path)).read()


def norm(s):
    return re.sub(r'\s+', ' ', s).strip()


def segment(text, anchor, others, skip_header=True, stops=()):
    """[start, end) of the good's description: from the first occurrence of its
    anchor to the first later occurrence of another good's anchor."""
    body_start = 0
    if skip_header:
        m = re.search(r'(requested a (tariff classification )?ruling|Description of goods|Dear )', text)
        body_start = m.start() if m else 0
    i = text.find(anchor, body_start) if anchor else -1
    if i < 0:
        i = text.find(anchor) if anchor else -1
    if i < 0:
        return body_start, len(text)
    ends = [text.find(o, i + len(anchor)) for o in list(others) + list(stops) if o and o != anchor]
    ends = [e for e in ends if e > i]
    return i, (min(ends) if ends else min(len(text), i + 2500))


BOUND = re.compile(r'[;:]|,(?!\d)|\.(?!\d)(?=\s|$)|\n\n')
LINE_BOUND = re.compile(r'[;:]|,(?!\d)|\.(?!\d)(?=\s|$)|\n| - ')
MODE = {'lines': False}


def clause_at(text, s, e, lo, hi, maxlen=150):
    """The clause of text[lo:hi] around the match [s, e): widened to the
    nearest clause boundaries, then cut to maxlen around the match."""
    bound = LINE_BOUND if MODE['lines'] else BOUND
    a = lo
    for m in bound.finditer(text, lo, s):
        a = m.end()
    b = hi
    m = bound.search(text, e, hi)
    if m:
        b = m.start()
    q = text[a:b]
    if len(norm(q)) > maxlen:
        a2 = max(a, s - int(maxlen * 0.35))
        b2 = min(b, e + int(maxlen * 0.65))
        # keep whole words
        while a2 > a and not text[a2 - 1].isspace():
            a2 -= 1
        while b2 < b and not text[b2].isspace():
            b2 += 1
        q = text[a2:b2]
    q = norm(q)
    q = q.strip(' ,;-')
    if '"' in q:
        # an LE string cannot hold a double quote: keep the side with the match
        parts = [p for p in q.split('"') if p.strip()]
        q = max(parts, key=len).strip(' ,;-')
    return q


def find(text, seg, patterns, maxlen=100):
    lo, hi = seg
    for p in patterns:
        m = re.search(p, text[lo:hi], re.I)
        if m:
            return clause_at(text, lo + m.start(), lo + m.end(), lo, hi, maxlen)
    return None


def first_clause(text, seg, maxlen=150):
    lo, hi = seg
    m = re.search(r'\S', text[lo:hi])
    s = lo + (m.start() if m else 0)
    return clause_at(text, s, s + 1, lo, hi, maxlen)


def check(text, quote):
    return norm(quote).lower() in norm(text).lower()
