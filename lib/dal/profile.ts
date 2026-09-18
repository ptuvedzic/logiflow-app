import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryResult } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export type DriverAccount = Readonly<{
  profileId: string;
  driverId: string;
  fullName: string;
  username: string;
}>;

export type DriverProfile = Readonly<{
  fullName: string;
  username: string;
}>;

export async function requireDriverAccountWithClient(
  client: SupabaseClient<Database>,
): Promise<AuthBoundaryResult<DriverAccount>> {
  const profileResult = await requireProfileWithClient(client);

  if (!profileResult.ok) {
    return profileResult;
  }

  if (!profileResult.data.isActive) {
    return {
      ok: false,
      error: { category: "inactive_profile", message: "Account is inactive." },
    };
  }

  if (profileResult.data.role !== "driver") {
    return {
      ok: false,
      error: { category: "forbidden", message: "Access denied." },
    };
  }

  const { data: drivers, error } = await client
    .from("drivers")
    .select("id")
    .eq("profile_id", profileResult.data.id)
    .limit(2);

  if (error || drivers === null || drivers.length > 1) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  if (drivers[0] === undefined) {
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
      profileId: profileResult.data.id,
      driverId: drivers[0].id,
      fullName: profileResult.data.fullName,
      username: profileResult.data.username,
    },
  };
}

export async function requireDriverAccount(): Promise<
  AuthBoundaryResult<DriverAccount>
> {
  const client = await createClient();

  return requireDriverAccountWithClient(client);
}

export async function getDriverProfile(): Promise<
  AuthBoundaryResult<DriverProfile>
> {
  const accountResult = await requireDriverAccount();

  if (!accountResult.ok) {
    return accountResult;
  }

  return {
    ok: true,
    data: {
      fullName: accountResult.data.fullName,
      username: accountResult.data.username,
    },
  };
}
