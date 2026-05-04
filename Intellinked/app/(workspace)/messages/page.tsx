import { MessageSquareDashed } from "lucide-react";

import { EmptyState, GhostLink, PageIntro, Pill, Surface } from "@/app/_components/ui";
import { conversations } from "@/app/_data/mock-data";

export default async function MessagesPage({
  searchParams,
}: {
  searchParams: Promise<{ with?: string }>;
}) {
  const params = await searchParams;
  const requestedSlug = params.with?.toLowerCase();
  const matchedConversation = conversations.find((conversation) =>
    conversation.name.toLowerCase().replaceAll(" ", "-").includes(requestedSlug ?? ""),
  );
  const fallbackConversation =
    requestedSlug && !matchedConversation
      ? {
          id: "conversation-requested",
          name: requestedSlug
            .split("-")
            .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
            .join(" "),
          role: "New contact",
          snippet:
            "This placeholder thread was opened from another page and will become a real conversation once messaging is connected.",
          time: "Draft",
          unread: 0,
        }
      : null;
  const selectedConversation =
    matchedConversation ?? fallbackConversation ?? conversations[0];

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
                className={`premium-card-soft rounded-3xl p-4 ${
                  conversation.id === selectedConversation.id ? "border-cyan/30 bg-cyan/8" : ""
                }`}
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

        <Surface>
          <div className="flex flex-col gap-4 border-b border-border/80 pb-5 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
                Selected conversation
              </p>
              <h2 className="mt-2 font-heading text-2xl font-semibold text-white">
                {selectedConversation.name}
              </h2>
              <p className="mt-2 text-sm text-muted">{selectedConversation.role}</p>
            </div>
            <GhostLink href="/profile">View sender profile</GhostLink>
          </div>

          <div className="mt-5 space-y-4">
            <div className="ml-auto max-w-md rounded-[24px] border border-cyan/20 bg-cyan/10 px-4 py-3 text-sm leading-7 text-cyan">
              Thanks for reaching out. I can share more details after the local demo review.
            </div>
            <div className="max-w-md rounded-[24px] border border-border bg-white/4 px-4 py-3 text-sm leading-7 text-muted-strong">
              {selectedConversation.snippet}
            </div>
            <div className="skeleton-bar h-16 w-3/4 rounded-[24px]" />
          </div>

          <div className="mt-6">
            <EmptyState
              eyebrow="Placeholder"
              title="Real-time messaging is not connected yet"
              description="This panel shows where threads, typing state, attachments, and delivery receipts will live once auth and database integration are added."
            />
          </div>
        </Surface>
      </div>

      <Surface className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
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
