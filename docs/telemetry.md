# Error reports and analytics: Sentry and PostHog

The LE2 server can report errors to [Sentry](https://sentry.io) — its own
exceptions and those of the pages it serves — offer a small **Feedback**
form (Sentry's User Feedback), and send [PostHog](https://posthog.com) page
views, autocaptured clicks and the editor's main actions.

**Both are off unless the server's environment configures them.** With no
variable set, nothing is loaded and nothing leaves the server or the
browser: every page still asks for `/telemetry.js`, which then answers one
line defining a function that does nothing. That is how tests and local
development run.

The LPS2 server has the same, in its own Sentry and PostHog projects
(`/lps2/docs/telemetry.md`, variables `LPS_…`).

## What is sent, and what is not

| | Sent | Not sent |
|---|---|---|
| Server → Sentry | the API operation's name (`answeringQuery`, `load`, …), the error's type and message (at most 1000 characters), the Prolog backtrace when the error carries one, environment, release | the program, the query, the scenario, any other field of the request, the user's name or IP |
| Browser → Sentry | uncaught errors of the page, with the SDK's default context (browser, URL) and `sendDefaultPii: false` | console output (a page may log a program), screenshots (the feedback form has none: it would show the program) |
| Feedback form → Sentry | the message typed, and a name and email **only if** the user types them | — |
| Browser → PostHog | page views; clicks, with the element's id and classes but **every text masked** (the editor's text is the user's program); the main actions below | session recordings (off), input values, cookies (see *Persistence*) |

Every page address that is reported — an error's, the feedback form's, a
page view's and every address among PostHog's properties — loses its
fragment and every query parameter but `example`, `scenario`, `query` and
`lang` (`url_params/1`): an editor link can carry a whole program
(`?text=…`, `#lzp=…`). PostHog's feature flags are turned off, since their
requests would send the first address unfiltered.

An error message is written by the code that raised it, and a few Prolog
errors quote the term they were about (a type error names the value it
found); with 1000 characters at most, that is the one way a fragment of a
program could reach Sentry.

The server sends a report from a thread of its own, with a five-second
timeout; the same error at most once in ten minutes, and at most sixty
reports an hour. An unreachable Sentry never slows or fails a request.

### The main actions (PostHog events)

Recognised by the operation each call to `/leapi` names
(`le_telemetry.pl`, `api_event/3`); only these fields travel with them:

| Event | When | Properties |
|---|---|---|
| `example opened` | a program opened from the server's examples | `example` (its name) |
| `query run` | a query run (the editor, the executive view, the views) | `with_scenario` |
| `file imported` | File ▸ Open of another system's file | `extension` |
| `program exported` | File ▸ Export to Another System… | `format` |
| `proof game opened`, `explanation drill opened` | | |
| `tests run`, `legal view opened`, `s(CASP) translation shown`, `program run in LPS` | | |
| `English to LE`, `assistant used`, `contract assistant started` | | |

Pages can send more with `window.leTrack(name, props)` (a no-op when
PostHog is off).

## The variables

| Variable | Meaning | Default |
|---|---|---|
| `LE_SENTRY_DSN` | the Sentry project's DSN: turns Sentry on | off |
| `LE_SENTRY_ENVIRONMENT` | Sentry's *environment* | `production` |
| `LE_SENTRY_RELEASE` | Sentry's *release* | `le2@<git hash>` from `build_info.txt` (written by `buildPush.sh`) |
| `LE_POSTHOG_KEY` | the PostHog project's API key (`phc_…`): turns PostHog on | off |
| `LE_POSTHOG_HOST` | PostHog's ingestion host | `https://eu.i.posthog.com` (EU cloud) |
| `LE_POSTHOG_PERSISTENCE` | where PostHog keeps its anonymous id | `memory` |

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

## 2. The PostHog project

1. Sign in at <https://eu.posthog.com> (EU cloud; <https://us.posthog.com>
   for the US one — then set `LE_POSTHOG_HOST=https://us.i.posthog.com`).
2. Create a project for this server: *project switcher ▸ New project*,
   named `Logical English 2`.
3. Copy the **Project API key** (`phc_…`): *Settings ▸ Project ▸ General*.
   It is public by design (it can only send events).
4. *Settings ▸ Project ▸ Autocapture & heatmaps*: **Autocapture** on (the
   pages ask for it too); heatmaps and web vitals as you like.
5. *Settings ▸ Session replay*: leave **Record user sessions** off (the pages
   also disable it: a recording would show the programs).
6. *Settings ▸ Project ▸ Toolbar / Authorized URLs*: add
   `https://logicalenglish2.fly.dev`.
7. *Settings ▸ Project ▸ General ▸ IP data capture*: turn on **Discard
   client IP data**.

## 3. Setting the variables on fly.io

The app is `logicalenglish2` (`fly.toml`). Neither value is secret — both end
up in every page — but keeping them as fly secrets leaves `fly.toml`
unchanged and lets them differ per deployment:

```sh
fly secrets set -a logicalenglish2 \
    LE_SENTRY_DSN='https://<key>@o<nnn>.ingest.de.sentry.io/<nnn>' \
    LE_POSTHOG_KEY='phc_<key>'
# only for a US PostHog project:
fly secrets set -a logicalenglish2 LE_POSTHOG_HOST='https://us.i.posthog.com'
```

`fly secrets set` restarts the machine with the new values (add `--stage`
to apply them at the next `fly deploy` instead). To turn either off:
`fly secrets unset -a logicalenglish2 LE_POSTHOG_KEY`.

Locally, export the same variables before starting the server, with
`LE_SENTRY_ENVIRONMENT=development` so that local errors can be filtered
out in Sentry.

## 4. Checking it works

- **Server**: open `https://logicalenglish2.fly.dev/telemetry_test`. It
  answers `{"sentry": true, "posthog": true, "sentry_test": "sent", …}` and
  sends a test error, `telemetry_test`, tagged `operation: telemetry_test`,
  `server: le2` — it appears in Sentry's *Issues* within a minute. (It is
  throttled like any report: again within ten minutes it says so and sends
  nothing, so the URL cannot flood the project.)
- **Browser errors**: open the editor, then in the browser's console
  `Sentry.captureException(new Error('browser check'))`.
- **Feedback**: the *Feedback* button, bottom right of every page; send a
  message and find it under *User Feedback*.
- **PostHog**: *Activity* (or *Live events*) shows `$pageview`,
  `$autocapture` and, after opening an example, `example opened`. (PostHog
  drops the events of browsers it takes for bots — a headless test browser
  included — so check with an ordinary one.)

The unit test `testing/test_telemetry.pl` checks the DSN parsing, the
envelope, the throttling and that nothing happens unconfigured, with a mock
Sentry on a local port.

## Persistence, cookies and consent

By default PostHog keeps its anonymous id in memory only: **no cookie and no
local storage**, so each page load is a new anonymous visitor. Page views,
actions and funnels within a page are counted; "unique users" and retention
are not meaningful. That default is chosen so that no consent banner is
needed for PostHog under the EU's ePrivacy rules and GDPR (nothing is stored
on the user's device, and no IP is kept if step 2.7 is done).

`LE_POSTHOG_PERSISTENCE=localStorage+cookie` makes visitors recognisable
across visits — and then storing an identifier on the device may require the
user's consent (a cookie banner) where EU law applies; add one before
turning it on. Sentry stores nothing on the device.

## Where the code is

- `le_telemetry.pl` — the configuration, the server's reports (Sentry
  envelope over HTTP), `/telemetry.js` and `/telemetry_test`.
- `web_extras/telemetry/telemetry.js` — the pages' client: loads Sentry's
  pinned CDN bundle (with its integrity hash) and the PostHog snippet, and
  recognises the main actions. LPS2 has a copy (`src/edges/lps_telemetry.js`):
  change both.
- `classic_web_api.pl` — the two handlers, the report in `handle_leapi/1`,
  and the script in the server-rendered pages; the static pages
  (`editor/*.html`, `web_extras/*/index.html`) have
  `<script src="/telemetry.js">` in their head.
- The feedback form's words are rows of `i18n/ui.csv`, in the language of
  the `le_ui_lang` cookie.

If a Content Security Policy is ever added, it must allow
`browser.sentry-cdn.com` (scripts), `*.ingest.sentry.io` (connect), and the
PostHog host and its assets host (`eu.i.posthog.com`,
`eu-assets.i.posthog.com`).
