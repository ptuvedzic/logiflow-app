"use server";

import { randomUUID } from "node:crypto";

import type { SupabaseClient } from "@supabase/supabase-js";
import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export type LogoutActionState =
  | {
      status: "idle";
      message: null;
      correlationId: null;
    }
  | {
      status: "infrastructure";
      message: "Unable to log out right now. Try again later.";
      correlationId: string;
    };

function infrastructureState(correlationId: string): LogoutActionState {
  return {
    status: "infrastructure",
    message: "Unable to log out right now. Try again later.",
    correlationId,
  };
}

function logLogoutDiagnostic(
  operation: string,
  outcome: "local_cleanup_failed" | "local_cleanup_succeeded",
  correlationId: string,
) {
  console.error({
    operation,
    category: "infrastructure",
    outcome,
    correlationId,
  });
}

async function hasLocalSession(
  client: SupabaseClient<Database>,
): Promise<boolean | null> {
  try {
    const { data, error } = await client.auth.getSession();

    return error ? null : data.session !== null;
  } catch {
    return null;
  }
}

export async function logoutAction(
  _previousState: LogoutActionState,
  _formData: FormData,
): Promise<LogoutActionState> {
  void _previousState;
  void _formData;

  const correlationId = randomUUID();
  let client: SupabaseClient<Database>;

  try {
    client = await createClient();
  } catch {
    logLogoutDiagnostic(
      "auth.logout.create_client",
      "local_cleanup_failed",
      correlationId,
    );
    return infrastructureState(correlationId);
  }

  let signOutReportedFailure = false;

  try {
    const { error } = await client.auth.signOut({ scope: "local" });
    signOutReportedFailure = error !== null;
  } catch {
    signOutReportedFailure = true;
  }

  const localSessionRemains = await hasLocalSession(client);

  if (localSessionRemains !== false) {
    logLogoutDiagnostic(
      "auth.logout.local_cleanup",
      "local_cleanup_failed",
      correlationId,
    );
    return infrastructureState(correlationId);
  }

  if (signOutReportedFailure) {
    logLogoutDiagnostic(
      "auth.logout.remote_sign_out",
      "local_cleanup_succeeded",
      correlationId,
    );
  }

  redirect("/login");
}
