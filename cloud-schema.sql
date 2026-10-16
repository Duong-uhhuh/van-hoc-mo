-- Supabase schema for Van Hoc Mo.
-- Run this entire file once in the Supabase SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  name text not null,
  class_name text not null default '',
  role text not null default 'student' check (role in ('student', 'teacher')),
  created_at timestamptz not null default now()
);

create table if not exists public.literary_works (
  id text primary key,
  title text not null,
  author text not null,
  genre text not null,
  period text not null,
  tags text[] not null default '{}',
  level text not null,
  mark text not null,
  cover text not null,
  description text not null,
  reading text not null,
  intro text not null,
  questions jsonb not null default '[]'::jsonb check (jsonb_typeof(questions) = 'array'),
  updated_at timestamptz not null default now()
);

create table if not exists public.learning_progress (
  user_id uuid not null references public.profiles (id) on delete cascade,
  work_id text not null,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (user_id, work_id)
);

create table if not exists public.learning_sessions (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  work_id text not null,
  activity text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.teacher_access_requests (
  user_id uuid primary key references auth.users (id) on delete cascade,
  reason text not null default '',
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists learning_sessions_user_created_idx
  on public.learning_sessions (user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.literary_works enable row level security;
alter table public.learning_progress enable row level security;
alter table public.learning_sessions enable row level security;
alter table public.teacher_access_requests enable row level security;

create or replace function public.user_is_teacher()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'teacher'
  );
$$;

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, name, class_name, role)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), split_part(new.email, '@', 1)),
    coalesce(nullif(new.raw_user_meta_data ->> 'class_name', ''), ''),
    'student'
  )
  on conflict (id) do update set email = excluded.email;
  if coalesce(new.raw_user_meta_data ->> 'teacher_access_request', 'false') = 'true' then
    insert into public.teacher_access_requests (user_id)
    values (new.id)
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();

drop policy if exists "Profiles readable by owner or teacher" on public.profiles;
create policy "Profiles readable by owner or teacher"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.user_is_teacher()));

drop policy if exists "Authenticated users read literary works" on public.literary_works;
create policy "Authenticated users read literary works"
  on public.literary_works for select to authenticated
  using (true);

drop policy if exists "Progress readable by owner or teacher" on public.learning_progress;
create policy "Progress readable by owner or teacher"
  on public.learning_progress for select to authenticated
  using (user_id = (select auth.uid()) or (select public.user_is_teacher()));

drop policy if exists "Users insert own progress" on public.learning_progress;
create policy "Users insert own progress"
  on public.learning_progress for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Users update own progress" on public.learning_progress;
create policy "Users update own progress"
  on public.learning_progress for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "Sessions readable by owner or teacher" on public.learning_sessions;
create policy "Sessions readable by owner or teacher"
  on public.learning_sessions for select to authenticated
  using (user_id = (select auth.uid()) or (select public.user_is_teacher()));

drop policy if exists "Users insert own sessions" on public.learning_sessions;
create policy "Users insert own sessions"
  on public.learning_sessions for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Users read own teacher access request" on public.teacher_access_requests;
create policy "Users read own teacher access request"
  on public.teacher_access_requests for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.literary_works from anon, authenticated;
revoke all on table public.learning_progress from anon, authenticated;
revoke all on table public.learning_sessions from anon, authenticated;
revoke all on table public.teacher_access_requests from anon, authenticated;

grant select on table public.profiles to authenticated;
grant select on table public.literary_works to authenticated;
grant select, insert, update on table public.learning_progress to authenticated;
grant select, insert on table public.learning_sessions to authenticated;
grant select on table public.teacher_access_requests to authenticated;
revoke all on function public.user_is_teacher() from public, anon;
grant execute on function public.user_is_teacher() to authenticated;

