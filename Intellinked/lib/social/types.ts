export type AccountTypeLabel =
  | "Professional"
  | "Business"
  | "Freelancer"
  | "Customer";

export type PostCallToAction = "Connect" | "Message" | "View Service";

export type CommentView = {
  id: string;
  userId: string;
  authorName: string;
  authorSlug?: string;
  content: string;
  timestamp: string;
  canDelete: boolean;
};

export type FeedPostView = {
  id: string;
  userId: string;
  authorName: string;
  authorType: AccountTypeLabel;
  authorSlug?: string;
  businessSlug?: string;
  businessName?: string;
  content: string;
  category: string;
  timestamp: string;
  likes: number;
  comments: number;
  shares: number;
  cta: PostCallToAction;
  likedByViewer: boolean;
  canDelete: boolean;
  commentsList: CommentView[];
  businessProfileId?: string | null;
};

export type ProfileView = {
  id: string;
  userId: string;
  slug: string;
  username: string | null;
  fullName: string;
  role: string;
  authorType: Exclude<AccountTypeLabel, "Business">;
  focusCategory: string;
  location: string;
  bio: string;
  skills: string[];
  contactPreference: string;
  websiteUrl: string | null;
  isPublic: boolean;
  isAdmin: boolean;
  isOwn: boolean;
  isFollowing: boolean;
  stats: {
    followers: number;
    posts: number;
    services: number;
  };
};

export type BusinessView = {
  id: string;
  userId: string;
  slug: string;
  businessName: string;
  category: string;
  location: string;
  description: string;
  servicesOffered: string[];
  contactEmail: string | null;
  contactPhone: string | null;
  website: string | null;
  facebook: string | null;
  isPublic: boolean;
  isOwn: boolean;
  isFollowing: boolean;
  stats: {
    followers: number;
    services: number;
    posts: number;
  };
};

export type ServiceListingView = {
  id: string;
  userId: string;
  businessProfileId: string | null;
  title: string;
  providerName: string;
  providerType: AccountTypeLabel;
  providerSlug?: string;
  businessSlug?: string;
  businessName?: string;
  category: string;
  location: string;
  summary: string;
  price: string;
  availability: string;
  tags: string[];
  isOwned: boolean;
  isPublic: boolean;
  isActive: boolean;
};

export type NotificationView = {
  id: string;
  title: string;
  detail: string;
  time: string;
  type: string;
  isRead: boolean;
};

export type ModerationReportView = {
  id: string;
  status: "Pending" | "In Review" | "Resolved" | "Dismissed";
  rawStatus: "pending" | "in_review" | "resolved" | "dismissed";
  target: string;
  reason: string;
  submittedBy: string;
  time: string;
  notes: string;
};

export type BlockedProfileView = {
  userId: string;
  displayName: string;
  username: string | null;
};

export type ViewerWorkspace = {
  userId: string;
  profileId: string;
  displayName: string;
  username: string | null;
  accountType: AccountTypeLabel;
  location: string;
  bio: string;
  websiteUrl: string | null;
  isPublic: boolean;
  isAdmin: boolean;
};
