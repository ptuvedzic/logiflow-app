import { z } from "zod";

export const publicEnvSchema = z.object({
  NEXT_PUBLIC_SUPABASE_URL: z.url(),
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z.string().trim().min(1),
  NEXT_PUBLIC_MAP_STYLE_URL: z.url(),
  NEXT_PUBLIC_TRACKING_ROUTE_GEOJSON_URL: z.url(),
});

export type PublicEnv = Readonly<z.infer<typeof publicEnvSchema>>;

function formatValidationError(error: z.ZodError): Error {
  const variableNames = [
    ...new Set(
      error.issues
        .map((issue) => issue.path[0])
        .filter((name): name is string => typeof name === "string"),
    ),
  ];

  const invalidVariables =
    variableNames.length > 0 ? variableNames.join(", ") : "unknown variables";

  return new Error(`Invalid environment variables: ${invalidVariables}.`);
}

export function parseEnvironment<T>(
  schema: z.ZodType<T>,
  values: Record<string, string | undefined>,
): Readonly<T> {
  const result = schema.safeParse(values);

  if (!result.success) {
    throw formatValidationError(result.error);
  }

  return Object.freeze(result.data);
}

export const publicEnv: PublicEnv = parseEnvironment(publicEnvSchema, {
  NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  NEXT_PUBLIC_MAP_STYLE_URL: process.env.NEXT_PUBLIC_MAP_STYLE_URL,
  NEXT_PUBLIC_TRACKING_ROUTE_GEOJSON_URL:
    process.env.NEXT_PUBLIC_TRACKING_ROUTE_GEOJSON_URL,
});
