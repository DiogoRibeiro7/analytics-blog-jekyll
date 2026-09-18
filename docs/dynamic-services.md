# Dynamic Services

A DataLog site is static and deploys to GitHub Pages. Some features a research site wants (correction reports, a contact form, comments, reactions, subscriptions, Webmentions) need a server. This document is the contract between the site and that server: one configuration model, one browser client, one error model, one security boundary. Every feature that talks to a backend uses it; none ships a fetch wrapper of its own.

The contract is backend- and database-agnostic. The reference deployment at the end uses serverless functions and MongoDB Atlas, but anything that answers the same HTTP is fine.

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

## Reference deployment: serverless functions and MongoDB Atlas

One way to run the service, with nothing in it the contract depends on. A Cloudflare Worker, a Vercel or Netlify function, or a small Express app all fit; the shape below is a Vercel-style handler.

```js
// api/v1/capabilities.js
export default function handler(request, response) {
  cors(request, response);
  response.status(200).json({
    api_version: "1",
    features: { corrections: true, contact: true, comments: false }
  });
}
```

```js
// api/v1/corrections.js
import { MongoClient } from "mongodb";
import { randomUUID } from "node:crypto";

const client = new MongoClient(process.env.MONGODB_URI);   // the credential lives here, never in the site

export default async function handler(request, response) {
  cors(request, response);
  const requestId = randomUUID();
  response.setHeader("X-Request-Id", requestId);
  if (request.method === "OPTIONS") return response.status(204).end();
  if (request.method !== "POST") return response.status(405).end();

  if (await tooMany(request)) {
    response.setHeader("Retry-After", "60");
    return response.status(429).json({ error: { code: "rate_limited", message: "Too many reports." }, request_id: requestId });
  }

  const report = validateCorrection(request.body);          // shape, lengths, allowed categories, no HTML
  if (report.errors) {
    return response.status(422).json({ error: { code: "invalid", message: "Check the fields.", errors: report.errors }, request_id: requestId });
  }

  const key = request.headers["idempotency-key"];
  const reports = client.db("datalog").collection("corrections");
  await reports.updateOne(
    { idempotency_key: key || requestId },
    { $setOnInsert: { ...report.value, idempotency_key: key || requestId, received_at: new Date(), status: "new" } },
    { upsert: true }
  );
  return response.status(202).json({ status: "received", request_id: requestId });
}

function cors(request, response) {
  response.setHeader("Access-Control-Allow-Origin", "https://example.org");   // the site's origin, not *
  response.setHeader("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS");   // PATCH and DELETE for subscriptions
  response.setHeader("Access-Control-Allow-Headers", "Content-Type, Idempotency-Key");
  response.setHeader("Access-Control-Expose-Headers", "X-Request-Id, Retry-After");
}
```

Notes for that deployment:

- `MONGODB_URI` and any mail or GitHub token are environment variables of the function, set in the provider's dashboard, never in the repository or `_config.yml`.
- Rate limiting: the provider's own (Cloudflare, Vercel firewall) or a counter collection keyed by IP hash and hour.
- A moderation queue is a collection with a `status` field and an admin route behind the provider's authentication; readers never see it.
- Keep `api_version` in the capabilities answer in step with the site's `dynamic_services.api_version`; bump both together, and an old site meeting a new service shows the mismatch instead of breaking quietly.

## Relationship to the feature issues

This contract is the transport. [Correction reports](components.md#correction-reports) (#256), the [contact form](components.md#contact-form) (#261), [comments](components.md#comments) (#253), [reactions](components.md#reactions) (#255), [Webmentions](components.md#webmentions) (#258) and [newsletter subscriptions](components.md#newsletter-subscriptions) (#254) define what they send and show; moderation (#257) would do the same, with its own paths, payloads and error codes, and no client of its own.
