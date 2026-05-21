create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('admin', 'researcher');
  end if;

  if not exists (select 1 from pg_type where typname = 'lead_status') then
    create type public.lead_status as enum (
      'Submitted',
      'Under Review',
      'Qualified',
      'Duplicate',
      'Contacted',
      'Interested',
      'Handoff',
      'Proposal Sent',
      'Closed Won',
      'Closed Lost',
      'Commission Pending',
      'Commission Paid'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'review_status') then
    create type public.review_status as enum ('pending', 'approved', 'rejected');
  end if;

  if not exists (select 1 from pg_type where typname = 'commission_status') then
    create type public.commission_status as enum ('Pending', 'Paid', 'Rejected');
  end if;

  if not exists (select 1 from pg_type where typname = 'resource_category') then
    create type public.resource_category as enum (
      'start_here',
      'daily_workflow',
      'target_niches',
      'scripts',
      'niche_scripts',
      'objection_replies',
      'pricing',
      'qualification',
      'scoring',
      'commission',
      'handoff',
      'images',
      'daily_report',
      'dos_donts',
      'faq'
    );
  end if;
end $$;

alter type public.resource_category add value if not exists 'start_here';
alter type public.resource_category add value if not exists 'daily_workflow';
alter type public.resource_category add value if not exists 'target_niches';
alter type public.resource_category add value if not exists 'scripts';
alter type public.resource_category add value if not exists 'niche_scripts';
alter type public.resource_category add value if not exists 'objection_replies';
alter type public.resource_category add value if not exists 'pricing';
alter type public.resource_category add value if not exists 'qualification';
alter type public.resource_category add value if not exists 'scoring';
alter type public.resource_category add value if not exists 'commission';
alter type public.resource_category add value if not exists 'handoff';
alter type public.resource_category add value if not exists 'images';
alter type public.resource_category add value if not exists 'daily_report';
alter type public.resource_category add value if not exists 'dos_donts';
alter type public.resource_category add value if not exists 'faq';

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text,
  role public.user_role not null default 'researcher',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  researcher_id uuid not null references public.profiles (id) on delete cascade,
  business_name text not null,
  business_type text not null,
  location text not null,
  business_link text,
  owner_contact_name text,
  has_website boolean not null default false,
  problem_found text not null,
  recommended_service text not null,
  lead_score integer not null check (lead_score between 0 and 100),
  message_sent boolean not null default false,
  reply_status text,
  interested boolean not null default false,
  budget_mentioned text,
  screenshot_path text not null,
  notes text,
  status public.lead_status not null default 'Submitted',
  review_status public.review_status not null default 'pending',
  normalized_business_name text not null,
  normalized_business_link text,
  submitted_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.commissions (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null unique references public.leads (id) on delete cascade,
  researcher_id uuid not null references public.profiles (id) on delete cascade,
  package_name text not null default '',
  project_amount numeric(12, 2),
  commission_amount numeric(12, 2),
  status public.commission_status not null default 'Pending',
  paid_date date,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.resource_items (
  id uuid primary key default gen_random_uuid(),
  category public.resource_category not null,
  title text not null,
  content text not null,
  link_url text,
  order_index integer not null default 0,
  is_published boolean not null default true,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  is_pinned boolean not null default false,
  is_published boolean not null default true,
  published_at timestamptz,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

insert into storage.buckets (id, name, public)
values ('lead-proofs', 'lead-proofs', false)
on conflict (id) do nothing;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
  );
$$;

grant usage on schema private to authenticated;
revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to authenticated;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists set_leads_updated_at on public.leads;
create trigger set_leads_updated_at
before update on public.leads
for each row
execute function public.set_updated_at();

drop trigger if exists set_commissions_updated_at on public.commissions;
create trigger set_commissions_updated_at
before update on public.commissions
for each row
execute function public.set_updated_at();

drop trigger if exists set_resource_items_updated_at on public.resource_items;
create trigger set_resource_items_updated_at
before update on public.resource_items
for each row
execute function public.set_updated_at();

drop trigger if exists set_announcements_updated_at on public.announcements;
create trigger set_announcements_updated_at
before update on public.announcements
for each row
execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.leads enable row level security;
alter table public.commissions enable row level security;
alter table public.resource_items enable row level security;
alter table public.announcements enable row level security;

alter table public.profiles force row level security;
alter table public.leads force row level security;
alter table public.commissions force row level security;
alter table public.resource_items force row level security;
alter table public.announcements force row level security;

drop policy if exists "profiles_select_self_or_admin" on public.profiles;
drop policy if exists "profiles_insert_self" on public.profiles;
drop policy if exists "profiles_insert_admin_only" on public.profiles;
drop policy if exists "profiles_update_admin_only" on public.profiles;

drop policy if exists "leads_select_self_or_admin" on public.leads;
drop policy if exists "leads_insert_self" on public.leads;
drop policy if exists "leads_update_admin_only" on public.leads;

drop policy if exists "commissions_select_self_or_admin" on public.commissions;
drop policy if exists "commissions_insert_admin_only" on public.commissions;
drop policy if exists "commissions_update_admin_only" on public.commissions;

drop policy if exists "resource_items_select_published_or_admin" on public.resource_items;
drop policy if exists "resource_items_insert_admin_only" on public.resource_items;
drop policy if exists "resource_items_update_admin_only" on public.resource_items;

drop policy if exists "announcements_select_published_or_admin" on public.announcements;
drop policy if exists "announcements_insert_admin_only" on public.announcements;
drop policy if exists "announcements_update_admin_only" on public.announcements;

drop policy if exists "lead_proofs_insert_own_or_admin" on storage.objects;
drop policy if exists "lead_proofs_select_own_or_admin" on storage.objects;
drop policy if exists "lead_proofs_update_admin_only" on storage.objects;
drop policy if exists "lead_proofs_delete_admin_only" on storage.objects;

create policy "profiles_select_self_or_admin"
on public.profiles
for select
to authenticated
using (auth.uid() = id or private.is_admin());

create policy "profiles_insert_self"
on public.profiles
for insert
to authenticated
with check (
  auth.uid() = id
  and role = 'researcher'
  and lower(email) = lower(auth.jwt() ->> 'email')
);

create policy "profiles_insert_admin_only"
on public.profiles
for insert
to authenticated
with check (private.is_admin());

create policy "profiles_update_admin_only"
on public.profiles
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "leads_select_self_or_admin"
on public.leads
for select
to authenticated
using (researcher_id = auth.uid() or private.is_admin());

create policy "leads_insert_self"
on public.leads
for insert
to authenticated
with check (researcher_id = auth.uid());

create policy "leads_update_admin_only"
on public.leads
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "commissions_select_self_or_admin"
on public.commissions
for select
to authenticated
using (researcher_id = auth.uid() or private.is_admin());

create policy "commissions_insert_admin_only"
on public.commissions
for insert
to authenticated
with check (private.is_admin());

create policy "commissions_update_admin_only"
on public.commissions
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "resource_items_select_published_or_admin"
on public.resource_items
for select
to authenticated
using (is_published = true or private.is_admin());

create policy "resource_items_insert_admin_only"
on public.resource_items
for insert
to authenticated
with check (private.is_admin());

create policy "resource_items_update_admin_only"
on public.resource_items
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "announcements_select_published_or_admin"
on public.announcements
for select
to authenticated
using (is_published = true or private.is_admin());

create policy "announcements_insert_admin_only"
on public.announcements
for insert
to authenticated
with check (private.is_admin());

create policy "announcements_update_admin_only"
on public.announcements
for update
to authenticated
using (private.is_admin())
with check (private.is_admin());

create policy "lead_proofs_insert_own_or_admin"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'lead-proofs'
  and (
    private.is_admin()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);

create policy "lead_proofs_select_own_or_admin"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'lead-proofs'
  and (
    private.is_admin()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);

create policy "lead_proofs_update_admin_only"
on storage.objects
for update
to authenticated
using (bucket_id = 'lead-proofs' and private.is_admin())
with check (bucket_id = 'lead-proofs' and private.is_admin());

create policy "lead_proofs_delete_admin_only"
on storage.objects
for delete
to authenticated
using (bucket_id = 'lead-proofs' and private.is_admin());

create unique index if not exists leads_normalized_business_link_key
  on public.leads (normalized_business_link)
  where normalized_business_link is not null and normalized_business_link <> '';

create index if not exists leads_researcher_id_idx
  on public.leads (researcher_id);

create index if not exists leads_status_idx
  on public.leads (status);

create index if not exists leads_review_status_idx
  on public.leads (review_status);

create index if not exists leads_submitted_at_idx
  on public.leads (submitted_at desc);

create index if not exists leads_normalized_business_name_idx
  on public.leads (normalized_business_name);

create index if not exists commissions_researcher_id_idx
  on public.commissions (researcher_id);

create index if not exists commissions_status_idx
  on public.commissions (status);

create index if not exists resource_items_category_idx
  on public.resource_items (category, order_index);

create index if not exists announcements_published_idx
  on public.announcements (is_published, is_pinned, published_at desc);

insert into public.resource_items (category, title, content, order_index, is_published)
select *
from (
  values
    ('scripts'::public.resource_category, 'Soft Intro Script', 'Hi {{owner_name}}, I checked {{business_name}} and noticed a few areas where Intellium Digital could help improve credibility and customer conversion. If you''re open, I can share a quick audit and the most practical next step.', 1, true),
    ('scripts'::public.resource_category, 'Follow-Up Script', 'Hi {{owner_name}}, following up on my last message about {{business_name}}. We typically help local businesses with branding, websites, payment setup, and digital cleanup so they look more legitimate online and convert better. If helpful, I can send a concise recommendation.', 2, true),
    ('scripts'::public.resource_category, 'Interested Lead Handoff Script', 'Thanks for the response. I''ll hand this over to our Intellium Digital team so they can review your business needs and recommend the best-fit setup. I''ll include the issues you mentioned so the conversation stays efficient.', 3, true),
    ('pricing'::public.resource_category, 'Core Packages', 'Starter Website: PHP 5,000\nBusiness Website: PHP 10,000+\nWebsite + Payment Setup: PHP 18,000\nFull Digital Setup: PHP 25,000+\nApp Development: PHP 35,000+', 1, true),
    ('qualification'::public.resource_category, 'Lead Qualification Checklist', 'Check if the business is active, reachable, has a clear service offer, has visible digital gaps, and can reasonably benefit from branding, web, payments, or full digital setup.', 1, true),
    ('scoring'::public.resource_category, 'Lead Scoring System', 'Add 20 points each for: active business, obvious digital problem, responsive owner, budget signal, and clear service fit. 80 to 100 = high priority. 50 to 79 = workable. Below 50 = low priority.', 1, true),
    ('commission'::public.resource_category, 'Commission Structure', 'Branding client: PHP 300 to PHP 500\nStarter Website PHP 5,000: PHP 500\nBusiness Website PHP 10,000+: PHP 1,000\nWebsite + Payment Setup PHP 18,000: PHP 2,000\nFull Digital Setup PHP 25,000+: PHP 3,000\nApp Development PHP 35,000+: PHP 4,000 to PHP 5,000', 1, true),
    ('commission'::public.resource_category, 'Rules', 'Do not spam\nDo not argue with business owners\nDo not promise guaranteed sales\nDo not promise guaranteed Maya, PayMongo, or payment provider approval\nDo not collect payments\nDo not change pricing without approval\nDo not submit fake leads\nDo not submit duplicate leads\nScreenshot or proof is required\nCommission applies only after the client successfully pays Intellium Digital', 2, true),
    ('handoff'::public.resource_category, 'Handoff Process', '1. Confirm owner interest.\n2. Log the lead with proof and notes.\n3. Set reply status and budget context.\n4. Admin reviews and assigns next action.\n5. Delivery or sales team takes over once qualified.', 1, true),
    ('images'::public.resource_category, 'Image Usage Guide', 'Use only approved brand assets, audit screenshots, and offer examples. Never send unapproved before-and-after visuals or edit pricing into images.', 1, true)
) as seed_data(category, title, content, order_index, is_published)
where not exists (select 1 from public.resource_items);

insert into public.announcements (title, content, is_pinned, is_published, published_at)
select
  'Welcome to IntelliLead Outreach Portal',
  'Use approved scripts only, submit proof with every lead, and remember that commission only applies after the client successfully pays Intellium Digital.',
  true,
  true,
  timezone('utc', now())
where not exists (select 1 from public.announcements);
