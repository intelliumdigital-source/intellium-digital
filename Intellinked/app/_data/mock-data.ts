export type Category =
  | "Digital services"
  | "Rentals"
  | "Real estate"
  | "Insurance"
  | "Loans"
  | "Freelancers"
  | "Online sellers"
  | "Small businesses"
  | "Jobs and gigs";

export type AuthorType =
  | "Professional"
  | "Business"
  | "Freelancer"
  | "Customer";

export type PostCallToAction = "Connect" | "Message" | "View Service";

export type Person = {
  slug: string;
  fullName: string;
  role: string;
  authorType: Exclude<AuthorType, "Business">;
  location: string;
  bio: string;
  skills: string[];
  recentPostIds: string[];
  stats: {
    followers: number;
    connections: number;
    opportunities: number;
  };
};

export type Business = {
  slug: string;
  businessName: string;
  category: Category;
  location: string;
  description: string;
  servicesOffered: string[];
  contactDetails: string;
  website: string;
  facebook: string;
  recentPostIds: string[];
  stats: {
    followers: number;
    leads: number;
    responseRate: string;
  };
};

export type FeedPost = {
  id: string;
  authorName: string;
  authorType: AuthorType;
  authorSlug?: string;
  businessSlug?: string;
  businessName?: string;
  content: string;
  category: Category;
  timestamp: string;
  likes: number;
  comments: number;
  shares: number;
  cta: PostCallToAction;
};

export type ServiceListing = {
  id: string;
  title: string;
  providerName: string;
  providerType: AuthorType;
  providerSlug?: string;
  businessSlug?: string;
  businessName?: string;
  category: Category;
  location: string;
  summary: string;
  price: string;
  tags: string[];
};

export type NotificationItem = {
  id: string;
  title: string;
  detail: string;
  time: string;
  type: "Engagement" | "Lead" | "Moderation" | "Community";
};

export type ConversationPreview = {
  id: string;
  name: string;
  role: string;
  snippet: string;
  time: string;
  unread: number;
};

export type ModerationReport = {
  id: string;
  status: "Pending" | "Escalated" | "Resolved";
  target: string;
  reason: string;
  submittedBy: string;
  time: string;
  notes: string;
};

export const categories: Category[] = [
  "Digital services",
  "Rentals",
  "Real estate",
  "Insurance",
  "Loans",
  "Freelancers",
  "Online sellers",
  "Small businesses",
  "Jobs and gigs",
];

export const people: Person[] = [
  {
    slug: "mika-reyes",
    fullName: "Mika Reyes",
    role: "Brand Strategist",
    authorType: "Professional",
    location: "Makati City",
    bio: "Helping founders sharpen positioning, launch faster, and build credible community trust.",
    skills: ["Brand strategy", "Go-to-market", "Community building"],
    recentPostIds: ["post-1", "post-7"],
    stats: {
      followers: 1280,
      connections: 346,
      opportunities: 18,
    },
  },
  {
    slug: "carlo-santos",
    fullName: "Carlo Santos",
    role: "Freelance Web Developer",
    authorType: "Freelancer",
    location: "Cebu City",
    bio: "Building fast websites and lead funnels for SMEs that want more inbound bookings.",
    skills: ["Next.js", "E-commerce", "Automation"],
    recentPostIds: ["post-2", "post-8"],
    stats: {
      followers: 920,
      connections: 281,
      opportunities: 12,
    },
  },
  {
    slug: "jam-garcia",
    fullName: "Jam Garcia",
    role: "Community Partnerships Lead",
    authorType: "Professional",
    location: "Davao City",
    bio: "Connecting local providers, startups, and neighborhood communities to create practical wins.",
    skills: ["Partnerships", "Events", "Lead generation"],
    recentPostIds: ["post-4"],
    stats: {
      followers: 760,
      connections: 204,
      opportunities: 9,
    },
  },
  {
    slug: "trina-valdez",
    fullName: "Trina Valdez",
    role: "Property Advisor",
    authorType: "Professional",
    location: "Pasig City",
    bio: "Matching families and growing teams with practical real estate options and cleaner decision paths.",
    skills: ["Real estate", "Consultation", "Sales enablement"],
    recentPostIds: ["post-5"],
    stats: {
      followers: 688,
      connections: 167,
      opportunities: 7,
    },
  },
];

export const businesses: Business[] = [
  {
    slug: "intellium-digital",
    businessName: "Intellium Digital",
    category: "Digital services",
    location: "Metro Manila",
    description: "Growth-focused digital partner behind intellinked, supporting local-first businesses with modern branding, websites, and campaigns.",
    servicesOffered: [
      "Brand identity",
      "Social campaigns",
      "Web design and build",
      "Launch strategy",
    ],
    contactDetails: "hello@intelliumdigital.online | +63 917 801 4412",
    website: "https://intelliumdigital.online",
    facebook: "https://facebook.com/IntelliumDigitalPH",
    recentPostIds: ["post-3", "post-6"],
    stats: {
      followers: 2140,
      leads: 63,
      responseRate: "98%",
    },
  },
  {
    slug: "bayanihan-spaces",
    businessName: "Bayanihan Spaces",
    category: "Rentals",
    location: "Quezon City",
    description: "Flexible event, meeting, and pop-up spaces for creators, trainers, and community sellers.",
    servicesOffered: ["Studio rentals", "Workshop rooms", "Pop-up booths"],
    contactDetails: "bookings@bayanihanspaces.ph | +63 917 320 1040",
    website: "https://bayanihanspaces.ph",
    facebook: "https://facebook.com/BayanihanSpacesPH",
    recentPostIds: ["post-9"],
    stats: {
      followers: 987,
      leads: 21,
      responseRate: "94%",
    },
  },
  {
    slug: "luntian-realty-partners",
    businessName: "Luntian Realty Partners",
    category: "Real estate",
    location: "Taguig City",
    description: "Curated commercial and residential options with practical walkthrough support for local buyers and lessors.",
    servicesOffered: ["Commercial leasing", "Residential brokerage", "Property walkthroughs"],
    contactDetails: "team@luntianrealty.ph | +63 917 665 9934",
    website: "https://luntianrealty.ph",
    facebook: "https://facebook.com/LuntianRealtyPH",
    recentPostIds: ["post-10"],
    stats: {
      followers: 1156,
      leads: 27,
      responseRate: "96%",
    },
  },
];

export const services: ServiceListing[] = [
  {
    id: "service-1",
    title: "Launch-ready Website Sprint",
    providerName: "Carlo Santos",
    providerType: "Freelancer",
    providerSlug: "carlo-santos",
    category: "Freelancers",
    location: "Cebu City",
    summary: "A 10-day sprint for service businesses that need a premium website, inquiry flow, and booking CTA.",
    price: "Starts at PHP 28,000",
    tags: ["Next.js", "SEO-ready", "Lead forms"],
  },
  {
    id: "service-2",
    title: "Social Launch Campaign Kit",
    providerName: "Intellium Digital",
    providerType: "Business",
    businessSlug: "intellium-digital",
    businessName: "Intellium Digital",
    category: "Digital services",
    location: "Metro Manila",
    summary: "Brand messaging, campaign creatives, and launch execution for local-first offers and communities.",
    price: "Starts at PHP 45,000",
    tags: ["Campaign strategy", "Creative direction", "Reporting"],
  },
  {
    id: "service-3",
    title: "Weekend Pop-up Booth Rental",
    providerName: "Bayanihan Spaces",
    providerType: "Business",
    businessSlug: "bayanihan-spaces",
    businessName: "Bayanihan Spaces",
    category: "Rentals",
    location: "Quezon City",
    summary: "Compact pop-up booth package for sellers, makers, and small brand activations.",
    price: "PHP 6,500 / weekend",
    tags: ["Foot traffic", "Inclusions", "Flexible slots"],
  },
  {
    id: "service-4",
    title: "Commercial Property Matchmaking",
    providerName: "Trina Valdez",
    providerType: "Professional",
    providerSlug: "trina-valdez",
    category: "Real estate",
    location: "Pasig City",
    summary: "Shortlist commercial spaces that fit your foot traffic, lease budget, and operational needs.",
    price: "Consultation by arrangement",
    tags: ["Broker support", "Lease review", "Area scouting"],
  },
  {
    id: "service-5",
    title: "SME Protection Review",
    providerName: "Jam Garcia",
    providerType: "Professional",
    providerSlug: "jam-garcia",
    category: "Insurance",
    location: "Davao City",
    summary: "Review current protection gaps and find more practical coverage options for small teams and founders.",
    price: "Free discovery call",
    tags: ["Business insurance", "Risk review", "Comparisons"],
  },
  {
    id: "service-6",
    title: "Part-time Community Manager",
    providerName: "Mika Reyes",
    providerType: "Professional",
    providerSlug: "mika-reyes",
    category: "Jobs and gigs",
    location: "Makati City",
    summary: "Set up calendar, nurture members, and turn activity into leads for growing communities.",
    price: "Retainer from PHP 18,000",
    tags: ["Engagement", "Content ops", "Lead nurture"],
  },
];

export const feedPosts: FeedPost[] = [
  {
    id: "post-1",
    authorName: "Mika Reyes",
    authorType: "Professional",
    authorSlug: "mika-reyes",
    content: "Filipino founders do not need more noise. They need clearer offers, stronger proof, and a community that actually converts interest into trust.",
    category: "Digital services",
    timestamp: "12 minutes ago",
    likes: 126,
    comments: 18,
    shares: 9,
    cta: "Connect",
  },
  {
    id: "post-2",
    authorName: "Carlo Santos",
    authorType: "Freelancer",
    authorSlug: "carlo-santos",
    content: "Opening two website sprint slots for local service providers this month. Best fit: clinics, consultants, coaches, and real estate teams that need better lead capture.",
    category: "Freelancers",
    timestamp: "48 minutes ago",
    likes: 89,
    comments: 13,
    shares: 4,
    cta: "View Service",
  },
  {
    id: "post-3",
    authorName: "Intellium Digital",
    authorType: "Business",
    businessSlug: "intellium-digital",
    businessName: "Intellium Digital",
    content: "intellinked is being shaped as a local-first platform where business owners, professionals, and customers can promote, collaborate, and find the right opportunities faster.",
    category: "Small businesses",
    timestamp: "1 hour ago",
    likes: 214,
    comments: 25,
    shares: 17,
    cta: "Message",
  },
  {
    id: "post-4",
    authorName: "Jam Garcia",
    authorType: "Professional",
    authorSlug: "jam-garcia",
    content: "If you run events or workshops, I can connect you with neighborhood communities looking for practical learning sessions in Davao this quarter.",
    category: "Jobs and gigs",
    timestamp: "3 hours ago",
    likes: 64,
    comments: 11,
    shares: 5,
    cta: "Connect",
  },
  {
    id: "post-5",
    authorName: "Trina Valdez",
    authorType: "Professional",
    authorSlug: "trina-valdez",
    content: "Seeing more SMEs ask for flexible office options instead of long lease lock-ins. If you are scouting in Pasig or BGC, I can send a tight shortlist.",
    category: "Real estate",
    timestamp: "5 hours ago",
    likes: 58,
    comments: 7,
    shares: 3,
    cta: "Message",
  },
  {
    id: "post-6",
    authorName: "Intellium Digital",
    authorType: "Business",
    businessSlug: "intellium-digital",
    businessName: "Intellium Digital",
    content: "Building with mock data first keeps the product fast to iterate. We are focusing on cleaner networking flows before wiring live infrastructure.",
    category: "Digital services",
    timestamp: "Yesterday",
    likes: 141,
    comments: 16,
    shares: 12,
    cta: "View Service",
  },
  {
    id: "post-7",
    authorName: "Mika Reyes",
    authorType: "Professional",
    authorSlug: "mika-reyes",
    content: "Community-led growth works best when the first reply is fast, the first win is obvious, and the follow-up does not disappear after the sale.",
    category: "Small businesses",
    timestamp: "Yesterday",
    likes: 77,
    comments: 10,
    shares: 6,
    cta: "Connect",
  },
  {
    id: "post-8",
    authorName: "Carlo Santos",
    authorType: "Freelancer",
    authorSlug: "carlo-santos",
    content: "Any online sellers here who want a cleaner product catalog page and inquiry flow? Happy to swap notes and share what is working right now.",
    category: "Online sellers",
    timestamp: "2 days ago",
    likes: 92,
    comments: 15,
    shares: 8,
    cta: "Message",
  },
  {
    id: "post-9",
    authorName: "Bayanihan Spaces",
    authorType: "Business",
    businessSlug: "bayanihan-spaces",
    businessName: "Bayanihan Spaces",
    content: "Weekend booth schedule is almost full. We still have two high-footfall slots for small food, crafts, and lifestyle sellers.",
    category: "Rentals",
    timestamp: "2 days ago",
    likes: 112,
    comments: 9,
    shares: 14,
    cta: "View Service",
  },
  {
    id: "post-10",
    authorName: "Luntian Realty Partners",
    authorType: "Business",
    businessSlug: "luntian-realty-partners",
    businessName: "Luntian Realty Partners",
    content: "Newly listed compact commercial units for clinics, salons, and service brands wanting a more visible address in Taguig.",
    category: "Real estate",
    timestamp: "3 days ago",
    likes: 84,
    comments: 6,
    shares: 7,
    cta: "View Service",
  },
];

export const notifications: NotificationItem[] = [
  {
    id: "notification-1",
    title: "New connection request from Carlo Santos",
    detail: "Carlo wants to connect after viewing your service workflow post.",
    time: "9m ago",
    type: "Community",
  },
  {
    id: "notification-2",
    title: "Lead inquiry on Launch-ready Website Sprint",
    detail: "A Quezon City clinic asked for a timeline and package breakdown.",
    time: "31m ago",
    type: "Lead",
  },
  {
    id: "notification-3",
    title: "Post gained traction in Small businesses",
    detail: "Your latest thought piece is trending with founders in Metro Manila.",
    time: "1h ago",
    type: "Engagement",
  },
  {
    id: "notification-4",
    title: "Report reviewed by moderation",
    detail: "A misleading listing was marked for follow-up and hidden from discovery.",
    time: "4h ago",
    type: "Moderation",
  },
];

export const conversations: ConversationPreview[] = [
  {
    id: "conversation-1",
    name: "Mika Reyes",
    role: "Brand Strategist",
    snippet: "If you want, I can send a simple launch checklist for the campaign page.",
    time: "10:18 AM",
    unread: 2,
  },
  {
    id: "conversation-2",
    name: "Bayanihan Spaces",
    role: "Rentals",
    snippet: "We still have a Saturday afternoon slot if your pop-up needs a faster date.",
    time: "Yesterday",
    unread: 0,
  },
  {
    id: "conversation-3",
    name: "Jam Garcia",
    role: "Community Partnerships",
    snippet: "Can we align the workshop topic with freelance pricing and client acquisition?",
    time: "Yesterday",
    unread: 1,
  },
];

export const reports: ModerationReport[] = [
  {
    id: "report-1",
    status: "Pending",
    target: "Post: Weekend Pop-up Booth Rental",
    reason: "Possible duplicate listing and unclear pricing terms",
    submittedBy: "Alyssa M.",
    time: "22m ago",
    notes: "Needs verification before staying in the rentals category feed.",
  },
  {
    id: "report-2",
    status: "Escalated",
    target: "User: demo-finance-fastcash",
    reason: "Suspected misleading loan promotion",
    submittedBy: "R. Delos Reyes",
    time: "1h ago",
    notes: "High urgency because the post promises guaranteed approval with no checks.",
  },
  {
    id: "report-3",
    status: "Resolved",
    target: "Business: Luntian Realty Partners",
    reason: "Reported broken external link",
    submittedBy: "J. Lim",
    time: "Yesterday",
    notes: "Link fixed and re-reviewed.",
  },
];

export const platformStats = [
  { label: "Active members", value: "3,400+" },
  { label: "Service listings", value: "260+" },
  { label: "Local opportunities", value: "94 this week" },
  { label: "Response health", value: "97% monitored" },
];

export const communityPulse = [
  "Digital services and small business offers are leading activity this week.",
  "Members responding within 30 minutes are getting noticeably better connection rates.",
  "Real estate and rentals searches are climbing around Metro Manila and Cebu.",
];

export function getPersonBySlug(slug: string) {
  return people.find((person) => person.slug === slug);
}

export function getBusinessBySlug(slug: string) {
  return businesses.find((business) => business.slug === slug);
}

export function getPostsByIds(postIds: string[]) {
  return feedPosts.filter((post) => postIds.includes(post.id));
}
