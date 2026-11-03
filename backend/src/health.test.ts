import { describe, it, expect } from "vitest";
import request from "supertest";
import app from "./server";

describe("Health Check API", () => {
it("should return HTTP 200 and a success message", async () => {
const response = await request(app).get("/health");

expect(response.status).toBe(200);

expect(response.body).toMatchObject({
  success: true,
  message: "DevOps Command Center API is running",
});

expect(response.body.timestamp).toBeDefined();
expect(Number.isNaN(Date.parse(response.body.timestamp))).toBe(false);


});
});
