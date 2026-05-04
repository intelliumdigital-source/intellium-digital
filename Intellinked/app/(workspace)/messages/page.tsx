import { MessageSquareDashed } from "lucide-react";

import { EmptyState, PageIntro, Pill, Surface } from "@/app/_components/ui";
import { conversations } from "@/app/_data/mock-data";

export default function MessagesPage() {
  return (
    <div className="space-y-6">
      <PageIntro
        eyebrow="Messages"
        title="Messaging is intentionally a placeholder in this MVP."
        description="Conversation previews are visible so the user journey feels complete, but real messaging is intentionally deferred."
      />

      <div className="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <Surface>
          <h2 className="font-heading text-2xl font-semibold text-white">Inbox preview</h2>
          <div className="mt-5 space-y-3">
            {conversations.map((conversation) => (
              <div
                key={conversation.id}
                className="premium-card-soft rounded-3xl p-4"
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="font-medium text-white">{conversation.name}</p>
                    <p className="mt-1 text-sm text-muted">{conversation.role}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-muted">{conversation.time}</p>
                    {conversation.unread > 0 ? (
                      <p className="mt-2 text-xs text-cyan">{conversation.unread} unread</p>
                    ) : null}
                  </div>
                </div>
                <p className="mt-3 text-sm leading-7 text-muted-strong">
                  {conversation.snippet}
                </p>
              </div>
            ))}
          </div>
        </Surface>

        <EmptyState
          title="Real-time messaging is not connected yet"
          description="This panel exists to complete the workflow and demonstrate where direct conversations will live once backend messaging is added."
        />
      </div>

      <Surface className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <MessageSquareDashed className="h-5 w-5 text-cyan" />
          <p className="text-sm text-muted-strong">
            Messaging UI is staged only. No chat persistence or delivery state is wired yet.
          </p>
        </div>
        <Pill active>Placeholder</Pill>
      </Surface>
    </div>
  );
}
