/* telemetry.js — error reports (Sentry, with its feedback form) and web
 * analytics (Cloudflare Web Analytics) for the pages of this server.
 *
 * Served as GET /telemetry.js: the server puts `var TELEMETRY = {…};` in
 * front of this file, built from its environment (le_telemetry.pl; LPS2 has
 * a copy of this file beside lps_telemetry.pl). With neither service
 * configured — everywhere but the deployed server — the server answers a
 * comment instead, and nothing is loaded or sent.
 *
 * What is sent, and what is not (docs/telemetry.md):
 *  - Sentry: uncaught errors of the page, with sendDefaultPii off, no console
 *    breadcrumbs (a page may log a program), and the feedback form without
 *    screenshots (a screenshot would show the program). Every address it
 *    reports keeps only the query parameters TELEMETRY.urlParams lists,
 *    since a link can carry a program.
 *  - Cloudflare Web Analytics: its beacon, as the site's dashboard gives it
 *    (page views and performance; no cookies, no local storage).
 */
(function (C) {
    'use strict';
    if (!C || (!C.sentry && !C.webAnalytics)) return;

    /* A page's address can carry its program (the editor's ?text= and
     * #lzp= links): what is reported keeps the path and only the parameters
     * TELEMETRY.urlParams names (an example's name, say). */
    var keep = C.urlParams || [];
    function cleanUrl(s) {
        if (typeof s !== 'string' || !/^https?:|^\//.test(s)) return s;
        try {
            var u = new URL(s, window.location.href);
            var q = new URLSearchParams();
            keep.forEach(function (k) {
                if (u.searchParams.has(k)) q.set(k, u.searchParams.get(k).slice(0, 120));
            });
            var qs = q.toString();
            return u.origin + u.pathname + (qs ? '?' + qs : '');
        } catch (e) { return ''; }
    }
    function cleanFields(o, names) {
        if (!o) return;
        names.forEach(function (k) { if (typeof o[k] === 'string') o[k] = cleanUrl(o[k]); });
    }
    /* A Sentry event, an error's or the feedback form's, as it leaves. */
    function cleanEvent(ev) {
        if (!ev) return ev;
        if (ev.request) {
            cleanFields(ev.request, ['url']);
            cleanFields(ev.request.headers, ['Referer']);
            delete ev.request.query_string;
        }
        if (ev.contexts) cleanFields(ev.contexts.feedback, ['url']);
        (ev.breadcrumbs || []).forEach(function (b) { cleanFields(b.data, ['url', 'from', 'to']); });
        return ev;
    }

    function addScript(src, integrity, onload) {
        var s = document.createElement('script');
        s.src = src;
        s.async = true;
        s.crossOrigin = 'anonymous';
        if (integrity) s.integrity = integrity;
        if (onload) s.onload = onload;
        (document.head || document.documentElement).appendChild(s);
    }

    /* Sentry: errors, and the feedback button. */
    if (C.sentry) {
        addScript(C.sentry.bundle, C.sentry.integrity, function () {
            var S = window.Sentry;
            if (!S || !S.init) return;
            var L = C.sentry.labels || {};
            S.init({
                dsn: C.sentry.dsn,
                environment: C.sentry.environment,
                release: C.sentry.release || undefined,
                sendDefaultPii: false,
                initialScope: { tags: { server: C.server } },
                beforeSend: cleanEvent,
                beforeBreadcrumb: function (b) {
                    cleanFields(b.data, ['url', 'from', 'to']);
                    return b;
                },
                integrations: [
                    S.breadcrumbsIntegration({ console: false }),
                    S.feedbackIntegration({
                        autoInject: true,
                        colorScheme: 'system',
                        enableScreenshot: false,
                        showBranding: false,
                        showName: true, showEmail: true,
                        isNameRequired: false, isEmailRequired: false,
                        triggerLabel: L.trigger,
                        formTitle: L.title,
                        messageLabel: L.message,
                        messagePlaceholder: L.placeholder,
                        nameLabel: L.name,
                        emailLabel: L.email,
                        submitButtonLabel: L.submit,
                        cancelButtonLabel: L.cancel,
                        successMessageText: L.thanks,
                        isRequiredLabel: L.required
                    })
                ]
            });
            /* beforeSend sees errors only; this sees the feedback too. */
            var client = S.getClient && S.getClient();
            if (client && client.on) client.on('beforeSendEvent', cleanEvent);
        });
    }

    /* Cloudflare Web Analytics: the dashboard's snippet,
     *   <script type='module' src='…/beacon.min.js' data-cf-beacon='{"token": "…"}'>
     * added to the page. */
    if (C.webAnalytics) {
        var b = document.createElement('script');
        b.type = 'module';
        b.src = C.webAnalytics.beacon;
        b.setAttribute('data-cf-beacon', JSON.stringify({ token: C.webAnalytics.token }));
        (document.head || document.documentElement).appendChild(b);
    }
})(typeof TELEMETRY === 'object' ? TELEMETRY : null);
