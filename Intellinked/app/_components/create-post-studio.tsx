"use client";

import { useState } from "react";

import { GhostLink, Pill, PostCard, Surface } from "@/app/_components/ui";
import type {
  AuthorType,
  Category,
  FeedPost,
  PostCallToAction,
} from "@/app/_data/mock-data";
import { businesses, categories, people } from "@/app/_data/mock-data";

const authorTypes: AuthorType[] = [
  "Professional",
  "Business",
  "Freelancer",
  "Customer",
];

const ctaOptions: PostCallToAction[] = ["Connect", "Message", "View Service"];

export function CreatePostStudio() {
  const [authorType, setAuthorType] = useState<AuthorType>("Professional");
  const [category, setCategory] = useState<Category>("Digital services");
  const [cta, setCta] = useState<PostCallToAction>("Connect");
  const [content, setContent] = useState(
    "I am looking to connect with Filipino founders, freelancers, and community builders who want faster collaboration and clearer local opportunities.",
  );

  const previewPerson = people.find((person) => person.authorType === authorType) ?? people[0];
  const previewBusiness = businesses[0];
  const previewName =
    authorType === "Business" ? previewBusiness.businessName : previewPerson.fullName;

  const previewPost: FeedPost = {
    id: "preview-post",
    authorName: previewName,
    authorType,
    authorSlug: authorType === "Business" ? undefined : previewPerson.slug,
    businessSlug: authorType === "Business" ? previewBusiness.slug : undefined,
    businessName: authorType === "Business" ? previewBusiness.businessName : undefined,
    content,
    category,
    timestamp: "Preview",
    likes: 24,
    comments: 6,
    shares: 2,
    cta,
  };

  return (
    <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
      <Surface>
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="font-heading text-2xl font-semibold text-white">Create a post</h2>
            <p className="mt-2 text-sm leading-7 text-muted">
              Keep this local-first and practical. The real composer can plug into live storage later.
            </p>
          </div>
          <Pill active>Mock publish only</Pill>
        </div>

        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          <label className="space-y-2 text-sm text-muted-strong">
            <span>Author type</span>
            <select
              value={authorType}
              onChange={(event) => setAuthorType(event.target.value as AuthorType)}
              className="input-shell w-full rounded-2xl px-4 py-3 text-white outline-none"
            >
              {authorTypes.map((option) => (
                <option key={option} value={option} className="bg-slate-950">
                  {option}
                </option>
              ))}
            </select>
          </label>

          <label className="space-y-2 text-sm text-muted-strong">
            <span>Primary category</span>
            <select
              value={category}
              onChange={(event) => setCategory(event.target.value as Category)}
              className="input-shell w-full rounded-2xl px-4 py-3 text-white outline-none"
            >
              {categories.map((option) => (
                <option key={option} value={option} className="bg-slate-950">
                  {option}
                </option>
              ))}
            </select>
          </label>
        </div>

        <label className="mt-4 block space-y-2 text-sm text-muted-strong">
          <span>Content</span>
          <textarea
            rows={7}
            value={content}
            onChange={(event) => setContent(event.target.value)}
            className="input-shell w-full rounded-[24px] px-4 py-4 text-white outline-none placeholder:text-muted"
            placeholder="Share what you offer, what you need, or what local opportunity you spotted."
          />
        </label>

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <div className="premium-card-soft rounded-[24px] p-4">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
              Preview author
            </p>
            <p className="mt-3 font-medium text-white">{previewName}</p>
            <p className="mt-2 text-sm leading-6 text-muted">
              {authorType === "Business"
                ? "Business post flow for announcements, offers, and service promotions."
                : previewPerson.contactPreference}
            </p>
          </div>
          <div className="premium-card-soft rounded-[24px] p-4">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-purple">
              Posting tip
            </p>
            <p className="mt-3 text-sm leading-6 text-muted-strong">
              Strong local posts usually explain who the offer is for, where it applies, and the clearest next action.
            </p>
            <p className="mt-3 text-xs text-muted">{content.length} characters</p>
          </div>
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          {ctaOptions.map((option) => (
            <button
              key={option}
              onClick={() => setCta(option)}
              className="rounded-full"
              type="button"
            >
              <Pill active={cta === option}>{option}</Pill>
            </button>
          ))}
        </div>

        <div className="mt-6 flex flex-wrap gap-3">
          <button
            type="button"
            className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:bg-cyan/18"
          >
            Save draft
          </button>
          <button
            type="button"
            className="rounded-full border border-border bg-white/4 px-5 py-3 text-sm font-medium text-muted-strong hover:text-white"
          >
            Publish later
          </button>
          <GhostLink href="/home">Back to feed</GhostLink>
        </div>
      </Surface>

      <div className="space-y-4">
        <Surface>
          <h3 className="font-heading text-xl font-semibold text-white">Live preview</h3>
          <p className="mt-2 text-sm leading-7 text-muted">
            This behaves like a modal composer presented as a full page for the MVP.
          </p>
        </Surface>
        <PostCard post={previewPost} />
      </div>
    </div>
  );
}
