
import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_PUBLISHABLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error("Supabase environment variables are missing!");
}

// General Supabase client
export const supabase = createClient(
  supabaseUrl,
  supabaseKey
);

// Create a Supabase client using an authenticated user's JWT.
// Database requests made through this client are subject to that user's RLS policies.
export function createUserSupabaseClient(accessToken: string) {
  return createClient(
    supabaseUrl!,
    supabaseKey!,
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
