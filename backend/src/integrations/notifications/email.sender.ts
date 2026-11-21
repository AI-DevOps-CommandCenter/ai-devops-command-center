import nodemailer from "nodemailer";
import { z } from "zod";

import { safeErrorMessage } from "../redact.js";
import type { EmailConfig } from "./config.js";
import { checkDelivery, incidentLine, invalidDelivery, logFailure, truncateText } from "./sender-utils.js";
import type { ClaimedDelivery, DeliveryResult, NotificationSender } from "./types.js";

// Sends notifications to one user by e-mail over SMTP (nodemailer).
// The recipient comes from claim_notification_deliveries().recipient_email.
// Messages are plain text only, so notification text can't inject HTML.

export interface MailMessage {
  from: string;
  to: string;
  subject: string;
  text: string;
}

export interface MailTransport {
  sendMail(message: MailMessage): Promise<{ messageId?: string; rejected?: unknown[] }>;
}

const SUBJECT_PREFIX = "[DevOps Command Center]";
const emailSchema = z.email();

// SMTP / socket error codes worth another attempt later.
const TRANSIENT_CODES = new Set([
  "ETIMEDOUT",
  "ECONNECTION",
  "ESOCKET",
  "EDNS",
  "ECONNRESET",
  "ECONNREFUSED",
  "EPIPE",
  "EAI_AGAIN"
]);

export function buildEmailMessage(delivery: ClaimedDelivery, from: string, to: string): MailMessage {
  // CR/LF in a subject could start a new header line.
  const title = delivery.title.replace(/[\r\n]+/g, " ").trim();
  const incident = incidentLine(delivery);

  return {
    from,
    to,
    subject: truncateText(`${SUBJECT_PREFIX} ${title}`, 250),
    text: [delivery.message, incident].filter(Boolean).join("\n\n") +
      "\n\n--\nSent by the AI-Powered Mobile DevOps Command Center."
  };
}

export function createSmtpTransport(config: EmailConfig, timeoutMs: number): MailTransport {
  return nodemailer.createTransport({
    host: config.host,
    port: config.port,
    secure: config.secure,
    requireTLS: config.requireTls && !config.secure,
    auth: config.user && config.password ? { user: config.user, pass: config.password } : undefined,
    connectionTimeout: timeoutMs,
    greetingTimeout: timeoutMs,
    socketTimeout: timeoutMs,
    // The message is built here; never let it pull in files or URLs.
    disableFileAccess: true,
    disableUrlAccess: true
  });
}

interface SmtpError {
  code?: unknown;
  responseCode?: unknown;
  response?: unknown;
}

// Classifies a nodemailer error. SMTP 4xx replies are temporary, 5xx are
// permanent (RFC 5321). Authentication and envelope errors are permanent.
export function classifySmtpError(error: unknown, secrets: string[] = []): { message: string; retryable: boolean; kind: string } {
  const e = (error ?? {}) as SmtpError;
  const code = typeof e.code === "string" ? e.code : undefined;
  const responseCode = typeof e.responseCode === "number" ? e.responseCode : undefined;
  const response = typeof e.response === "string" ? truncateText(e.response, 200) : "";

  let retryable: boolean;
  if (responseCode !== undefined) {
    retryable = responseCode >= 400 && responseCode < 500;
  } else if (code === "EAUTH" || code === "EENVELOPE" || code === "EMESSAGE") {
    retryable = false;
  } else {
    retryable = code !== undefined && TRANSIENT_CODES.has(code);
  }

  const parts = [
    "Email:",
    code === "EAUTH" ? "SMTP authentication failed." : "SMTP delivery failed.",
    code ? `[${code}]` : "",
    responseCode ? `${responseCode}` : "",
    response
  ].filter(Boolean);

  return {
    message: safeErrorMessage(parts.join(" "), 500, secrets),
    retryable,
    kind: code ?? (responseCode ? `smtp_${responseCode}` : "unknown")
  };
}

export class EmailSender implements NotificationSender {
  readonly channel = "email" as const;

  constructor(
    private readonly config: EmailConfig,
    private readonly transport: MailTransport,
    private readonly options: { timeoutMs: number }
  ) {}

  async send(delivery: ClaimedDelivery): Promise<DeliveryResult> {
    const invalid = checkDelivery(this.channel, delivery);
    if (invalid) return invalid;

    const recipient = delivery.recipient_email?.trim() ?? "";
    if (!emailSchema.safeParse(recipient).success) {
      return invalidDelivery(this.channel, "recipient has no valid e-mail address.");
    }

    const secrets = [this.config.password ?? "", this.config.user ?? ""];
    let timer: NodeJS.Timeout | undefined;

    try {
      // Overall limit in addition to nodemailer's socket timeouts.
      const timeout = new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(Object.assign(new Error("timeout"), { code: "ETIMEDOUT" })), this.options.timeoutMs);
      });

      const info = await Promise.race([
        this.transport.sendMail(buildEmailMessage(delivery, this.config.from, recipient)),
        timeout
      ]);

      if (Array.isArray(info.rejected) && info.rejected.length > 0) {
        logFailure(this.channel, delivery.delivery_id, "recipient_rejected");
        return { status: "failed", errorMessage: "Email: the SMTP server rejected the recipient.", retryable: false };
      }

      return {
        status: "sent",
        providerMessageId: typeof info.messageId === "string" ? truncateText(info.messageId, 200) : null
      };
    } catch (error) {
      const failure = classifySmtpError(error, secrets);
      logFailure(this.channel, delivery.delivery_id, failure.kind);
      return { status: "failed", errorMessage: failure.message, retryable: failure.retryable };
    } finally {
      clearTimeout(timer);
    }
  }
}
