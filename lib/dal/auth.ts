import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export type AuthenticatedIdentity = Readonly<{
  id: string;
}>;

export type CurrentProfile = Readonly<{
  id: string;
  fullName: string;
  username: string;
  role: Database["public"]["Enums"]["profile_role"];
  isActive: boolean;
}>;

export type AuthBoundaryError =
  | {
      category: "unauthenticated";
      message: "Authentication required.";
    }
  | {
      category: "missing_profile";
      message: "Account profile unavailable.";
    }
  | {
      category: "inactive_profile";
      message: "Account is inactive.";
    }
  | {
      category: "forbidden";
      message: "Access denied.";
    }
  | {
      category: "infrastructure";
      message: "Unable to verify account access.";
    };

export type AuthBoundaryResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: AuthBoundaryError };

async function verifyIdentity(
  client: SupabaseClient<Database>,
): Promise<AuthBoundaryResult<AuthenticatedIdentity>> {
  const { data, error } = await client.auth.getClaims();
  const subject = data?.claims.sub;

  if (error || typeof subject !== "string" || subject.trim() === "") {
    return {
      ok: false,
      error: {
        category: "unauthenticated",
        message: "Authentication required.",
      },
    };
  }

  return {
    ok: true,
    data: { id: subject },
  };
}

export async function requireSession(): Promise<
  AuthBoundaryResult<AuthenticatedIdentity>
> {
  const client = await createClient();

  return verifyIdentity(client);
}

export async function requireProfile(): Promise<
  AuthBoundaryResult<CurrentProfile>
> {
  const client = await createClient();

  return requireProfileWithClient(client);
}

export async function requireProfileWithClient(
  client: SupabaseClient<Database>,
): Promise<AuthBoundaryResult<CurrentProfile>> {
  const identityResult = await verifyIdentity(client);

  if (!identityResult.ok) {
    return identityResult;
  }

  const { data, error } = await client
    .from("profiles")
    .select("id, full_name, username, role, is_active")
    .eq("id", identityResult.data.id)
    .maybeSingle();

  if (error) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  if (data === null) {
    return {
      ok: false,
      error: {
        category: "missing_profile",
        message: "Account profile unavailable.",
      },
    };
  }

  return {
    ok: true,
    data: {
      id: data.id,
      fullName: data.full_name,
      username: data.username,
      role: data.role,
      isActive: data.is_active,
    },
  };
}

export async function requireActiveProfile(): Promise<
  AuthBoundaryResult<CurrentProfile>
> {
  const profileResult = await requireProfile();

  if (!profileResult.ok) {
    return profileResult;
  }

  if (profileResult.data.isActive === false) {
    return {
      ok: false,
      error: {
        category: "inactive_profile",
        message: "Account is inactive.",
      },
    };
  }

  return profileResult;
}

export async function requireRole(
  allowedRole: Database["public"]["Enums"]["profile_role"],
  ...additionalAllowedRoles: Database["public"]["Enums"]["profile_role"][]
): Promise<AuthBoundaryResult<CurrentProfile>> {
  const profileResult = await requireActiveProfile();

  if (!profileResult.ok) {
    return profileResult;
  }

  if (
    profileResult.data.role === allowedRole ||
    additionalAllowedRoles.includes(profileResult.data.role)
  ) {
    return profileResult;
  }

  return {
    ok: false,
    error: {
      category: "forbidden",
      message: "Access denied.",
    },
  };
}
