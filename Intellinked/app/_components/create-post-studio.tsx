"use client";

import { useState } from "react";

import { createPostAction } from "@/app/actions/workspace";
import { GhostLink, Pill, PostCard, Surface } from "@/app/_components/ui";
import { categories } from "@/app/_data/mock-data";
import type {
  AccountTypeLabel,
  FeedPostView,
  PostCallToAction,
  ViewerWorkspace,
} from "@/lib/social/types";

const authorTypes: AccountTypeLabel[] = [
  "Professional",
  "Business",
  "Freelancer",
  "Customer",
];

const ctaOptions: PostCallToAction[] = ["Connect", "Message", "View Service"];

export function CreatePostStudio({
  viewer,
  businessProfileId,
}: {
  viewer: ViewerWorkspace;
  businessProfileId: string | null;
}) {
  const initialAuthorType =
    viewer.accountType === "Business" && !businessProfileId
      ? "Professional"
      : viewer.accountType;
  const [authorType, setAuthorType] = useState<AccountTypeLabel>(initialAuthorType);
  const [category, setCategory] = useState<string>("Digital services");
  const [cta, setCta] = useState<PostCallToAction>("Connect");
  const [visibility, setVisibility] = useState<"public" | "followers" | "private">("public");
  const [content, setContent] = useState(
    "I am looking to connect with Filipino founders, freelancers, and community builders who want faster collaboration and clearer local opportunities.",
  );

  const previewPerson = {
    fullName: viewer.displayName,
    slug: viewer.username ?? viewer.userId,
    contactPreference:
      viewer.websiteUrl && viewer.websiteUrl.length > 0
        ? `Best reached through ${viewer.websiteUrl}.`
        : "Open to local opportunities, direct service inquiries, and profile conversations.",
  };
  const previewBusiness = {
    businessName: viewer.displayName,
    slug: businessProfileId ?? "business-profile",
  };
  const previewName =
    authorType === "Business" ? previewBusiness.businessName : previewPerson.fullName;

  const previewPost: FeedPostView = {
    id: "preview-post",
    userId: viewer.userId,
    authorName: previewName,
    authorType,
    authorSlug: authorType === "Business" ? undefined : previewPerson.slug,
    businessSlug:
      authorType === "Business" && businessProfileId ? previewBusiness.slug : undefined,
    businessName:
      authorType === "Business" && businessProfileId ? previewBusiness.businessName : undefined,
    content,
    category,
    timestamp: "Preview",
    likes: 24,
    comments: 6,
    shares: 2,
    cta,
    likedByViewer: false,
    canDelete: false,
    commentsList: [],
    businessProfileId,
  };

  return (
    <div className="grid gap-6 xl:grid-cols-[1.1fr_0.9fr]">
      <Surface>
        <div className="flex items-center justify-between gap-4">
          <div>
            <h2 className="font-heading text-2xl font-semibold text-white">Create a post</h2>
            <p className="mt-2 text-sm leading-7 text-muted">
              Publish directly to Supabase while keeping the premium full-page composer flow intact.
            </p>
          </div>
          <Pill active>Live publish</Pill>
        </div>

        <form action={createPostAction} className="mt-6">
          <input
            type="hidden"
            name="business_profile_id"
            value={authorType === "Business" ? businessProfileId ?? "" : ""}
          />
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="space-y-2 text-sm text-muted-strong">
              <span>Author type</span>
              <select
                name="author_type"
                value={authorType}
                onChange={(event) => setAuthorType(event.target.value as AccountTypeLabel)}
                className="input-shell w-full rounded-2xl px-4 py-3 text-white outline-none"
              >
                {authorTypes.map((option) => (
                  <option
                    key={option}
                    value={option}
                    className="bg-slate-950"
                    disabled={option === "Business" && !businessProfileId}
                  >
                    {option}
                  </option>
                ))}
              </select>
            </label>

            <label className="space-y-2 text-sm text-muted-strong">
              <span>Primary category</span>
              <select
                name="category"
                value={category}
                onChange={(event) => setCategory(event.target.value)}
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
              name="content"
              rows={7}
              value={content}
              onChange={(event) => setContent(event.target.value)}
              className="input-shell w-full rounded-[24px] px-4 py-4 text-white outline-none placeholder:text-muted"
              placeholder="Share what you offer, what you need, or what local opportunity you spotted."
            />
          </label>

          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <label className="space-y-2 text-sm text-muted-strong">
              <span>Visibility</span>
              <select
                name="visibility"
                value={visibility}
                onChange={(event) =>
                  setVisibility(event.target.value as "public" | "followers" | "private")
                }
                className="input-shell w-full rounded-2xl px-4 py-3 text-white outline-none"
              >
                <option value="public" className="bg-slate-950">
                  Public
                </option>
                <option value="followers" className="bg-slate-950">
                  Followers only
                </option>
                <option value="private" className="bg-slate-950">
                  Private
                </option>
              </select>
            </label>
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
          </div>

          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            <div className="premium-card-soft rounded-[24px] p-4">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-purple">
                Posting tip
              </p>
              <p className="mt-3 text-sm leading-6 text-muted-strong">
                Strong local posts usually explain who the offer is for, where it applies, and the clearest next action.
              </p>
              <p className="mt-3 text-xs text-muted">{content.length} characters</p>
            </div>
            <div className="premium-card-soft rounded-[24px] p-4">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan">
                CTA
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
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
              <input type="hidden" name="cta" value={cta} />
            </div>
          </div>

          <div className="mt-6 flex flex-wrap gap-3">
            <button
              type="submit"
              className="rounded-full border border-cyan/30 bg-cyan/12 px-5 py-3 text-sm font-semibold text-cyan hover:bg-cyan/18"
            >
              Publish post
            </button>
            <GhostLink href="/home">Back to feed</GhostLink>
          </div>
        </form>
      </Surface>

      <div className="space-y-4">
        <Surface>
          <h3 className="font-heading text-xl font-semibold text-white">Live preview</h3>
          <p className="mt-2 text-sm leading-7 text-muted">
            This behaves like a modal composer presented as a full page, but the publish action now writes into Supabase.
          </p>
        </Surface>
        <PostCard post={previewPost} />
      </div>
    </div>
  );
}
