import "server-only";

import { createHmac } from "node:crypto";

import { Redis } from "@upstash/redis";

import { serverEnv } from "@/lib/env.server";

const USER_LIMIT = 3;
const SOURCE_LIMIT = 10;
const WINDOW_SECONDS = 15 * 60;

const CHECK_LIMIT_SCRIPT = `#!lua flags=allow-key-locking
local user_count = tonumber(redis.call("GET", KEYS[1]) or "0")
local source_count = tonumber(redis.call("GET", KEYS[2]) or "0")
local blocked = 0
if user_count >= tonumber(ARGV[1]) or source_count >= tonumber(ARGV[2]) then
  blocked = 1
end
return {user_count, source_count, blocked}`;

const RECORD_FAILURE_SCRIPT = `#!lua flags=allow-key-locking
local user_count = redis.call("INCR", KEYS[1])
if user_count == 1 then
  redis.call("EXPIRE", KEYS[1], ARGV[1])
end
local source_count = redis.call("INCR", KEYS[2])
if source_count == 1 then
  redis.call("EXPIRE", KEYS[2], ARGV[1])
end
local user_ttl = redis.call("TTL", KEYS[1])
local source_ttl = redis.call("TTL", KEYS[2])
return {user_count, source_count, user_ttl, source_ttl}`;

const redis = new Redis({
  url: serverEnv.KV_REST_API_URL,
  token: serverEnv.KV_REST_API_TOKEN,
  enableTelemetry: false,
});

export type PasswordChangeLimitResult =
  | { status: "allowed" }
  | { status: "blocked" }
  | { status: "infrastructure" };

export type PasswordChangeLimitMutationResult =
  | { status: "recorded" }
  | { status: "cleared" }
  | { status: "infrastructure" };

type PasswordChangeLimitIdentity = Readonly<{
  profileId: string;
  sourceIdentity: string;
}>;

function createPrivacyDigest(dimension: "user" | "source", value: string) {
  return createHmac(
    "sha256",
    Buffer.from(serverEnv.LOGIN_RATE_LIMIT_HMAC_SECRET, "base64"),
  )
    .update(`password-change:${dimension}\u0000${value}`, "utf8")
    .digest("hex");
}

function createLimiterKey(dimension: "user" | "source", identity: string) {
  const digest = createPrivacyDigest(dimension, identity);

  return `logiflow:${serverEnv.RATE_LIMIT_ENVIRONMENT}:auth:password-change:v1:${dimension}:${digest}`;
}

function createKeys(identity: PasswordChangeLimitIdentity) {
  return [
    createLimiterKey("user", identity.profileId),
    createLimiterKey("source", identity.sourceIdentity),
  ] as const;
}

function isNonnegativeSafeInteger(value: unknown): value is number {
  return (
    typeof value === "number" && Number.isSafeInteger(value) && value >= 0
  );
}

function isPositiveSafeInteger(value: unknown): value is number {
  return (
    typeof value === "number" && Number.isSafeInteger(value) && value >= 1
  );
}

function parseCheckResult(value: unknown): PasswordChangeLimitResult {
  if (!Array.isArray(value) || value.length !== 3) {
    return { status: "infrastructure" };
  }

  const [userCount, sourceCount, blocked] = value;

  if (
    !isNonnegativeSafeInteger(userCount) ||
    !isNonnegativeSafeInteger(sourceCount) ||
    (blocked !== 0 && blocked !== 1)
  ) {
    return { status: "infrastructure" };
  }

  const expectedBlocked = userCount >= USER_LIMIT || sourceCount >= SOURCE_LIMIT;

  if ((blocked === 1) !== expectedBlocked) {
    return { status: "infrastructure" };
  }

  return { status: expectedBlocked ? "blocked" : "allowed" };
}

function isValidFailureResult(value: unknown): boolean {
  if (!Array.isArray(value) || value.length !== 4) {
    return false;
  }

  const [userCount, sourceCount, userTtl, sourceTtl] = value;

  return (
    isPositiveSafeInteger(userCount) &&
    isPositiveSafeInteger(sourceCount) &&
    isPositiveSafeInteger(userTtl) &&
    userTtl <= WINDOW_SECONDS &&
    isPositiveSafeInteger(sourceTtl) &&
    sourceTtl <= WINDOW_SECONDS
  );
}

function hasValidIdentity(identity: PasswordChangeLimitIdentity) {
  return identity.profileId.length > 0 && identity.sourceIdentity.length > 0;
}

export async function checkPasswordChangeLimit(
  identity: PasswordChangeLimitIdentity,
): Promise<PasswordChangeLimitResult> {
  if (!hasValidIdentity(identity)) {
    return { status: "infrastructure" };
  }

  try {
    const result = await redis.eval<
      [string, string],
      unknown
    >(
      CHECK_LIMIT_SCRIPT,
      [...createKeys(identity)],
      [String(USER_LIMIT), String(SOURCE_LIMIT)],
    );

    return parseCheckResult(result);
  } catch {
    return { status: "infrastructure" };
  }
}

export async function recordPasswordChangeFailure(
  identity: PasswordChangeLimitIdentity,
): Promise<PasswordChangeLimitMutationResult> {
  if (!hasValidIdentity(identity)) {
    return { status: "infrastructure" };
  }

  try {
    const result = await redis.eval<
      [string],
      unknown
    >(
      RECORD_FAILURE_SCRIPT,
      [...createKeys(identity)],
      [String(WINDOW_SECONDS)],
    );

    return isValidFailureResult(result)
      ? { status: "recorded" }
      : { status: "infrastructure" };
  } catch {
    return { status: "infrastructure" };
  }
}

export async function clearPasswordChangeUserLimit(
  profileId: string,
): Promise<PasswordChangeLimitMutationResult> {
  if (profileId.length === 0) {
    return { status: "infrastructure" };
  }

  try {
    const deletedCount = await redis.del(createLimiterKey("user", profileId));

    return deletedCount === 0 || deletedCount === 1
      ? { status: "cleared" }
      : { status: "infrastructure" };
  } catch {
    return { status: "infrastructure" };
  }
}
