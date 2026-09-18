import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";

import type { AccountProvisioningInput } from "@/features/accounts/account-schema";
import type { Database } from "@/types/database.generated";

import { requireRole, type AuthBoundaryError } from "@/lib/dal/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { z } from "zod";

export const ACCOUNTS_PER_PAGE = 10;

export type ManagedAccountRole = "dispatcher" | "driver";
export type ManagedAccountStatus = "active" | "inactive";

export type ManagedAccount = Readonly<{
  fullName: string;
  username: string;
  role: ManagedAccountRole;
  status: ManagedAccountStatus;
  createdAt: string;
}>;

export type ManagedAccountListInput = Readonly<{
  search: string;
  role: "all" | ManagedAccountRole;
  status: "all" | ManagedAccountStatus;
  page: number;
}>;

export type ManagedAccountList = Readonly<{
  accounts: readonly ManagedAccount[];
  totalCount: number;
  totalPages: number;
}>;

type AccountDalError =
  | AuthBoundaryError
  | { category: "not_found"; message: "Managed account unavailable." }
  | { category: "infrastructure"; message: "Unable to manage accounts right now." };

export type AccountDalResult<T> =
  | { ok: true; data: T }
  | { ok: false; error: AccountDalError };

const managedAccountPayloadSchema = z.object({
  accounts: z.array(
    z.object({
      full_name: z.string(),
      username: z.string(),
      role: z.enum(["dispatcher", "driver"]),
      is_active: z.boolean(),
      created_at: z.string(),
    }),
  ),
  total_count: z.number().int().nonnegative(),
});

export async function listManagedAccounts(
  input: ManagedAccountListInput,
): Promise<AccountDalResult<ManagedAccountList>> {
  const adminResult = await requireRole("admin");

  if (!adminResult.ok) {
    return adminResult;
  }

  const client = createAdminClient();
  const { data, error } = await client.rpc("list_managed_accounts", {
    ...(input.search === "" ? {} : { search_query: input.search }),
    ...(input.role === "all" ? {} : { role_filter: input.role }),
    ...(input.status === "all" ? {} : { active_filter: input.status === "active" }),
    page_offset: (input.page - 1) * ACCOUNTS_PER_PAGE,
    page_limit: ACCOUNTS_PER_PAGE,
  });
  const parsed = managedAccountPayloadSchema.safeParse(data);

  if (error || !parsed.success) {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to manage accounts right now." },
    };
  }

  return {
    ok: true,
    data: {
      accounts: parsed.data.accounts.map((account) => ({
        fullName: account.full_name,
        username: account.username,
        role: account.role,
        status: account.is_active ? "active" : "inactive",
        createdAt: account.created_at,
      })),
      totalCount: parsed.data.total_count,
      totalPages: Math.ceil(parsed.data.total_count / ACCOUNTS_PER_PAGE),
    },
  };
}

export type ManagedAccountTarget = Readonly<{
  id: string;
  username: string;
  role: ManagedAccountRole;
  isActive: boolean;
}>;

export async function getManagedAccountTarget(
  username: string,
): Promise<AccountDalResult<ManagedAccountTarget>> {
  const adminResult = await requireRole("admin");

  if (!adminResult.ok) {
    return adminResult;
  }

  const client = createAdminClient();
  const { data, error } = await client
    .rpc("resolve_managed_account", { target_username: username })
    .maybeSingle();

  if (error) {
    return {
      ok: false,
      error: { category: "infrastructure", message: "Unable to manage accounts right now." },
    };
  }

  if (data === null || (data.account_role !== "dispatcher" && data.account_role !== "driver")) {
    return {
      ok: false,
      error: { category: "not_found", message: "Managed account unavailable." },
    };
  }

  return {
    ok: true,
    data: {
      id: data.account_id,
      username: data.account_username,
      role: data.account_role,
      isActive: data.account_is_active,
    },
  };
}

export async function setManagedAccountActiveState(
  username: string,
  requestedActive: boolean,
): Promise<
  | { ok: true }
  | { ok: false; error: AuthBoundaryError | { category: "database"; code: string; message: string } }
> {
  const adminResult = await requireRole("admin");

  if (!adminResult.ok) {
    return adminResult;
  }

  const client = createAdminClient();
  const { error } = await client.rpc("set_managed_account_active_state", {
    target_username: username,
    requested_active: requestedActive,
  });

  return error
    ? { ok: false, error: { category: "database", code: error.code, message: error.message } }
    : { ok: true };
}

export async function createAccountApplicationState(
  client: SupabaseClient<Database>,
  input: AccountProvisioningInput & {
    authUserId: string;
    driverId: string | null;
  },
) {
  const args = {
    auth_user_id: input.authUserId,
    full_name: input.fullName,
    username: input.username,
    provisioned_role: input.role,
    ...(input.driverId === null ? {} : { driver_id: input.driverId }),
  };

  return client.rpc("provision_account_profile", args);
}
