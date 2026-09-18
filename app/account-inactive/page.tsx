import { Container } from "@/components/ui/container";
import { ErrorState } from "@/components/ui/error-state";

export default function AccountInactivePage() {
  return (
    <main className="flex min-h-screen items-center bg-background-app py-8">
      <Container className="mx-auto max-w-md">
        <ErrorState
          title="Account inactive"
          description="Contact your administrator if you need access to your account."
        />
      </Container>
    </main>
  );
}
