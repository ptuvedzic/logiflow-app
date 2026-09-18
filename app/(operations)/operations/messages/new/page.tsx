import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { Card } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { MessageForm } from "@/features/messages/message-form";
import { getMessageSendOptions } from "@/lib/dal/messages";

export default async function NewMessagePage() {
  const result = await getMessageSendOptions();

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader
        title="Send message"
        description="Send a one-way operational message to an eligible Driver."
      />
      <Card>
        <MessageForm recipients={result.data.recipients} shipments={result.data.shipments} />
      </Card>
    </div>
  );
}
