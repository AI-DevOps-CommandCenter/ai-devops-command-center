import { readFileSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";

import { safeErrorMessage } from "../redact.js";
import { checkDelivery, invalidDelivery, logFailure, truncateText } from "./sender-utils.js";
import type { ClaimedDelivery, DeliveryResult, NotificationSender } from "./types.js";

// Sends push notifications to a user's registered devices with Firebase Cloud
// Messaging (firebase-admin). The device tokens come from
// claim_notification_deliveries().device_tokens (device_tokens of the user).
//
// FIREBASE_SERVICE_ACCOUNT_FILE  path of the service-account JSON (relative
//                                paths are read from the backend folder). The
//                                file is git-ignored and is never logged: only
//                                its project_id is used in messages.
//
// The FCM client is behind the PushMessaging interface so the sender can be
// tested without Firebase.

export interface PushMulticastMessage {
  tokens: string[];
  notification: { title: string; body: string };
  data: Record<string, string>;
  android: { priority: "high" };
}

export interface PushSendResponse {
  success: boolean;
  messageId?: string;
  error?: { code?: string };
}

export interface PushMessaging {
  sendEachForMulticast(message: PushMulticastMessage): Promise<{
    successCount: number;
    failureCount: number;
    responses: PushSendResponse[];
  }>;
}

export interface PushConfig {
  serviceAccountFile: string;
}

// FCM accepts up to 500 tokens per multicast call; a user has a few devices.
const MAX_TOKENS = 500;
const TITLE_MAX = 200;
const BODY_MAX = 1000;

// The token is no longer valid: another attempt can't reach this device.
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
  "messaging/mismatched-credential",
  "messaging/sender-id-mismatch"
]);

// Credential or project problems: permanent until the configuration is fixed.
const CONFIG_CODES = new Set([
  "messaging/invalid-credential",
  "app/invalid-credential",
  "messaging/third-party-auth-error",
  "messaging/authentication-error"
]);

export function loadPushConfig(env: NodeJS.ProcessEnv = process.env): PushConfig | null {
  const file = env.FIREBASE_SERVICE_ACCOUNT_FILE?.trim() ?? "";
  return file ? { serviceAccountFile: file } : null;
}

export function buildPushMessage(delivery: ClaimedDelivery, tokens: string[]): PushMulticastMessage {
  const data: Record<string, string> = { notification_id: delivery.notification_id, title: delivery.title };
  if (delivery.incident_id) data.incident_id = delivery.incident_id;
  return {
    tokens,
    notification: {
      title: truncateText(delivery.title.replace(/[\r\n]+/g, " ").trim(), TITLE_MAX),
      body: truncateText(delivery.message, BODY_MAX)
    },
    data,
    android: { priority: "high" }
  };
}

// Reads the service account and creates the FCM client. firebase-admin is
// loaded only when push is configured. Errors name the problem, never the
// file contents.
export async function createFirebaseMessaging(config: PushConfig, baseDir = process.cwd()): Promise<PushMessaging> {
  const path = isAbsolute(config.serviceAccountFile) ? config.serviceAccountFile : resolve(baseDir, config.serviceAccountFile);
  let account: { project_id?: unknown; client_email?: unknown; private_key?: unknown };
  try {
    account = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    throw new Error("Invalid push configuration: FIREBASE_SERVICE_ACCOUNT_FILE can't be read as JSON.");
  }
  if (typeof account.project_id !== "string" || typeof account.client_email !== "string" || typeof account.private_key !== "string") {
    throw new Error("Invalid push configuration: the service-account file has no project_id, client_email or private_key.");
  }

  const { initializeApp, cert, getApps } = await import("firebase-admin/app");
  const { getMessaging } = await import("firebase-admin/messaging");
  const name = "dc-push";
  const app = getApps().find((a) => a.name === name) ??
    initializeApp({ credential: cert(account as Parameters<typeof cert>[0]), projectId: account.project_id }, name);
  return getMessaging(app) as unknown as PushMessaging;
}

export class PushSender implements NotificationSender {
  readonly channel = "push" as const;

  constructor(private readonly messaging: PushMessaging) {}

  async send(delivery: ClaimedDelivery): Promise<DeliveryResult> {
    const invalid = checkDelivery(this.channel, delivery);
    if (invalid) return invalid;

    const tokens = [...new Set((delivery.device_tokens ?? []).filter((t) => typeof t === "string" && t.length > 0))].slice(0, MAX_TOKENS);
    if (tokens.length === 0) {
      return invalidDelivery(this.channel, "the user has no registered device.");
    }

    try {
      const result = await this.messaging.sendEachForMulticast(buildPushMessage(delivery, tokens));
      if (result.successCount > 0) {
        const first = result.responses.find((r) => r.success && r.messageId);
        if (result.failureCount > 0) logFailure(this.channel, delivery.delivery_id, `partial (${result.failureCount}/${tokens.length} devices)`);
        return { status: "sent", providerMessageId: first?.messageId ? safeErrorMessage(first.messageId, 200) : null };
      }
      const codes = result.responses.map((r) => r.error?.code ?? "unknown");
      const permanent = codes.every((c) => DEAD_TOKEN_CODES.has(c) || CONFIG_CODES.has(c));
      logFailure(this.channel, delivery.delivery_id, permanent ? "rejected" : "unavailable");
      return {
        status: "failed",
        errorMessage: safeErrorMessage(`Push: FCM rejected all ${tokens.length} device(s): ${[...new Set(codes)].join(", ")}.`),
        retryable: !permanent
      };
    } catch (error) {
      const code = typeof error === "object" && error !== null && "code" in error ? String((error as { code: unknown }).code) : "unknown";
      logFailure(this.channel, delivery.delivery_id, code);
      return {
        status: "failed",
        errorMessage: safeErrorMessage(`Push: FCM request failed (${code}).`, 200),
        retryable: !CONFIG_CODES.has(code)
      };
    }
  }
}
