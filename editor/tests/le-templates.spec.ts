import { test, expect } from '@playwright/test';
import { matchFact, fillTemplate } from '../src/le-templates';

// Pure-logic tests for the template matcher (no browser, no server): the
// splitting of facts into editable field values that the Scenario Variations
// panel and the Query editor rely on.

const LIMIT_AGG = 'the limit of indemnity for *a section* is *an amount*, *a qualifier*, as stated in your schedule';
const LIMIT_COVER = 'the limit of indemnity for *a section* for *a cover* is *an amount* as stated in your schedule';

test.describe('le-templates matchFact', () => {
    // Regression: a thousands-separated number must not be split at the
    // template's literal comma (amount "10" / qualifier "000,000, in the
    // aggregate" was the bug). A comma followed by a digit belongs to the
    // number; a comma followed by a space is grammatical.
    test('grouped number is not split at the template comma', () => {
        const m = matchFact(
            'the limit of indemnity for this section is 10,000,000, in the aggregate, as stated in your schedule.',
            [LIMIT_AGG]);
        expect(m).not.toBeNull();
        expect(m!.values).toEqual(['this section', '10,000,000', 'in the aggregate']);
    });

    test('smaller grouped numbers too', () => {
        const m = matchFact(
            'the limit of indemnity for this section is 250,000, in the aggregate, as stated in your schedule.',
            [LIMIT_AGG]);
        expect(m!.values).toEqual(['this section', '250,000', 'in the aggregate']);
    });

    test('a plain number before a grammatical comma still matches', () => {
        const m = matchFact(
            'the limit of indemnity for this section is 250, per person per day, as stated in your schedule.',
            [LIMIT_AGG]);
        expect(m!.values).toEqual(['this section', '250', 'per person per day']);
    });

    test('comma-free template unaffected', () => {
        const m = matchFact(
            'the limit of indemnity for this section for war risks is 5,000,000 as stated in your schedule.',
            [LIMIT_COVER]);
        expect(m!.values).toEqual(['this section', 'war risks', '5,000,000']);
    });

    test('fillTemplate attaches grammatical commas to the preceding word', () => {
        const out = fillTemplate(LIMIT_AGG, ['this section', '10,000,000', 'in the aggregate']);
        expect(out).toBe('the limit of indemnity for this section is 10,000,000, in the aggregate, as stated in your schedule');
        // ... and the round trip is stable.
        const m = matchFact(out, [LIMIT_AGG]);
        expect(m!.values).toEqual(['this section', '10,000,000', 'in the aggregate']);
    });
});
