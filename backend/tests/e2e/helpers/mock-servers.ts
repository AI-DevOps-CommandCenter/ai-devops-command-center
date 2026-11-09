import { createServer as createHttpServer, type IncomingMessage, type ServerResponse } from "node:http";
import { createServer as createTcpServer, type Socket } from "node:net";
import type { AddressInfo } from "node:net";

// Local stand-ins for Slack, Discord, GitHub and an SMTP server.
// They listen on 127.0.0.1 only. Real HTTP and SMTP traffic flows between
// the code under test and these servers; nothing leaves the machine.

export interface CapturedHttpRequest {
  method: string;
  path: string;
  headers: IncomingMessage["headers"];
  body: string;
}

export type HttpHandler = (req: CapturedHttpRequest, res: ServerResponse) => void;

export async function startHttpMock(handler: HttpHandler) {
  const requests: CapturedHttpRequest[] = [];
  const sockets = new Set<Socket>();

  const server = createHttpServer((req, res) => {
    const chunks: Buffer[] = [];
    req.on("data", (c: Buffer) => chunks.push(c));
    req.on("end", () => {
      const captured = {
        method: req.method ?? "",
        path: req.url ?? "",
        headers: req.headers,
        body: Buffer.concat(chunks).toString("utf8")
      };
      requests.push(captured);
      handler(captured, res);
    });
  });
  server.on("connection", (s) => {
    sockets.add(s);
    s.on("close", () => sockets.delete(s));
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address() as AddressInfo;

  return {
    url: `http://127.0.0.1:${port}`,
    requests,
    async close() {
      for (const s of sockets) s.destroy(); // also ends deliberately hanging requests
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  };
}

export function reply(res: ServerResponse, status: number, body: unknown, headers: Record<string, string> = {}) {
  const isText = typeof body === "string";
  res.writeHead(status, { "content-type": isText ? "text/plain" : "application/json", ...headers });
  res.end(isText ? body : JSON.stringify(body));
}

// --- Minimal SMTP server (RFC 5321 subset: EHLO, AUTH PLAIN, MAIL, RCPT, DATA) ---

export interface SmtpMockOptions {
  user?: string;
  password?: string;
  // Reply for RCPT TO by address; default "250 OK".
  rcptReply?: (address: string) => string;
}

export interface ReceivedMail {
  from: string;
  to: string[];
  data: string;
  authenticatedAs: string | null;
}

export async function startSmtpMock(options: SmtpMockOptions = {}) {
  const messages: ReceivedMail[] = [];
  const sockets = new Set<Socket>();
  let counter = 0;

  const server = createTcpServer((socket) => {
    sockets.add(socket);
    socket.on("close", () => sockets.delete(socket));
    socket.setEncoding("utf8");

    let buffer = "";
    let inData = false;
    let mail: ReceivedMail = { from: "", to: [], data: "", authenticatedAs: null };
    let authenticatedAs: string | null = null;
    const send = (line: string) => socket.write(`${line}\r\n`);

    send("220 mock.smtp.test ESMTP ready");

    socket.on("data", (chunk: string) => {
      buffer += chunk;
      let index: number;
      while ((index = buffer.indexOf("\r\n")) >= 0) {
        const line = buffer.slice(0, index);
        buffer = buffer.slice(index + 2);

        if (inData) {
          if (line === ".") {
            inData = false;
            counter += 1;
            messages.push({ ...mail, authenticatedAs });
            send(`250 2.0.0 OK queued as MOCK${counter}`);
            mail = { from: "", to: [], data: "", authenticatedAs: null };
          } else {
            mail.data += `${line.startsWith("..") ? line.slice(1) : line}\n`;
          }
          continue;
        }

        const upper = line.toUpperCase();
        if (upper.startsWith("EHLO") || upper.startsWith("HELO")) {
          socket.write("250-mock.smtp.test\r\n250-AUTH PLAIN\r\n250 8BITMIME\r\n");
        } else if (upper.startsWith("AUTH PLAIN")) {
          const [, user, password] = Buffer.from(line.slice(11).trim(), "base64").toString("utf8").split("\0");
          if (user === options.user && password === options.password) {
            authenticatedAs = user;
            send("235 2.7.0 Authentication successful");
          } else {
            send("535 5.7.8 Authentication credentials invalid");
          }
        } else if (upper.startsWith("MAIL FROM:")) {
          if (options.user && !authenticatedAs) {
            send("530 5.7.0 Authentication required");
          } else {
            mail.from = line.slice(10).trim().replace(/^<|>.*$/g, "");
            send("250 OK");
          }
        } else if (upper.startsWith("RCPT TO:")) {
          const address = line.slice(8).trim().replace(/^<|>.*$/g, "");
          const answer = options.rcptReply?.(address) ?? "250 OK";
          if (answer.startsWith("250")) mail.to.push(address);
          send(answer);
        } else if (upper === "DATA") {
          inData = true;
          send("354 End data with <CR><LF>.<CR><LF>");
        } else if (upper === "RSET") {
          mail = { from: "", to: [], data: "", authenticatedAs: null };
          send("250 OK");
        } else if (upper === "QUIT") {
          send("221 Bye");
          socket.end();
        } else {
          send("502 Command not implemented");
        }
      }
    });
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address() as AddressInfo;

  return {
    port,
    messages,
    async close() {
      for (const s of sockets) s.destroy();
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  };
}

// The real fetch, limited to loopback addresses. Must be captured before
// tests/setup.ts replaces the global fetch (i.e. at module load).
export function loopbackOnly(realFetch: typeof fetch) {
  return (input: string, init?: RequestInit) => {
    const host = new URL(input).hostname;
    if (host !== "127.0.0.1") {
      throw new Error(`E2E tests may only reach 127.0.0.1, not ${host}`);
    }
    return realFetch(input, init);
  };
}
