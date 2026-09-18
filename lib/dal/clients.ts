import "server-only";

import type { ClientEditInput, ClientFormInput, ClientLifecycleInput } from "@/features/clients/client-schema";
import { requireProfileWithClient, type AuthBoundaryError } from "@/lib/dal/auth";
import { createClient } from "@/lib/supabase/server";

export const CLIENTS_PER_PAGE = 10;

export type ClientStatus = "active" | "archived";
export type ClientListInput = Readonly<{ search: string; status: "all" | ClientStatus; page: number }>;
export type ClientListItem = Readonly<{
  id: string;
  companyName: string;
  contactPerson: string | null;
  phone: string | null;
  email: string | null;
  status: ClientStatus;
}>;
export type ClientRecord = ClientListItem & Readonly<{ address: string | null; notes: string | null; updatedAt: string }>;
export type ClientListResult = Readonly<{ clients: readonly ClientListItem[]; totalCount: number; totalPages: number }>;

type ClientError = AuthBoundaryError
  | { category: "not_found"; message: string }
  | { category: "conflict"; message: string }
  | { category: "business_rule"; message: string }
  | { category: "infrastructure"; message: string };
export type ClientResult<T> = { ok: true; data: T } | { ok: false; error: ClientError };

async function authorizedClient() {
  const client = await createClient();
  const profile = await requireProfileWithClient(client);
  if (!profile.ok) return { ok: false as const, error: profile.error };
  if (!profile.data.isActive) return { ok: false as const, error: { category: "inactive_profile" as const, message: "Account is inactive." as const } };
  if (profile.data.role !== "admin" && profile.data.role !== "dispatcher") return { ok: false as const, error: { category: "forbidden" as const, message: "Access denied." as const } };
  return { ok: true as const, client, profile: profile.data };
}

function mapRow(row: { id: string; company_name: string; contact_person: string | null; phone: string | null; email: string | null; status: ClientStatus }): ClientListItem {
  return { id: row.id, companyName: row.company_name, contactPerson: row.contact_person, phone: row.phone, email: row.email, status: row.status };
}

function translateMutationError(message: string): ClientError {
  if (message.includes("client_has_active_shipment")) return { category: "business_rule", message: "This client has an active shipment that must be resolved before archiving." };
  if (message.includes("client_lifecycle_conflict") || message.includes("client_combined_mutation_invalid")) return { category: "conflict", message: "Client changed before this request could be completed." };
  if (message.includes("client_access_denied")) return { category: "forbidden", message: "Access denied." };
  return { category: "infrastructure", message: "Unable to manage clients right now." };
}

function postgrestQuotedSearch(value: string): string {
  return value.replaceAll("\\", "\\\\").replaceAll('"', '\\"');
}

export async function listClients(input: ClientListInput): Promise<ClientResult<ClientListResult>> {
  const auth = await authorizedClient();
  if (!auth.ok) return auth;
  let query = auth.client.from("clients").select("id, company_name, contact_person, phone, email, status", { count: "exact" });
  if (input.search !== "") {
    const search = postgrestQuotedSearch(input.search);
    query = query.or(`company_name.ilike."%${search}%",contact_person.ilike."%${search}%"`);
  }
  if (input.status !== "all") query = query.eq("status", input.status);
  const from = (input.page - 1) * CLIENTS_PER_PAGE;
  const { data, error, count } = await query.order("company_name", { ascending: true }).order("created_at", { ascending: false }).order("id", { ascending: true }).range(from, from + CLIENTS_PER_PAGE - 1);
  if (error || count === null) return { ok: false, error: { category: "infrastructure", message: "Unable to load clients right now." } };
  return { ok: true, data: { clients: data.map(mapRow), totalCount: count, totalPages: Math.ceil(count / CLIENTS_PER_PAGE) } };
}

export async function getClient(clientId: string): Promise<ClientResult<ClientRecord>> {
  const auth = await authorizedClient();
  if (!auth.ok) return auth;
  const { data, error } = await auth.client.from("clients").select("id, company_name, contact_person, phone, email, address, notes, status, updated_at").eq("id", clientId).maybeSingle();
  if (error) return { ok: false, error: { category: "infrastructure", message: "Unable to load the client right now." } };
  if (!data) return { ok: false, error: { category: "not_found", message: "Client unavailable." } };
  return { ok: true, data: { ...mapRow(data), address: data.address, notes: data.notes, updatedAt: data.updated_at } };
}

function fields(input: ClientFormInput) {
  return { company_name: input.companyName, contact_person: input.contactPerson, phone: input.phone, email: input.email, address: input.address, notes: input.notes };
}

export async function createClientRecord(id: string, input: ClientFormInput): Promise<ClientResult<null>> {
  const auth = await authorizedClient();
  if (!auth.ok) return auth;
  const { error } = await auth.client.from("clients").insert({ id, ...fields(input) });
  return error ? { ok: false, error: translateMutationError(error.message) } : { ok: true, data: null };
}

export async function updateClientRecord(input: ClientEditInput): Promise<ClientResult<"updated" | "noop">> {
  const auth = await authorizedClient();
  if (!auth.ok) return auth;
  const { data: current, error: readError } = await auth.client.from("clients").select("company_name, contact_person, phone, email, address, notes, updated_at").eq("id", input.clientId).maybeSingle();
  if (readError) return { ok: false, error: { category: "infrastructure", message: "Unable to manage clients right now." } };
  if (!current) return { ok: false, error: { category: "not_found", message: "Client unavailable." } };
  if (current.updated_at !== input.expectedUpdatedAt) return { ok: false, error: { category: "conflict", message: "Client changed since you opened this form. Reload and try again." } };
  const values = fields(input);
  if (current.company_name === values.company_name && current.contact_person === values.contact_person && current.phone === values.phone && current.email === values.email && current.address === values.address && current.notes === values.notes) return { ok: true, data: "noop" };
  const { data, error } = await auth.client.from("clients").update(values).eq("id", input.clientId).eq("updated_at", input.expectedUpdatedAt).select("id").maybeSingle();
  if (error) return { ok: false, error: translateMutationError(error.message) };
  if (!data) return { ok: false, error: { category: "conflict", message: "Client changed since you opened this form. Reload and try again." } };
  return { ok: true, data: "updated" };
}

export async function changeClientLifecycle(input: ClientLifecycleInput): Promise<ClientResult<null>> {
  const auth = await authorizedClient();
  if (!auth.ok) return auth;
  const expected = input.operation === "archive" ? "active" : "archived";
  const requested = input.operation === "archive" ? "archived" : "active";
  const { data, error } = await auth.client.from("clients").update({ status: requested }).eq("id", input.clientId).eq("status", expected).select("id").maybeSingle();
  if (error) return { ok: false, error: translateMutationError(error.message) };
  if (!data) return { ok: false, error: { category: "conflict", message: "Client changed before this request could be completed." } };
  return { ok: true, data: null };
}
