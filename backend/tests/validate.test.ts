import { describe, expect, it } from "vitest";
import express from "express";
import request from "supertest";
import { z } from "zod";

import { validate } from "../src/middleware/validate.js";
import {
  idParamSchema,
  paginationQuerySchema
} from "../src/validation/common.schemas.js";

function buildApp() {
  const app = express();
  app.use(express.json());

  app.post(
    "/items/:id",
    validate(
      {
        params: idParamSchema,
        query: paginationQuerySchema,
        body: z.object({ name: z.string().trim().min(1) })
      },
      "Invalid item request."
    ),
    (_req, res) => {
      res.json({ success: true, validated: res.locals.validated });
    }
  );

  return app;
}

describe("validate() middleware (Zod)", () => {
  const app = buildApp();
  const id = "33333333-3333-4333-8333-333333333333";

  it("passes valid input and exposes parsed values", async () => {
    const res = await request(app)
      .post(`/items/${id}?limit=10`)
      .send({ name: "  web  " });

    expect(res.status).toBe(200);
    expect(res.body.validated).toEqual({
      params: { id },
      query: { limit: 10 },
      body: { name: "web" }
    });
  });

  it("rejects invalid input with the standard error shape and details", async () => {
    const res = await request(app)
      .post("/items/not-a-uuid?limit=500")
      .send({ name: "" });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toBe("Invalid item request.");
    expect(res.body.errors.map((e: { location: string; path: string }) => `${e.location}:${e.path}`))
      .toEqual(["params:id", "query:limit", "body:name"]);
  });
});
