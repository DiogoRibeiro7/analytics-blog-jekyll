# Dynamic Services

A DataLog site is static and deploys to GitHub Pages. Some features a research site wants (correction reports, a contact form, comments, reactions, subscriptions, Webmentions) need a server. This document is the contract between the site and that server: one configuration model, one browser client, one error model, one security boundary. Every feature that talks to a backend uses it; none ships a fetch wrapper of its own.

The contract is backend- and database-agnostic. [datalog-services](https://github.com/DiogoRibeiro7/datalog-services), the [reference service](#the-reference-service), implements all of it and deploys to Cloudflare Workers without a server to run; anything that answers the same HTTP is fine, and its conformance suite checks that it does.

## Configuration

In `_config.yml`:

```yaml
dynamic_services:
  base_url: https://api.example.org   # empty or absent: every dynamic feature is off
  api_version: v1                     # the version segment of every path, and the version the service must report
  timeout_ms: 8000                    # how long the browser waits for an answer
  credentials: omit                   # omit (default), same-origin or include, for cookie-authenticated services
  features:                           # each feature can be turned off here, whatever the service offers
    corrections: true
    contact: true
    comments: false
  paths:                              # optional: a feature's path under the versioned base, when it is not /<feature>
    corrections: /feedback/corrections
  csrf_header: X-CSRF-Token           # optional, with csrf_cookie: sent on writes when the cookie is set
  csrf_cookie: csrf_token
```

These settings are **public**. The site inlines them into every page as `window.DatalogDynamicServices` (`_includes/meta/dynamic-services-config.html`), so a reader's browser can call the service. They must never hold a credential: the configuration validator stops the build when a key under `dynamic_services` names one (`secret`, `token`, `password`, `api_key`, `private_key`).

The Content Security Policy allows `connect-src` to the base URL's origin automatically ([content-security-policy.md](content-security-policy.md)).

## The API

Every path is under `<base_url>/<api_version>`. The service answers JSON.

### Discovery

```http
GET /v1/capabilities
```

```json
{
  "api_version": "1",
  "features": {
    "corrections": true,
    "contact": true,
    "comments": false
  }
}
```

The client fetches this once per page and remembers it. A service that reports another `api_version` than the site expects is a **version mismatch**: every feature shows "This site and its service expect different API versions" instead of failing on its own, which is how an incompatible front end and backend are noticed. A feature the service does not list is **unsupported**, and a feature turned off in `features` is **disabled**; both show as such, and neither is retried.

`GET /v1/health` is optional; the client exposes it as `client.health()` for a status page.

### Errors

A failed request answers with a status the client understands and, when it can, a body:

```json
{
  "error": {
    "code": "message_too_short",
    "message": "The message needs at least 20 characters.",
    "errors": { "message": "At least 20 characters." }
  },
  "request_id": "req_01J8…"
}
```

- `code` is the feature's own error code, for the widget and for logs.
- `message` is for the reader when the theme has nothing better.
- `errors`, on a `422`, maps field names to messages; the forms show them next to the fields.
- The `X-Request-Id` response header (or `request_id` in the body) is shown to the reader as "Reference: …" so a report can be traced without collecting anything about them.

### Writes

A write sends `Content-Type: application/json`, and `Idempotency-Key: <key>` when the feature gives one, so a retried submission is stored once. With `csrf_header` and `csrf_cookie` set, the client sends the cookie's value in the header on every write; that is only meaningful with `credentials: same-origin` or `include`.

## The client

`assets/js/dynamic-services/client.js`:

```js
import { getClient, ServiceError, describeError } from "./dynamic-services/client.js";

const client = getClient();                       // from window.DatalogDynamicServices
await client.feature("corrections");              // true, or a disabled / unsupported / version error
const { data, requestId } = await client.post(client.pathFor("corrections"), payload, {
  idempotencyKey: crypto.randomUUID()
});
```

- `request(method, path, { body, headers, idempotencyKey, signal, retries })`, with `get`, `post`, `patch` and `delete` as shorthands; `urlFor(path)` and `pathFor(feature)` build addresses.
- **Timeouts** through `AbortController`, `timeout_ms` per request.
- **Retries** for idempotent reads only (GET, HEAD, OPTIONS; twice), on a timeout, a network failure, a `429` or a `5xx`, after `Retry-After` when the service sends one and it is under ten seconds. A write is never retried unless the feature passes `retries`, since it carries an idempotency key or it does not.
- **Every failure is a `ServiceError`** with a `kind`: `disabled`, `unsupported`, `version`, `timeout`, `network`, `malformed` (a 2xx that is not JSON), `unauthorized` (401), `forbidden` (403), `not_found` (404), `conflict` (409), `invalid` (422, with `errors`), `rate_limited` (429, with `retryAfter` in seconds), `server` (5xx), `http` (anything else) and `aborted` (the feature's own signal). It also carries `status`, `code`, `requestId` and `retryable`.
- `describeError(error, labels)` gives the reader's message for a kind, with the request id appended; the labels come from `dynamic_services.errors` in `_data/i18n`.
- `capabilities()` and `feature(name)` do the discovery above.
- No fabricated data: when the service is down, the feature says so. The client never invents an answer.

`assets/js/dynamic-services/form-state.js` is the shared form behaviour the correction-report and contact forms use: `setFormState(form, state, message, fieldErrors)` sets `data-state` (`idle`, `pending`, `success`, `invalid`, `error`, `disabled`) and `aria-busy`, disables the submit button while pending, announces the message in `[data-form-status]` (`role="status"`, or `role="alert"` for a failure), and marks the fields a `422` names with `aria-invalid` and their `[data-error-for]` message, focusing the first. `readForm(form)` reads the fields; `showFailure(form, error, labels)` maps a `ServiceError` onto the form.

## The security boundary

- **No credential reaches the browser.** Database, mail and API credentials live on the server. The public settings above are the whole of what the site knows.
- **Authorization is the server's.** A privileged operation (moderation, deleting, listing private submissions) is enforced server-side, whatever the client sends.
- **CORS** is the backend's deployment policy: allow the site's origin and the methods and headers the client sends (`Content-Type`, `Idempotency-Key`, `X-CSRF-Token` when used); expose `X-Request-Id` and `Retry-After`.
- **CSRF protection is required** when a write endpoint authenticates with cookies (`credentials: include` or `same-origin`). The `csrf_header`/`csrf_cookie` pair is the double-submit pattern; a service without cookie authentication does not need it.
- **Rate limiting and abuse prevention are the server's** (per IP, per key, per article); it answers `429` with `Retry-After`, and the theme shows the wait.
- **User-generated content is untrusted** until the server has validated and sanitized it, and the theme renders what comes back as text, never as HTML.
- **Private data stays private.** A reporter's or a sender's email is never echoed to a page; correction reports and contact messages never flow into a public feed; nothing sensitive is written into the generated site.

## Observability

- The request id the service returns is shown to the reader and logged with the error, so a maintainer can find the request without the site collecting anything about the reader.
- `GET /v1/health` for a status page, when the service has one.
- Feature-specific error `code`s, for the widgets and for logs.
- Nothing here reports to an analytics product: the service layer is independent of GA4 or any other tracker.

## The reference service

[datalog-services](https://github.com/DiogoRibeiro7/datalog-services) is a backend for everything on this page: the seven features, the error model, idempotency keys, CSRF, rate limits and request ids. It runs as a Cloudflare Worker with a D1 database, and lives outside the gem, on its own release cycle. Its repository holds the contract's working documents:

| Document | What it is |
| --- | --- |
| [OpenAPI description](https://github.com/DiogoRibeiro7/datalog-services/blob/main/openapi/datalog-services.v1.yaml) | Every route, status, header and body of API version 1, kept equal to the service's routes by its tests |
| [Deployment guide](https://github.com/DiogoRibeiro7/datalog-services/blob/main/docs/deploy-cloudflare.md) | From an empty Cloudflare account to a base URL: secrets, the site's origin, the moderation account, mail, spam controls, retention and deletion, and the `_config.yml` to write afterwards |
| [Conformance suite](https://github.com/DiogoRibeiro7/datalog-services/blob/main/conformance/README.md) | Checks any backend at a base URL against the contract, validating each answer against the OpenAPI description, and reports what failed and why |

Once it is deployed, turning a feature on is configuration, with no code of the site's own:

```yaml
dynamic_services:
  base_url: https://datalog-services.your-subdomain.workers.dev
  features:
    comments: true
    reactions: true
    corrections: true
```

Comments also need the `api` provider, which [components.md: Comments](components.md#comments) shows.

What those documents leave to the site:

- **Another backend is welcome.** The theme knows only the HTTP. Serverless functions with MongoDB Atlas, a small Express app, or a mailing-list provider behind the subscription routes all fit. Write to the OpenAPI description, and run the conformance suite against a test deployment until it passes.
- **Keep `api_version` in step.** The service reports it in `capabilities`, and the site expects it in `dynamic_services.api_version`. Bump both together: an old site meeting a new service then shows the mismatch instead of breaking quietly.
- **Credentials stay in the backend's environment**, set as its provider's secrets, never in the repository or `_config.yml`: the database, the mail provider, the moderators' sign-in.

## Relationship to the feature issues

This contract is the transport. [Correction reports](components.md#correction-reports) (#256), the [contact form](components.md#contact-form) (#261), [comments](components.md#comments) (#253), [reactions](components.md#reactions) (#255), [Webmentions](components.md#webmentions) (#258) and [newsletter subscriptions](components.md#newsletter-subscriptions) (#254) define what they send and show. The [moderation inbox](moderation.md) (#257) is the one authenticated feature: it uses the same client with `credentials: include`, and its document says why the page itself protects nothing.
