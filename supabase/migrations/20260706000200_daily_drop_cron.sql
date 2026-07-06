-- Daily drop scheduling. Applied live via the Management API; the real cron
-- secret is injected at apply time (kept out of source). Replace
-- __CRON_SECRET__ with the value in ~/shop/.env.shop (SHOP_CRON_SECRET) if
-- re-applying by hand.
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 15 fresh products every day at 14:00 UTC (~7am PT).
select cron.schedule('dreamcart-daily-drop', '0 14 * * *', $$
  select net.http_post(
    url := 'https://wpjmshibfhdpzvfrjzrv.supabase.co/functions/v1/generate-products',
    headers := jsonb_build_object('content-type','application/json','x-cron-secret','__CRON_SECRET__'),
    body := jsonb_build_object('count', 15, 'store', false)
  );
$$);
