import "server-only";

import { z } from "zod";

import { requireProfileWithClient } from "@/lib/dal/auth";
import type { AuthBoundaryError, AuthBoundaryResult } from "@/lib/dal/auth";
import { serverEnv } from "@/lib/env.server";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/types/database.generated";

export type DriverDocument = Readonly<{
  id: string;
  shipmentReference: string;
  documentType: "proof_of_delivery";
  fileName: string;
  lifecycleStatus: "active";
  uploadedAt: string;
}>;

export type CurrentDriverDocuments = Readonly<{
  shipmentId: string;
  shipmentReference: string;
  documents: readonly DriverDocument[];
}>;

type DocumentDownloadError =
  | AuthBoundaryError
  | { category: "not_found"; message: "Document unavailable." }
  | { category: "storage"; message: "Document temporarily unavailable." };

export type DocumentDownloadResult =
  | { ok: true; data: Readonly<{ signedUrl: string }> }
  | { ok: false; error: DocumentDownloadError };

const CURRENT_SHIPMENT_STATUSES = [
  "assigned",
  "loading",
  "in_transit",
] as const satisfies readonly Database["public"]["Enums"]["shipment_status"][];

const documentIdSchema = z.uuid();

async function requireCurrentDriverShipment(
  client: Awaited<ReturnType<typeof createClient>>,
): Promise<
  AuthBoundaryResult<Readonly<{ id: string; reference: string }> | null>
> {
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

  const { data: driver, error: driverError } = await client
    .from("drivers")
    .select("id")
    .eq("profile_id", profileResult.data.id)
    .maybeSingle();

  if (driverError) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  if (driver === null) {
    return {
      ok: false,
      error: {
        category: "missing_profile",
        message: "Account profile unavailable.",
      },
    };
  }

  const { data: shipments, error: shipmentError } = await client
    .from("shipments")
    .select("id, tracking_number")
    .eq("driver_id", driver.id)
    .in("status", [...CURRENT_SHIPMENT_STATUSES])
    .limit(2);

  if (shipmentError || shipments === null || shipments.length > 1) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  const shipment = shipments[0];

  return shipment === undefined
    ? { ok: true, data: null }
    : {
        ok: true,
        data: { id: shipment.id, reference: shipment.tracking_number },
      };
}

export async function getCurrentDriverDocuments(): Promise<
  AuthBoundaryResult<CurrentDriverDocuments | null>
> {
  const client = await createClient();
  const shipmentResult = await requireCurrentDriverShipment(client);

  if (!shipmentResult.ok) {
    return shipmentResult;
  }

  if (shipmentResult.data === null) {
    return { ok: true, data: null };
  }

  const shipment = shipmentResult.data;

  const { data: documents, error } = await client
    .from("documents")
    .select("id, document_type, file_name, lifecycle_status, uploaded_at")
    .eq("shipment_id", shipment.id)
    .eq("document_type", "proof_of_delivery")
    .eq("lifecycle_status", "active")
    .order("uploaded_at", { ascending: false });

  if (error || documents === null) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  return {
    ok: true,
    data: {
      shipmentId: shipment.id,
      shipmentReference: shipment.reference,
      documents: documents.map((document) => ({
        id: document.id,
        shipmentReference: shipment.reference,
        documentType: "proof_of_delivery",
        fileName: document.file_name,
        lifecycleStatus: "active",
        uploadedAt: document.uploaded_at,
      })),
    },
  };
}

export async function createCurrentDriverDocumentDownload(
  documentId: string,
): Promise<DocumentDownloadResult> {
  const parsedDocumentId = documentIdSchema.safeParse(documentId);

  if (!parsedDocumentId.success) {
    return {
      ok: false,
      error: { category: "not_found", message: "Document unavailable." },
    };
  }

  const client = await createClient();
  const profileResult = await requireProfileWithClient(client);
  if (!profileResult.ok) return profileResult;
  if (!profileResult.data.isActive) return { ok: false, error: { category: "inactive_profile", message: "Account is inactive." } };
  if (profileResult.data.role === "admin" || profileResult.data.role === "dispatcher") {
    const { data: document, error } = await client.from("documents").select("file_path").eq("id", parsedDocumentId.data).maybeSingle();
    if (error) return { ok: false, error: { category: "infrastructure", message: "Unable to verify account access." } };
    if (document === null) return { ok: false, error: { category: "not_found", message: "Document unavailable." } };
    const { data, error: signingError } = await client.storage.from(serverEnv.SUPABASE_DOCUMENTS_BUCKET).createSignedUrl(document.file_path, 300);
    return signingError || data === null ? { ok: false, error: { category: "storage", message: "Document temporarily unavailable." } } : { ok: true, data: { signedUrl: data.signedUrl } };
  }
  if (profileResult.data.role !== "driver") return { ok: false, error: { category: "forbidden", message: "Access denied." } };
  const shipmentResult = await requireCurrentDriverShipment(client);

  if (!shipmentResult.ok) {
    return shipmentResult;
  }

  if (shipmentResult.data === null) {
    return {
      ok: false,
      error: { category: "not_found", message: "Document unavailable." },
    };
  }

  const { data: document, error } = await client
    .from("documents")
    .select("file_path")
    .eq("id", parsedDocumentId.data)
    .eq("shipment_id", shipmentResult.data.id)
    .eq("document_type", "proof_of_delivery")
    .eq("lifecycle_status", "active")
    .maybeSingle();

  if (error) {
    return {
      ok: false,
      error: {
        category: "infrastructure",
        message: "Unable to verify account access.",
      },
    };
  }

  if (document === null) {
    return {
      ok: false,
      error: { category: "not_found", message: "Document unavailable." },
    };
  }

  const { data, error: signingError } = await client.storage
    .from(serverEnv.SUPABASE_DOCUMENTS_BUCKET)
    .createSignedUrl(document.file_path, 300);

  if (signingError || data === null) {
    return {
      ok: false,
      error: {
        category: "storage",
        message: "Document temporarily unavailable.",
      },
    };
  }

  return { ok: true, data: { signedUrl: data.signedUrl } };
}
