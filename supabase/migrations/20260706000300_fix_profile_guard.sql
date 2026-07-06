-- Fix: the guard_profile_update trigger clobbered coin/streak updates even when
-- they came from our own SECURITY DEFINER economy RPCs, because `SET ROLE
-- authenticated` (set by PostgREST) stays in effect inside a definer function,
-- so current_setting('role') is still 'authenticated' there. Result: claim_daily
-- / spin / purchase_cart wrote the ledger but the balance never moved.
--
-- Replace the trigger with column-level privileges: authenticated users may only
-- UPDATE display_name over the API; every economy column is writable only by the
-- table owner (postgres), which the SECURITY DEFINER functions run as.

drop trigger if exists guard_profile_update on public.profiles;
drop function if exists public.guard_profile_update();

revoke update on public.profiles from authenticated, anon;
grant update (display_name) on public.profiles to authenticated;
