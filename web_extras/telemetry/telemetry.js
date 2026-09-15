/* telemetry.js — error reports (Sentry, with its feedback form) and product
 * analytics (PostHog, autocapture) for the pages of this server.
 *
 * Served as GET /telemetry.js: the server puts `var TELEMETRY = {…};` in
 * front of this file, built from its environment (le_telemetry.pl; LPS2 has
 * a copy of this file beside lps_telemetry.pl). With neither service
 * configured TELEMETRY is null, nothing is loaded and nothing is sent: the
 * only effect is a track() function that does nothing.
 *
 * What is sent, and what is not (docs/telemetry.md):
 *  - Sentry: uncaught errors of the page, with sendDefaultPii off, no console
 *    breadcrumbs (a page may log a program), and the feedback form without
 *    screenshots (a screenshot would show the program).
 *  - PostHog: page views and autocaptured clicks with every element's text
 *    masked (the editor's text is the user's program), no session recording;
 *    and the page's main actions, recognised by the operation named in its
 *    calls to this server's API. Only the operation's event name leaves the
 *    page, with the few fields TELEMETRY.events names (an example's name, an
 *    export format, an uploaded file's extension) — never a program.
 *  - Both: the page's address without its fragment and with only the query
 *    parameters TELEMETRY.urlParams lists, since a link can carry a program.
 */
(function (C) {
    'use strict';
    var trackName = (C && C.track) || 'leTrack';
    var track = function () {};
    window[trackName] = track;
    if (!C || (!C.sentry && !C.posthog)) return;

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
    /* Every address among a PostHog event's properties ($current_url,
     * $session_entry_url, $initial_referrer, …, and those it $sets). */
    function cleanProps(o) {
        if (!o || typeof o !== 'object') return;
        Object.keys(o).forEach(function (k) {
            var v = o[k];
            if (typeof v === 'string' && /^https?:/.test(v)) o[k] = cleanUrl(v);
            else if (k === '$set' || k === '$set_once') cleanProps(v);
        });
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

    /* PostHog: the standard loader snippet, then init. */
    if (C.posthog) {
        !function (t, e) { var o, n, p, r; e.__SV || (window.posthog = e, e._i = [], e.init = function (i, s, a) { function g(t, e) { var o = e.split("."); 2 == o.length && (t = t[o[0]], e = o[1]), t[e] = function () { t.push([e].concat(Array.prototype.slice.call(arguments, 0))) } } (p = t.createElement("script")).type = "text/javascript", p.crossOrigin = "anonymous", p.async = !0, p.src = s.api_host.replace(".i.posthog.com", "-assets.i.posthog.com") + "/static/array.js", (r = t.getElementsByTagName("script")[0]) ? r.parentNode.insertBefore(p, r) : t.head.appendChild(p); var u = e; for (void 0 !== a ? u = e[a] = [] : a = "posthog", u.people = u.people || [], u.toString = function (t) { var e = "posthog"; return "posthog" !== a && (e += "." + a), t || (e += " (stub)"), e }, u.people.toString = function () { return u.toString(1) + ".people (stub)" }, o = "init capture register register_once register_for_session unregister unregister_for_session getFeatureFlag getFeatureFlagPayload isFeatureEnabled reloadFeatureFlags on onFeatureFlags onSessionId identify setPersonProperties group resetGroups reset get_distinct_id get_session_id alias set_config opt_in_capturing opt_out_capturing has_opted_in_capturing has_opted_out_capturing debug".split(" "), n = 0; n < o.length; n++)g(u, o[n]); e._i.push([i, s, a]) }, e.__SV = 1) }(document, window.posthog || []);
        window.posthog.init(C.posthog.key, {
            api_host: C.posthog.host,
            autocapture: true,
            capture_pageview: true,
            capture_pageleave: true,
            disable_session_recording: true,
            disable_surveys: true,
            mask_all_text: true,
            mask_all_element_attributes: true,
            persistence: C.posthog.persistence || 'memory',
            person_profiles: 'identified_only',
            /* no feature flags: their requests send the person's properties,
             * the first address included, unfiltered */
            advanced_disable_flags: true,
            before_send: function (ev) {
                if (ev) { cleanProps(ev.properties); cleanProps(ev.$set); cleanProps(ev.$set_once); }
                return ev;
            }
        });
        track = function (name, props) {
            try { window.posthog.capture(String(name), props || {}); } catch (e) { }
        };
        window[trackName] = track;
        watchApi();
    }

    /* The page's main actions: every call to this server's API names its
     * operation; those TELEMETRY.events lists become events. A field spec is
     * "field" (its text, cut short), "field?" (whether it is given) or
     * "field.ext" (a file name's extension). */
    function watchApi() {
        var events = C.events || {};
        var apiPath = C.api;
        if (!apiPath || !window.fetch) return;
        var original = window.fetch;
        window.fetch = function (input, init) {
            try { observe(input, init); } catch (e) { }
            return original.apply(this, arguments);
        };
        function observe(input, init) {
            var url = typeof input === 'string' ? input : (input && input.url);
            if (!url || !init || typeof init.body !== 'string') return;
            var u = new URL(url, window.location.href);
            if (u.origin !== window.location.origin || u.pathname !== apiPath) return;
            var m = /"operation"\s*:\s*"([A-Za-z_]+)"/.exec(init.body);
            var ev = m && events[m[1]];
            if (!ev) return;
            var props = { operation: m[1] };
            var fields = ev.props || {};
            var names = Object.keys(fields);
            if (names.length) {
                var body = JSON.parse(init.body);
                names.forEach(function (p) { props[p] = field(body, fields[p]); });
            }
            track(ev.name, props);
        }
        function field(body, spec) {
            if (spec.slice(-1) === '?') {
                var v = body[spec.slice(0, -1)];
                return v !== undefined && v !== null && v !== '';
            }
            if (spec.slice(-4) === '.ext') {
                var n = String(body[spec.slice(0, -4)] || '');
                var i = n.lastIndexOf('.');
                return i >= 0 ? n.slice(i + 1).toLowerCase().slice(0, 12) : '';
            }
            var t = body[spec];
            return t === undefined || t === null ? null : String(t).slice(0, 120);
        }
    }
})(typeof TELEMETRY === 'object' ? TELEMETRY : null);
