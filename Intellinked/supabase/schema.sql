create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  account_type text not null default 'professional' check (
    account_type in ('professional', 'business', 'freelancer', 'customer')
  ),
  location text,
  bio text,
  avatar_url text,
  website_url text,
  is_public boolean not null default true,
  is_admin boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.business_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  business_name text not null,
  slug text unique,
  category text,
  location text,
  description text,
  contact_email text,
  contact_phone text,
  website_url text,
  facebook_url text,
  is_public boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  business_profile_id uuid references public.business_profiles(id) on delete set null,
  author_type text not null default 'professional' check (
    author_type in ('professional', 'business', 'freelancer', 'customer')
  ),
  category text,
  content text not null,
  cta text not null default 'Connect' check (
    cta in ('Connect', 'Message', 'View Service')
  ),
  visibility text not null default 'public' check (
    visibility in ('public', 'private', 'followers')
  ),
  is_published boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_comment_id uuid references public.comments(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_user_id uuid references auth.users(id) on delete cascade,
  following_business_profile_id uuid references public.business_profiles(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    (
      case when following_user_id is null then 0 else 1 end +
      case when following_business_profile_id is null then 0 else 1 end
    ) = 1
  )
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  business_profile_id uuid references public.business_profiles(id) on delete set null,
  title text not null,
  category text,
  location text,
  summary text,
  price_label text,
  availability text,
  is_public boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  comment_id uuid references public.comments(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  business_profile_id uuid references public.business_profiles(id) on delete set null,
  reason text not null,
  details text,
  status text not null default 'pending' check (
    status in ('pending', 'in_review', 'resolved', 'dismissed')
  ),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  moderation_notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (
    (
      case when reported_user_id is null then 0 else 1 end +
      case when post_id is null then 0 else 1 end +
      case when comment_id is null then 0 else 1 end +
      case when service_id is null then 0 else 1 end +
      case when business_profile_id is null then 0 else 1 end
    ) >= 1
  )
);

create table if not exists public.blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (blocker_user_id, blocked_user_id),
  check (blocker_user_id <> blocked_user_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  type text not null,
  title text not null,
  body text,
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists follows_unique_user_target
  on public.follows (follower_id, following_user_id)
  where following_user_id is not null;

create unique index if not exists follows_unique_business_target
  on public.follows (follower_id, following_business_profile_id)
  where following_business_profile_id is not null;

create index if not exists profiles_public_idx
  on public.profiles (is_public, created_at desc);

create index if not exists business_profiles_public_idx
  on public.business_profiles (is_public, category, created_at desc);

create index if not exists posts_owner_idx
  on public.posts (user_id, created_at desc);

create index if not exists posts_public_feed_idx
  on public.posts (visibility, is_published, created_at desc);

create index if not exists comments_post_idx
  on public.comments (post_id, created_at asc);

create index if not exists services_owner_idx
  on public.services (user_id, created_at desc);

create index if not exists services_public_idx
  on public.services (is_public, is_active, category, created_at desc);

create index if not exists reports_status_idx
  on public.reports (status, created_at desc);

create index if not exists blocks_blocker_idx
  on public.blocks (blocker_user_id, created_at desc);

create index if not exists notifications_user_idx
  on public.notifications (user_id, is_read, created_at desc);

create or replace function public.is_admin_user(check_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where user_id = check_user_id
      and is_admin = true
  );
$$;

grant execute on function public.is_admin_user(uuid) to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    user_id,
    display_name,
    account_type
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    coalesce(lower(new.raw_user_meta_data ->> 'account_type'), 'professional')
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists business_profiles_set_updated_at on public.business_profiles;
create trigger business_profiles_set_updated_at
before update on public.business_profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists posts_set_updated_at on public.posts;
create trigger posts_set_updated_at
before update on public.posts
for each row execute procedure public.set_updated_at();

drop trigger if exists post_likes_set_updated_at on public.post_likes;
create trigger post_likes_set_updated_at
before update on public.post_likes
for each row execute procedure public.set_updated_at();

drop trigger if exists comments_set_updated_at on public.comments;
create trigger comments_set_updated_at
before update on public.comments
for each row execute procedure public.set_updated_at();

drop trigger if exists follows_set_updated_at on public.follows;
create trigger follows_set_updated_at
before update on public.follows
for each row execute procedure public.set_updated_at();

drop trigger if exists services_set_updated_at on public.services;
create trigger services_set_updated_at
before update on public.services
for each row execute procedure public.set_updated_at();

drop trigger if exists reports_set_updated_at on public.reports;
create trigger reports_set_updated_at
before update on public.reports
for each row execute procedure public.set_updated_at();

drop trigger if exists blocks_set_updated_at on public.blocks;
create trigger blocks_set_updated_at
before update on public.blocks
for each row execute procedure public.set_updated_at();

drop trigger if exists notifications_set_updated_at on public.notifications;
create trigger notifications_set_updated_at
before update on public.notifications
for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.business_profiles enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.follows enable row level security;
alter table public.services enable row level security;
alter table public.reports enable row level security;
alter table public.blocks enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "profiles_select_public_or_owner" on public.profiles;
create policy "profiles_select_public_or_owner"
on public.profiles
for select
to authenticated
using (is_public = true or user_id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
on public.profiles
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "business_profiles_select_public_or_owner" on public.business_profiles;
create policy "business_profiles_select_public_or_owner"
on public.business_profiles
for select
to authenticated
using (is_public = true or user_id = auth.uid());

drop policy if exists "business_profiles_insert_own" on public.business_profiles;
create policy "business_profiles_insert_own"
on public.business_profiles
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "business_profiles_update_own" on public.business_profiles;
create policy "business_profiles_update_own"
on public.business_profiles
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "business_profiles_delete_own" on public.business_profiles;
create policy "business_profiles_delete_own"
on public.business_profiles
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "posts_select_public_or_owner" on public.posts;
create policy "posts_select_public_or_owner"
on public.posts
for select
to authenticated
using (
  (is_published = true and visibility = 'public')
  or user_id = auth.uid()
);

drop policy if exists "posts_insert_own" on public.posts;
create policy "posts_insert_own"
on public.posts
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own"
on public.posts
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own"
on public.posts
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "post_likes_select_authenticated" on public.post_likes;
create policy "post_likes_select_authenticated"
on public.post_likes
for select
to authenticated
using (true);

drop policy if exists "post_likes_insert_own" on public.post_likes;
create policy "post_likes_insert_own"
on public.post_likes
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "post_likes_delete_own" on public.post_likes;
create policy "post_likes_delete_own"
on public.post_likes
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "comments_select_authenticated" on public.comments;
create policy "comments_select_authenticated"
on public.comments
for select
to authenticated
using (true);

drop policy if exists "comments_insert_own" on public.comments;
create policy "comments_insert_own"
on public.comments
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "comments_update_own" on public.comments;
create policy "comments_update_own"
on public.comments
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "comments_delete_own" on public.comments;
create policy "comments_delete_own"
on public.comments
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "follows_select_authenticated" on public.follows;
create policy "follows_select_authenticated"
on public.follows
for select
to authenticated
using (true);

drop policy if exists "follows_insert_own" on public.follows;
create policy "follows_insert_own"
on public.follows
for insert
to authenticated
with check (follower_id = auth.uid());

drop policy if exists "follows_update_own" on public.follows;
create policy "follows_update_own"
on public.follows
for update
to authenticated
using (follower_id = auth.uid())
with check (follower_id = auth.uid());

drop policy if exists "follows_delete_own" on public.follows;
create policy "follows_delete_own"
on public.follows
for delete
to authenticated
using (follower_id = auth.uid());

drop policy if exists "services_select_public_or_owner" on public.services;
create policy "services_select_public_or_owner"
on public.services
for select
to authenticated
using (
  (is_public = true and is_active = true)
  or user_id = auth.uid()
);

drop policy if exists "services_insert_own" on public.services;
create policy "services_insert_own"
on public.services
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "services_update_own" on public.services;
create policy "services_update_own"
on public.services
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "services_delete_own" on public.services;
create policy "services_delete_own"
on public.services
for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "reports_select_reporter_or_admin" on public.reports;
create policy "reports_select_reporter_or_admin"
on public.reports
for select
to authenticated
using (
  reporter_user_id = auth.uid()
  or public.is_admin_user(auth.uid())
);

drop policy if exists "reports_insert_reporter" on public.reports;
create policy "reports_insert_reporter"
on public.reports
for insert
to authenticated
with check (reporter_user_id = auth.uid());

drop policy if exists "reports_update_admin_only" on public.reports;
create policy "reports_update_admin_only"
on public.reports
for update
to authenticated
using (public.is_admin_user(auth.uid()))
with check (public.is_admin_user(auth.uid()));

drop policy if exists "reports_delete_reporter_or_admin" on public.reports;
create policy "reports_delete_reporter_or_admin"
on public.reports
for delete
to authenticated
using (
  (reporter_user_id = auth.uid() and status = 'pending')
  or public.is_admin_user(auth.uid())
);

drop policy if exists "blocks_select_own" on public.blocks;
create policy "blocks_select_own"
on public.blocks
for select
to authenticated
using (blocker_user_id = auth.uid());

drop policy if exists "blocks_insert_own" on public.blocks;
create policy "blocks_insert_own"
on public.blocks
for insert
to authenticated
with check (blocker_user_id = auth.uid());

drop policy if exists "blocks_update_own" on public.blocks;
create policy "blocks_update_own"
on public.blocks
for update
to authenticated
using (blocker_user_id = auth.uid())
with check (blocker_user_id = auth.uid());

drop policy if exists "blocks_delete_own" on public.blocks;
create policy "blocks_delete_own"
on public.blocks
for delete
to authenticated
using (blocker_user_id = auth.uid());

drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own"
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "notifications_insert_own_or_admin" on public.notifications;
create policy "notifications_insert_own_or_admin"
on public.notifications
for insert
to authenticated
with check (
  user_id = auth.uid()
  or public.is_admin_user(auth.uid())
);

drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own"
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "notifications_delete_own" on public.notifications;
create policy "notifications_delete_own"
on public.notifications
for delete
to authenticated
using (user_id = auth.uid());
