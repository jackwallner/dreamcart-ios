-- Coin economy RPCs. All SECURITY DEFINER, callable by authenticated users,
-- each transactional and each writing a coin_ledger row.

-- Snapshot of everything the app needs about the current user in one call.
create or replace function public.me()
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.profiles; can_daily boolean; can_spin boolean;
begin
  select * into p from public.profiles where id = auth.uid();
  if not found then
    -- Self-heal if the signup trigger was skipped (e.g. pre-existing user).
    insert into public.profiles (id, coins) values (auth.uid(), 750)
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

-- Daily coins. Streak grows if the last claim was yesterday, resets otherwise.
-- Grant scales with streak; DreamCart+ doubles it.
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
  grant_amt := least(100 + (new_streak - 1) * 25, 400);   -- 100..400 over ~13 days
  if new_streak % 7 = 0 then grant_amt := grant_amt + 300; bonus := true; end if; -- weekly bump
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

-- One free spin a day (unlimited for DreamCart+). Weighted prize wheel; the
-- server picks the slice so the client can't fish for the jackpot.
create or replace function public.spin()
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.profiles; r double precision; prize int; slice int;
begin
  select * into p from public.profiles where id = auth.uid() for update;
  if p.last_spin_date = current_date and not p.is_plus then
    return jsonb_build_object('ok', false, 'reason', 'spun_today', 'coins', p.coins);
  end if;
  r := random();
  -- Wheel: 8 slices. Weighted toward small wins, rare 1000 jackpot.
  if    r < 0.28 then prize := 50;  slice := 0;
  elsif r < 0.52 then prize := 100; slice := 1;
  elsif r < 0.70 then prize := 150; slice := 2;
  elsif r < 0.83 then prize := 250; slice := 3;
  elsif r < 0.92 then prize := 400; slice := 4;
  elsif r < 0.97 then prize := 600; slice := 5;
  elsif r < 0.995 then prize := 800; slice := 6;
  else prize := 1000; slice := 7;
  end if;
  update public.profiles set coins = coins + prize, last_spin_date = current_date
  where id = p.id returning * into p;
  insert into public.coin_ledger (user_id, delta, reason, ref, balance_after)
  values (p.id, prize, 'spin', slice::text, p.coins);
  return jsonb_build_object('ok', true, 'prize', prize, 'slice', slice, 'coins', p.coins);
end $$;

-- Buy a cart. Atomic: locks the profile, sums the price of items the user does
-- not already own, checks the balance, deducts, records the order + closet.
create or replace function public.purchase_cart(p_product_ids uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  p public.profiles; total int; n int; new_order uuid; bought uuid[];
begin
  select * into p from public.profiles where id = auth.uid() for update;

  -- Only charge for active products not already in the closet.
  create temp table _cart on commit drop as
  select pr.id, pr.price from public.products pr
  where pr.id = any(p_product_ids) and pr.is_active
    and not exists (select 1 from public.closet_items c where c.user_id = p.id and c.product_id = pr.id);

  select coalesce(sum(price),0), count(*) into total, n from _cart;
  if n = 0 then
    return jsonb_build_object('ok', false, 'reason', 'nothing_to_buy', 'coins', p.coins);
  end if;
  if total > p.coins then
    return jsonb_build_object('ok', false, 'reason', 'insufficient_coins',
                              'need', total, 'coins', p.coins);
  end if;

  insert into public.orders (user_id, total_coins, item_count)
  values (p.id, total, n) returning id into new_order;
  insert into public.order_items (order_id, product_id, price_coins)
  select new_order, id, price from _cart;
  insert into public.closet_items (user_id, product_id)
  select p.id, id from _cart on conflict do nothing;
  select array_agg(id) into bought from _cart;

  update public.profiles set
    coins = coins - total,
    lifetime_spent = lifetime_spent + total,
    items_owned = items_owned + n
  where id = p.id returning * into p;
  insert into public.coin_ledger (user_id, delta, reason, ref, balance_after)
  values (p.id, -total, 'checkout', new_order::text, p.coins);

  return jsonb_build_object('ok', true, 'order_id', new_order, 'spent', total,
                            'item_count', n, 'coins', p.coins, 'bought', bought);
end $$;

-- Credit a coin pack. Called only by the RevenueCat webhook (service role);
-- idempotent on the store transaction id so a re-delivered webhook is a no-op.
create table if not exists public.pack_grants (
  transaction_id text primary key,
  user_id uuid not null,
  coins int not null,
  created_at timestamptz not null default now()
);

create or replace function public.grant_coin_pack(
  p_user uuid, p_coins int, p_transaction text, p_product text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare bal int;
begin
  insert into public.pack_grants (transaction_id, user_id, coins)
  values (p_transaction, p_user, p_coins)
  on conflict (transaction_id) do nothing;
  if not found then
    select coins into bal from public.profiles where id = p_user;
    return jsonb_build_object('ok', true, 'duplicate', true, 'coins', bal);
  end if;
  update public.profiles set coins = coins + p_coins where id = p_user returning coins into bal;
  insert into public.coin_ledger (user_id, delta, reason, ref, balance_after)
  values (p_user, p_coins, 'pack', p_product, bal);
  return jsonb_build_object('ok', true, 'coins', bal);
end $$;

-- Reflect DreamCart+ entitlement from the webhook.
create or replace function public.set_plus(p_user uuid, p_is_plus boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.profiles set is_plus = p_is_plus where id = p_user;
end $$;

revoke all on function public.grant_coin_pack(uuid,int,text,text) from public, anon, authenticated;
revoke all on function public.set_plus(uuid,boolean) from public, anon, authenticated;
grant execute on function public.me()               to authenticated;
grant execute on function public.claim_daily()      to authenticated;
grant execute on function public.spin()             to authenticated;
grant execute on function public.purchase_cart(uuid[]) to authenticated;
