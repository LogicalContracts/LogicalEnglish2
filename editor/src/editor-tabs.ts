// The editor's file tabs: a strip above the editor, one tab per open
// document, in the style of a browser's or an IDE's tabs — icon, name, a dot
// while it has unsaved changes, a close button; "+" opens a new document.
// This module only draws the strip and reports clicks; client.ts owns the
// documents (one Monaco model each) and switches the editor between them.

import { t } from './i18n';

export interface TabInfo {
    id: number;
    title: string;      // the file name
    tooltip?: string;   // where it came from (example, URL, file)
    dirty: boolean;
    // the program the panels are about, while another tab is in front
    program?: boolean;
}

export interface TabBarOptions {
    onSelect: (id: number) => void;
    onClose: (id: number) => void;
    onNew: () => void;
    newTitle: string;       // tooltip of "+"
    programTitle: string;   // tooltip of the program marker
}

function ensureStyles() {
    if (document.getElementById('editor-tabs-styles')) return;
    const style = document.createElement('style');
    style.id = 'editor-tabs-styles';
    style.textContent = `
        #editor-tabs { display: flex; align-items: stretch; height: 30px; box-sizing: border-box;
            overflow-x: auto; overflow-y: hidden; background: var(--header-bg);
            border-bottom: 1px solid var(--border-color); scrollbar-width: thin; }
        #editor-tabs .le-tab { display: flex; align-items: center; gap: 6px; min-width: 110px; max-width: 240px;
            flex: 0 1 200px; padding: 0 6px 0 10px; font-size: 12px; cursor: pointer; user-select: none;
            color: var(--label-color); border-right: 1px solid var(--border-color); position: relative; }
        #editor-tabs .le-tab:hover { background: var(--item-hover-bg); color: var(--text-color); }
        #editor-tabs .le-tab.active { background: var(--bg-color); color: var(--text-color);
            box-shadow: inset 0 2px 0 #0e639c; }
        #editor-tabs .le-tab.program::after { content: ''; position: absolute; left: 8px; right: 8px; bottom: 2px;
            border-bottom: 2px dotted #0e639c; }
        #editor-tabs .le-tab-icon { font-size: 9px; font-weight: bold; color: #4fc1ff; border: 1px solid #4fc1ff;
            border-radius: 3px; padding: 0 2px; line-height: 12px; flex: none; }
        .light-theme #editor-tabs .le-tab-icon { color: #0e639c; border-color: #0e639c; }
        #editor-tabs .le-tab-title { flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        #editor-tabs .le-tab-close { flex: none; width: 18px; height: 18px; line-height: 17px; text-align: center;
            border-radius: 3px; font-size: 14px; color: inherit; visibility: hidden; }
        #editor-tabs .le-tab:hover .le-tab-close, #editor-tabs .le-tab.active .le-tab-close,
        #editor-tabs .le-tab.dirty .le-tab-close { visibility: visible; }
        #editor-tabs .le-tab-close:hover { background: rgba(128,128,128,0.35); }
        #editor-tabs .le-tab.dirty .le-tab-close::before { content: '●'; font-size: 10px; }
        #editor-tabs .le-tab.dirty .le-tab-close span { display: none; }
        #editor-tabs .le-tab.dirty .le-tab-close:hover::before { content: ''; }
        #editor-tabs .le-tab.dirty .le-tab-close:hover span { display: inline; }
        #editor-tabs .le-tab-new { flex: none; width: 30px; display: flex; align-items: center; justify-content: center;
            cursor: pointer; font-size: 17px; color: var(--label-color); }
        #editor-tabs .le-tab-new:hover { background: var(--item-hover-bg); color: var(--text-color); }
    `;
    document.head.appendChild(style);
}

export class TabBar {
    constructor(private el: HTMLElement, private o: TabBarOptions) {
        ensureStyles();
    }

    render(tabs: TabInfo[], activeId: number) {
        this.el.innerHTML = '';
        for (const tab of tabs) {
            const tabEl = document.createElement('div');
            tabEl.className = 'le-tab' + (tab.id === activeId ? ' active' : '')
                + (tab.dirty ? ' dirty' : '') + (tab.program ? ' program' : '');
            tabEl.dataset.tabId = String(tab.id);
            tabEl.title = (tab.tooltip || tab.title) + (tab.program ? `\n${this.o.programTitle}` : '');
            const icon = document.createElement('span');
            icon.className = 'le-tab-icon';
            icon.textContent = 'LE';
            const title = document.createElement('span');
            title.className = 'le-tab-title';
            title.textContent = tab.title;
            const close = document.createElement('span');
            close.className = 'le-tab-close';
            close.title = t('Close');
            const x = document.createElement('span');
            x.textContent = '×';
            close.appendChild(x);
            close.addEventListener('click', (e) => { e.stopPropagation(); this.o.onClose(tab.id); });
            tabEl.addEventListener('click', () => this.o.onSelect(tab.id));
            // middle click closes, as in browsers
            tabEl.addEventListener('auxclick', (e) => { if (e.button === 1) { e.preventDefault(); this.o.onClose(tab.id); } });
            tabEl.append(icon, title, close);
            this.el.appendChild(tabEl);
            if (tab.id === activeId) setTimeout(() => this.reveal(tabEl), 0);
        }
        const plus = document.createElement('div');
        plus.className = 'le-tab-new';
        plus.id = 'editor-tab-new';
        plus.textContent = '+';
        plus.title = this.o.newTitle;
        plus.addEventListener('click', () => this.o.onNew());
        this.el.appendChild(plus);
    }

    // Scrolls the strip (only the strip) so that a tab is in view.
    private reveal(tabEl: HTMLElement) {
        const strip = this.el.getBoundingClientRect();
        const r = tabEl.getBoundingClientRect();
        if (r.left < strip.left) this.el.scrollLeft -= strip.left - r.left;
        else if (r.right > strip.right) this.el.scrollLeft += r.right - strip.right;
    }
}
