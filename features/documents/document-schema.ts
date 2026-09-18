import { z } from "zod";

export const DOCUMENT_TYPES = {
  vehicle: ["registration", "insurance", "technical_inspection", "road_tax", "tachograph_calibration"],
  shipment: ["cmr", "invoice", "delivery_note", "proof_of_delivery", "photos"],
  driver: ["driving_license", "professional_license", "certificate"],
} as const;
export type DocumentOwnerType = keyof typeof DOCUMENT_TYPES;
export type CanonicalDocumentType = (typeof DOCUMENT_TYPES)[DocumentOwnerType][number];
export const DOCUMENT_TYPE_LABELS: Record<CanonicalDocumentType, string> = {
  registration: "Registration", insurance: "Insurance", technical_inspection: "Technical inspection",
  road_tax: "Road tax", tachograph_calibration: "Tachograph calibration", cmr: "CMR", invoice: "Invoice",
  delivery_note: "Delivery note", proof_of_delivery: "Proof of Delivery", photos: "Photos",
  driving_license: "Driving license", professional_license: "Professional license", certificate: "Certificate",
};
const allTypes = Object.values(DOCUMENT_TYPES).flat() as [CanonicalDocumentType, ...CanonicalDocumentType[]];
const optionalDate = z.string().trim().refine((value) => value === "" || z.iso.date().safeParse(value).success, "Enter a valid date.").transform((value) => value || null);
const dates = z.object({ validFrom: optionalDate, validUntil: optionalDate }).superRefine((value, context) => {
  if (value.validFrom && value.validUntil && value.validUntil < value.validFrom) context.addIssue({ code: "custom", path: ["validUntil"], message: "Valid until cannot be before valid from." });
});
export const documentListQuerySchema = z.object({
  search: z.string().trim().max(100).catch(""), owner: z.enum(["all", "shipment", "vehicle", "driver"]).catch("all"),
  type: z.enum(["all", ...allTypes]).catch("all"), lifecycle: z.enum(["active", "archived", "all"]).catch("active"),
  validity: z.enum(["all", "valid", "expiring", "expired", "no_expiry", "archived"]).catch("all"), page: z.coerce.number().int().positive().catch(1),
});
export const uploadIntentSchema = z.object({ ownerType: z.enum(["shipment", "vehicle", "driver"]), ownerId: z.uuid(), documentType: z.enum(allTypes), fileName: z.string().trim().min(1), mimeType: z.enum(["application/pdf", "image/jpeg", "image/png"]), size: z.number().int().positive().max(20 * 1024 * 1024) }).and(dates).superRefine((value, context) => {
  if (!(DOCUMENT_TYPES[value.ownerType] as readonly string[]).includes(value.documentType)) context.addIssue({ code: "custom", path: ["documentType"], message: "Select a valid document type." });
});
export const uploadCompletionSchema = uploadIntentSchema.and(z.object({ documentId: z.uuid(), filePath: z.string().min(1), uploadToken: z.string().min(1) }));
export const documentEditSchema = z.object({ documentId: z.uuid(), expectedUpdatedAt: z.iso.datetime(), documentType: z.enum(allTypes) }).and(dates);
export const documentLifecycleSchema = z.object({ documentId: z.uuid(), expectedUpdatedAt: z.iso.datetime(), lifecycleStatus: z.enum(["active", "archived"]) });
export type DocumentListInput = z.infer<typeof documentListQuerySchema>;
export type UploadIntentInput = z.infer<typeof uploadIntentSchema>;
export type UploadCompletionInput = z.infer<typeof uploadCompletionSchema>;
export type DocumentEditInput = z.infer<typeof documentEditSchema>;
