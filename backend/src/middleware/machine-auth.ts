import { createHmac, timingSafeEqual } from "node:crypto";
import type { IncomingMessage } from "node:http";
import type { RequestHandler } from "express";

/**
 * Signed machine-to-machine requests between n8n and the backend (decision A5).
 *
 * Both directions use the same scheme (HMAC-SHA256 over a canonical string),
 * with a shared secret that lives only in the backend's and n8n's own secret
 * stores (never in git, never in Flutter):
 *
 *   X-DC-Timestamp: <unix seconds>
 *   X-DC-Nonce:     <16-200 chars, [A-Za-z0-9_-]>
 *   X-DC-Signature: sha256=<hex HMAC-SHA256(secret, canonical)>
 *
 *   canonical = timestamp + "." + nonce + "." + METHOD + "." + path + "." + rawBody
 *
 * Including method and path means a signature for one endpoint cannot be
 * replayed against another. Requests more than 5 minutes from the server clock
 * are rejected, and each nonce is accepted once (NonceStore; in production the
 * database function consume_automation_nonce, called as the automation
 * identity, so replay protection also holds across backend instances).
 *
 * This module only authenticates the caller as "n8n". The database call that
 * follows uses the automation identity's JWT (no privileged key, D-001).
 */

export const TIMESTAMP_HEADER = "x-dc-timestamp";
export const NONCE_HEADER = "x-dc-nonce";
export const SIGNATURE_HEADER = "x-dc-signature";
export const MAX_CLOCK_SKEW_SECONDS = 300;
export const MIN_SECRET_LENGTH = 32;

const NONCE_PATTERN = /^[A-Za-z0-9_-]{16,200}$/;
const SIGNATURE_PATTERN = /^sha256=[0-9a-f]{64}$/;

export type NonceResult = "ok" | "replayed";

export interface NonceStore {
  consume(nonce: string, signedAt: Date): Promise<NonceResult>;
}

export interface SignedRequestParts {
  timestamp: number;
  nonce: string;
  method: string;
  path: string;
  body: string;
}

export function canonicalString(parts: SignedRequestParts): string {
  return [
    String(parts.timestamp),
    parts.nonce,
    parts.method.toUpperCase(),
    parts.path,
    parts.body
  ].join(".");
}

export function computeSignature(secret: string, parts: SignedRequestParts): string {
  return "sha256=" + createHmac("sha256", secret).update(canonicalString(parts), "utf8").digest("hex");
}

/** Headers for an outgoing signed request (backend -> n8n). */
export function buildSignedHeaders(
  secret: string,
  request: { method: string; path: string; body: string; nonce: string; now?: Date }
): Record<string, string> {
  assertSecret(secret);
  const timestamp = Math.floor((request.now ?? new Date()).getTime() / 1000);

  return {
    [TIMESTAMP_HEADER]: String(timestamp),
    [NONCE_HEADER]: request.nonce,
    [SIGNATURE_HEADER]: computeSignature(secret, {
      timestamp,
      nonce: request.nonce,
      method: request.method,
      path: request.path,
      body: request.body
    })
  };
}

/**
 * Use as `express.json({ verify: captureRawBody })` on machine routes, so the
 * signature is checked against the exact bytes that were sent.
 */
export function captureRawBody(req: IncomingMessage, _res: unknown, buf: Buffer): void {
  (req as IncomingMessage & { rawBody?: Buffer }).rawBody = Buffer.from(buf);
}

export interface MachineAuthOptions {
  secret: string;
  nonceStore: NonceStore;
  now?: () => Date;
}

/** Express middleware that admits only correctly signed, fresh, unreplayed requests. */
export function machineAuth(options: MachineAuthOptions): RequestHandler {
  assertSecret(options.secret);
  const now = options.now ?? (() => new Date());

  return async (req, res, next) => {
    const reject = (status: number, message: string) => {
      res.status(status).json({ success: false, message });
    };

    const timestampHeader = req.get(TIMESTAMP_HEADER);
    const nonce = req.get(NONCE_HEADER);
    const signature = req.get(SIGNATURE_HEADER);

    if (!timestampHeader || !nonce || !signature) {
      return reject(401, "Signed request headers are required.");
    }

    if (!/^\d{1,12}$/.test(timestampHeader)) {
      return reject(401, "Invalid request timestamp.");
    }
    const timestamp = Number(timestampHeader);
    const skew = Math.abs(now().getTime() / 1000 - timestamp);
    if (skew > MAX_CLOCK_SKEW_SECONDS) {
      return reject(401, "Signed request is outside the 5 minute window.");
    }

    if (!NONCE_PATTERN.test(nonce) || !SIGNATURE_PATTERN.test(signature)) {
      return reject(401, "Invalid request signature.");
    }

    const rawBody = (req as typeof req & { rawBody?: Buffer }).rawBody;
    const expected = computeSignature(options.secret, {
      timestamp,
      nonce,
      method: req.method,
      path: req.originalUrl,
      body: rawBody ? rawBody.toString("utf8") : ""
    });

    const given = Buffer.from(signature, "utf8");
    const wanted = Buffer.from(expected, "utf8");
    if (given.length !== wanted.length || !timingSafeEqual(given, wanted)) {
      return reject(401, "Invalid request signature.");
    }

    try {
      const result = await options.nonceStore.consume(nonce, new Date(timestamp * 1000));
      if (result === "replayed") {
        return reject(409, "Replayed request.");
      }
    } catch {
      // Fail closed: without replay protection the request is not accepted.
      return reject(503, "Request verification is temporarily unavailable.");
    }

    next();
  };
}

/** In-memory nonce store: for tests and single-instance development only. */
export function createMemoryNonceStore(now: () => Date = () => new Date()): NonceStore {
  const seen = new Map<string, number>();

  return {
    async consume(nonce) {
      const cutoff = now().getTime() - 15 * 60 * 1000;
      for (const [key, at] of seen) {
        if (at < cutoff) seen.delete(key);
      }
      if (seen.has(nonce)) return "replayed";
      seen.set(nonce, now().getTime());
      return "ok";
    }
  };
}

/** Minimal shape of a Supabase client used by the database nonce store. */
export interface RpcClient {
  rpc(
    fn: string,
    args: Record<string, unknown>
  ): PromiseLike<{ error: { code?: string; message?: string } | null }>;
}

/**
 * Database-backed nonce store: consume_automation_nonce() (migration 000400).
 * `client` must be signed in as the automation identity (A5).
 */
export function createDatabaseNonceStore(client: RpcClient): NonceStore {
  return {
    async consume(nonce, signedAt) {
      const { error } = await client.rpc("consume_automation_nonce", {
        p_nonce: nonce,
        p_signed_at: signedAt.toISOString()
      });

      if (!error) return "ok";
      if (error.code === "DC409") return "replayed";
      throw new Error("Nonce verification failed.");
    }
  };
}

function assertSecret(secret: string): void {
  if (typeof secret !== "string" || secret.length < MIN_SECRET_LENGTH) {
    throw new Error(`The machine signing secret must be at least ${MIN_SECRET_LENGTH} characters.`);
  }
}
