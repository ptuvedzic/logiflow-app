import { Container } from "@/components/ui/container";
import { ErrorState } from "@/components/ui/error-state";

export default function ForbiddenPage() {
  return (
    <main className="flex min-h-screen items-center bg-background-app py-8">
      <Container className="mx-auto max-w-md">
        <ErrorState
          title="Access denied"
          description="You do not have permission to access this page."
        />
      </Container>
    </main>
  );
}
