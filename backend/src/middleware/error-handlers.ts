import type { Request, Response, NextFunction } from "express";

// JSON 404 for unknown routes (previously Express's default HTML page).
export function notFoundHandler(_req: Request, res: Response) {
  res.status(404).json({
    success: false,
    message: "Route not found."
  });
}

interface HttpError {
  type?: string;
  status?: number;
}

// Final error handler. Body-parser errors keep their HTTP status but get a
// JSON body; anything else is a generic 500 without internal details.
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  next: NextFunction
) {
  if (res.headersSent) {
    next(err);
    return;
  }

  const httpError = (err ?? {}) as HttpError;

  if (httpError.type === "entity.parse.failed") {
    res.status(400).json({
      success: false,
      message: "Malformed JSON request body."
    });
    return;
  }

  if (httpError.type === "entity.too.large") {
    res.status(413).json({
      success: false,
      message: "Request body is too large."
    });
    return;
  }

  console.error("Unhandled error:", err);

  res.status(500).json({
    success: false,
    message: "Internal server error."
  });
}
