-- Boost DreamCart's coin economy so shoppers can buy a lot early and daily.
-- More generous starting balance (750 -> 3000), daily claim (~100-400 -> 1000-2000),
-- and spin wheel (~50-1000 -> 800-12000, avg ~2080). All server-authoritative;
-- the client SpinView.prizes array mirrors the new spin() slice payouts.

-- 1. Starting balance for new users: 750 -> 3000.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  welcome int := 3000;
begin
  insert into public.profiles (id, display_name, coins)
  values (new.id, 'Shopper', welcome)
  on conflict (id) do nothing;
  insert into public.coin_ledger (user_id, delta, reason, balance_after)
  values (new.id, welcome, 'welcome', welcome);
  return new;
end $$;

-- 2. me() self-heal seed for pre-existing users: 750 -> 3000.
create or replace function public.me()
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.profiles; can_daily boolean; can_spin boolean;
begin
  select * into p from public.profiles where id = auth.uid();
  if not found then
    insert into public.profiles (id, coins) values (auth.uid(), 3000)
      on conflict (id) do nothing
      returning * into p;
    if p.id is null then select * into p from public.profiles where id = auth.uid(); end if;
  end if;
  can_daily := p.last_daily_claim is distinct from current_date;
  can_spin  := p.last_spin_date  is distinct from current_date;
  return jsonb_build_object(
    'id', p.id, 'display_name', p.display_name, 'coins', p.coins,
    'streak', p.streak, 'best_streak', p.best_streak, 'is_plus', p.is_plus,
    'lifetime_spent', p.lifetime_spent, 'items_owned', p.items_owned,
    'can_claim_daily', can_daily, 'can_spin', can_spin,
    'last_daily_claim', p.last_daily_claim, 'last_spin_date', p.last_spin_date
  );
end $$;

-- 3. Daily coins: base 1000, +100/day up to 2000; weekly bump +1000.
create or replace function public.claim_daily()
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.profiles; grant_amt int; new_streak int; bonus boolean := false;
begin
  select * into p from public.profiles where id = auth.uid() for update;
  if p.last_daily_claim = current_date then
    return jsonb_build_object('ok', false, 'reason', 'already_claimed', 'coins', p.coins);
  end if;
  if p.last_daily_claim = current_date - 1 then
    new_streak := p.streak + 1;
  else
    new_streak := 1;
  end if;
  grant_amt := least(1000 + (new_streak - 1) * 100, 2000);   -- 1000..2000 over ~11 days
  if new_streak % 7 = 0 then grant_amt := grant_amt + 1000; bonus := true; end if; -- weekly bump
  if p.is_plus then grant_amt := grant_amt * 2; end if;
  update public.profiles set
    coins = coins + grant_amt,
    streak = new_streak,
    best_streak = greatest(best_streak, new_streak),
    last_daily_claim = current_date
  where id = p.id returning * into p;
  insert into public.coin_ledger (user_id, delta, reason, ref, balance_after)
  values (p.id, grant_amt, 'daily', new_streak::text, p.coins);
  return jsonb_build_object('ok', true, 'granted', grant_amt, 'coins', p.coins,
                            'streak', new_streak, 'weekly_bonus', bonus);
end $$;

-- 4. Spin wheel: rescaled to 800..12000 (avg ~2080). Slice payouts MUST match
-- SpinView.prizes in the client, index for index.
create or replace function public.spin()
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.profiles; r double precision; prize int; slice int;
begin
  select * into p from public.profiles where id = auth.uid() for update;
  if p.last_spin_date = current_date and not p.is_plus then
    return jsonb_build_object('ok', false, 'reason', 'spun_today', 'coins', p.coins);
  end if;
  r := random();
  if    r < 0.28  then prize := 800;   slice := 0;
  elsif r < 0.52  then prize := 1500;  slice := 1;
  elsif r < 0.70  then prize := 2000;  slice := 2;
  elsif r < 0.83  then prize := 2500;  slice := 3;
  elsif r < 0.92  then prize := 3500;  slice := 4;
  elsif r < 0.97  then prize := 5000;  slice := 5;
  elsif r < 0.995 then prize := 7500;  slice := 6;
  else prize := 12000; slice := 7;
  end if;
  update public.profiles set coins = coins + prize, last_spin_date = current_date
  where id = p.id returning * into p;
  insert into public.coin_ledger (user_id, delta, reason, ref, balance_after)
  values (p.id, prize, 'spin', slice::text, p.coins);
  return jsonb_build_object('ok', true, 'prize', prize, 'slice', slice, 'coins', p.coins);
end $$;

-- 5. One-time: bring existing shoppers up to the new 3000 floor so current
-- accounts feel the boosted economy too. Idempotent (only touches < 3000).
do $$
declare rec record;
begin
  for rec in select id, coins from public.profiles where coins < 3000 loop
    update public.profiles set coins = 3000 where id = rec.id;
    insert into public.coin_ledger (user_id, delta, reason, balance_after)
    values (rec.id, 3000 - rec.coins, 'economy_boost', 3000);
  end loop;
end $$;
