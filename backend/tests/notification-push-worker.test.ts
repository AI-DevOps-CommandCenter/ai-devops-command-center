import { describe, expect, it, vi } from "vitest";

import { buildPushMessage, PushSender, type PushMessaging } from "../src/integrations/notifications/push.sender.js";
import { createAllNotificationSenders, isPushConfigured } from "../src/integrations/notifications/index.js";
import type { ClaimedDelivery, NotificationSender } from "../src/integrations/notifications/types.js";
import { processNotificationDeliveryBatch } from "../src/workers/notification-delivery-processor.js";
import {
  createNotificationDispatcher,
  notificationWorkerOptionsFromEnv,
  sendWithSenders,
  startNotificationWorker
} from "../src/workers/notification-dispatcher.js";
import type { NotificationDelivery } from "../src/services/notification-delivery.service.js";

function delivery(overrides: Partial<ClaimedDelivery> = {}): NotificationDelivery {
  return {
    delivery_id: "d-1",
    channel: "push",
    attempt_count: 1,
    notification_id: "n-1",
    user_id: "u-1",
    incident_id: "11111111-1111-4111-8111-111111111111",
    title: "Approval needed",
    message: "Restart checkout-api is waiting for approval.",
    recipient_email: null,
    device_tokens: ["token-a", "token-b"],
    ...overrides
  } as NotificationDelivery;
}

type FcmResponse = { success: boolean; messageId?: string; error?: { code?: string } };

function messaging(responses: FcmResponse[]) {
  const successCount = responses.filter((r) => r.success).length;
  return {
    sendEachForMulticast: vi.fn().mockResolvedValue({ successCount, failureCount: responses.length - successCount, responses })
  } satisfies PushMessaging;
}

describe("push sender (FCM)", () => {
  it("builds a multicast message with notification text and string data only", () => {
    const m = buildPushMessage(delivery({ title: "Line one\r\nline two" }), ["t"]);
    expect(m.tokens).toEqual(["t"]);
    expect(m.notification).toEqual({ title: "Line one line two", body: "Restart checkout-api is waiting for approval." });
    expect(m.data).toEqual({ notification_id: "n-1", title: "Line one\r\nline two", incident_id: "11111111-1111-4111-8111-111111111111" });
    expect(Object.values(m.data).every((v) => typeof v === "string")).toBe(true);
    expect(m.android.priority).toBe("high");
  });

  it("leaves incident_id out of data when the notification has none", () => {
    expect(buildPushMessage(delivery({ incident_id: null }), ["t"]).data).not.toHaveProperty("incident_id");
  });

  it("sends to every unique device token and returns the first message id", async () => {
    const fcm = messaging([{ success: true, messageId: "projects/p/messages/1" }, { success: true, messageId: "projects/p/messages/2" }]);
    const result = await new PushSender(fcm).send(delivery({ device_tokens: ["token-a", "token-b", "token-a", ""] }));
    expect(fcm.sendEachForMulticast).toHaveBeenCalledWith(expect.objectContaining({ tokens: ["token-a", "token-b"] }));
    expect(result).toEqual({ status: "sent", providerMessageId: "projects/p/messages/1" });
  });

  it("counts a delivery as sent when at least one device got it", async () => {
    const fcm = messaging([{ success: false, error: { code: "messaging/registration-token-not-registered" } }, { success: true, messageId: "m-2" }]);
    expect(await new PushSender(fcm).send(delivery())).toEqual({ status: "sent", providerMessageId: "m-2" });
  });

  it("fails permanently without calling FCM when the user has no device", async () => {
    const fcm = messaging([]);
    const result = await new PushSender(fcm).send(delivery({ device_tokens: [] }));
    expect(fcm.sendEachForMulticast).not.toHaveBeenCalled();
    expect(result).toMatchObject({ status: "failed", retryable: false, errorMessage: "Push: the user has no registered device." });
  });

  it("is permanent when every token is dead, retryable when FCM is unavailable", async () => {
    const dead = messaging([
      { success: false, error: { code: "messaging/registration-token-not-registered" } },
      { success: false, error: { code: "messaging/invalid-registration-token" } }
    ]);
    expect(await new PushSender(dead).send(delivery())).toMatchObject({ status: "failed", retryable: false });
    const down = messaging([
      { success: false, error: { code: "messaging/unavailable" } },
      { success: false, error: { code: "messaging/registration-token-not-registered" } }
    ]);
    expect(await new PushSender(down).send(delivery())).toMatchObject({ status: "failed", retryable: true });
  });

  it("turns a thrown FCM error into a safe failure without the token or message text", async () => {
    const fcm = { sendEachForMulticast: vi.fn().mockRejectedValue(Object.assign(new Error("secret token-a leaked"), { code: "app/network-error" })) };
    const result = await new PushSender(fcm).send(delivery());
    expect(result).toEqual({ status: "failed", errorMessage: "Push: FCM request failed (app/network-error).", retryable: true });
    const auth = { sendEachForMulticast: vi.fn().mockRejectedValue(Object.assign(new Error("x"), { code: "app/invalid-credential" })) };
    expect(await new PushSender(auth).send(delivery())).toMatchObject({ retryable: false });
  });

  it("rejects a delivery for another channel", async () => {
    const fcm = messaging([]);
    expect(await new PushSender(fcm).send(delivery({ channel: "email" }))).toMatchObject({ status: "failed", retryable: false });
    expect(fcm.sendEachForMulticast).not.toHaveBeenCalled();
  });
});

describe("sender registry", () => {
  it("adds push only when FIREBASE_SERVICE_ACCOUNT_FILE is set", async () => {
    const fcm = messaging([]);
    expect([...(await createAllNotificationSenders({}, { pushMessaging: fcm })).keys()]).toEqual([]);
    const senders = await createAllNotificationSenders({ FIREBASE_SERVICE_ACCOUNT_FILE: "secrets/x.json" }, { pushMessaging: fcm });
    expect(senders.get("push")).toBeInstanceOf(PushSender);
    expect(isPushConfigured({ FIREBASE_SERVICE_ACCOUNT_FILE: " " })).toBe(false);
  });

  it("fails with a message that names the variable, not the file contents", async () => {
    await expect(createAllNotificationSenders({ FIREBASE_SERVICE_ACCOUNT_FILE: "secrets/does-not-exist.json" }))
      .rejects.toThrow("FIREBASE_SERVICE_ACCOUNT_FILE can't be read as JSON.");
  });
});

describe("worker retry policy", () => {
  const deps = (d: NotificationDelivery, result: unknown) => ({
    claim: vi.fn().mockResolvedValue([d]),
    send: vi.fn().mockResolvedValue(result),
    record: vi.fn().mockResolvedValue(undefined)
  });

  it("leaves a retryable failure pending (not recorded) below maxAttempts", async () => {
    const d = deps(delivery({ attempt_count: 2 }), { status: "failed", errorMessage: "Push: x", retryable: true });
    expect(await processNotificationDeliveryBatch(d, 50, 5)).toEqual({ claimed: 1, succeeded: 0, failed: 0, retrying: 1 });
    expect(d.record).not.toHaveBeenCalled();
  });

  it("records the failure once attempt_count reaches maxAttempts", async () => {
    const d = deps(delivery({ attempt_count: 5 }), { status: "failed", errorMessage: "Push: FCM unavailable.", retryable: true });
    expect(await processNotificationDeliveryBatch(d, 50, 5)).toEqual({ claimed: 1, succeeded: 0, failed: 1, retrying: 0 });
    expect(d.record).toHaveBeenCalledWith("d-1", "failed", null, "Push: FCM unavailable.");
  });

  it("records a permanent failure at once", async () => {
    const d = deps(delivery({ attempt_count: 1 }), { status: "failed", errorMessage: "Push: the user has no registered device.", retryable: false });
    await processNotificationDeliveryBatch(d, 50, 5);
    expect(d.record).toHaveBeenCalledWith("d-1", "failed", null, "Push: the user has no registered device.");
  });

  it("treats a channel without a sender as retryable", async () => {
    const send = sendWithSenders(new Map());
    expect(await send(delivery({ channel: "slack" }))).toEqual({ status: "failed", errorMessage: "No slack sender is configured on the backend.", retryable: true });
  });

  it("routes each delivery to the sender for its channel", async () => {
    const push: NotificationSender = { channel: "push", send: vi.fn().mockResolvedValue({ status: "sent", providerMessageId: "m" }) };
    const send = sendWithSenders(new Map([["push", push]]));
    expect(await send(delivery())).toEqual({ status: "sent", providerMessageId: "m" });
  });
});

describe("worker loop", () => {
  it("reads interval, batch size and max attempts from the environment", () => {
    expect(notificationWorkerOptionsFromEnv({})).toEqual({ intervalMs: 10_000, batchSize: 50, maxAttempts: 5 });
    expect(notificationWorkerOptionsFromEnv({ NOTIFICATION_WORKER_POLL_INTERVAL_MS: "0" }).intervalMs).toBe(0);
    expect(() => notificationWorkerOptionsFromEnv({ NOTIFICATION_WORKER_POLL_INTERVAL_MS: "500" })).toThrow();
    expect(() => notificationWorkerOptionsFromEnv({ NOTIFICATION_MAX_ATTEMPTS: "0" })).toThrow();
  });

  it("claims, sends and records through the automation client; a database error does not stop the loop", async () => {
    const rpc = vi.fn()
      .mockResolvedValueOnce({ data: [delivery()], error: null })
      .mockResolvedValueOnce({ data: null, error: null })
      .mockResolvedValueOnce({ data: null, error: { message: "JWT expired" } });
    const automation = { get: vi.fn().mockResolvedValue({ rpc }), invalidate: vi.fn() };
    const push: NotificationSender = { channel: "push", send: vi.fn().mockResolvedValue({ status: "sent", providerMessageId: "m-1" }) };
    const lines: string[] = [];
    const worker = createNotificationDispatcher(automation as never, new Map([["push", push]]), {
      intervalMs: 10_000, batchSize: 10, maxAttempts: 5, log: (l) => lines.push(l)
    });

    expect(await worker.tick()).toEqual({ claimed: 1, succeeded: 1, failed: 0, retrying: 0 });
    expect(rpc).toHaveBeenNthCalledWith(1, "claim_notification_deliveries", { p_limit: 10 });
    expect(rpc).toHaveBeenNthCalledWith(2, "record_notification_delivery", {
      p_delivery_id: "d-1", p_status: "sent", p_provider_message_id: "m-1", p_error_message: null
    });

    expect(await worker.tick()).toBeNull();
    expect(automation.invalidate).toHaveBeenCalled();
    expect(lines.at(-1)).toMatch(/batch failed/);
  });

  it("does not start when turned off, without the automation identity or without any channel", async () => {
    expect(await startNotificationWorker({ NOTIFICATION_WORKER_POLL_INTERVAL_MS: "0" })).toEqual({ started: false, reason: "NOTIFICATION_WORKER_POLL_INTERVAL_MS=0" });
    expect(await startNotificationWorker({})).toMatchObject({ started: false, reason: expect.stringMatching(/AUTOMATION_EMAIL/) });
    expect(await startNotificationWorker({ AUTOMATION_EMAIL: "a@example.com", AUTOMATION_PASSWORD: "pw" }))
      .toMatchObject({ started: false, reason: expect.stringMatching(/no channel configured/) });
  });
});
