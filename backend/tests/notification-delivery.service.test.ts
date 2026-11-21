import { describe, expect, it } from "vitest";

import type { UserSupabaseClient } from "../src/config/supabase.js";
import {
  claimNotificationDeliveries,
  recordNotificationDelivery
} from "../src/services/notification-delivery.service.js";

import {
  createMockUserClient,
  callsFor
} from "./helpers/supabase-mock.js";

describe("notification-delivery.service", () => {
  describe("claimNotificationDeliveries", () => {
    it("calls the claim RPC with the requested limit", async () => {
      const { client, calls } = createMockUserClient();

      await claimNotificationDeliveries(
        client as unknown as UserSupabaseClient,
        25
      );

      const rpcCalls = callsFor(
        calls,
        "rpc:claim_notification_deliveries",
        "rpc"
      );

      expect(rpcCalls).toHaveLength(1);
      expect(rpcCalls[0].args[0]).toEqual({ p_limit: 25 });
    });

    it("uses the default limit of 50", async () => {
      const { client, calls } = createMockUserClient();

      await claimNotificationDeliveries(
        client as unknown as UserSupabaseClient
      );

      const rpcCalls = callsFor(
        calls,
        "rpc:claim_notification_deliveries",
        "rpc"
      );

      expect(rpcCalls[0].args[0]).toEqual({ p_limit: 50 });
    });

    it("returns the claimed delivery records", async () => {
      const delivery = {
        delivery_id: "delivery-123",
        channel: "email",
        attempt_count: 1,
        notification_id: "notification-123",
        user_id: "user-123",
        incident_id: "incident-123",
        title: "Incident detected",
        message: "A critical incident was detected.",
        recipient_email: "user@example.com",
        device_tokens: null
      };

      const { client } = createMockUserClient({
        "rpc:claim_notification_deliveries": {
          data: [delivery],
          error: null
        }
      });

      const result = await claimNotificationDeliveries(
        client as unknown as UserSupabaseClient
      );

      expect(result).toEqual([delivery]);
    });

    it("returns an empty array when the RPC returns null data", async () => {
      const { client } = createMockUserClient({
        "rpc:claim_notification_deliveries": {
          data: null,
          error: null
        }
      });

      const result = await claimNotificationDeliveries(
        client as unknown as UserSupabaseClient
      );

      expect(result).toEqual([]);
    });

    it.each([0, 501, 1.5, -1])(
      "rejects an invalid delivery limit: %s",
      async (limit) => {
        const { client, calls } = createMockUserClient();

        await expect(
          claimNotificationDeliveries(
            client as unknown as UserSupabaseClient,
            limit
          )
        ).rejects.toThrow(
          "Notification delivery limit must be between 1 and 500."
        );

        expect(calls).toHaveLength(0);
      }
    );

    it("propagates database errors", async () => {
      const databaseError = new Error("Database claim failed");

      const { client } = createMockUserClient({
        "rpc:claim_notification_deliveries": {
          data: null,
          error: databaseError
        }
      });

      await expect(
        claimNotificationDeliveries(
          client as unknown as UserSupabaseClient
        )
      ).rejects.toThrow("Database claim failed");
    });
  });

  describe("recordNotificationDelivery", () => {
    it("calls the record RPC with all supplied arguments", async () => {
      const { client, calls } = createMockUserClient();

      await recordNotificationDelivery(
        client as unknown as UserSupabaseClient,
        "delivery-123",
        "sent",
        "provider-message-456",
        null
      );

      const rpcCalls = callsFor(
        calls,
        "rpc:record_notification_delivery",
        "rpc"
      );

      expect(rpcCalls).toHaveLength(1);
      expect(rpcCalls[0].args[0]).toEqual({
        p_delivery_id: "delivery-123",
        p_status: "sent",
        p_provider_message_id: "provider-message-456",
        p_error_message: null
      });
    });

    it("uses null for optional arguments by default", async () => {
      const { client, calls } = createMockUserClient();

      await recordNotificationDelivery(
        client as unknown as UserSupabaseClient,
        "delivery-123",
        "failed"
      );

      const rpcCalls = callsFor(
        calls,
        "rpc:record_notification_delivery",
        "rpc"
      );

      expect(rpcCalls[0].args[0]).toEqual({
        p_delivery_id: "delivery-123",
        p_status: "failed",
        p_provider_message_id: null,
        p_error_message: null
      });
    });

    it("propagates database errors", async () => {
      const databaseError = new Error("Database recording failed");

      const { client } = createMockUserClient({
        "rpc:record_notification_delivery": {
          data: null,
          error: databaseError
        }
      });

      await expect(
        recordNotificationDelivery(
          client as unknown as UserSupabaseClient,
          "delivery-123",
          "failed",
          null,
          "Provider unavailable"
        )
      ).rejects.toThrow("Database recording failed");
    });
  });
});