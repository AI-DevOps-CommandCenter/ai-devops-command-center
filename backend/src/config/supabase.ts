import "./load-env.js";
import { createClient } from "@supabase/supabase-js";

import { loadSupabaseEnv } from "./env.js";

// Validates the configuration at startup (Zod). Only a publishable key is
// accepted; privileged keys are rejected (decision D-001).
const { SUPABASE_URL: supabaseUrl, SUPABASE_PUBLISHABLE_KEY: supabaseKey } =
  loadSupabaseEnv();

// General Supabase client (publishable key only). Used to verify user JWTs.
export const supabase = createClient(
  supabaseUrl,
  supabaseKey
);

// Create a Supabase client using an authenticated user's JWT.
// Database requests made through this client are subject to that user's RLS policies.
export function createUserSupabaseClient(accessToken: string) {
  return createClient(
    supabaseUrl,
    supabaseKey,
    {
      global: {
        headers: {
          Authorization: `Bearer ${accessToken}`
        }
      },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false
      }
    }
  );
}

// Export the exact inferred client type
export type UserSupabaseClient =
  ReturnType<typeof createUserSupabaseClient>;
