import "server-only";

import { createClient } from "@supabase/supabase-js";

import { serverEnv } from "@/lib/env.server";
import { publicEnv } from "@/lib/env";
import type { Database } from "@/types/database.generated";

export function createAdminClient() {
  return createClient<Database>(
    publicEnv.NEXT_PUBLIC_SUPABASE_URL,
    serverEnv.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    },
  );
}
