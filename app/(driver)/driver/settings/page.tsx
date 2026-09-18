import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { PasswordForm } from "@/app/(driver)/driver/settings/password-form";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { requireDriverAccount } from "@/lib/dal/profile";

export default async function DriverSettingsPage() {
  const accountResult = await requireDriverAccount();

  if (!accountResult.ok) {
    handleAuthBoundaryFailure(accountResult.error);
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader
        title="Settings"
        description="Manage your account security."
      />
      <Card
        header={<h2 className="text-h3 text-foreground">Change password</h2>}
      >
        <PasswordForm />
      </Card>
    </div>
  );
}
