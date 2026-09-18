import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { getDriverProfile } from "@/lib/dal/profile";

export default async function DriverProfilePage() {
  const result = await getDriverProfile();

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="Profile" />
      <Card
        header={
          <h2 className="text-h3 text-foreground">Account information</h2>
        }
      >
        <dl className="grid min-w-0 gap-4 md:grid-cols-2">
          <div className="min-w-0">
            <dt className="text-label text-secondary">Full name</dt>
            <dd className="mt-2 break-words text-body-medium text-foreground">
              {result.data.fullName}
            </dd>
          </div>
          <div className="min-w-0">
            <dt className="text-label text-secondary">Username</dt>
            <dd className="mt-2 break-words text-body-medium text-foreground">
              {result.data.username}
            </dd>
          </div>
        </dl>
      </Card>
    </div>
  );
}
