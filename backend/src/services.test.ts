
import {
  afterEach,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from "vitest";
import express from "express";
import request from "supertest";

const {
  getUserMock,
  fromMock,
  selectMock,
  orderMock,
  eqMock,
  profileMaybeSingleMock,
  serviceMaybeSingleMock,
  insertMock,
  singleMock,
  updateMock,
  deleteMock,
} = vi.hoisted(() => ({
  getUserMock: vi.fn(),
  fromMock: vi.fn(),
  selectMock: vi.fn(),
  orderMock: vi.fn(),
  eqMock: vi.fn(),
  profileMaybeSingleMock: vi.fn(),
  serviceMaybeSingleMock: vi.fn(),
  insertMock: vi.fn(),
  singleMock: vi.fn(),
  updateMock: vi.fn(),
  deleteMock: vi.fn(),
}));

vi.mock("./lib/supabase", () => ({
  supabase: {
    auth: {
      getUser: getUserMock,
    },
    from: fromMock,
  },
}));

import servicesRouter from "./routes/services.routes";

const serviceId = "48741d41-edba-4ce9-80b7-5019cfb9aaa4";

const testService = {
  id: serviceId,
  name: "Authentication Service",
  description: "Handles authentication",
  environment: "testing",
  endpoint: "https://example.com/auth",
  status: "healthy",
};

function createApp() {
  const app = express();

  app.use(express.json());
  app.use("/api/services", servicesRouter);

  return app;
}

function authenticateAs(role: "user" | "admin" | "operator") {
  getUserMock.mockResolvedValue({
    data: {
      user: {
        id: "test-user-id",
        email: "test@example.com",
      },
    },
    error: null,
  });

  profileMaybeSingleMock.mockResolvedValue({
    data: { role },
    error: null,
  });
}

describe("Services API", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // Return a different mock query for each database table.
    fromMock.mockImplementation((table: string) => {
      if (table === "profiles") {
        return {
          select: vi.fn().mockReturnValue({
            eq: vi.fn().mockReturnValue({
              maybeSingle: profileMaybeSingleMock,
            }),
          }),
        };
      }

      return {
        select: selectMock,
        insert: insertMock,
        update: updateMock,
        delete: deleteMock,
      };
    });

    // GET /api/services
    selectMock.mockReturnValue({
      order: orderMock,
      eq: eqMock,
    });

    orderMock.mockResolvedValue({
      data: [testService],
      error: null,
    });

    // GET /api/services/:id
    eqMock.mockReturnValue({
      maybeSingle: serviceMaybeSingleMock,
    });

    serviceMaybeSingleMock.mockResolvedValue({
      data: testService,
      error: null,
    });

    // POST /api/services
    insertMock.mockReturnValue({
      select: vi.fn().mockReturnValue({
        single: singleMock,
      }),
    });

    singleMock.mockResolvedValue({
      data: testService,
      error: null,
    });

    // PATCH /api/services/:id
    updateMock.mockReturnValue({
      eq: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          maybeSingle: serviceMaybeSingleMock,
        }),
      }),
    });

    // DELETE /api/services/:id
    deleteMock.mockReturnValue({
      eq: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          maybeSingle: serviceMaybeSingleMock,
        }),
      }),
    });
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("should return 200 and a list of services", async () => {
    authenticateAs("user");

    const app = createApp();

    const response = await request(app)
      .get("/api/services")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.count).toBe(1);
    expect(response.body.data[0].name).toBe(
      "Authentication Service"
    );
  });

  it("should return 401 when authentication is missing", async () => {
    const app = createApp();

    const response = await request(app).get("/api/services");

    expect(response.status).toBe(401);
  });

  it("should return 400 when creating a service with invalid data", async () => {
    authenticateAs("admin");

    const app = createApp();

    const response = await request(app)
      .post("/api/services")
      .set("Authorization", "Bearer valid-token")
      .send({
        name: "",
        environment: "invalid",
      });

    expect(response.status).toBe(400);
    expect(response.body.message).toBe("Invalid service data");
    expect(insertMock).not.toHaveBeenCalled();
  });

  it("should create a service when an admin submits valid data", async () => {
    authenticateAs("admin");

    singleMock.mockResolvedValue({
      data: testService,
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .post("/api/services")
      .set("Authorization", "Bearer valid-token")
      .send({
        name: "Authentication Service",
        environment: "testing",
        endpoint: "https://example.com/auth",
      });

    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
    expect(response.body.data.name).toBe(
      "Authentication Service"
    );
    expect(insertMock).toHaveBeenCalled();
  });

  it("should deny a user from creating a service", async () => {
    authenticateAs("user");

    const app = createApp();

    const response = await request(app)
      .post("/api/services")
      .set("Authorization", "Bearer valid-token")
      .send({
        name: "New Service",
        environment: "testing",
      });

    expect(response.status).toBe(403);
    expect(insertMock).not.toHaveBeenCalled();
  });

  it("should return 400 when the service ID is invalid", async () => {
    authenticateAs("user");

    const app = createApp();

    const response = await request(app)
      .get("/api/services/not-a-uuid")
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(400);
  });

  it("should return 404 when a service does not exist", async () => {
    authenticateAs("user");

    serviceMaybeSingleMock.mockResolvedValue({
      data: null,
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .get(`/api/services/${serviceId}`)
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(404);
    expect(response.body.message).toBe("Service not found");
  });

  it("should return 400 when updating a service with an empty body", async () => {
    authenticateAs("admin");

    const app = createApp();

    const response = await request(app)
      .patch(`/api/services/${serviceId}`)
      .set("Authorization", "Bearer valid-token")
      .send({});

    expect(response.status).toBe(400);
    expect(response.body.message).toBe("Invalid service data");
    expect(updateMock).not.toHaveBeenCalled();
  });

  it("should update a service when an operator submits valid data", async () => {
    authenticateAs("operator");

    serviceMaybeSingleMock.mockResolvedValue({
      data: {
        ...testService,
        name: "Updated Service",
      },
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .patch(`/api/services/${serviceId}`)
      .set("Authorization", "Bearer valid-token")
      .send({
        name: "Updated Service",
      });

    expect(response.status).toBe(200);
    expect(response.body.data.name).toBe("Updated Service");
    expect(updateMock).toHaveBeenCalled();
  });

  it("should deny a user from deleting a service", async () => {
    authenticateAs("user");

    const app = createApp();

    const response = await request(app)
      .delete(`/api/services/${serviceId}`)
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(403);
    expect(deleteMock).not.toHaveBeenCalled();
  });

  it("should delete a service when an admin submits the request", async () => {
    authenticateAs("admin");

    serviceMaybeSingleMock.mockResolvedValue({
      data: {
        id: serviceId,
        name: "Authentication Service",
      },
      error: null,
    });

    const app = createApp();

    const response = await request(app)
      .delete(`/api/services/${serviceId}`)
      .set("Authorization", "Bearer valid-token");

    expect(response.status).toBe(200);
    expect(response.body.message).toBe(
      "Service deleted successfully"
    );
    expect(deleteMock).toHaveBeenCalled();
  });
});
