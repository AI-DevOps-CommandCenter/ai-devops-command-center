import { describe, expect, it, vi } from "vitest";

import {
  NotificationProviderError,
  processNotificationDeliveryBatch
} from "../src/workers/notification-delivery-processor.js";

import type { NotificationDelivery } from "../src/services/notification-delivery.service.js";

import type {
  NotificationDeliveryProcessorDependencies
} from "../src/workers/notification-delivery-processor.js";

function makeDelivery(
  id: string,
  channel: NotificationDelivery["channel"] = "email"
): NotificationDelivery {
  return {
    delivery_id: id,
    channel,
    attempt_count: 1,
    notification_id: `notification-${id}`,
    user_id: "user-123",
    incident_id: "incident-123",
    title: "Incident detected",
    message: "A critical incident was detected.",
    recipient_email: "user@example.com",
    device_tokens: null
  };
}

function makeDependencies(
  overrides: Partial<NotificationDeliveryProcessorDependencies> = {}
): NotificationDeliveryProcessorDependencies {
  return {
    claim: vi.fn().mockResolvedValue([makeDelivery("delivery-1")]),
    send: vi.fn().mockResolvedValue({
      status: "sent",
      providerMessageId: "provider-123"
    }),
    record: vi.fn().mockResolvedValue(undefined),
    ...overrides
  };
}

describe("notification-delivery-processor", () => {
  it("returns zero counts when there are no pending deliveries", async () => {
    const dependencies = makeDependencies({
      claim: vi.fn().mockResolvedValue([])
    });

    const result = await processNotificationDeliveryBatch(dependencies);

    expect(result).toEqual({
      claimed: 0,
      succeeded: 0,
      failed: 0
    });
    expect(dependencies.send).not.toHaveBeenCalled();
    expect(dependencies.record).not.toHaveBeenCalled();
  });

  it("sends and records a successful delivery", async () => {
    const delivery = makeDelivery("delivery-1");
    const dependencies = makeDependencies({
      claim: vi.fn().mockResolvedValue([delivery])
    });

    const result = await processNotificationDeliveryBatch(
      dependencies,
      20
    );

    expect(dependencies.claim).toHaveBeenCalledWith(20);
    expect(dependencies.send).toHaveBeenCalledWith(delivery);
    expect(dependencies.record).toHaveBeenCalledWith(
      "delivery-1",
      "sent",
      "provider-123",
      null
    );

    expect(result).toEqual({
      claimed: 1,
      succeeded: 1,
      failed: 0
    });
  });

  it("records a provider failure without stopping the remaining deliveries", async () => {
    const first = makeDelivery("delivery-1");
    const second = makeDelivery("delivery-2");

    const send = vi.fn()
      .mockRejectedValueOnce(
        new NotificationProviderError("Email provider is not configured.")
      )
      .mockResolvedValueOnce({
        status: "delivered",
        providerMessageId: "provider-456"
      });

    const dependencies = makeDependencies({
      claim: vi.fn().mockResolvedValue([first, second]),
      send
    });

    const result = await processNotificationDeliveryBatch(dependencies);

    expect(send).toHaveBeenCalledTimes(2);

    expect(dependencies.record).toHaveBeenNthCalledWith(
      1,
      "delivery-1",
      "failed",
      null,
      "Email provider is not configured."
    );

    expect(dependencies.record).toHaveBeenNthCalledWith(
      2,
      "delivery-2",
      "delivered",
      "provider-456",
      null
    );

    expect(result).toEqual({
      claimed: 2,
      succeeded: 1,
      failed: 1
    });
  });

  it("does not expose unexpected error details in the recorded message", async () => {
    const dependencies = makeDependencies({
      send: vi.fn().mockRejectedValue(
        new Error("Unexpected response containing sensitive details")
      )
    });

    await processNotificationDeliveryBatch(dependencies);

    expect(dependencies.record).toHaveBeenCalledWith(
      "delivery-1",
      "failed",
      null,
      "Notification provider request failed."
    );
  });

  it("records the provider message ID as null when the provider omits it", async () => {
    const dependencies = makeDependencies({
      send: vi.fn().mockResolvedValue({
        status: "sent"
      })
    });

    await processNotificationDeliveryBatch(dependencies);

    expect(dependencies.record).toHaveBeenCalledWith(
      "delivery-1",
      "sent",
      null,
      null
    );
  });

  it("propagates claim errors", async () => {
    const dependencies = makeDependencies({
      claim: vi.fn().mockRejectedValue(new Error("Claim failed"))
    });

    await expect(
      processNotificationDeliveryBatch(dependencies)
    ).rejects.toThrow("Claim failed");

    expect(dependencies.send).not.toHaveBeenCalled();
  });

  it("propagates recording errors instead of reporting false success", async () => {
    const dependencies = makeDependencies({
      record: vi.fn().mockRejectedValue(new Error("Recording failed"))
    });

    await expect(
      processNotificationDeliveryBatch(dependencies)
    ).rejects.toThrow("Recording failed");
  });
});