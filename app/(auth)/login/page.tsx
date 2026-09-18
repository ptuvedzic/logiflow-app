import { redirect } from "next/navigation";

import { LoginForm } from "@/app/(auth)/login/login-form";
import { Card } from "@/components/ui/card";
import { Container } from "@/components/ui/container";
import { getRoleHome } from "@/lib/auth/role-home";
import { requireProfile } from "@/lib/dal/auth";

export default async function LoginPage() {
  const profileResult = await requireProfile();

  if (profileResult.ok) {
    if (!profileResult.data.isActive) {
      redirect("/account-inactive");
    }

    redirect(getRoleHome(profileResult.data.role));
  }

  switch (profileResult.error.category) {
    case "unauthenticated":
      break;
    case "missing_profile":
      redirect("/account-error");
    case "inactive_profile":
      redirect("/account-inactive");
    case "forbidden":
      redirect("/forbidden");
    case "infrastructure":
      throw new Error("Unable to verify account access.");
  }

  return (
    <main className="flex min-h-screen items-center bg-background-app py-8">
      <Container className="mx-auto max-w-[460px]">
        <Card>
          <div className="flex flex-col gap-6">
            <div className="flex flex-col gap-2 text-center">
              <h1 className="text-h2 text-foreground">Welcome back</h1>
              <p className="text-small text-secondary">
                Sign in with your company account.
              </p>
            </div>

            <LoginForm />

            <p className="text-small text-secondary">
              Contact your administrator if you cannot access your account.
            </p>
          </div>
        </Card>
      </Container>
    </main>
  );
}
