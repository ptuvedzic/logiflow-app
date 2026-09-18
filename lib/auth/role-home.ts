import "server-only";

import type { Database } from "@/types/database.generated";

type ProfileRole = Database["public"]["Enums"]["profile_role"];

export type RoleHome = "/operations/dashboard" | "/driver/dashboard";

export function getRoleHome(role: ProfileRole): RoleHome {
  switch (role) {
    case "admin":
    case "dispatcher":
      return "/operations/dashboard";
    case "driver":
      return "/driver/dashboard";
  }
}
