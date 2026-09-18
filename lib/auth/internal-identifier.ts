import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { serverEnv } from "@/lib/env.server";
import type { Database } from "@/types/database.generated";

export type InternalAuthIdentifierResult =
  | { ok: true; identifier: string; credentialIdentity: string }
  | {
      ok: false;
      error:
        | {
            category: "invalid_username";
            message: "Invalid username.";
          }
        | {
            category: "infrastructure";
            message: "Unable to derive authentication identifier.";
          };
    };

export async function deriveInternalAuthIdentifier(
  client: SupabaseClient<Database>,
  username: string,
): Promise<InternalAuthIdentifierResult> {
  const { data, error } = await client.rpc("auth_username_local_part", {
    username,
  });

  if (error) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to derive authentication identifier.",
      },
    };
  }

  if (typeof data !== "string" || data.length === 0) {
    return {
      ok: false,
      error: {
        category: "invalid_username",
        message: "Invalid username.",
      },
    };
  }

  const identifier = `${data}@${serverEnv.AUTH_INTERNAL_DOMAIN}`;

  if (new TextEncoder().encode(identifier).byteLength > 255) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to derive authentication identifier.",
      },
    };
  }

  return { ok: true, identifier, credentialIdentity: data };
}
