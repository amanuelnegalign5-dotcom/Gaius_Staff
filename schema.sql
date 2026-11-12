-- GAIUS MINISTRY STAFF, MONDAY ATTENDANCE & REPORTING DATABASE
-- Run once in Supabase Dashboard -> SQL Editor.
-- This schema uses Supabase Auth + database Row Level Security (RLS).

create extension if not exists pgcrypto;
create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  full_name text not null,
  role text not null default 'staff' check (role in ('admin','staff')),
  center text not null default 'HQ',
  department text not null default 'Other',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  event_date date not null,
  event_type text not null check (event_type in ('staff_meeting','weekly_program')),
  title_en text not null,
  title_am text not null,
  start_time time,
  end_time time,
  location text,
  leader_notes text,
  attendance_closed boolean not null default false,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(event_date,event_type),
  check (extract(isodow from event_date) = 1)
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'not_recorded' check (status in ('not_recorded','present','late','absent','excused')),
  marked_by uuid references public.profiles(id),
  checked_in_at timestamptz,
  updated_at timestamptz not null default now(),
  unique(event_id,member_id)
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  owner_name text not null,
  title text not null,
  department text not null,
  center text not null,
  period_month integer not null check (period_month between 1 and 12),
  period_year integer not null check (period_year between 2020 and 2100),
  planned numeric(14,2) not null default 0 check (planned >= 0),
  actual numeric(14,2) not null default 0 check (actual >= 0),
  reach numeric(14,2) not null default 0 check (reach >= 0),
  activity_day smallint check (activity_day between 1 and 31),
  status text not null default 'not_started' check (status in ('not_started','in_progress','completed','delayed','decision_required')),
  priority text not null default 'medium' check (priority in ('high','medium','low')),
  responsible_person text,
  due_date date,
  reason text,
  action_taken text,
  description text,
  evidence text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Safe additive migration for the expanded monthly-report fields.
alter table public.activities add column if not exists activity_day smallint check (activity_day between 1 and 31);
alter table public.activities add column if not exists status text not null default 'not_started' check (status in ('not_started','in_progress','completed','delayed','decision_required'));
alter table public.activities add column if not exists priority text not null default 'medium' check (priority in ('high','medium','low'));
alter table public.activities add column if not exists responsible_person text;
alter table public.activities add column if not exists due_date date;
alter table public.activities add column if not exists reason text;
alter table public.activities add column if not exists action_taken text;
alter table public.activities add column if not exists evidence text;

create table if not exists public.leader_comments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete cascade,
  activity_id uuid references public.activities(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) > 0 and length(body) <= 5000),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leader_comments_one_target check ((event_id is null) <> (activity_id is null)),
  constraint leader_comments_target_unique unique nulls not distinct (event_id,activity_id,member_id)
);

create index if not exists events_date_idx on public.events(event_date desc);
create index if not exists attendance_event_idx on public.attendance(event_id);
create index if not exists attendance_member_idx on public.attendance(member_id,event_id);
create index if not exists activities_period_idx on public.activities(period_year,period_month);
create index if not exists activities_owner_idx on public.activities(owner_id);
create index if not exists leader_comments_member_idx on public.leader_comments(member_id,created_at desc);

-- Security-definer helpers are placed in a non-exposed schema and pin search_path.
create or replace function private.is_active_user()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.is_active = true
  );
$$;

create or replace function private.is_admin_user()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.is_active = true and p.role = 'admin'
  );
$$;

revoke all on function private.is_active_user() from public;
revoke all on function private.is_admin_user() from public;
grant usage on schema private to authenticated;
grant execute on function private.is_active_user() to authenticated;
grant execute on function private.is_admin_user() to authenticated;

-- Create a least-privilege profile when Supabase Auth creates a user.
create or replace function public.handle_new_gaius_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_username text;
  v_full_name text;
begin
  v_username := coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1));
  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', v_username);
  insert into public.profiles(id,username,full_name,center,department,role,is_active)
  values (new.id, lower(v_username), v_full_name,
          coalesce(new.raw_user_meta_data ->> 'center','HQ'),
          coalesce(new.raw_user_meta_data ->> 'department','Other'),
          'staff', true)
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function public.handle_new_gaius_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created_gaius on auth.users;
create trigger on_auth_user_created_gaius
after insert on auth.users
for each row execute function public.handle_new_gaius_user();

-- Enable RLS on every exposed application table.
alter table public.profiles enable row level security;
alter table public.events enable row level security;
alter table public.attendance enable row level security;
alter table public.activities enable row level security;
alter table public.leader_comments enable row level security;

-- Remove anonymous access; authenticated policies below control row-level access.
revoke all on public.profiles, public.events, public.attendance, public.activities, public.leader_comments from anon;
grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.events to authenticated;
grant select,insert,update,delete on public.attendance to authenticated;
grant select,insert,update,delete on public.activities to authenticated;
grant select,insert,update,delete on public.leader_comments to authenticated;

-- Profiles: signed-in active members can see the staff directory; only admins can update access.
drop policy if exists profiles_select_directory on public.profiles;
create policy profiles_select_directory on public.profiles for select to authenticated
using ((select private.is_active_user()) and (is_active = true or (select private.is_admin_user())));
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles for update to authenticated
using ((select private.is_admin_user())) with check ((select private.is_admin_user()));

-- Events: all active members can view; administrators manage the schedule and event notes.
drop policy if exists events_active_read on public.events;
create policy events_active_read on public.events for select to authenticated
using ((select private.is_active_user()));
drop policy if exists events_admin_insert on public.events;
create policy events_admin_insert on public.events for insert to authenticated
with check ((select private.is_admin_user()));
drop policy if exists events_admin_update on public.events;
create policy events_admin_update on public.events for update to authenticated
using ((select private.is_admin_user())) with check ((select private.is_admin_user()));
drop policy if exists events_admin_delete on public.events;
create policy events_admin_delete on public.events for delete to authenticated
using ((select private.is_admin_user()));

-- Attendance: members can see their own attendance; administrators manage the full register.
drop policy if exists attendance_read_self_or_admin on public.attendance;
create policy attendance_read_self_or_admin on public.attendance for select to authenticated
using ((select private.is_active_user()) and (member_id = (select auth.uid()) or (select private.is_admin_user())));
drop policy if exists attendance_admin_insert on public.attendance;
create policy attendance_admin_insert on public.attendance for insert to authenticated
with check ((select private.is_admin_user()));
drop policy if exists attendance_admin_update on public.attendance;
create policy attendance_admin_update on public.attendance for update to authenticated
using ((select private.is_admin_user())) with check ((select private.is_admin_user()));
drop policy if exists attendance_admin_delete on public.attendance;
create policy attendance_admin_delete on public.attendance for delete to authenticated
using ((select private.is_admin_user()));

-- Activities: all active members can read organization-wide activity records.
-- A member may create and update their own record; admins may manage all records.
drop policy if exists activities_active_read on public.activities;
create policy activities_active_read on public.activities for select to authenticated
using ((select private.is_active_user()));
drop policy if exists activities_insert_own on public.activities;
create policy activities_insert_own on public.activities for insert to authenticated
with check ((select private.is_active_user()) and owner_id = (select auth.uid()));
drop policy if exists activities_update_owner_or_admin on public.activities;
create policy activities_update_owner_or_admin on public.activities for update to authenticated
using (owner_id = (select auth.uid()) or (select private.is_admin_user()))
with check (owner_id = (select auth.uid()) or (select private.is_admin_user()));
drop policy if exists activities_delete_owner_or_admin on public.activities;
create policy activities_delete_owner_or_admin on public.activities for delete to authenticated
using (owner_id = (select auth.uid()) or (select private.is_admin_user()));

-- Leadership comments: administrators write; each recipient sees their own comments.
drop policy if exists leader_comments_read_recipient_or_admin on public.leader_comments;
create policy leader_comments_read_recipient_or_admin on public.leader_comments for select to authenticated
using ((select private.is_active_user()) and (member_id = (select auth.uid()) or (select private.is_admin_user())));
drop policy if exists leader_comments_admin_insert on public.leader_comments;
create policy leader_comments_admin_insert on public.leader_comments for insert to authenticated
with check ((select private.is_admin_user()) and created_by = (select auth.uid()));
drop policy if exists leader_comments_admin_update on public.leader_comments;
create policy leader_comments_admin_update on public.leader_comments for update to authenticated
using ((select private.is_admin_user())) with check ((select private.is_admin_user()) and created_by = (select auth.uid()));
drop policy if exists leader_comments_admin_delete on public.leader_comments;
create policy leader_comments_admin_delete on public.leader_comments for delete to authenticated
using ((select private.is_admin_user()));

-- After creating your first Auth user in the Supabase Dashboard, promote that
-- account using the one-time UPDATE statement in README.md. Do not make the
-- first admin role configurable from the public app.
