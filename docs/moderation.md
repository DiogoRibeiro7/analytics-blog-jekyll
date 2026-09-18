# Moderation Inbox

Once a site hosts its own [comments](components.md#comments) and takes [correction reports](components.md#correction-reports), someone has to read what arrives. The moderation inbox is one page that lists it, pending comments, comments flagged as spam, correction reports, abuse reports on published comments, and lets a moderator act, without querying a database by hand. It is a contract and an optional admin page; the store behind it is the backend's choice.

Newsletter subscribers are deliberately not here: they are more sensitive personal data with their own rules, and their management belongs to the mailing backend.

## The Security Boundary

**A static site cannot hold an admin secret, so this page protects nothing.** Everything DataLog publishes, the page, its script, its settings, is public. There is no password in the page, no token in `_config.yml`, and no check in the browser that means anything: a check the visitor's browser runs is a check the visitor controls.

Authentication and authorization belong to the moderation service, or to an identity-aware proxy in front of it (Cloudflare Access, an OAuth2 proxy, the hosting provider's own authentication), **on every request**:

- The browser sends the session it was given, a cookie, with `credentials: include`. The page never sees or stores it.
- Not signed in: the service answers `401`, and the page says so and links `moderation.sign_in_url`. Signed in but not a moderator: `403`, and the page says that. Neither answer carries any item.
- The build stops when a key under `moderation` (or `dynamic_services`) is named like a secret (`password`, `token`, `secret`, `api_key`, `private_key`): those settings reach every visitor.
- The page is `noindex,nofollow`, out of the sitemap, the search index and the navigation. That is tidiness, not protection: anyone can open it, and what they get is the sign-in notice.

Because the session is a cookie sent cross-site, the service also needs what any cookie-authenticated API needs:

- CORS with credentials: `Access-Control-Allow-Origin` set to the site's exact origin (never `*`) and `Access-Control-Allow-Credentials: true`.
- Protection against cross-site request forgery on the action route: a `SameSite=Lax` or `Strict` session cookie where the site and the service share a registrable domain, and otherwise a CSRF token, which the client sends when `dynamic_services.csrf_header` and `csrf_cookie` are set ([dynamic-services.md](dynamic-services.md#writes)).
- A short session and a moderator list kept on the server.

## Setup

```yaml
moderation:
  enabled: true                   # off by default
  endpoint: ""                    # only when the moderation API lives apart from dynamic_services.base_url
  credentials: include            # how the browser sends the moderator's session: include, same-origin or omit
  sign_in_url: https://api.example.org/auth/login   # linked when the service answers 401
```

and a page, anywhere, not linked from the navigation:

```yaml
---
layout: page
title: Moderation
permalink: /admin/moderation/
robots: noindex,nofollow
sitemap: false
exclude_from_search: true
nav_exclude: true
moderation_inbox: true
---
```

The inbox talks to `moderation.endpoint` when it is set, and otherwise to `dynamic_services.base_url` (unless `dynamic_services.features.moderation` is `false`). An endpoint of its own is added to the Content Security Policy's `connect-src` on the inbox page only. With `enabled` not `true`, or without an API to talk to, the page says moderation is not set up.

## The Contract

All under the versioned base, all authenticated by the service.

### Listing

`GET /v1/moderation/items`, with any of `type` (`comment`, `correction`, `abuse`), `status`, `path`, `category` (a correction category), `since` (a date), `q` (text) and `cursor`. **Without `status` the service returns the queue**: what awaits a decision, pending comments, new, reviewed and accepted correction reports, open abuse reports.

```json
{
  "items": [
    {
      "id": "c_81",
      "type": "comment",
      "status": "pending",
      "created_at": "2026-09-18T09:12:00Z",
      "path": "/2024/04/05/sql-optimization-guide/",
      "title": "SQL Optimization Playbook",
      "author": { "name": "Alice", "email": "alice@example.org" },
      "body": "Does the clustering step hold for skewed keys?",
      "context": { "parent": { "author": { "name": "Bob" }, "body": "It did for us." } },
      "history": []
    },
    {
      "id": "r_17",
      "type": "correction",
      "status": "new",
      "created_at": "2026-09-17T16:40:00Z",
      "path": "/2024/04/05/sql-optimization-guide/",
      "category": "code",
      "section": "optimization-checklist",
      "quote": "Cluster the fact table on purchase_ts",
      "message": "The table clusters on customer_id.",
      "author": { "email": "reader@example.org" },
      "history": [{ "action": "reviewed", "at": "2026-09-17T18:00:00Z", "moderator": "diogo", "note": "Checking the DDL." }]
    }
  ],
  "next_cursor": "eyJvIjoyMH0"
}
```

An `abuse` item is a reader's report on a published comment: `reason`, and the comment as `context.parent`. `next_cursor`, when present, continues the listing. The inbox renders every field as text; a `path` is linked only when it is a path on the site, a resolution link only when it is `http(s)`.

### Acting

`POST /v1/moderation/items/<id>/actions` with an `Idempotency-Key`:

```json
{ "action": "resolve", "note": "Fixed the DDL and the prose.", "link": "https://github.com/example/site/pull/42" }
```

| Type | From | Actions | Leaves the item |
| --- | --- | --- | --- |
| `comment` | `pending` | `approve`, `spam`, `delete` | `approved`, `spam`, `deleted` |
| `comment` | `approved` | `hide`, `spam`, `delete` | `hidden`, `spam`, `deleted` |
| `comment` | `spam`, `hidden` | `approve`, `delete` | `approved`, `deleted` |
| `correction` | `new` | `reviewed`, `accept`, `reject` | `reviewed`, `accepted`, `rejected` |
| `correction` | `reviewed` | `accept`, `reject` | `accepted`, `rejected` |
| `correction` | `accepted` | `resolve` (with `link`), `reject` | `resolved`, `rejected` |
| `abuse` | `open` | `dismiss`, `hide`, `delete` (of the reported comment) | `dismissed`, `hidden`, `deleted` |

The service answers `200` with `{ "item": { … } }`, the item as it now stands, history included. The inbox offers only the actions of the table, but the service is what enforces them: it answers `409` for an action the item's status does not allow (someone else acted first), `422` for a missing `link`, `401`/`403` as above, and `5xx` when it fails. **Nothing changes on the page unless the service says it did**: a failure leaves the item as it was, with the reason next to it and its buttons working again.

### Audit

Every action is recorded by the service with the action, the time, the moderator's identity **as the service knows it** (never a name the browser supplies) and the note, and comes back as the item's `history`. For a correction, `resolve` carries the address of the issue, pull request or revision that settled it, so a published [revision](components.md#revision-history) can be traced to the report that prompted it.

## Reference Deployment

One shape, none of it required: the serverless functions of [dynamic-services.md](dynamic-services.md#reference-deployment-serverless-functions-and-mongodb-atlas) plus two routes behind the provider's authentication.

```js
// api/v1/moderation/items.js
export default async function handler(request, response) {
  cors(request, response);                       // exact origin + Access-Control-Allow-Credentials: true
  const moderator = await session(request);      // the provider's session, or the identity proxy's signed header
  if (!moderator) return response.status(401).json({ error: { code: "unauthorized" } });
  if (!MODERATORS.includes(moderator.id)) return response.status(403).json({ error: { code: "forbidden" } });

  const { type, status, path, category, since, q, cursor } = request.query;
  const filter = status ? { status } : { status: { $in: ["pending", "new", "reviewed", "accepted", "open"] } };
  // … type, path, category, since, q narrow the filter; cursor pages it
  const items = await db.collection("moderation_view").find(filter).sort({ created_at: -1 }).limit(20).toArray();
  return response.status(200).json({ items: items.map(publicShape), next_cursor: nextCursor(items) });
}
```

```js
// api/v1/moderation/items/[id]/actions.js
const allowed = ALLOWED[item.type]?.[item.status] ?? [];
if (!allowed.includes(action)) return response.status(409).json({ error: { code: "conflict" } });
await db.collection(collectionOf(item.type)).updateOne(
  { _id: item._id, status: item.status },                      // the status it had: two moderators cannot both win
  { $set: { status: RESULT[action], ...(link && { resolution: { url: link } }) },
    $push: { history: { action, at: new Date(), moderator: moderator.id, note } } }
);
```

`moderation_view` can be a MongoDB view over the `comments`, `corrections` and `abuse_reports` collections, a SQL `UNION`, or three queries merged in the function. `MODERATORS` and every credential live in the function's environment. MongoDB is not required.

## The Page

The inbox carries `data-state`: `loading`, `loaded`, `empty`, `error`, `unauthorized` (with the sign-in link), `forbidden` and `disabled` (no API, the feature off or not offered, or an API version mismatch). Each item has its own status line for the action in progress and its outcome; after an action an item that no longer matches the filter leaves the list, and the outcome is announced. Filters: what, status (the queue by default), report category, page path, since, text.

```scss
.moderation { }                    // the inbox; [data-state="…"]
.moderation__boundary, .moderation__filters, .moderation__status, .moderation__sign-in, .moderation__list { }
.moderation-item { }               // one item; .moderation-item--comment, --correction, --abuse; [aria-busy]
.moderation-item__meta, .moderation-item__type, .moderation-item__status, .moderation-item__body, .moderation-item__history, .moderation-item__actions, .moderation-item__message { }
```
