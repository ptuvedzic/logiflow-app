import "server-only";

import { createHmac } from "node:crypto";
import { isIP } from "node:net";

import { Redis } from "@upstash/redis";
import { headers } from "next/headers";

import { serverEnv } from "@/lib/env.server";

const SOURCE_LIMIT = 20;
const USERNAME_LIMIT = 5;
const WINDOW_SECONDS = 15 * 60;
const VERCEL_SOURCE_HEADER = "x-forwarded-for";
const DEVELOPMENT_SOURCE_IDENTITY = "local-development";

const ATOMIC_LOGIN_LIMIT_SCRIPT = `#!lua flags=allow-key-locking
local source_count = redis.call("INCR", KEYS[1])
if source_count == 1 then
  redis.call("EXPIRE", KEYS[1], ARGV[1])
end

local username_count = redis.call("INCR", KEYS[2])
if username_count == 1 then
  redis.call("EXPIRE", KEYS[2], ARGV[1])
end

local source_ttl = redis.call("TTL", KEYS[1])
local username_ttl = redis.call("TTL", KEYS[2])
local blocked = 0
if source_count > tonumber(ARGV[2]) or username_count > tonumber(ARGV[3]) then
  blocked = 1
end

return {source_count, username_count, source_ttl, username_ttl, blocked}`;

const redis = new Redis({
  url: serverEnv.KV_REST_API_URL,
  token: serverEnv.KV_REST_API_TOKEN,
  enableTelemetry: false,
});

export type TrustedLoginSourceResult =
  | { ok: true; sourceIdentity: string }
  | { ok: false; status: "infrastructure" };

export type LoginRateLimitResult =
  | { status: "allowed" }
  | { status: "blocked" }
  | { status: "infrastructure" };

export type UsernameLimitCleanupResult =
  | { status: "cleared" }
  | { status: "infrastructure" };

function canonicalizeIpAddress(value: string): string | null {
  const candidate = value.trim();

  if (
    candidate.length === 0 ||
    candidate !== value ||
    candidate.includes(",") ||
    candidate.includes("%") ||
    /[\u0000-\u001f\u007f]/.test(candidate)
  ) {
    return null;
  }

  const version = isIP(candidate);

  if (version === 4) {
    return candidate;
  }

  if (version !== 6) {
    return null;
  }

  try {
    const hostname = new URL(`http://[${candidate}]/`).hostname;

    if (!hostname.startsWith("[") || !hostname.endsWith("]")) {
      return null;
    }

    const canonical = hostname.slice(1, -1);
    return isIP(canonical) === 6 ? canonical : null;
  } catch {
    return null;
  }
}

function createPrivacyDigest(dimension: "source" | "username", value: string) {
  return createHmac(
    "sha256",
    Buffer.from(serverEnv.LOGIN_RATE_LIMIT_HMAC_SECRET, "base64"),
  )
    .update(`${dimension}\u0000${value}`, "utf8")
    .digest("hex");
}

function createLimiterKey(
  dimension: "source" | "username",
  identity: string,
) {
  const digest = createPrivacyDigest(dimension, identity);

  return `logiflow:${serverEnv.RATE_LIMIT_ENVIRONMENT}:auth:login:v1:${dimension}:${digest}`;
}

function isPositiveSafeInteger(value: unknown): value is number {
  return Number.isSafeInteger(value) && typeof value === "number" && value >= 1;
}

function parseLimiterResponse(value: unknown): LoginRateLimitResult {
  if (!Array.isArray(value) || value.length !== 5) {
    return { status: "infrastructure" };
  }

  const [sourceCount, usernameCount, sourceTtl, usernameTtl, blocked] = value;

  if (
    !isPositiveSafeInteger(sourceCount) ||
    !isPositiveSafeInteger(usernameCount) ||
    !isPositiveSafeInteger(sourceTtl) ||
    sourceTtl > WINDOW_SECONDS ||
    !isPositiveSafeInteger(usernameTtl) ||
    usernameTtl > WINDOW_SECONDS ||
    (blocked !== 0 && blocked !== 1)
  ) {
    return { status: "infrastructure" };
  }

  const expectedBlocked =
    sourceCount > SOURCE_LIMIT || usernameCount > USERNAME_LIMIT;

  if ((blocked === 1) !== expectedBlocked) {
    return { status: "infrastructure" };
  }

  return { status: expectedBlocked ? "blocked" : "allowed" };
}

export async function getTrustedLoginSource(): Promise<TrustedLoginSourceResult> {
  let headerValue: string | null;

  try {
    headerValue = (await headers()).get(VERCEL_SOURCE_HEADER);
  } catch {
    return { ok: false, status: "infrastructure" };
  }

  if (headerValue === null) {
    return serverEnv.RATE_LIMIT_ENVIRONMENT === "development"
      ? { ok: true, sourceIdentity: DEVELOPMENT_SOURCE_IDENTITY }
      : { ok: false, status: "infrastructure" };
  }

  const sourceIdentity = canonicalizeIpAddress(headerValue);

  return sourceIdentity === null
    ? { ok: false, status: "infrastructure" }
    : { ok: true, sourceIdentity };
}

export async function evaluateLoginAttempt({
  sourceIdentity,
  credentialIdentity,
}: Readonly<{
  sourceIdentity: string;
  credentialIdentity: string;
}>): Promise<LoginRateLimitResult> {
  if (sourceIdentity.length === 0 || credentialIdentity.length === 0) {
    return { status: "infrastructure" };
  }

  const sourceKey = createLimiterKey("source", sourceIdentity);
  const usernameKey = createLimiterKey("username", credentialIdentity);

  try {
    const result = await redis.eval<
      [string, string, string],
      unknown
    >(
      ATOMIC_LOGIN_LIMIT_SCRIPT,
      [sourceKey, usernameKey],
      [String(WINDOW_SECONDS), String(SOURCE_LIMIT), String(USERNAME_LIMIT)],
    );

    return parseLimiterResponse(result);
  } catch {
    return { status: "infrastructure" };
  }
}

export async function clearSuccessfulUsernameLimit({
  credentialIdentity,
}: Readonly<{
  credentialIdentity: string;
}>): Promise<UsernameLimitCleanupResult> {
  if (credentialIdentity.length === 0) {
    return { status: "infrastructure" };
  }

  const usernameKey = createLimiterKey("username", credentialIdentity);

  try {
    const deletedCount = await redis.del(usernameKey);

    return deletedCount === 0 || deletedCount === 1
      ? { status: "cleared" }
      : { status: "infrastructure" };
  } catch {
    return { status: "infrastructure" };
  }
}
