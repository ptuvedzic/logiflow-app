"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { completeDocumentUpload, createDocumentUploadIntent } from "@/app/(operations)/operations/documents/actions";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Select } from "@/components/ui/select";
import { createClient } from "@/lib/supabase/client";
import type { DocumentOwnerOption } from "@/lib/dal/operations-documents";
import { DOCUMENT_TYPES, DOCUMENT_TYPE_LABELS, type DocumentOwnerType } from "./document-schema";

type OwnerGroups = Readonly<Record<DocumentOwnerType, readonly DocumentOwnerOption[]>>;

export function DocumentUploadForm({ owners, driverOwner }: Readonly<{ owners?: OwnerGroups; driverOwner?: DocumentOwnerOption }>) {
  const router = useRouter();
  const driver = Boolean(driverOwner);
  const [ownerType, setOwnerType] = useState<DocumentOwnerType>(driver ? "shipment" : "vehicle");
  const [ownerId, setOwnerId] = useState(driverOwner?.id ?? "");
  const [pending, setPending] = useState(false);
  const [progress, setProgress] = useState(0);
  const [message, setMessage] = useState<string | null>(null);
  const [confirmation, setConfirmation] = useState<FormData | null>(null);
  const options = driver ? (driverOwner ? [driverOwner] : []) : (owners?.[ownerType] ?? []);
  const types = useMemo(() => driver ? (["proof_of_delivery"] as const) : DOCUMENT_TYPES[ownerType], [driver, ownerType]);

  async function upload(formData: FormData) {
    setPending(true); setMessage(null); setProgress(5);
    const file = formData.get("file");
    if (!(file instanceof File) || file.size === 0) { setMessage("Select a file."); setPending(false); return; }
    const input = {
      ownerType,
      ownerId: driver ? (driverOwner?.id ?? "") : String(formData.get("ownerId")),
      documentType: driver ? "proof_of_delivery" : String(formData.get("documentType")),
      fileName: file.name, mimeType: file.type, size: file.size,
      validFrom: String(formData.get("validFrom") ?? ""), validUntil: String(formData.get("validUntil") ?? ""),
    };
    const intent = await createDocumentUploadIntent(input as never);
    if (!intent.ok) { setMessage(intent.error.message); setPending(false); return; }
    setProgress(25);
    const uploaded = await createClient().storage.from("documents").uploadToSignedUrl(intent.data.filePath, intent.data.token, file, { contentType: file.type, upsert: false });
    if (uploaded.error) { setMessage("Upload failed. Try again."); setPending(false); return; }
    setProgress(80);
    const completion = await completeDocumentUpload({ ...input, documentId: intent.data.documentId, filePath: intent.data.filePath, fileName: intent.data.fileName, uploadToken: intent.data.token });
    if (!completion.ok) { setMessage(completion.error.message); setPending(false); return; }
    setProgress(100); router.push(driver ? "/driver/documents" : "/operations/documents"); router.refresh();
  }

  function submit(formData: FormData) {
    if (driver) { setConfirmation(formData); return; }
    void upload(formData);
  }

  return <>
    <form action={submit} className="flex flex-col gap-4" noValidate>
      {!driver ? <div className="grid gap-4 md:grid-cols-2">
        <div className="flex flex-col gap-2"><label className="text-label" htmlFor="document-owner-type">Owner type</label><Select id="document-owner-type" value={ownerType} disabled={pending} onChange={(event) => { const next = event.target.value as DocumentOwnerType; setOwnerType(next); setOwnerId(owners?.[next][0]?.id ?? ""); }}><option value="vehicle">Vehicle</option><option value="shipment">Shipment</option><option value="driver">Driver</option></Select></div>
        <div className="flex flex-col gap-2"><label className="text-label" htmlFor="document-owner">Owner</label><Select id="document-owner" name="ownerId" value={ownerId} onChange={(event) => setOwnerId(event.target.value)} required disabled={pending}><option value="" disabled>Select an owner</option>{options.map((owner) => <option key={owner.id} value={owner.id}>{owner.label}</option>)}</Select></div>
      </div> : <p className="text-body text-secondary">Shipment: <span className="font-medium text-foreground">{driverOwner?.label}</span></p>}
      <div className="grid gap-4 md:grid-cols-2">
        <div className="flex flex-col gap-2"><label className="text-label" htmlFor="document-type">Document type</label><Select id="document-type" name="documentType" defaultValue={driver ? "proof_of_delivery" : types[0]} disabled={pending}>{types.map((type) => <option key={type} value={type}>{DOCUMENT_TYPE_LABELS[type]}</option>)}</Select></div>
        <div className="flex flex-col gap-2"><label className="text-label" htmlFor="document-file">File</label><Input id="document-file" name="file" type="file" accept="application/pdf,image/jpeg,image/png,.pdf,.jpg,.jpeg,.png" required disabled={pending} /><p className="text-small text-secondary">PDF, JPEG, or PNG. Maximum 20 MiB.</p></div>
        {!driver ? <><div className="flex flex-col gap-2"><label className="text-label" htmlFor="document-valid-from">Valid from</label><Input id="document-valid-from" name="validFrom" type="date" disabled={pending} /></div><div className="flex flex-col gap-2"><label className="text-label" htmlFor="document-valid-until">Valid until</label><Input id="document-valid-until" name="validUntil" type="date" disabled={pending} /></div></> : <><input type="hidden" name="validFrom" value="" /><input type="hidden" name="validUntil" value="" /></>}
      </div>
      {pending ? <div aria-live="polite"><p className="text-small text-secondary">Uploading… {progress}%</p><progress className="mt-2 h-2 w-full accent-primary" max={100} value={progress}>Uploading {progress}%</progress></div> : null}
      {message ? <p role="alert" className="text-small text-danger">{message}</p> : null}
      <div className="flex flex-col-reverse gap-2 sm:flex-row"><Button type="button" variant="outline" disabled={pending} onClick={() => router.push(driver ? "/driver/documents" : "/operations/documents")}>Cancel</Button><Button type="submit" loading={pending} disabled={pending || !ownerId}>Upload document</Button></div>
    </form>
    <Dialog open={confirmation !== null} onOpenChange={(open) => { if (!open) setConfirmation(null); }}><DialogContent><DialogHeader><DialogTitle>Upload Proof of Delivery?</DialogTitle><DialogDescription>The new file will replace the active POD metadata for this Shipment. Previous files remain retained.</DialogDescription></DialogHeader><DialogFooter><Button type="button" variant="outline" onClick={() => setConfirmation(null)}>Cancel</Button><Button type="button" onClick={() => { const value = confirmation; setConfirmation(null); if (value) void upload(value); }}>Upload POD</Button></DialogFooter></DialogContent></Dialog>
  </>;
}
