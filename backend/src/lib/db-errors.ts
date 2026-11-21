// Maps errors returned by Supabase/PostgREST (database function errors and
// PostgreSQL errors) to HTTP responses.
//
// The workflow functions (migrations 000400-000800) raise custom SQLSTATEs
// with messages written for end users, e.g. "You cannot decide your own
// request." Those messages are returned as-is. PostgreSQL's own errors get a
// generic message so internal details are never exposed.
// Contract: database/API_AND_INTEGRATION_CONTRACTS.md, Part B.1.

import type { Response } from "express";

export interface HttpError {
  status: number;
  message: string;
}

const FUNCTION_ERROR_STATUS: Record<string, number> = {
  DC401: 401,
  DC403: 403,
  DC404: 404,
  DC409: 409,
  DC422: 400
};

const POSTGRES_ERROR: Record<string, HttpError> = {
  "23505": { status: 409, message: "Duplicate request." },
  "23503": { status: 409, message: "A referenced record is missing or still in use." },
  "23001": { status: 409, message: "A referenced record is missing or still in use." },
  "23514": { status: 400, message: "Invalid value." },
  "22P02": { status: 400, message: "Invalid value." },
  "42501": { status: 403, message: "You do not have permission to perform this action." }
};

function readString(value: unknown, key: string): string | undefined {
  if (value === null || typeof value !== "object") return undefined;
  const field = (value as Record<string, unknown>)[key];
  return typeof field === "string" ? field : undefined;
}

// Returns the HTTP error for a known database error, or null when the error
// is unknown (callers then answer with their usual 500 response).
export function mapDbError(error: unknown): HttpError | null {
  const code = readString(error, "code");

  if (!code) return null;

  const functionStatus = FUNCTION_ERROR_STATUS[code];
  if (functionStatus !== undefined) {
    return {
      status: functionStatus,
      message: readString(error, "message") ?? "Request rejected by the database."
    };
  }

  return POSTGRES_ERROR[code] ?? null;
}

// Sends the mapped error, or logs it and sends the caller's usual 500
// message when the error is not a known database error.
export function sendDbError(
  res: Response,
  error: unknown,
  logLabel: string,
  fallbackMessage: string
) {
  const mapped = mapDbError(error);

  if (mapped) {
    return res.status(mapped.status).json({
      success: false,
      message: mapped.message
    });
  }

  console.error(logLabel, error);

  return res.status(500).json({
    success: false,
    message: fallbackMessage
  });
}
