// Key events that are not keyboard events, kept away from Monaco.
//
// Monaco listens for `keydown`/`keyup` on the document body and turns every
// such event into a StandardKeyboardEvent, which calls getModifierState() on
// it. Chrome's autofill and password managers dispatch plain `Event`s named
// `keydown` when a suggestion is picked in an input (an API key field, a
// login, a filter), and Monaco then threw "t.getModifierState is not a
// function" (Sentry le2, 2026-09-16, on /editor/index.html). A listener on
// the window in the capture phase runs before the body's, and stops only
// those impostors: a real key press is a KeyboardEvent and goes on as before.
export function installKeyEventGuard(): void {
    const w = window as any;
    if (w.__leKeyEventGuard) return;
    w.__leKeyEventGuard = true;
    for (const type of ['keydown', 'keyup', 'keypress']) {
        window.addEventListener(type, (e: Event) => {
            if (!(e instanceof KeyboardEvent)) e.stopImmediatePropagation();
        }, true);
    }
}
