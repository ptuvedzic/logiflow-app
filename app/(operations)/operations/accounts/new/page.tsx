import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { AccountForm } from "@/features/accounts/account-form";
import { requireRole } from "@/lib/dal/auth";

export default async function CreateAccountPage() {
  const profileResult = await requireRole("admin");

  if (!profileResult.ok) {
    handleAuthBoundaryFailure(profileResult.error);
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader
        title="Create account"
        description="Create a Dispatcher or Driver account."
      />
      <Card>
        <AccountForm />
      </Card>
    </div>
  );
}
