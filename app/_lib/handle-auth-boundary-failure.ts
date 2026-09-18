import "server-only";

import { redirect } from "next/navigation";

import type { AuthBoundaryError } from "@/lib/dal/auth";

export function handleAuthBoundaryFailure(
  error: AuthBoundaryError,
): never {
  switch (error.category) {
    case "unauthenticated":
      redirect("/login");
    case "inactive_profile":
      redirect("/account-inactive");
    case "forbidden":
      redirect("/forbidden");
    case "missing_profile":
      redirect("/account-error");
    case "infrastructure":
      throw new Error("Unable to verify account access.");
  }
}
