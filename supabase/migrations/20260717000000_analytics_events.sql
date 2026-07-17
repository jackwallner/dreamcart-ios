-- First-party product analytics. Client-batched behavior events (browse,
-- swipe, cart, checkout, spin, coin shop) written straight from the app —
-- see Shared/Services/Analytics.swift. Insert-only from the client; nothing
-- is ever read back over the API (dashboards/exports go through the service
-- role key, not the anon/authenticated roles), so there's no read policy.

create table if not exists public.analytics_events (
  id               bigint generated always as identity primary key,
  user_id          uuid references auth.users(id) on delete set null,
  session_id       text not null,
  name             text not null,
  props            jsonb not null default '{}'::jsonb,
  client_timestamp timestamptz not null,
  inserted_at      timestamptz not null default now(),
  app_version      text not null default '',
  locale           text not null default ''
);

create index if not exists analytics_events_name_inserted_idx
  on public.analytics_events (name, inserted_at desc);
create index if not exists analytics_events_user_idx
  on public.analytics_events (user_id, inserted_at desc);

alter table public.analytics_events enable row level security;

-- Inserts only, from anon (pre-auth onboarding events) and authenticated
-- alike. No select/update/delete policy exists for either role, so clients
-- can never read, alter, or delete analytics rows over PostgREST.
create policy analytics_events_insert on public.analytics_events
  for insert
  to anon, authenticated
  with check (
    -- Authenticated writers may only tag rows as themselves; anon writers
    -- (pre-auth) must leave user_id null rather than spoofing another user.
    (auth.role() = 'authenticated' and user_id = auth.uid())
    or (auth.role() = 'anon' and user_id is null)
  );
