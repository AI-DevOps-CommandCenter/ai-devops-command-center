import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import express from "express";
import request from "supertest";

// Create mock functions before importing the middleware.
const {
  getUserMock,
  fromMock,
  selectMock,
  eqMock,
  maybeSingleMock,
} = vi.hoisted(() => ({
  getUserMock: vi.fn(),
  fromMock: vi.fn(),
  selectMock: vi.fn(),
  eqMock: vi.fn(),
  maybeSingleMock: vi.fn(),
}));

// Mock Supabase so tests do not call the real database.
vi.mock("./lib/supabase", () => ({
  supabase: {
    auth: {
      getUser: getUserMock,
    },
    from: fromMock,
  },
}));

import { requireAuth, requireRole } from "./middleware/auth";

const testUser = {
  id: "test-user-id",
  email: "test@example.com",
};

function createApp() {
  const app = express();

  app.use(express.json());

  app.get("/protected", requireAuth, (_req, res) => {
    res.status(200).json({
      success: true,
      role: res.locals.userRole,
      userId: res.locals.authUser.id,
    });
  });

  app.post(
    "/admin-action",
    requireAuth,
    requireRole("admin", "operator"),
    (_req, res) => {
      res.status(200).json({
        success: true,
        message: "Action allowed.",
      });
    },
  );

  return app;
}

describe("Authentication and RBAC Middleware", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Configure the mocked Supabase profile query.
    fromMock.mockReturnValue({
      select: selectMock,
    });

    selectMock.mockReturnValue({
      eq: eqMock,
    });

    eqMock.mockReturnValue({
      maybeSingle: maybeSingleMock,
    });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("should return 401 when the authorization header is missing", async () => {
    const app = createApp();

    const response = await request(app).get("/protected");

    expect(response.status).toBe(401);
    expect(response.body.message).toBe("Authentication required.");
    expect(getUserMock).not.toHaveBeenCalled();
  });

  it("should return 401 when the access token is empty", async () => {
const app = createApp();

const response = await request(app)
.get("/protected")
.set("Authorization", "Bearer");

expect(response.status).toBe(401);
expect(response.body.message).toBe("Authentication required.");
});


  it("should return 401 when the access token is invalid", async () => {
    getUserMock.mockResolvedValue({
      data: { user: null },
      error: { message: "Invalid token" },
    });

    const app = createApp();

    const response = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer invalid-token");

    expect(response.status).toBe(401);
    expect(response.body.message).toBe(
      "Invalid or expired access token.",
    );
  });

  it("should return 403 when the user profile does not exist", async () => {
    getUserMock.mockResolvedValue({
      data: { user: testUser },
      error: null,
    });

    maybeSingleMock.mockResolvedValue({
      data: null,
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(403);
    expect(response.body.message).toBe(
      "User profile or valid role not found.",
    );
  });

  it("should return 403 when the user has an invalid role", async () => {
    getUserMock.mockResolvedValue({
      data: { user: testUser },
      error: null,
    });

    maybeSingleMock.mockResolvedValue({
      data: { role: "guest" },
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(403);
    expect(response.body.message).toBe(
      "User profile or valid role not found.",
    );
  });

  it("should return 500 when the profile query fails", async () => {
    getUserMock.mockResolvedValue({
      data: { user: testUser },
      error: null,
    });

    maybeSingleMock.mockResolvedValue({
      data: null,
      error: { message: "Database query failed" },
    });

    const consoleError = vi
      .spyOn(console, "error")
      .mockImplementation(() => {});

    const app = createApp();

    const response = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(500);
    expect(response.body.message).toBe(
      "Unable to verify user permissions.",
    );

    consoleError.mockRestore();
  });

  it("should allow an authenticated user with a valid user role", async () => {
    getUserMock.mockResolvedValue({
      data: { user: testUser },
      error: null,
    });

    maybeSingleMock.mockResolvedValue({
      data: { role: "user" },
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .get("/protected")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      success: true,
      role: "user",
      userId: testUser.id,
    });
  });

  it("should deny a user role access to an admin-only action", async () => {
    getUserMock.mockResolvedValue({
      data: { user: testUser },
      error: null,
    });

    maybeSingleMock.mockResolvedValue({
      data: { role: "user" },
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .post("/admin-action")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(403);
    expect(response.body.message).toBe(
      "You do not have permission to perform this action.",
    );
  });

  it.each(["admin", "operator"] as const)(
    "should allow the %s role to perform an admin-only action",
    async (role) => {
      getUserMock.mockResolvedValue({
        data: { user: testUser },
        error: null,
      });

      maybeSingleMock.mockResolvedValue({
        data: { role },
        error: null,
      });

      const app = createApp();

      const response = await request(app)
        .post("/admin-action")
        .set("Authorization", "Bearer valid-token");

      expect(response.status).toBe(200);
      expect(response.body.message).toBe("Action allowed.");
    },
  );
});