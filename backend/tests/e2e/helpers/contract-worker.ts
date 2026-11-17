import {
  toRecordDeliveryParams,
  type ClaimedDelivery,
  type DeliveryResult,
  type NotificationSender
} from "../../../src/integrations/notifications/index.js";

// TEST-ONLY stand-in for the notification sender worker (owner: Vinuka, M5),
// which does not exist on this branch yet. It follows contract B.4 step by
// step so the senders can be tested end to end:
//
//   1. claim_notification_deliveries(p_limit)
//   2. sender.send(row) for the row's channel
//   3. record_notification_delivery(...) - except for a retryable failure
//      below the attempt limit, which stays pending and is claimed again
//      after 2 minutes (database behaviour).
//
// It is not production code. When the real worker lands, these tests should
// run against it instead.

export interface RpcClient {
  rpc(fn: string, args: unknown): PromiseLike<{ data: unknown; error: unknown }>;
}

export interface CycleOutcome {
  delivery: ClaimedDelivery;
  result: DeliveryResult;
  recorded: boolean;
}

export async function runDeliveryCycle(
  client: RpcClient,
  senders: Map<string, NotificationSender>,
  options: { limit?: number; maxAttempts?: number } = {}
): Promise<CycleOutcome[]> {
  const { data, error } = await client.rpc("claim_notification_deliveries", { p_limit: options.limit ?? 50 });
  if (error) throw Object.assign(new Error("claim_notification_deliveries failed"), { cause: error });

  const outcomes: CycleOutcome[] = [];
  for (const delivery of (data ?? []) as ClaimedDelivery[]) {
    const sender = senders.get(delivery.channel);
    const result: DeliveryResult = sender
      ? await sender.send(delivery)
      : { status: "failed", errorMessage: `Channel ${delivery.channel} is not configured.`, retryable: false };

    const keepPending =
      result.status === "failed" && result.retryable && delivery.attempt_count < (options.maxAttempts ?? 5);

    if (!keepPending) {
      const recorded = await client.rpc("record_notification_delivery", toRecordDeliveryParams(delivery.delivery_id, result));
      if (recorded.error) throw Object.assign(new Error("record_notification_delivery failed"), { cause: recorded.error });
    }
    outcomes.push({ delivery, result, recorded: !keepPending });
  }
  return outcomes;
}
