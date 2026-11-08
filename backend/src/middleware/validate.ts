import type { Request, Response, NextFunction } from "express";
import { z } from "zod";

export interface RequestSchemas {
  body?: z.ZodType;
  params?: z.ZodType;
  query?: z.ZodType;
}

export interface ValidationErrorDetail {
  location: "body" | "params" | "query";
  path: string;
  message: string;
}

// Zod-based request validation. On failure it responds with the API's
// standard error shape ({ success: false, message }) plus field details.
// On success, the parsed (and trimmed/coerced) values are exposed on
// res.locals.validated so the original req objects are left untouched.
export function validate(
  schemas: RequestSchemas,
  message = "Invalid request."
) {
  return (req: Request, res: Response, next: NextFunction) => {
    const errors: ValidationErrorDetail[] = [];
    const validated: Partial<Record<"body" | "params" | "query", unknown>> = {};

    for (const location of ["params", "query", "body"] as const) {
      const schema = schemas[location];

      if (!schema) {
        continue;
      }

      const result = schema.safeParse(req[location]);

      if (result.success) {
        validated[location] = result.data;
        continue;
      }

      for (const issue of result.error.issues) {
        errors.push({
          location,
          path: issue.path.join("."),
          message: issue.message
        });
      }
    }

    if (errors.length > 0) {
      return res.status(400).json({
        success: false,
        message,
        errors
      });
    }

    res.locals.validated = validated;
    next();
  };
}
