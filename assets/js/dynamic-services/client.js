/**
 * @fileoverview The dynamic-services client (#259): the one way the theme's
 * optional backend-backed features (correction reports, contact, comments,
 * reactions, subscriptions, Webmentions) call a site's API. It resolves the
 * base URL and API version, sends and reads JSON, times requests out,
 * retries idempotent reads only, turns every failure into one ServiceError
 * shape, and discovers what the service offers before a feature relies on
 * it. The site stays static: the client runs in the browser with the public
 * settings in window.DatalogDynamicServices and never a credential.
 * @module dynamic-services/client
 */

export const DEFAULT_TIMEOUT = 8000;
export const MAX_RETRY_AFTER = 10;
export const CAPABILITIES_PATH = "/capabilities";
export const HEALTH_PATH = "/health";

const STATUS_KINDS = {
  401: "unauthorized",
  403: "forbidden",
  404: "not_found",
  409: "conflict",
  422: "invalid",
  429: "rate_limited"
};
const RETRYABLE = new Set(["timeout", "network", "rate_limited", "server"]);
const IDEMPOTENT = new Set(["GET", "HEAD", "OPTIONS"]);

/**
 * What a reader sees when a message for a kind is not configured.
 * @type {Object.<string, string>}
 */
export const DEFAULT_LABELS = {
  disabled: "This feature is not set up on this site.",
  unsupported: "The service behind this site does not offer this feature.",
  version: "This site and its service expect different API versions.",
  timeout: "The service took too long to answer. Try again in a moment.",
  network: "The service could not be reached. Check your connection and try again.",
  malformed: "The service answered in a way this site could not read.",
  unauthorized: "You need to sign in for this.",
  forbidden: "You are not allowed to do this.",
  not_found: "The service has nothing at that address.",
  conflict: "This was already done, or something changed in the meantime.",
  invalid: "Some of what you entered needs a correction.",
  rate_limited: "Too many requests for now. Please wait a little and try again.",
  server: "The service ran into a problem. Try again later.",
  http: "The service refused the request.",
  aborted: "The request was cancelled.",
  reference: "Reference: {{id}}"
};

/**
 * Every failure, whatever its source, as one object: a `kind` a feature can
 * switch on, the HTTP status and the backend's error code when there is one,
 * the request id the backend returned, `retryAfter` in seconds for a 429,
 * field `errors` for a 422, and whether a retry could help.
 */
export class ServiceError extends Error {
  constructor(kind, message, details = {}) {
    super(message);
    this.name = "ServiceError";
    this.kind = kind;
    this.status = details.status ?? null;
    this.code = details.code ?? null;
    this.requestId = details.requestId ?? null;
    this.retryAfter = details.retryAfter ?? null;
    this.errors = details.errors ?? null;
    this.expected = details.expected ?? null;
    this.actual = details.actual ?? null;
    this.retryable = details.retryable ?? RETRYABLE.has(kind);
  }
}

/**
 * The public settings the site inlines (_includes/meta/dynamic-services-config.html).
 * @param {Object} [win]
 * @returns {Object}
 */
export function readConfig(win = globalThis) {
  const config = win.DatalogDynamicServices;
  return config && typeof config === "object" ? config : {};
}

/**
 * "1", "v1" or 1 as the path segment "v1".
 * @param {string|number} [value]
 * @returns {string}
 */
export function versionSegment(value) {
  const raw = String(value ?? "1").trim() || "1";
  return /^v/i.test(raw) ? `v${raw.slice(1)}` : `v${raw}`;
}

/**
 * A Retry-After header as seconds, whether it is a delay or a date.
 * @param {string|null} value
 * @param {number} [now]
 * @returns {number|null}
 */
export function parseRetryAfter(value, now = Date.now()) {
  if (!value) {
    return null;
  }
  const seconds = Number(value);
  if (Number.isFinite(seconds)) {
    return Math.max(0, seconds);
  }
  const at = Date.parse(value);
  return Number.isNaN(at) ? null : Math.max(0, Math.round((at - now) / 1000));
}

function readCookie(doc, name) {
  if (!doc || typeof doc.cookie !== "string") {
    return null;
  }
  const entry = doc.cookie.split(";").map((part) => part.trim()).find((part) => part.startsWith(`${name}=`));
  return entry ? decodeURIComponent(entry.slice(name.length + 1)) : null;
}

function errorFrom(response, data, requestId) {
  const status = response.status;
  const kind = STATUS_KINDS[status] || (status >= 500 ? "server" : "http");
  const detail = data && typeof data === "object" ? data.error || data : {};
  const message = (detail && (detail.message || detail.title)) || `The service answered ${status}`;
  return new ServiceError(kind, message, {
    status,
    code: (detail && detail.code) || null,
    requestId,
    retryAfter: parseRetryAfter(response.headers.get("Retry-After")),
    errors: (detail && detail.errors) || null
  });
}

/**
 * A message for a reader, from a kind's label; the request id, when the
 * backend gave one, follows it so a report can be traced.
 * @param {ServiceError|Error} error
 * @param {Object.<string, string>} [labels] - Overrides by kind, plus `reference` with {{id}}
 * @returns {string}
 */
export function describeError(error, labels = {}) {
  const kind = error && error.kind ? error.kind : "http";
  const text = labels[kind] || DEFAULT_LABELS[kind] || labels.http || DEFAULT_LABELS.http;
  if (error && error.requestId) {
    const reference = labels.reference || DEFAULT_LABELS.reference;
    return `${text} ${reference.split("{{id}}").join(error.requestId)}`;
  }
  return text;
}

/**
 * @param {Object} [config] - The public settings; defaults to window.DatalogDynamicServices
 * @param {Object} [deps] - `fetch`, `delay` and `document`, replaceable in tests
 * @returns {Object} The client
 */
export function createClient(config = readConfig(), deps = {}) {
  const fetchImpl = deps.fetch || ((...args) => globalThis.fetch(...args));
  const wait = deps.delay || ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  const doc = deps.document === undefined ? globalThis.document : deps.document;
  const base = String(config.base_url || "").replace(/\/+$/, "");
  const version = versionSegment(config.api_version);
  const timeout = Number(config.timeout_ms) > 0 ? Number(config.timeout_ms) : DEFAULT_TIMEOUT;
  const credentials = ["omit", "same-origin", "include"].includes(config.credentials) ? config.credentials : "omit";
  const features = config.features && typeof config.features === "object" ? config.features : {};
  const paths = config.paths && typeof config.paths === "object" ? config.paths : {};
  const enabled = base !== "";
  let discovery = null;

  /** The full URL of a path under the versioned base, or a URL given whole. */
  function urlFor(path) {
    if (/^https?:\/\//i.test(path)) {
      return path;
    }
    return `${base}/${version}${path.startsWith("/") ? path : `/${path}`}`;
  }

  /** A feature's path: the site's override, else /<feature>. */
  function pathFor(feature) {
    const override = paths[feature];
    return typeof override === "string" && override !== "" ? override : `/${feature}`;
  }

  async function attempt(method, path, options) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    let cancelled = false;
    if (options.signal) {
      options.signal.addEventListener("abort", () => {
        cancelled = true;
        controller.abort();
      });
    }
    const headers = { Accept: "application/json", ...(options.headers || {}) };
    const init = { method, headers, credentials, signal: controller.signal };
    if (options.body !== undefined) {
      headers["Content-Type"] = "application/json";
      init.body = JSON.stringify(options.body);
    }
    if (options.idempotencyKey) {
      headers["Idempotency-Key"] = options.idempotencyKey;
    }
    if (!IDEMPOTENT.has(method) && config.csrf_header && config.csrf_cookie) {
      const token = readCookie(doc, config.csrf_cookie);
      if (token) {
        headers[config.csrf_header] = token;
      }
    }

    let response;
    let text;
    try {
      response = await fetchImpl(urlFor(path), init);
      text = await response.text();
    } catch (error) {
      if (cancelled) {
        throw new ServiceError("aborted", "The request was cancelled", { retryable: false });
      }
      if (controller.signal.aborted) {
        throw new ServiceError("timeout", `No answer within ${timeout} ms`);
      }
      throw new ServiceError("network", "The service could not be reached");
    } finally {
      clearTimeout(timer);
    }

    const requestId = response.headers.get("X-Request-Id") || null;
    let data = null;
    if (text) {
      try {
        data = JSON.parse(text);
      } catch (error) {
        if (response.ok) {
          throw new ServiceError("malformed", "The service did not answer with JSON", {
            status: response.status,
            requestId,
            retryable: false
          });
        }
      }
    }
    if (!response.ok) {
      throw errorFrom(response, data, requestId);
    }
    return { data, status: response.status, requestId, headers: response.headers };
  }

  /**
   * One request, retried on a timeout, a network failure, a 429 or a 5xx
   * when the method is idempotent (or `retries` says so) and the wait is short.
   * @param {string} method
   * @param {string} path - Under the versioned base, or a whole URL
   * @param {Object} [options] - `body`, `headers`, `idempotencyKey`, `signal`, `retries`
   * @returns {Promise<{data: *, status: number, requestId: string|null, headers: Headers}>}
   */
  async function request(method, path, options = {}) {
    if (!enabled) {
      throw new ServiceError("disabled", "Dynamic services are not configured for this site", { retryable: false });
    }
    const verb = String(method).toUpperCase();
    const retries = options.retries ?? (IDEMPOTENT.has(verb) ? 2 : 0);
    let tries = 0;
    for (;;) {
      try {
        return await attempt(verb, path, options);
      } catch (error) {
        const tooLong = error.retryAfter !== null && error.retryAfter > MAX_RETRY_AFTER;
        if (!(error instanceof ServiceError) || !error.retryable || tries >= retries || tooLong) {
          throw error;
        }
        tries += 1;
        await wait(error.retryAfter !== null ? error.retryAfter * 1000 : 300 * tries);
      }
    }
  }

  /**
   * What the service offers, from GET /<version>/capabilities, fetched once.
   * A service speaking another API version is a `version` error, so the
   * mismatch shows instead of each widget failing on its own.
   * @returns {Promise<Object>}
   */
  function capabilities() {
    if (!discovery) {
      discovery = request("GET", CAPABILITIES_PATH)
        .then(({ data }) => {
          const actual = String((data && data.api_version) ?? "").replace(/^v/i, "");
          const expected = version.slice(1);
          if (actual !== expected) {
            throw new ServiceError("version", `The service speaks API version ${actual || "unknown"}; this site expects ${expected}`, {
              expected,
              actual,
              retryable: false
            });
          }
          return data;
        })
        .catch((error) => {
          discovery = null;
          throw error;
        });
    }
    return discovery;
  }

  /**
   * Whether a feature can be used: on in the site's settings and offered by
   * the service. Resolves true, or rejects with a `disabled`, `unsupported`
   * or `version` error.
   * @param {string} name
   * @returns {Promise<boolean>}
   */
  async function feature(name) {
    if (!enabled) {
      throw new ServiceError("disabled", "Dynamic services are not configured for this site", { retryable: false });
    }
    if (features[name] === false) {
      throw new ServiceError("disabled", `${name} is off in this site's settings`, { retryable: false });
    }
    const found = await capabilities();
    if (!found || !found.features || !found.features[name]) {
      throw new ServiceError("unsupported", `The service does not offer ${name}`, { retryable: false });
    }
    return true;
  }

  return {
    enabled,
    base,
    version,
    timeout,
    credentials,
    urlFor,
    pathFor,
    request,
    get: (path, options) => request("GET", path, options),
    post: (path, body, options = {}) => request("POST", path, { ...options, body }),
    patch: (path, body, options = {}) => request("PATCH", path, { ...options, body }),
    delete: (path, options) => request("DELETE", path, options),
    capabilities,
    feature,
    health: () => request("GET", HEALTH_PATH).then(({ data }) => data)
  };
}

let shared = null;

/**
 * The client every feature shares, built from the page's public settings.
 * @returns {Object}
 */
export function getClient() {
  if (!shared) {
    shared = createClient();
  }
  return shared;
}

/** Forgets the shared client, for tests. */
export function resetClient() {
  shared = null;
}
