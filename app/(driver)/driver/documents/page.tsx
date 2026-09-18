import Link from "next/link";
import { Download, FileText } from "lucide-react";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { DocumentUploadForm } from "@/features/documents/document-upload-form";
import { getCurrentDriverDocuments } from "@/lib/dal/documents";

const uploadDateFormatter = new Intl.DateTimeFormat("en", {
  dateStyle: "medium",
  timeZone: "UTC",
});

export default async function DriverDocumentsPage() {
  const result = await getCurrentDriverDocuments();

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="Documents" />
      {result.data === null ? (
        <EmptyState
          icon={FileText}
          title="No current shipment"
          description="You do not have a shipment assigned right now."
        />
      ) : result.data.documents.length === 0 ? (
        <>
        <Card header={<h2 className="text-h3 text-foreground">Upload Proof of Delivery</h2>}>
          <DocumentUploadForm driverOwner={{ id: result.data.shipmentId, label: result.data.shipmentReference }} />
        </Card>
        <EmptyState
          icon={FileText}
          title="No documents available"
          description={`No Proof of Delivery is available for ${result.data.shipmentReference}.`}
        />
        </>
      ) : (
        <>
        <Card header={<h2 className="text-h3 text-foreground">Upload Proof of Delivery</h2>}>
          <DocumentUploadForm driverOwner={{ id: result.data.shipmentId, label: result.data.shipmentReference }} />
        </Card>
        <section aria-labelledby="current-documents-heading" className="flex flex-col gap-4">
          <h2 id="current-documents-heading" className="text-h3 text-foreground">
            {result.data.shipmentReference}
          </h2>
          <div className="grid min-w-0 gap-4">
            {result.data.documents.map((document) => (
              <Card
                key={document.id}
                header={
                  <div className="flex min-w-0 items-start gap-3">
                    <FileText
                      aria-hidden="true"
                      className="mt-0.5 shrink-0 text-primary"
                      size={20}
                      strokeWidth={1.75}
                    />
                    <div className="min-w-0">
                      <h3 className="break-words text-body-medium text-foreground">
                        {document.fileName}
                      </h3>
                      <p className="mt-1 text-small text-secondary">
                        Proof of Delivery
                      </p>
                    </div>
                  </div>
                }
                footer={
                  <Link
                    href={`/api/documents/${document.id}/download`}
                    className="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-control border border-input bg-background-card px-4 text-label text-secondary transition-colors duration-interaction ease-standard hover:bg-background-hover focus-visible:border-info focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-info-soft focus-visible:ring-offset-2 focus-visible:ring-offset-background-card md:w-auto"
                  >
                    <Download aria-hidden="true" size={20} strokeWidth={1.75} />
                    View or download
                  </Link>
                }
              >
                <dl>
                  <div>
                    <dt className="text-label text-secondary">Uploaded</dt>
                    <dd className="mt-2 text-body text-foreground">
                      {uploadDateFormatter.format(new Date(document.uploadedAt))}
                    </dd>
                  </div>
                </dl>
              </Card>
            ))}
          </div>
        </section>
        </>
      )}
    </div>
  );
}
