import { ResourceCategory } from "@/lib/types";

export interface TrainingResourceItem {
  title: string;
  content: string;
  linkUrl?: string;
  tags?: string[];
}

export const outreachSections: Array<{
  category: ResourceCategory;
  title: string;
  description: string;
  copyable?: boolean;
}> = [
  {
    category: "start_here",
    title: "1. Start Here",
    description: "Beginner-friendly onboarding for how to work as an Intellium Digital outreach researcher."
  },
  {
    category: "daily_workflow",
    title: "2. Daily Workflow",
    description: "The exact operating flow from lead discovery to handoff and commission."
  },
  {
    category: "target_niches",
    title: "3. Target Niches",
    description: "Playbooks by niche so researchers know what to look for, what to recommend, and what to avoid."
  },
  {
    category: "qualification",
    title: "4. Lead Qualification",
    description: "What qualifies as a submit-worthy lead and what should be ignored."
  },
  {
    category: "scoring",
    title: "5. Lead Scoring",
    description: "Simple 1 to 5 lead scoring so admin can prioritize strong opportunities."
  },
  {
    category: "scripts",
    title: "6. Approved Scripts",
    description: "General client-facing scripts in English and Taglish. Personalize the first line only.",
    copyable: true
  },
  {
    category: "niche_scripts",
    title: "7. Niche-Based Scripts",
    description: "Short, detailed, follow-up, and pricing-transition scripts by niche.",
    copyable: true
  },
  {
    category: "objection_replies",
    title: "8. Objection Replies",
    description: "Professional responses for common concerns without overpromising or negotiating.",
    copyable: true
  },
  {
    category: "pricing",
    title: "9. Pricing Replies",
    description: "Researcher-safe pricing guidance, pricing transitions, and quote framing.",
    copyable: true
  },
  {
    category: "images",
    title: "10. Image Usage Guide",
    description: "Which promo images to send, when to send them, and how to keep image usage aligned with the offer."
  },
  {
    category: "handoff",
    title: "11. Handoff Process",
    description: "When to stop messaging and how to hand warm leads to Intellium Digital correctly."
  },
  {
    category: "commission",
    title: "12. Commission Rules",
    description: "Commission policy, qualification rules, and payout conditions."
  },
  {
    category: "daily_report",
    title: "13. Daily Report Format",
    description: "A clean report template researchers can copy and submit every day.",
    copyable: true
  },
  {
    category: "dos_donts",
    title: "14. Do's and Don'ts",
    description: "Behavior rules that protect the brand, the client relationship, and your commission."
  },
  {
    category: "faq",
    title: "15. FAQ for Researchers",
    description: "Fast answers to common outreach questions so researchers can keep moving."
  }
];

export const fallbackResourceContent: Record<ResourceCategory, TrainingResourceItem[]> = {
  start_here: [
    {
      title: "Start Here: How to Work as an Intellium Digital Outreach Researcher",
      tags: ["Onboarding", "Required Reading"],
      content: `Your role:
You are a commission-based outreach researcher for Intellium Digital. Your job is to find local businesses that need a more credible digital presence, start a professional first conversation, and submit strong leads through the portal with proof.

Your goal:
Find real businesses that have visible digital problems and a realistic chance of buying services such as branding, websites, booking flows, payment-ready setup, SEO, automation, inquiry forms, launch graphics, and business apps.

What kind of clients to find:
- Active businesses with Facebook, Instagram, TikTok, Google Maps, LinkedIn, Marketplace, or local directory presence
- Owners or contact persons who can be reached directly
- Businesses that look like they care about image, growth, leads, bookings, or customer trust
- Businesses that still look unstructured online and can benefit from professional setup

What problems to look for:
- No website
- Weak branding or inconsistent visuals
- Rates, menus, packages, or offers are scattered in posts
- No inquiry form, booking form, or quote form
- No payment-ready page or clear payment process
- Customers keep asking the same questions in comments or messages
- Business looks active but not professionally presented

What services to recommend:
- Branding / Logo / Cover Photo for weak visual trust
- Starter Website for businesses with no website but simple needs
- Business Website for businesses needing multiple pages and stronger credibility
- Website + Payment-Ready Setup for businesses selling packages, reservations, or appointments
- Full Digital Business Setup for businesses that need a bigger digital cleanup
- Business App Development for larger workflows or custom operational needs
- Automation / Inquiry Forms when the business needs lead capture or process improvement

How commission works:
- You are commission-based only
- Commission is counted only after the client successfully pays Intellium Digital
- The lead must be submitted in the portal
- Screenshot or proof of conversation is required
- Duplicate, fake, refunded, or unpaid leads do not qualify

What not to do:
- Do not spam
- Do not argue with business owners
- Do not promise guaranteed sales
- Do not promise guaranteed Maya, PayMongo, or payment provider approval
- Do not collect payments
- Do not negotiate final pricing without approval
- Do not close technical discussions yourself
- Do not submit fake or duplicate leads

How to submit leads properly:
1. Verify the business is real and active.
2. Identify the digital problem clearly.
3. Score the lead honestly.
4. Send an approved script and keep proof.
5. Submit the lead through the portal with complete details.
6. If the client becomes interested, stop negotiating and hand off to Intellium Digital.

Mindset:
You are not trying to pressure businesses. You are trying to identify businesses that are already losing trust, leads, or operational efficiency because their digital presence is weak.`
    }
  ],
  daily_workflow: [
    {
      title: "Find -> Check -> Score -> Message -> Report -> Follow Up -> Handoff -> Earn",
      tags: ["Workflow", "Daily System"],
      content: `Find:
Search where business owners already promote themselves or interact with customers.
Best places to search:
- Facebook groups
- Facebook pages
- Instagram
- TikTok
- Google Maps
- LinkedIn
- Marketplace
- Local directories

Look for businesses that are active but digitally unstructured.

Check:
Review the business before messaging.
Check:
- page quality
- branding consistency
- website presence
- service presentation
- booking flow
- inquiry flow
- contact options
- payment readiness
- customer questions in comments

Score:
Use the 1 to 5 scoring guide.
Only submit leads that score 3 out of 5 or higher.

Message:
Send the approved script.
Rules:
- personalize the first line
- keep the tone professional and friendly
- do not over-explain in the first message
- do not send too many messages at once

Report:
Once a lead is qualified or contacted, report it through the portal.
Include:
- business details
- problem found
- recommended service
- score
- reply status
- proof upload
- notes

Follow Up:
If there is no reply, follow up after 24 to 48 hours.
Only send one clean follow-up unless the business keeps the conversation going.

Handoff:
The moment the client asks for pricing, samples, how to start, budget, payment, or a call, hand off the lead to Intellium Digital.
Do not keep negotiating after the client becomes warm.

Earn:
Commission is earned only when:
- the lead is real
- the lead is not a duplicate
- the lead is submitted with proof
- the client successfully pays Intellium Digital

Daily standard:
Find carefully, check properly, score honestly, message professionally, report cleanly, and hand off quickly.`
    },
    {
      title: "Where to Search and What to Notice Fast",
      tags: ["Sourcing", "Research"],
      content: `Facebook groups:
Look for people posting offers, packages, rates, bookings, and promotions without a clean landing page.

Facebook pages:
Look for active pages with comments, inquiries, or shared customer questions.

Instagram:
Find businesses with strong activity but weak profile structure, no link strategy, or no clear service funnel.

TikTok:
Look for businesses getting attention but sending traffic only to DMs instead of a clean inquiry or booking flow.

Google Maps:
Look for real active businesses with minimal digital assets beyond a listing.

LinkedIn:
Best for freelancers, consultants, agents, and service professionals who need stronger authority online.

Marketplace:
Useful for sellers and service businesses that clearly need better structure and trust-building.

Local directories:
Helpful for spotting active businesses with outdated branding or no proper digital home.

Quick-win signs:
- Customers are asking the same questions repeatedly
- Pricing or rates are hard to find
- Booking steps are unclear
- The owner is active but presentation is weak
- The business is already promoting but lacks structure`
    }
  ],
  target_niches: [
    {
      title: "Motor Rentals",
      tags: ["Motor Rentals", "High Fit"],
      content: `What to look for:
- Active rental posts
- Requirements answered repeatedly in comments
- Rates scattered across posts
- No website or booking inquiry page

Common problems:
- No website
- Rates are scattered
- No booking form
- No requirements page
- Customers keep asking the same questions

Best service to recommend:
- Website + booking inquiry form
- Website + payment-ready setup

Best script to use:
Use the motor rental niche script and lead with clarity around rates, requirements, and booking steps.

Best promo image to send:
- Cebu Alamos client spotlight
- Website + booking flow poster
- Payment-ready promo

Sample opening line:
"I saw your rental business and noticed customers may need a clearer place to view rates, requirements, and booking steps."

Lead quality signs:
- Active page
- Frequent inquiries
- Multiple units or serious operations
- Owner replies to customers

Red flags:
- No recent activity
- Fake or copied listings
- No clear contact person
- Page looks abandoned`
    },
    {
      title: "Car Rentals",
      tags: ["Car Rentals", "High Ticket"],
      content: `What to look for:
- Car rental fleets or frequent booking posts
- Professional intent but messy online presentation
- Page sends everyone to inbox manually

Common problems:
- No trust-building website
- No clean fleet presentation
- No quote or reservation form
- No clear process for requirements and availability

Best service to recommend:
- Business Website
- Website + payment-ready setup

Best script to use:
Position the offer around credibility, reservation flow, and cleaner presentation for serious clients.

Best promo image to send:
- Website + booking flow poster
- Payment-ready promo
- General services poster

Sample opening line:
"I checked your car rental page and noticed a cleaner site for fleet viewing, inquiries, and booking steps could make the business look much more established."

Lead quality signs:
- Real fleet photos
- Active inquiries
- Business caters to travelers, events, or airport traffic

Red flags:
- No proof the business is active
- Personal-only profile with no real business presence
- Obvious duplicate of another rental brand`
    },
    {
      title: "Salons / Spas",
      tags: ["Beauty", "Booking"],
      content: `What to look for:
- Active posts with services, promos, or transformations
- Clients booking manually through chat
- No service menu page or booking structure

Common problems:
- Weak branding
- No service menu page
- No booking page
- No professional gallery or offer presentation

Best service to recommend:
- Branding
- Starter Website
- Booking-focused website

Best script to use:
Lead with professionalism, easier appointment booking, and stronger visual credibility.

Best promo image to send:
- Booking website poster
- Professional online presence poster
- Branding poster

Sample opening line:
"Your salon already has services people want. A more polished online setup could make booking and trust much easier for new clients."

Lead quality signs:
- Regular promos
- Visible customer activity
- Real before-and-after results
- Clearly service-based business

Red flags:
- No active posting
- Unclear if still operating
- No reachable contact`
    },
    {
      title: "Clinics",
      tags: ["Clinic", "Trust"],
      content: `What to look for:
- Medical, dental, aesthetic, therapy, or wellness clinic pages
- Appointment inquiries happening through DMs only
- Trust and professionalism gaps online

Common problems:
- No proper clinic website
- No inquiry or booking flow
- Weak service presentation
- No strong credibility-building assets

Best service to recommend:
- Business Website
- Booking / inquiry form setup
- Branding cleanup

Best script to use:
Keep the tone highly professional and centered on trust, clarity, and appointments.

Best promo image to send:
- Booking website poster
- Professional presence poster
- Branding poster

Sample opening line:
"I checked your clinic page and noticed a stronger digital setup for services, inquiries, and appointments could help the brand look more established and easier to trust."

Lead quality signs:
- Real clinic photos
- Active bookings or service posts
- Multiple services or specialists

Red flags:
- No verified business signals
- Inactive page
- No owner or manager contact`
    },
    {
      title: "Real Estate Agents",
      tags: ["Real Estate", "Personal Brand"],
      content: `What to look for:
- Agents posting listings consistently
- No personal brand website
- Leads are handled only through messages

Common problems:
- No personal brand authority page
- No inquiry form
- Listings disappear in the feed
- No structured lead capture

Best service to recommend:
- Personal brand website
- Lead form setup
- Full digital setup

Best script to use:
Frame the offer around authority, lead capture, and a more credible brand presence.

Best promo image to send:
- Personal brand website poster
- Lead form poster
- Full digital setup poster

Sample opening line:
"You already post listings consistently. A professional site with inquiry flow and a stronger personal brand could help turn that activity into more organized leads."

Lead quality signs:
- Consistent listing activity
- Visible client-facing professionalism
- Higher-ticket positioning

Red flags:
- Page is inactive
- No clear professional identity
- Fake listings or copied materials`
    },
    {
      title: "Food Businesses",
      tags: ["Food", "Menu"],
      content: `What to look for:
- Cafes, home-based sellers, restaurants, meal services, or food brands
- Customers asking for menu, price, location, or order process repeatedly

Common problems:
- No menu page
- No order form or inquiry page
- Weak promo presentation
- Offers buried in old posts

Best service to recommend:
- Starter Website
- Menu website
- Promo graphics

Best script to use:
Lead with clearer menu presentation, easier inquiries, and stronger trust.

Best promo image to send:
- Menu website poster
- Promo graphics poster
- Starter website poster

Sample opening line:
"I noticed customers may benefit from a cleaner place to view your menu, promos, and order steps instead of scrolling through older posts."

Lead quality signs:
- Active posting
- Comment activity
- Repeat promos or recurring offers

Red flags:
- No evidence the business is active
- Fake product photos
- No reachable business owner`
    },
    {
      title: "Freelancers",
      tags: ["Freelancers", "Portfolio"],
      content: `What to look for:
- Designers, photographers, editors, VA agencies, developers, coaches, consultants
- Strong skill but weak online packaging

Common problems:
- No portfolio site
- Weak personal branding
- No service page
- No client inquiry form

Best service to recommend:
- Portfolio website
- Branding
- Service page setup

Best script to use:
Position the offer around credibility, professionalism, and easier client conversion.

Best promo image to send:
- Portfolio website poster
- Branding poster
- Service page poster

Sample opening line:
"You clearly have services to offer. A stronger digital presence could help package your work more professionally and make inquiries easier to convert."

Lead quality signs:
- Consistent service posts
- Clear niche
- Strong work samples

Red flags:
- Hobby-only page
- No real client-facing activity
- No budget potential`
    },
    {
      title: "Tutorial Centers",
      tags: ["Education", "Enrollment"],
      content: `What to look for:
- Enrollment posts
- Parent inquiries in comments
- Schedule, rates, and programs shared manually

Common problems:
- No enrollment page
- No inquiry form
- No structured program presentation
- Weak trust-building online presence

Best service to recommend:
- Starter Website
- Inquiry form setup
- Business Website

Best script to use:
Focus on making programs, schedules, and inquiries easier for parents or students.

Best promo image to send:
- Starter website poster
- Inquiry form poster
- Professional presence poster

Sample opening line:
"I noticed a cleaner site for your programs, schedules, and inquiries could make it easier for parents or students to understand what you offer quickly."

Lead quality signs:
- Active enrollments
- Parent or student questions
- Clear educational offer

Red flags:
- Inactive page
- No real business identity
- No reachable contact`
    },
    {
      title: "Repair Shops",
      tags: ["Repair", "Local Service"],
      content: `What to look for:
- Repair service offers
- Frequent inquiries about rates, location, and turnaround time
- No proper service overview online

Common problems:
- No service website
- No pricing page
- No inquiry form
- Weak branding

Best service to recommend:
- Starter Website
- Service website
- Inquiry form setup

Best script to use:
Frame the offer around trust, clarity, and easier inquiries for service-based customers.

Best promo image to send:
- Service website poster
- Pricing page poster
- Inquiry form poster

Sample opening line:
"I checked your repair service page and noticed a cleaner setup for services, inquiries, and customer trust could make your business look much more established."

Lead quality signs:
- Active local demand
- Real service photos
- Customers asking about rates or process

Red flags:
- No current activity
- Unclear if the shop still operates
- No business contact person`
    },
    {
      title: "Local Stores",
      tags: ["Retail", "Local"],
      content: `What to look for:
- Physical or community-based stores
- Products posted manually with no structured browsing or inquiry flow

Common problems:
- No product page or inquiry flow
- Weak branding
- No clear promo or catalog structure
- Business relies only on casual posting

Best service to recommend:
- Starter Website
- Inquiry form
- Branding

Best script to use:
Position the offer around visibility, trust, and easier inquiry handling.

Best promo image to send:
- Starter website poster
- All-in-one service menu
- Inquiry form poster

Sample opening line:
"Your store already has products people can buy. A cleaner digital setup could help present them more professionally and make customer inquiries easier."

Lead quality signs:
- Regular posting
- Customer engagement
- Visible inventory or offers

Red flags:
- No real business proof
- No contact person
- Inactive or copied page`
    },
    {
      title: "General Service Businesses",
      tags: ["General", "Flexible Fit"],
      content: `What to look for:
- Home services, maintenance, events, printing, consulting, logistics, and other service-based businesses
- Businesses that are active but still manually handling everything through chat

Common problems:
- No website
- Weak branding
- No inquiry form
- No structured service page
- No clear trust-building assets

Best service to recommend:
- Starter Website
- Business Website
- Full digital setup

Best script to use:
Use a general script focused on credibility, clear services, and easier inquiries.

Best promo image to send:
- All-in-one service menu
- Starter website poster
- Full digital setup poster

Sample opening line:
"I checked your business presence and noticed a stronger digital setup could help present your services more clearly and make customer inquiries easier to manage."

Lead quality signs:
- Real business activity
- Clear service offer
- Reachable owner or staff

Red flags:
- Fake-looking page
- No active business signs
- No real budget potential`
    }
  ],
  qualification: [
    {
      title: "Good Lead Signs",
      tags: ["Qualification", "Submit These"],
      content: `A good lead usually has several of these signs:
- no website
- weak branding
- active Facebook or Instagram page
- messy service or rate posts
- no booking form
- no inquiry form
- no payment-ready page
- no clear service menu
- no professional landing page
- owner is contactable
- business is active
- business looks like it can afford services
- customers are commenting or asking questions
- business posts promos but lacks structure

Why these matter:
The best lead is not just a business with problems. It is a business that is active, reachable, and likely to care about fixing those problems.`
    },
    {
      title: "Bad Lead Signs and Submission Rule",
      tags: ["Qualification", "Avoid These"],
      content: `Do not prioritize these:
- inactive page
- fake business
- no contact person
- no budget potential
- already has a strong website and branding
- rude or clearly uninterested owner
- duplicate lead
- no proof of conversation

Submission rule:
Only submit leads that are:
1. real
2. active
3. reachable
4. supported by proof
5. scored at 3 out of 5 or higher

If you are unsure:
Do not guess. Add notes, compare with the checklist, and ask admin before forcing a weak lead into the portal.`
    }
  ],
  scoring: [
    {
      title: "Lead Scoring Guide: 1 to 5",
      tags: ["Scoring", "Required"],
      content: `Give 1 point for each of the following:
1 point - no website
1 point - weak branding
1 point - active business page
1 point - clear product or service offer
1 point - looks like they can afford services

Score meaning:
1 out of 5 = weak lead, do not submit
2 out of 5 = low priority
3 out of 5 = qualified lead
4 out of 5 = strong lead
5 out of 5 = high-priority lead

Submission rule:
Only 3 out of 5 or higher should be submitted.

How to use this well:
- Score based on evidence, not assumptions
- A business can be active and still be a weak lead if there is no buying potential
- A business can have no website but still be low-priority if the business looks inactive or unreachable
- Use notes to explain why you scored the lead the way you did`
    }
  ],
  scripts: [
    {
      title: "1. Generic Outreach",
      tags: ["General", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, I checked {{business_name}} and noticed there may be an opportunity to improve how the business is presented online. Intellium Digital helps businesses build a more credible digital presence through branding, websites, inquiry forms, booking flows, payment-ready setup, and automation. If you're open, I can share what stood out and the most practical next step.

Taglish:
Hi {{owner_name}}, na-check ko ang {{business_name}} and mukhang may opportunity to improve how the business is presented online. Intellium Digital helps businesses build a more credible digital presence through branding, websites, inquiry forms, booking flows, payment-ready setup, and automation. If open kayo, I can share what stood out and the most practical next step.`
    },
    {
      title: "2. No Website",
      tags: ["No Website", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, I noticed {{business_name}} does not have a dedicated website yet. A clean website can help customers quickly see your services, rates, inquiry steps, and contact details without relying only on posts or chat. Intellium Digital can help set that up if this is something you're considering.

Taglish:
Hi {{owner_name}}, napansin ko na wala pang dedicated website ang {{business_name}}. A clean website can help customers quickly see your services, rates, inquiry steps, and contact details instead of relying lang sa posts or chat. Intellium Digital can help set that up if kino-consider ninyo ito.`
    },
    {
      title: "3. Weak Branding",
      tags: ["Branding", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, I checked your page and it looks like the business could benefit from stronger branding to build more trust at first glance. Clearer visuals and a more polished online presence can make the business look more established and easier to remember.

Taglish:
Hi {{owner_name}}, na-check ko ang page ninyo and mukhang makakatulong ang stronger branding to build more trust at first glance. Clearer visuals and a more polished online presence can make the business look more established and easier to remember.`
    },
    {
      title: "4. Only Facebook Page",
      tags: ["Facebook Only", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, I noticed the business mainly relies on Facebook right now. That works for activity, but a proper website or landing page can make your business look more credible and give customers one clear place to view services, inquiries, and next steps.

Taglish:
Hi {{owner_name}}, napansin ko na Facebook mainly ang gamit ng business right now. Useful iyon for activity, pero a proper website or landing page can make the business look more credible and give customers one clear place to view services, inquiries, and next steps.`
    },
    {
      title: "5. Needs Booking Form",
      tags: ["Booking", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, I noticed customers may need an easier way to book or inquire instead of messaging manually every time. A booking page or inquiry form can save time and make the process clearer for new customers.

Taglish:
Hi {{owner_name}}, napansin ko na customers may need an easier way to book or inquire instead of messaging manually every time. A booking page or inquiry form can save time and make the process clearer for new customers.`
    },
    {
      title: "6. Needs Payment-Ready Page",
      tags: ["Payment-Ready", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, if customers usually ask how to reserve or pay, a payment-ready page can help make your process more organized and professional. Intellium Digital helps businesses set up cleaner digital flows for inquiries, bookings, and payment preparation.

Taglish:
Hi {{owner_name}}, if customers usually ask how to reserve or pay, a payment-ready page can help make your process more organized and professional. Intellium Digital helps businesses set up cleaner digital flows for inquiries, bookings, and payment preparation.`
    },
    {
      title: "7. Needs Full Digital Setup",
      tags: ["Full Setup", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, I checked your online presence and it looks like the business could benefit from a full digital cleanup rather than just one small update. Branding, website structure, inquiry flow, and customer presentation can all work together to make the business look more credible and easier to convert.

Taglish:
Hi {{owner_name}}, na-check ko ang online presence ninyo and mukhang the business could benefit from a full digital cleanup rather than one small update lang. Branding, website structure, inquiry flow, and customer presentation can work together to make the business look more credible and easier to convert.`
    },
    {
      title: "8. Follow-Up After No Reply",
      tags: ["Follow-Up", "English + Taglish"],
      content: `English:
Hi {{owner_name}}, just following up in case my last message got buried. I reached out because {{business_name}} looks like it has strong potential, and a cleaner digital setup could help make your services easier to present and inquire about. If helpful, I can send a quick suggestion.

Taglish:
Hi {{owner_name}}, quick follow-up lang in case natabunan ang last message ko. I reached out because {{business_name}} looks like it has strong potential, and a cleaner digital setup could help make your services easier to present and inquire about. If helpful, I can send a quick suggestion.`
    },
    {
      title: "9. Follow-Up After Interest",
      tags: ["Warm Lead", "English + Taglish"],
      content: `English:
Thanks for the reply. I can hand this over to the Intellium Digital team so they can review your needs properly and recommend the best-fit setup based on your business goals.

Taglish:
Thanks for the reply. I can hand this over to the Intellium Digital team so they can review your needs properly and recommend the best-fit setup based on your business goals.`
    },
    {
      title: "10. Pricing Inquiry",
      tags: ["Pricing", "English + Taglish"],
      content: `English:
Pricing depends on the scope, pages, features, design, and integrations needed, but Intellium Digital has starter options for different business stages. If you want, I can endorse you to the team so they can give the most accurate recommendation based on what you need.

Taglish:
Pricing depends on the scope, pages, features, design, and integrations needed, pero may starter options ang Intellium Digital for different business stages. If you want, I can endorse you to the team para maibigay nila ang most accurate recommendation based on what you need.`
    },
    {
      title: "11. Budget Inquiry",
      tags: ["Budget", "English + Taglish"],
      content: `English:
If you already have a target budget in mind, that helps the team recommend the most practical option first. Even a rough range is useful so they can suggest the best next step without overshooting.

Taglish:
If may target budget na kayo in mind, malaking help iyon para ma-recommend ng team ang most practical option first. Kahit rough range lang, useful iyon so they can suggest the best next step without overshooting.`
    },
    {
      title: "12. Handoff to Intellium Digital",
      tags: ["Handoff", "English + Taglish"],
      content: `English:
I'll hand this over to the Intellium Digital team now so they can assist you properly with pricing, samples, and the best-fit setup for your business. I'll include the context from our conversation so you don't have to repeat everything.

Taglish:
Iha-hand off ko na ito sa Intellium Digital team so they can assist you properly with pricing, samples, and the best-fit setup for your business. Isasama ko ang context from our conversation para hindi na ninyo ulitin lahat.`
    },
    {
      title: "13. Soft Closing Message",
      tags: ["Soft Close", "English + Taglish"],
      content: `English:
If you'd like, the team can take a closer look and recommend the most practical setup based on your business right now. No pressure. The goal is just to match the solution to what actually makes sense for you.

Taglish:
If you'd like, the team can take a closer look and recommend the most practical setup based on your business right now. No pressure. Ang goal lang is to match the solution to what actually makes sense for you.`
    },
    {
      title: "14. Not Interested Reply",
      tags: ["Graceful Exit", "English + Taglish"],
      content: `English:
No problem at all. Thanks for taking the time to reply. If you ever want to improve your digital presence later on, feel free to reach out and I'd be happy to point you to the right team.

Taglish:
No problem at all. Thanks sa pag-reply. If ever gusto ninyong i-improve ang digital presence ninyo later on, feel free to reach out and I’d be happy to point you to the right team.`
    },
    {
      title: "15. Thank You Message",
      tags: ["Courtesy", "English + Taglish"],
      content: `English:
Thank you for your time, {{owner_name}}. I'll make sure the team receives the details clearly so they can assist you properly.

Taglish:
Thank you for your time, {{owner_name}}. I’ll make sure na ma-receive ng team ang details clearly so they can assist you properly.`
    }
  ],
  niche_scripts: [
    {
      title: "1. Motor Rental Owners",
      tags: ["Motor Rentals"],
      content: `Short version:
Hi {{owner_name}}, I saw your motor rental business and noticed customers may need a clearer place to view rates, requirements, and booking steps.

Detailed version:
Hi {{owner_name}}, I checked your motor rental page and noticed the business could benefit from a cleaner digital setup where customers can quickly view rates, requirements, inquiry steps, and booking details without asking the same questions repeatedly.

Follow-up version:
Just following up in case my last message got buried. A cleaner website or inquiry flow could make the rental process easier for your customers and less repetitive for your team.

Pricing transition:
If you're interested, I can endorse you to the Intellium Digital team so they can recommend the most practical setup and pricing based on your rental process.`
    },
    {
      title: "2. Car Rental Owners",
      tags: ["Car Rentals"],
      content: `Short version:
Hi {{owner_name}}, I checked your car rental page and noticed a cleaner setup for fleet viewing, inquiries, and reservation steps could help the business look more established.

Detailed version:
Your business already has real service potential. A stronger site for fleet presentation, trust-building, and booking inquiries can make the business feel more premium and easier to transact with.

Follow-up version:
Following up in case the message got buried. A proper digital setup could help make reservations and fleet presentation much more organized for serious clients.

Pricing transition:
If helpful, I can pass you to the Intellium Digital team so they can share the best-fit option depending on your pages, booking flow, and requirements.`
    },
    {
      title: "3. Salon / Spa Owners",
      tags: ["Salons", "Spas"],
      content: `Short version:
Hi {{owner_name}}, your salon already has services people want. A cleaner booking and service presentation could help build more trust and make appointments easier.

Detailed version:
I checked your page and noticed that a more polished online setup for services, promos, portfolio, and bookings could make the business look more established and easier for new clients to understand quickly.

Follow-up version:
Quick follow-up. A booking page or cleaner service menu can help reduce manual back-and-forth and support a more premium brand feel.

Pricing transition:
If you want, I can hand this over to the Intellium Digital team so they can suggest the best setup based on your current branding and booking needs.`
    },
    {
      title: "4. Clinic Owners",
      tags: ["Clinics"],
      content: `Short version:
Hi {{owner_name}}, I noticed your clinic could benefit from a stronger digital setup for trust, services, and appointment inquiries.

Detailed version:
For clinics, clear credibility and easy inquiry flow matter a lot. A more professional online setup can help present services better and make it easier for patients to reach out properly.

Follow-up version:
Just following up. A cleaner digital presence for services, appointments, and patient inquiries could help your clinic look more established online.

Pricing transition:
If useful, I can endorse you to the Intellium Digital team so they can recommend the right scope based on your clinic’s services and appointment flow.`
    },
    {
      title: "5. Real Estate Agents",
      tags: ["Real Estate"],
      content: `Short version:
Hi {{owner_name}}, you already post listings consistently. A stronger personal brand site and lead form setup could help organize inquiries better.

Detailed version:
A professional digital presence can help position you more credibly, keep listings from getting buried in the feed, and give interested clients a cleaner place to inquire.

Follow-up version:
Following up. A personal brand website with lead capture can help turn listing activity into more structured inquiries.

Pricing transition:
If you'd like, I can pass this to the Intellium Digital team so they can recommend the most practical setup based on your listings and lead flow.`
    },
    {
      title: "6. Food Business Owners",
      tags: ["Food Businesses"],
      content: `Short version:
Hi {{owner_name}}, I noticed customers may benefit from a cleaner place to view your menu, promos, and order steps.

Detailed version:
Your food business already looks active. A menu-focused site or inquiry setup can make ordering, promo viewing, and customer trust much easier than relying only on posts.

Follow-up version:
Quick follow-up. A cleaner menu and inquiry flow can help reduce repeat questions and make ordering feel more organized.

Pricing transition:
If you're open, I can hand this over to the Intellium Digital team so they can recommend the best option based on your menu, promos, and ordering process.`
    },
    {
      title: "7. Freelancers",
      tags: ["Freelancers"],
      content: `Short version:
Hi {{owner_name}}, your work looks valuable. A stronger digital presence could help package it more professionally and make inquiries easier.

Detailed version:
Many freelancers lose trust and leads because their work is good but their online presentation is too fragmented. A portfolio or service page can help turn that into a more credible client experience.

Follow-up version:
Following up. A simple but professional portfolio or service site can help make your offers easier to understand and easier to inquire about.

Pricing transition:
If you want, I can connect you with the Intellium Digital team so they can recommend the right portfolio or branding setup for your current stage.`
    },
    {
      title: "8. Repair Shops",
      tags: ["Repair Shops"],
      content: `Short version:
Hi {{owner_name}}, I checked your repair service page and noticed a clearer service and inquiry setup could help customers trust the business more quickly.

Detailed version:
For repair shops, customers usually want fast clarity on services, location, rates, and process. A stronger digital setup can make that much easier than relying only on chat or scattered posts.

Follow-up version:
Quick follow-up. A cleaner site or inquiry flow can make your repair services look more established and easier to understand.

Pricing transition:
If helpful, I can endorse you to the Intellium Digital team so they can suggest the most practical setup based on your repair services and inquiry volume.`
    },
    {
      title: "9. Tutorial Centers",
      tags: ["Tutorial Centers"],
      content: `Short version:
Hi {{owner_name}}, I noticed a cleaner page for your programs, schedules, and inquiries could help parents or students understand the offer faster.

Detailed version:
Tutorial centers often benefit from a clearer digital setup because schedules, programs, rates, and inquiries can get messy when everything is handled through posts alone.

Follow-up version:
Following up. A structured inquiry or enrollment page can make it easier for parents and students to understand your programs and next steps.

Pricing transition:
If you want, I can hand this over to the Intellium Digital team so they can recommend the best setup based on your programs and enrollment flow.`
    },
    {
      title: "10. Local Stores",
      tags: ["Local Stores"],
      content: `Short version:
Hi {{owner_name}}, your store already has products people can buy. A cleaner digital setup could help present them more professionally.

Detailed version:
For local stores, a stronger online setup can help with trust, product presentation, promos, and customer inquiries instead of relying only on scattered posts or chat.

Follow-up version:
Quick follow-up. A simple website or inquiry page can make your store feel more organized and easier for customers to explore.

Pricing transition:
If helpful, I can connect you with the Intellium Digital team so they can suggest the most practical setup based on your products and customer flow.`
    }
  ],
  objection_replies: [
    {
      title: "I already have a Facebook page.",
      content: `A Facebook page is useful for activity, but a dedicated website or landing page gives customers one clear place for your services, inquiry steps, and trust-building information. The goal is not to replace Facebook. The goal is to make your overall digital presence stronger and more credible.`
    },
    {
      title: "I do not need a website.",
      content: `That makes sense if the current setup is already working well for you. The reason I reached out is that a website or structured inquiry page can help reduce repeated questions, make the business look more established, and give customers a cleaner path to understand your offer. If ever you revisit it later, the team can guide you properly.`
    },
    {
      title: "Maybe next time.",
      content: `No problem. Timing matters. If you want, I can leave this with the team so they can reconnect only when the timing is better for you.`
    },
    {
      title: "Is this legit?",
      content: `Yes. Intellium Digital works on helping businesses improve their digital presence through branding, websites, inquiry systems, booking flows, payment-ready setup, and related digital assets. If you want samples or a proper discussion, I can hand you directly to the team.`
    },
    {
      title: "Do you have samples?",
      content: `Yes, the team can share relevant samples depending on your business type and the service you may need. I can hand this over so you get the proper examples instead of generic ones.`
    },
    {
      title: "Will I get more customers?",
      content: `A stronger digital setup can improve clarity, trust, and customer experience, but no one should promise guaranteed sales. What the team can do is recommend a setup that helps the business present itself more professionally and convert inquiries more efficiently.`
    },
    {
      title: "How long does it take?",
      content: `That depends on the scope, pages, features, and assets required. The team can give a more accurate timeline after understanding what setup fits your business best.`
    },
    {
      title: "What do I need to provide?",
      content: `Usually the team will ask for your business details, logo or branding files if available, service information, content references, and any special features you want. They can guide you step by step once they assess the project properly.`
    },
    {
      title: "I’ll think about it.",
      content: `That’s completely fine. If you want, I can still pass your details to the team so they can be ready to assist once you decide the timing is right.`
    },
    {
      title: "Send details.",
      content: `Sure. Intellium Digital helps businesses build a more credible digital presence through branding, websites, inquiry forms, booking flows, payment-ready setup, SEO, automation, launch graphics, and business apps. If you want, I can hand you to the team so they can share the most relevant details for your business instead of sending something too generic.`
    }
  ],
  pricing: [
    {
      title: "Researcher Pricing Guide",
      tags: ["Pricing", "Reference Only"],
      content: `Branding / Logo / Cover Photo:
Starts at PHP 3,500+

Starter Website:
Starts at PHP 5,000

Business Website:
Starts at PHP 10,000+

Website + Payment-Ready Setup:
Promo at PHP 18,000

Full Digital Business Setup:
Starts at PHP 25,000+

Business App Development:
Starts at PHP 35,000+

Automation / Inquiry Forms:
Custom quote

Important explanation:
Final pricing depends on:
- number of pages
- features
- design complexity
- content needs
- integrations
- timeline
- business requirements

Researcher rule:
Use pricing as a reference only.
Do not negotiate final pricing without admin approval.`
    },
    {
      title: "Pricing Replies and Safe Transitions",
      tags: ["Pricing Replies", "Copyable"],
      content: `How much?
"Pricing depends on the scope, features, and business requirements, but Intellium Digital has starter options for different business stages. If you want, I can endorse you to the team so they can recommend the most accurate option."

Too expensive.
"Understood. The team usually recommends based on what is most practical for the business right now, not just the biggest package. If helpful, I can let them know you'd prefer the most cost-efficient option first."

Can you lower the price?
"Final pricing and package adjustments are handled only by the Intellium Digital team after they review the scope properly. I can hand this over so they can assess what setup makes the most sense."

Can I pay later?
"Payment terms and project handling are discussed by the Intellium Digital team directly. I can pass this to them so they can explain the proper next steps."

Can I pay installment?
"That depends on the project and approval from the team. I can hand this over so they can advise you properly."

Is Maya or PayMongo approval guaranteed?
"No one should promise guaranteed Maya, PayMongo, or payment provider approval. What the team can do is help prepare a more professional setup and guide the process based on the project requirements."

Pricing transition:
"To avoid giving you incomplete information, I’d rather hand this to the Intellium Digital team so they can recommend the right scope and pricing based on your actual business needs."`
    }
  ],
  images: [
    {
      title: "Image Usage Rules",
      tags: ["Images", "Compliance"],
      content: `Use images to support the conversation, not to overwhelm the lead.

Use images only when:
- the business asks for more info
- the lead is warm or curious
- the image directly matches the problem you identified

Do not:
- spam multiple posters at once
- send random images unrelated to the business
- edit pricing into images without approval
- make fake before-and-after claims
- use images that promise guaranteed results

Best practice:
1. Send one strong image first.
2. Add one sentence explaining why it is relevant.
3. If the lead asks for more, then send a second supporting image.`
    },
    {
      title: "Image Categories Researchers Should Send",
      tags: ["Images", "Asset Guide"],
      content: `Image categories:
1. General services poster
2. Starter website poster
3. Website + payment-ready promo
4. Full digital setup poster
5. Business app development poster
6. Cebu Alamos client spotlight
7. Service menu / pricing poster
8. Before vs after digital presence poster

How to choose:
- Use general services poster for broad interest
- Use starter website poster for businesses with no website
- Use payment-ready promo when the business handles reservations or payments
- Use full digital setup poster when the business has multiple digital issues
- Use business app development poster only for larger or more custom operational cases
- Use client spotlight when social proof is needed
- Use service menu poster when the lead asks what Intellium Digital offers
- Use before vs after poster only if it is approved and accurate`
    },
    {
      title: "By Niche: Best Images to Send",
      tags: ["Images", "Niche Matching"],
      content: `Motor and car rentals:
- Cebu Alamos client spotlight
- website + booking flow poster
- payment-ready promo

Salons and clinics:
- booking website poster
- professional online presence poster
- branding poster

Food businesses:
- menu website poster
- promo graphics poster
- starter website poster

Real estate:
- personal brand website poster
- lead form poster
- full digital setup poster

Freelancers:
- portfolio website poster
- branding poster
- service page poster

Repair shops and local stores:
- service website poster
- pricing page poster
- inquiry form poster

General businesses:
- all-in-one service menu
- starter website poster
- full digital setup poster`
    }
  ],
  handoff: [
    {
      title: "When Researchers Must Hand Off",
      tags: ["Handoff", "Required"],
      content: `Hand off immediately when the client:
- asks for pricing
- asks for samples
- says interested
- asks how to start
- mentions budget
- wants a call
- wants payment details
- asks technical questions

Why:
Researchers should qualify and warm the lead, not close the deal alone.

Researchers should not:
- close deals by themselves
- collect payments
- promise discounts
- promise technical deliverables without approval
- answer high-risk payment provider questions with certainty`
    },
    {
      title: "Handoff Format",
      tags: ["Handoff", "Template"],
      content: `Business Name:
Business Type:
Location:
Business Link:
Owner / Contact Name:
Problem Found:
Recommended Service:
Lead Score:
Client Interest Level:
Budget Mentioned:
Screenshot / Proof:
Suggested Next Step:

Handoff note:
Keep the handoff short, factual, and complete. The goal is to let the Intellium Digital team continue the conversation without losing context.`
    },
    {
      title: "Suggested Next Step Examples",
      tags: ["Handoff", "Examples"],
      content: `Suggested Next Step examples:
- Client is interested in a starter website. Team should send best-fit recommendation and sample flow.
- Client asked for pricing and timeline. Team should assess scope and respond directly.
- Client mentioned budget and wants to start soon. Team should qualify scope and recommend the fastest practical package.
- Client wants a call. Team should take over scheduling and next-step handling.`
    }
  ],
  commission: [
    {
      title: "Detailed Commission Policy",
      tags: ["Commission", "Policy"],
      content: `Commission structure:
- commission-based only
- no base salary
- commission is paid only after client successfully pays
- lead must be submitted through the portal
- proof of conversation is required
- duplicate leads do not qualify
- fake leads do not qualify
- unpaid inquiries do not qualify
- refunded projects may void commission
- final commission approval is done by Intellium Digital admin
- researchers are not allowed to collect client payments

Important:
Warm interest is not the same as earned commission.
Commission is tied to verified, paid business outcomes, not just conversation volume.`
    },
    {
      title: "Commission Table",
      tags: ["Commission", "Reference"],
      content: `Branding client:
PHP 300 to PHP 500

Starter Website PHP 5,000:
PHP 500

Business Website PHP 10,000+:
PHP 1,000

Website + Payment Setup PHP 18,000:
PHP 2,000

Full Digital Setup PHP 25,000+:
PHP 3,000

App Development PHP 35,000+:
PHP 4,000 to PHP 5,000

Final note:
Final commission amount may vary within the approved range depending on project scope and admin approval.`
    }
  ],
  daily_report: [
    {
      title: "Daily Outreach Report Template",
      tags: ["Template", "Copy Daily"],
      content: `DAILY OUTREACH REPORT
Researcher Name:
Date:
Niche Focus:
Businesses Found:
Qualified Leads:
Messages Sent:
Replies Received:
Interested Leads:
Follow-Ups Done:
Best Lead Today:
Issues / Questions:
Notes:`
    },
    {
      title: "How to Use the Daily Report",
      tags: ["Reporting"],
      content: `Keep the report practical.

Businesses Found:
How many businesses you reviewed

Qualified Leads:
How many scored 3 out of 5 or higher

Messages Sent:
Actual first-message outreach count

Replies Received:
Any response, including not interested

Interested Leads:
Only those who showed real buying signals

Issues / Questions:
Use this section to flag blockers, confusing client questions, or cases where you need admin guidance.`
    }
  ],
  dos_donts: [
    {
      title: "Do's",
      tags: ["Rules", "Positive"],
      content: `Do:
- personalize the first line
- check the business before messaging
- focus on real business problems
- use only approved scripts and claims
- keep your tone respectful and concise
- submit complete proof and notes
- follow up after 24 to 48 hours if there is no reply
- hand off warm leads quickly
- ask admin when unsure`
    },
    {
      title: "Don'ts",
      tags: ["Rules", "Prohibited"],
      content: `Do not:
- spam business owners
- argue in comments or inbox
- promise guaranteed sales
- promise guaranteed Maya, PayMongo, or provider approval
- negotiate final pricing
- promise discounts
- collect payments
- submit fake leads
- submit duplicate leads
- keep negotiating after a client becomes warm
- answer technical implementation questions with confidence if you are not the delivery team`
    }
  ],
  faq: [
    {
      title: "How do I know if a lead is qualified?",
      content: `Use the qualification checklist and the 1 to 5 scoring guide. A lead should be real, active, reachable, backed by proof, and score 3 out of 5 or higher.`
    },
    {
      title: "What if the business already has a website?",
      content: `Check whether the website is strong enough. If it is outdated, unclear, unprofessional, missing inquiry flow, missing booking flow, or weak in trust-building, the business may still be a valid lead.`
    },
    {
      title: "Can I message international businesses?",
      content: `Prioritize businesses that fit Intellium Digital's current outreach direction and can realistically be handled by the team. If you are unsure about a market, ask admin first.`
    },
    {
      title: "Can I negotiate price?",
      content: `No. Researchers should not negotiate final pricing without approval. Hand pricing conversations to Intellium Digital.`
    },
    {
      title: "Can I collect payment?",
      content: `No. Researchers must never collect client payments.`
    },
    {
      title: "When do I get paid?",
      content: `Commission is considered only after the client successfully pays Intellium Digital and the lead is validated by admin.`
    },
    {
      title: "What proof do I need?",
      content: `Upload screenshot or proof of the conversation, plus complete lead details and notes inside the portal.`
    },
    {
      title: "What if two researchers submit the same lead?",
      content: `Duplicate leads do not qualify. Admin will review timestamps, proof, and lead history.`
    },
    {
      title: "What if the client replies after a week?",
      content: `Continue professionally, update the portal, and hand off once the lead becomes warm or asks the right buying questions.`
    },
    {
      title: "What if the client asks for a discount?",
      content: `Do not promise discounts. Pass the conversation to the Intellium Digital team.`
    },
    {
      title: "What if the client asks for samples?",
      content: `Acknowledge the request and hand off to the team so they can share the right samples for that niche or scope.`
    },
    {
      title: "What if the client asks about Maya or PayMongo approval?",
      content: `Do not promise guaranteed approval. Tell them the team can guide the setup and explain the process, but payment provider approval is not guaranteed.`
    },
    {
      title: "What if I am not sure what service to recommend?",
      content: `Recommend based on the clearest visible problem. If unsure, submit the lead with notes or ask admin before overcommitting. It is better to be accurate than overly confident.`
    }
  ]
};

export const defaultChecklistItems = [
  "Review the Start Here and Daily Workflow sections before first outreach.",
  "Verify business activity, contactability, and proof before every submission.",
  "Submit only leads that score 3 out of 5 or higher.",
  "Use approved scripts and hand off warm leads quickly.",
  "Finish the day with a portal update and daily outreach report."
];

export const targetClients = [
  "Motor rentals",
  "Car rentals",
  "Salons",
  "Clinics",
  "Real estate agents",
  "Food businesses",
  "Freelancers",
  "Small service businesses",
  "Tutorial centers",
  "Repair shops",
  "Local stores"
];

export const recommendedServices = [
  "Branding",
  "Starter Website",
  "Business Website",
  "Website + Payment Setup",
  "Full Digital Setup",
  "App Development",
  "Automation / Inquiry Forms"
];
