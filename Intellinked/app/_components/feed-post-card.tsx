import Link from "next/link";
import {
  ArrowRight,
  Ban,
  CircleAlert,
  MessageSquareText,
  Share2,
  ThumbsUp,
  Trash2,
} from "lucide-react";

import {
  blockUserAction,
  createCommentAction,
  createReportAction,
  deleteCommentAction,
  deletePostAction,
  togglePostLikeAction,
} from "@/app/actions/workspace";
import { Pill, Surface } from "@/app/_components/ui";
import type { FeedPostView } from "@/lib/social/types";

function formatCompact(value: number) {
  return new Intl.NumberFormat("en", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value);
}

function initials(value: string) {
  return value
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
}

export function FeedPostCard({ post }: { post: FeedPostView }) {
  const profileHref =
    post.authorType === "Business" && post.businessSlug
      ? `/businesses/${post.businessSlug}`
      : post.authorSlug
        ? `/people/${post.authorSlug}`
        : "/profile";
  const messageHref =
    post.authorType === "Business" && post.businessSlug
      ? `/messages?with=${post.businessSlug}`
      : post.authorSlug
        ? `/messages?with=${post.authorSlug}`
        : "/messages";
  const serviceHref =
    post.businessName || post.authorName
      ? `/services?q=${encodeURIComponent(post.businessName ?? post.authorName)}`
      : "/services";
  const ctaHref =
    post.cta === "Message"
      ? messageHref
      : post.cta === "View Service"
        ? serviceHref
        : profileHref;

  return (
    <Surface className="flex flex-col gap-5">
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-start gap-4">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-cyan/20 via-blue/20 to-purple/25 font-semibold text-white">
            {initials(post.authorName)}
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <Link href={profileHref} className="font-semibold text-white hover:text-cyan">
                {post.authorName}
              </Link>
              <Pill>{post.authorType}</Pill>
              <Pill>{post.category}</Pill>
            </div>
            <p className="mt-2 text-sm text-muted">
              {post.businessName ? `${post.businessName} | ` : ""}
              {post.timestamp}
            </p>
          </div>
        </div>

        <div className="flex flex-wrap gap-2">
          <form action={createReportAction}>
            <input type="hidden" name="target_type" value="post" />
            <input type="hidden" name="target_id" value={post.id} />
            <input type="hidden" name="reported_user_id" value={post.userId} />
            <input type="hidden" name="reason" value="Misleading or inappropriate post" />
            <button className="rounded-full border border-border bg-white/4 px-3 py-2 text-xs text-muted-strong hover:text-white">
              Report
            </button>
          </form>
          <form action={blockUserAction}>
            <input type="hidden" name="blocked_user_id" value={post.userId} />
            <button className="rounded-full border border-border bg-white/4 px-3 py-2 text-xs text-muted-strong hover:text-white">
              Block
            </button>
          </form>
        </div>
      </div>

      <p className="text-sm leading-7 text-muted-strong sm:text-[15px]">{post.content}</p>

      <div className="flex flex-wrap gap-3 text-sm text-muted">
        <span className="inline-flex items-center gap-2">
          <ThumbsUp className="h-4 w-4 text-cyan" />
          {formatCompact(post.likes)}
        </span>
        <span className="inline-flex items-center gap-2">
          <MessageSquareText className="h-4 w-4 text-blue" />
          {formatCompact(post.comments)}
        </span>
        <span className="inline-flex items-center gap-2">
          <Share2 className="h-4 w-4 text-purple" />
          {formatCompact(post.shares)}
        </span>
      </div>

      <div className="flex flex-wrap gap-2">
        <form action={togglePostLikeAction}>
          <input type="hidden" name="post_id" value={post.id} />
          <input type="hidden" name="author_user_id" value={post.userId} />
          <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
            <ThumbsUp className="h-4 w-4" />
            {post.likedByViewer ? "Unlike" : "Like"}
          </button>
        </form>
        <a
          href={`#comments-${post.id}`}
          className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white"
        >
          <MessageSquareText className="h-4 w-4" />
          Comment
        </a>
        <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-4 py-2 text-sm text-muted-strong hover:text-white">
          <Share2 className="h-4 w-4" />
          Share
        </button>
        {post.canDelete ? (
          <form action={deletePostAction}>
            <input type="hidden" name="post_id" value={post.id} />
            <button className="inline-flex items-center gap-2 rounded-full border border-danger/25 bg-danger/10 px-4 py-2 text-sm text-danger hover:text-white">
              <Trash2 className="h-4 w-4" />
              Delete
            </button>
          </form>
        ) : null}
        <Link
          href={ctaHref}
          className="ml-auto inline-flex min-h-11 items-center gap-2 rounded-full border border-cyan/30 bg-cyan/12 px-4 py-2 text-sm font-semibold text-cyan hover:-translate-y-0.5 hover:bg-cyan/18 hover:text-white"
        >
          {post.cta}
          <ArrowRight className="h-4 w-4" />
        </Link>
      </div>

      <div id={`comments-${post.id}`} className="space-y-3 border-t border-border/70 pt-4">
        <form action={createCommentAction} className="flex flex-col gap-3 sm:flex-row">
          <input type="hidden" name="post_id" value={post.id} />
          <input type="hidden" name="author_user_id" value={post.userId} />
          <input
            name="content"
            className="input-shell min-h-11 flex-1 rounded-full px-4 py-3 text-sm text-white outline-none placeholder:text-muted"
            placeholder="Add a comment"
          />
          <button
            type="submit"
            className="inline-flex min-h-11 items-center justify-center rounded-full border border-cyan/30 bg-cyan/12 px-4 py-3 text-sm font-semibold text-cyan hover:text-white"
          >
            Reply
          </button>
        </form>

        {post.commentsList.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-border bg-white/3 px-4 py-4 text-sm text-muted">
            No comments yet. Start the conversation.
          </div>
        ) : (
          post.commentsList.map((comment) => (
            <div
              key={comment.id}
              className="premium-card-soft rounded-3xl p-4"
            >
              <div className="flex items-start justify-between gap-4">
                <div>
                  <Link
                    href={comment.authorSlug ? `/people/${comment.authorSlug}` : "/profile"}
                    className="font-medium text-white hover:text-cyan"
                  >
                    {comment.authorName}
                  </Link>
                  <p className="mt-1 text-xs text-muted">{comment.timestamp}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <form action={createReportAction}>
                    <input type="hidden" name="target_type" value="comment" />
                    <input type="hidden" name="target_id" value={comment.id} />
                    <input type="hidden" name="reported_user_id" value={comment.userId} />
                    <input type="hidden" name="reason" value="Comment needs review" />
                    <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-3 py-2 text-xs text-muted-strong hover:text-white">
                      <CircleAlert className="h-3.5 w-3.5" />
                      Report
                    </button>
                  </form>
                  {comment.canDelete ? (
                    <form action={deleteCommentAction}>
                      <input type="hidden" name="comment_id" value={comment.id} />
                      <button className="inline-flex items-center gap-2 rounded-full border border-danger/25 bg-danger/10 px-3 py-2 text-xs text-danger hover:text-white">
                        <Trash2 className="h-3.5 w-3.5" />
                        Delete
                      </button>
                    </form>
                  ) : (
                    <form action={blockUserAction}>
                      <input type="hidden" name="blocked_user_id" value={comment.userId} />
                      <button className="inline-flex items-center gap-2 rounded-full border border-border bg-white/4 px-3 py-2 text-xs text-muted-strong hover:text-white">
                        <Ban className="h-3.5 w-3.5" />
                        Block
                      </button>
                    </form>
                  )}
                </div>
              </div>
              <p className="mt-3 text-sm leading-7 text-muted-strong">{comment.content}</p>
            </div>
          ))
        )}
      </div>
    </Surface>
  );
}
