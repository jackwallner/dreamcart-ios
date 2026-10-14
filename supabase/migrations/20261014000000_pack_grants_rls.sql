-- pack_grants is written only by grant_coin_pack (security definer) from the
-- RevenueCat webhook. Without RLS the anon key could read every user's store
-- transactions or pre-insert ids to block real grants. No policies: only the
-- definer function and the service role reach it.
alter table public.pack_grants enable row level security;
revoke all on public.pack_grants from anon, authenticated;
