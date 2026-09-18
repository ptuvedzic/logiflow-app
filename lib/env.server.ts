import "server-only";

import { z } from "zod";

import { parseEnvironment, publicEnv, publicEnvSchema } from "@/lib/env";

const base64SecretSchema = z
  .string()
  .trim()
  .regex(/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/)
  .refine((value) => Buffer.from(value, "base64").byteLength >= 32, {
    message: "Must encode at least 32 bytes.",
  });

const serverEnvSchema = publicEnvSchema.extend({
  SUPABASE_SERVICE_ROLE_KEY: z.string().trim().min(1),
  SUPABASE_DOCUMENTS_BUCKET: z.literal("documents"),
  AUTH_INTERNAL_DOMAIN: z
    .string()
    .trim()
    .toLowerCase()
    .min(1)
    .max(63)
    .regex(
      /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*$/,
    ),
  KV_REST_API_URL: z.url().refine((value) => value.startsWith("https://"), {
    message: "Must use HTTPS.",
  }),
  KV_REST_API_TOKEN: z.string().trim().min(1),
  LOGIN_RATE_LIMIT_HMAC_SECRET: base64SecretSchema,
  RATE_LIMIT_ENVIRONMENT: z.enum(["development", "preview", "production"]),
});

export type ServerEnv = Readonly<z.infer<typeof serverEnvSchema>>;

export const serverEnv: ServerEnv = parseEnvironment(serverEnvSchema, {
  ...publicEnv,
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  SUPABASE_DOCUMENTS_BUCKET: process.env.SUPABASE_DOCUMENTS_BUCKET,
  AUTH_INTERNAL_DOMAIN: process.env.AUTH_INTERNAL_DOMAIN,
  KV_REST_API_URL: process.env.KV_REST_API_URL,
  KV_REST_API_TOKEN: process.env.KV_REST_API_TOKEN,
  LOGIN_RATE_LIMIT_HMAC_SECRET: process.env.LOGIN_RATE_LIMIT_HMAC_SECRET,
  RATE_LIMIT_ENVIRONMENT: process.env.RATE_LIMIT_ENVIRONMENT,
});
