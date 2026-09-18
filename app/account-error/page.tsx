import { Container } from "@/components/ui/container";
import { ErrorState } from "@/components/ui/error-state";

export default function AccountErrorPage() {
  return (
    <main className="flex min-h-screen items-center bg-background-app py-8">
      <Container className="mx-auto max-w-md">
        <ErrorState
          title="Account unavailable"
          description="Your account could not be accessed. Contact your administrator."
        />
      </Container>
    </main>
  );
}
