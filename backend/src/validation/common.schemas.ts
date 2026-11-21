import { z } from "zod";

// Shared Zod schemas for request validation.
// Existing controllers keep their own validation for now so their error
// messages stay unchanged. New and refactored endpoints should use these.

export const uuidSchema = z.uuid();

export const idParamSchema = z.object({
  id: uuidSchema
});

export const paginationQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).optional(),
  offset: z.coerce.number().int().min(0).optional()
});

export const jsonObjectBodySchema = z.record(z.string(), z.unknown());

export const nonEmptyTrimmedString = z.string().trim().min(1);
