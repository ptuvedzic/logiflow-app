import { createCurrentDriverDocumentDownload } from "@/lib/dal/documents";

export async function GET(
  _request: Request,
  context: RouteContext<"/api/documents/[documentId]/download">,
) {
  const { documentId } = await context.params;
  const result = await createCurrentDriverDocumentDownload(documentId);

  if (result.ok) {
    return Response.redirect(result.data.signedUrl, 307);
  }

  switch (result.error.category) {
    case "unauthenticated":
      return new Response("Authentication required.", { status: 401 });
    case "inactive_profile":
    case "forbidden":
    case "missing_profile":
    case "not_found":
      return new Response("Document unavailable.", { status: 404 });
    case "infrastructure":
    case "storage":
      return new Response("Document temporarily unavailable. Please retry.", {
        status: 503,
      });
  }
}
