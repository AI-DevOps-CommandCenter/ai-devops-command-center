import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  createRemediationWebhookDispatcher
} from "../src/services/remediation-webhook.service.js";

import { buildSignedHeaders } from "../src/middleware/machine-auth.js";

import { createMockUserClient } from "./helpers/supabase-mock.js";

import { getPlaybookRunById } from "../src/services/playbook-run.service.js";

vi.mock("../src/services/playbook-run.service.js", () => ({
  getPlaybookRunById: vi.fn()
}));

const RUN_ID = "11111111-1111-4111-8111-111111111111";
const INCIDENT_ID = "22222222-2222-4222-8222-222222222222";

const SIGNING_SECRET =
  "test-machine-signing-secret-with-at-least-32-characters";

const WEBHOOK_URL =
  "https://example.test/webhook/remediation";

const runFixture = {
  id: RUN_ID,
  incident_id: INCIDENT_ID,
  action_type: "restart",
  request_payload: {
    service_name: "api-service"
  },
  status: "approved"
};

describe("Remediation webhook dispatcher", () => {
  const mockGetPlaybookRunById = vi.mocked(getPlaybookRunById);

  beforeEach(() => {
    vi.clearAllMocks();
    mockGetPlaybookRunById.mockResolvedValue(runFixture as never);
  });

  it("sends a correctly signed webhook and accepts HTTP 202", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({ accepted: true }),
        { status: 202 }
      )
    );

    const sleep = vi.fn().mockResolvedValue(undefined);
    const log = vi.fn();

    const dispatcher = createRemediationWebhookDispatcher(
      {
        url: WEBHOOK_URL,
        signingSecret: SIGNING_SECRET
      },
      {
        fetchImpl: fetchImpl as typeof fetch,
        sleep,
        log
      }
    );

    const { client } = createMockUserClient();

    await dispatcher.dispatch(client as never, RUN_ID);

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    expect(sleep).not.toHaveBeenCalled();

    const [url, options] = fetchImpl.mock.calls[0]!;

    expect(url).toBe(WEBHOOK_URL);
    expect(options?.method).toBe("POST");

    const body = JSON.parse(options?.body as string);

    expect(body).toEqual({
      playbook_run_id: RUN_ID,
      incident_id: INCIDENT_ID,
      action_type: "restart",
      request_payload: {
        service_name: "api-service"
      }
    });

    const headers = new Headers(options?.headers);

    expect(headers.get("content-type")).toBe("application/json");
    expect(headers.get("X-DC-Timestamp")).toBeTruthy();
    expect(headers.get("X-DC-Nonce")).toBeTruthy();

    const expectedHeaders = buildSignedHeaders(
      SIGNING_SECRET,
      {
        method: "POST",
        path: "/webhook/remediation",
        body: options?.body as string,
        nonce: headers.get("X-DC-Nonce")!
      }
    );

    const expectedHeaderValues = new Headers(expectedHeaders);

    expect(headers.get("X-DC-Signature")).toBe(
      expectedHeaderValues.get("X-DC-Signature")
    );

    expect(log).toHaveBeenCalledWith(RUN_ID, 1, "202");
  });

  it("retries after HTTP 503 and succeeds on HTTP 202", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(new Response(null, { status: 503 }))
      .mockResolvedValueOnce(new Response(null, { status: 202 }));

    const sleep = vi.fn().mockResolvedValue(undefined);
    const log = vi.fn();

    const dispatcher = createRemediationWebhookDispatcher(
      {
        url: WEBHOOK_URL,
        signingSecret: SIGNING_SECRET
      },
      {
        fetchImpl: fetchImpl as typeof fetch,
        sleep,
        log
      }
    );

    const { client } = createMockUserClient();

    await dispatcher.dispatch(client as never, RUN_ID);

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(sleep).toHaveBeenCalledTimes(1);
    expect(sleep).toHaveBeenCalledWith(2000);

    const firstHeaders = new Headers(
      fetchImpl.mock.calls[0]![1]?.headers
    );

    const secondHeaders = new Headers(
      fetchImpl.mock.calls[1]![1]?.headers
    );

    expect(firstHeaders.get("X-DC-Nonce")).not.toBe(
      secondHeaders.get("X-DC-Nonce")
    );

    expect(log).toHaveBeenNthCalledWith(1, RUN_ID, 1, "503");
    expect(log).toHaveBeenNthCalledWith(2, RUN_ID, 2, "202");
  });

  it("retries after HTTP 502 and succeeds on HTTP 202", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(new Response(null, { status: 502 }))
      .mockResolvedValueOnce(new Response(null, { status: 202 }));

    const sleep = vi.fn().mockResolvedValue(undefined);
    const log = vi.fn();

    const dispatcher = createRemediationWebhookDispatcher(
      {
        url: WEBHOOK_URL,
        signingSecret: SIGNING_SECRET
      },
      {
        fetchImpl: fetchImpl as typeof fetch,
        sleep,
        log
      }
    );

    const { client } = createMockUserClient();

    await dispatcher.dispatch(client as never, RUN_ID);

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(sleep).toHaveBeenCalledTimes(1);
    expect(sleep).toHaveBeenCalledWith(2000);

    const firstHeaders = new Headers(
      fetchImpl.mock.calls[0]![1]?.headers
    );

    const secondHeaders = new Headers(
      fetchImpl.mock.calls[1]![1]?.headers
    );

    expect(firstHeaders.get("X-DC-Nonce")).not.toBe(
      secondHeaders.get("X-DC-Nonce")
    );

    expect(log).toHaveBeenNthCalledWith(1, RUN_ID, 1, "502");
    expect(log).toHaveBeenNthCalledWith(2, RUN_ID, 2, "202");
  });

  it("retries after a network error and succeeds on HTTP 202", async () => {
    const fetchImpl = vi
      .fn()
      .mockRejectedValueOnce(new TypeError("Network connection failed"))
      .mockResolvedValueOnce(new Response(null, { status: 202 }));

    const sleep = vi.fn().mockResolvedValue(undefined);
    const log = vi.fn();

    const dispatcher = createRemediationWebhookDispatcher(
      {
        url: WEBHOOK_URL,
        signingSecret: SIGNING_SECRET
      },
      {
        fetchImpl: fetchImpl as typeof fetch,
        sleep,
        log
      }
    );

    const { client } = createMockUserClient();

    await dispatcher.dispatch(client as never, RUN_ID);

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(sleep).toHaveBeenCalledTimes(1);
    expect(sleep).toHaveBeenCalledWith(2000);

    const firstHeaders = new Headers(
      fetchImpl.mock.calls[0]![1]?.headers
    );

    const secondHeaders = new Headers(
      fetchImpl.mock.calls[1]![1]?.headers
    );

    expect(firstHeaders.get("X-DC-Nonce")).not.toBe(
      secondHeaders.get("X-DC-Nonce")
    );

    expect(log).toHaveBeenNthCalledWith(
      1,
      RUN_ID,
      1,
      "network_error"
    );

    expect(log).toHaveBeenNthCalledWith(2, RUN_ID, 2, "202");
  });

  it("stops immediately when n8n returns HTTP 409", async () => {
    const fetchImpl = vi.fn().mockResolvedValue(
      new Response(null, { status: 409 })
    );

    const sleep = vi.fn().mockResolvedValue(undefined);
    const log = vi.fn();

    const dispatcher = createRemediationWebhookDispatcher(
      {
        url: WEBHOOK_URL,
        signingSecret: SIGNING_SECRET
      },
      {
        fetchImpl: fetchImpl as typeof fetch,
        sleep,
        log
      }
    );

    const { client } = createMockUserClient();

    await dispatcher.dispatch(client as never, RUN_ID);

    expect(fetchImpl).toHaveBeenCalledTimes(1);
    expect(sleep).not.toHaveBeenCalled();
    expect(log).toHaveBeenCalledWith(RUN_ID, 1, "409");
  });
});