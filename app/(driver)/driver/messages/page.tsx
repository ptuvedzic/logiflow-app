import { Mail } from "lucide-react";

import { handleAuthBoundaryFailure } from "@/app/_lib/handle-auth-boundary-failure";
import { MessageList } from "@/app/(driver)/driver/messages/message-list";
import { EmptyState } from "@/components/ui/empty-state";
import { PageHeader } from "@/components/ui/page-header";
import { getDriverMessages } from "@/lib/dal/messages";

export default async function DriverMessagesPage() {
  const result = await getDriverMessages();

  if (!result.ok) {
    handleAuthBoundaryFailure(result.error);
  }

  return (
    <div className="flex min-w-0 flex-col gap-4">
      <PageHeader title="Messages" />
      {result.data.length === 0 ? (
        <EmptyState
          icon={Mail}
          title="No messages"
          description="Operational messages sent to you will appear here."
        />
      ) : (
        <MessageList messages={result.data} />
      )}
    </div>
  );
}
