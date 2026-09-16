# Error reports and web analytics: Sentry and Cloudflare

The LE2 server can report errors to [Sentry](https://sentry.io) — its own
exceptions and those of the pages it serves — offer a small **Feedback**
form (Sentry's User Feedback), and load [Cloudflare Web
Analytics](https://developers.cloudflare.com/web-analytics/) on its pages.

**Both are off unless the server's environment configures them, and only the
deployed server's does** (fly secrets, §3). With no variable set, nothing is
loaded and nothing leaves the server or the browser: every page still asks
for `/telemetry.js`, which then answers a comment. That is how tests, local
development and any other deployment run.

The LPS2 server has the same, with its own Sentry project and Web Analytics
site (`/lps2/docs/telemetry.md`, variables `LPS_…`).

## What is sent, and what is not

| | Sent | Not sent |
|---|---|---|
| Server → Sentry | the API operation's name (`answeringQuery`, `load`, …), the error's type and message (at most 1000 characters), the Prolog backtrace when the error carries one, environment, release | the program, the query, the scenario, any other field of the request, the user's name or IP |
| Browser → Sentry | uncaught errors of the page, with the SDK's default context (browser, URL) and `sendDefaultPii: false` | console output (a page may log a program), screenshots (the feedback form has none: it would show the program) |
| Feedback form → Sentry | the message typed, and a name and email **only if** the user types them | — |
| Browser → Cloudflare Web Analytics | Cloudflare's beacon: page views (the page's path, referrer, country, browser and device class) and page-load performance | cookies, local storage, fingerprinting, the page's contents, clicks, programs typed in the editor |

Every page address Sentry reports — an error's, the feedback form's — loses
its fragment and every query parameter but `example`, `scenario`, `query`
and `lang` (`url_params/1`): an editor link can carry a whole program
(`?text=…`, `#lzp=…`). The Cloudflare beacon is Cloudflare's own script and
reads the page's address itself. Cloudflare's dashboard reports paths, and a
fragment (`#lzp=…`) never leaves the browser, but check *Top paths* after
the first deployment to confirm that no `?text=` query string is kept (see
§4).

An error message is written by the code that raised it, and a few Prolog
errors quote the term they were about (a type error names the value it
found); with 1000 characters at most, that is the one way a fragment of a
program could reach Sentry.

The server sends a report from a thread of its own, with a five-second
timeout; the same error at most once in ten minutes, and at most sixty
reports an hour. An unreachable Sentry never slows or fails a request.

## The variables

| Variable | Meaning | Default |
|---|---|---|
| `LE_SENTRY_DSN` | the Sentry project's DSN: turns Sentry on | off |
| `LE_SENTRY_ENVIRONMENT` | Sentry's *environment* | `production` |
| `LE_SENTRY_RELEASE` | Sentry's *release* | `le2@<git hash>` from `build_info.txt` (written by `buildPush.sh`) |
| `LE_CLOUDFLARE_ANALYTICS_TOKEN` | the Web Analytics site's token: turns the beacon on | off |

The names start with `LE_` so that the LPS2 server, which loads parts of
Logical English into its own process, never reports into these projects.

## 1. The Sentry project

1. Sign in at <https://sentry.io> (or create the organisation).
2. **Projects ▸ Create Project**. Platform: **Browser JavaScript**. Alert
   frequency: *Alert me on every new issue*. Name: `logical-english-2`.
   Create it. (Skip the SDK instructions: the pages load the SDK
   themselves.)
3. Copy the **DSN**: *Settings ▸ Projects ▸ logical-english-2 ▸ Client Keys
   (DSN)*. It looks like `https://<key>@o<nnn>.ingest.<region>.sentry.io/<nnn>`.
   The one DSN serves both reporters: the browser SDK, and the server's
   Prolog reporter (`le_telemetry.pl`, which speaks Sentry's envelope
   protocol). Server events carry the tag `server: le2` and platform
   `other`; the browser's are JavaScript.
4. **Allowed domains**: *Settings ▸ Projects ▸ logical-english-2 ▸ General
   Settings ▸ Client Security ▸ Allowed Domains*: `logicalenglish2.fly.dev`
   (and any other host the server is reached at). Events from other origins
   are then refused.
5. **Privacy**: *Settings ▸ Projects ▸ logical-english-2 ▸ Security &
   Privacy*: keep *Data Scrubber* on, and turn on *Prevent Storing of IP
   Addresses*.
6. **User Feedback** needs nothing to be enabled: the form is part of the
   pages' SDK bundle, and what users send appears under *User Feedback* in
   the sidebar (or *Issues ▸ Feedback*).
7. **Alerts**: the project comes with *new issue → email*. To be told of a
   burst too: *Alerts ▸ Create Alert ▸ Issues ▸ Number of events in an
   issue is more than 20 in one hour → Send a notification to the project's
   team*.

## 2. The Cloudflare Web Analytics site

The site already exists; its token is `1b82e2b050984555b84cbcbd02983d7a`.
To create it again, or check its settings:

1. Sign in at <https://dash.cloudflare.com> ▸ **Analytics & Logs ▸ Web
   Analytics** ▸ **Add a site**.
2. Hostname: `logicalenglish2.fly.dev` (the site is not proxied by
   Cloudflare, so the JS snippet is the way in; no DNS change).
3. Cloudflare shows the snippet:

   ```html
   <!-- Cloudflare Web Analytics --><script type='module' src='https://static.cloudflareinsights.com/beacon.min.js' data-cf-beacon='{"token": "1b82e2b050984555b84cbcbd02983d7a"}'></script><!-- End Cloudflare Web Analytics -->
   ```

   Do **not** paste it into the pages: only its token is needed. The server
   adds the same script to every page it serves (`telemetry.js`), and only
   when the token is set, so local runs and tests are never counted.
4. The token is not secret (it ends up in every page); it is kept as a fly
   secret so that only the deployed server has it.

## 3. Setting the variables on fly.io

The app is `logicalenglish2` (`fly.toml`). Neither value is secret — both end
up in every page — but as fly secrets they stay out of `fly.toml`, the image
and every other environment: only the deployed server reports.

```sh
fly secrets set -a logicalenglish2 \
    LE_SENTRY_DSN='https://<key>@o<nnn>.ingest.de.sentry.io/<nnn>' \
    LE_CLOUDFLARE_ANALYTICS_TOKEN='1b82e2b050984555b84cbcbd02983d7a'
fly secrets list -a logicalenglish2        # names and digests, to check
```

`fly secrets set` restarts the machine with the new values (add `--stage`
to apply them at the next `fly deploy` instead). To turn one off:
`fly secrets unset -a logicalenglish2 LE_CLOUDFLARE_ANALYTICS_TOKEN`.

Do not set `LE_CLOUDFLARE_ANALYTICS_TOKEN` locally: the local pages would be
counted as the site's. To try Sentry locally, export `LE_SENTRY_DSN` with
`LE_SENTRY_ENVIRONMENT=development`, so that local errors can be filtered
out.

## 4. Checking it works

- **Server**: open `https://logicalenglish2.fly.dev/telemetry_test`. It
  answers `{"sentry": true, "web_analytics": true, "sentry_test": "sent", …}` and
  sends a test error, `telemetry_test`, tagged `operation: telemetry_test`,
  `server: le2` — it appears in Sentry's *Issues* within a minute. (It is
  throttled like any report: again within ten minutes it says so and sends
  nothing, so the URL cannot flood the project.)
- **Browser errors**: open the editor, then in the browser's console
  `Sentry.captureException(new Error('browser check'))`.
- **Feedback**: the *Feedback* button, bottom right of every page; send a
  message and find it under *User Feedback*.
- **Web Analytics**: in the browser's developer tools (*Network*), a page
  loads `static.cloudflareinsights.com/beacon.min.js` and posts to
  `cloudflareinsights.com/cdn-cgi/rum`. The dashboard (*Web Analytics ▸
  logicalenglish2.fly.dev*) shows the visits within minutes. In *Top paths*,
  check that the editor's `?text=…` links do not appear with their query
  string (the `#lzp=…` form of a link is not a path and is not reported).

The unit test `testing/test_telemetry.pl` checks the DSN parsing, the
envelope, the throttling and that nothing happens unconfigured, with a mock
Sentry on a local port.

## Cookies and consent

Cloudflare Web Analytics sets no cookie and uses no local storage, and Sentry
stores nothing on the device, so neither needs a consent banner under the
EU's ePrivacy rules. Turn on *Prevent Storing of IP Addresses* in Sentry
(step 1.5).

## Where the code is

- `le_telemetry.pl` — the configuration, the server's reports (Sentry
  envelope over HTTP), `/telemetry.js` and `/telemetry_test`.
- `web_extras/telemetry/telemetry.js` — the pages' client: loads Sentry's
  pinned CDN bundle (with its integrity hash) and Cloudflare's beacon.
  LPS2 has a copy (`src/edges/lps_telemetry.js`): change both.
- `classic_web_api.pl` — the two handlers, the report in `handle_leapi/1`,
  and the script in the server-rendered pages; the static pages
  (`editor/*.html`, `web_extras/*/index.html`) have
  `<script src="/telemetry.js">` in their head.
- The feedback form's words are rows of `i18n/ui.csv`, in the language of
  the `le_ui_lang` cookie.

If a Content Security Policy is ever added, it must allow
`browser.sentry-cdn.com` and `static.cloudflareinsights.com` (scripts), and
`*.ingest.sentry.io` and `cloudflareinsights.com` (connect).
