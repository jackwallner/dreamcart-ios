-- DreamCart: dopamine shopping app. Initial schema.
-- Server holds the authoritative coin economy; the client never writes coins.
-- All coin mutations flow through SECURITY DEFINER RPCs (claim_daily, spin,
-- purchase_cart) or the RevenueCat webhook (grant_coin_pack), each of which
-- writes a coin_ledger row so the balance is always reconstructable.

-- ---------------------------------------------------------------------------
-- Reference data: brands + products (public read).
-- ---------------------------------------------------------------------------

create table if not exists public.brands (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  name         text not null,
  tagline      text not null default '',
  aesthetic    text not null default '',      -- house look, feeds the image prompt
  accent_hex   text not null default '#111111',
  bg_hex       text not null default '#F2F2F2',-- studio backdrop, keeps a brand's shots consistent
  sort         int  not null default 0,
  created_at   timestamptz not null default now()
);

create table if not exists public.products (
  id           uuid primary key default gen_random_uuid(),
  brand_id     uuid not null references public.brands(id) on delete cascade,
  name         text not null,
  category     text not null,                 -- top|bottom|dress|outerwear|shoes|bag|jewelry|sunglasses|hat|accessory
  slot         text not null,                 -- outfit slot: top|bottom|footwear|outerwear|bag|jewelry|eyewear|headwear
  style_tags   text[] not null default '{}',
  color_name   text not null default '',
  price        int  not null check (price > 0),
  rarity       text not null default 'common', -- common|rare|epic|legendary
  description  text not null default '',
  image_url    text not null default '',
  drop_date    date not null default current_date,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);
create index if not exists products_active_drop_idx on public.products (is_active, drop_date desc);
create index if not exists products_brand_idx on public.products (brand_id);
create index if not exists products_category_idx on public.products (category);

-- ---------------------------------------------------------------------------
-- Per-user state.
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  display_name      text not null default 'Shopper',
  coins             int  not null default 0 check (coins >= 0),
  streak            int  not null default 0,
  best_streak       int  not null default 0,
  last_daily_claim  date,
  last_spin_date    date,
  is_plus           boolean not null default false,
  lifetime_spent    int  not null default 0,   -- total coins ever spent shopping (for flex stats)
  items_owned       int  not null default 0,
  created_at        timestamptz not null default now()
);

create table if not exists public.closet_items (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  product_id   uuid not null references public.products(id) on delete cascade,
  acquired_at  timestamptz not null default now(),
  unique (user_id, product_id)
);
create index if not exists closet_user_idx on public.closet_items (user_id);

create table if not exists public.favorites (
  user_id      uuid not null references auth.users(id) on delete cascade,
  product_id   uuid not null references public.products(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table if not exists public.orders (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  total_coins  int  not null,
  item_count   int  not null,
  created_at   timestamptz not null default now()
);
create index if not exists orders_user_idx on public.orders (user_id, created_at desc);

create table if not exists public.order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references public.orders(id) on delete cascade,
  product_id   uuid not null references public.products(id) on delete cascade,
  price_coins  int  not null
);

create table if not exists public.outfits (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  name         text not null default 'Untitled Look',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.outfit_items (
  outfit_id    uuid not null references public.outfits(id) on delete cascade,
  product_id   uuid not null references public.products(id) on delete cascade,
  slot         text not null,
  primary key (outfit_id, slot)
);

create table if not exists public.coin_ledger (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  delta         int not null,
  reason        text not null,                -- welcome|daily|spin|checkout|pack|refund|plus_bonus
  ref           text,
  balance_after int not null,
  created_at    timestamptz not null default now()
);
create index if not exists ledger_user_idx on public.coin_ledger (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- RLS. Reference tables are world-readable; user rows are owner-only.
-- Coin/closet/order writes are done by SECURITY DEFINER functions, so the
-- policies here deliberately grant only what the app reads directly.
-- ---------------------------------------------------------------------------

alter table public.brands        enable row level security;
alter table public.products      enable row level security;
alter table public.profiles      enable row level security;
alter table public.closet_items  enable row level security;
alter table public.favorites     enable row level security;
alter table public.orders        enable row level security;
alter table public.order_items   enable row level security;
alter table public.outfits       enable row level security;
alter table public.outfit_items  enable row level security;
alter table public.coin_ledger   enable row level security;

create policy brands_read   on public.brands   for select using (true);
create policy products_read on public.products for select using (true);

create policy profiles_read   on public.profiles for select using (auth.uid() = id);
create policy profiles_update on public.profiles for update using (auth.uid() = id)
  with check (auth.uid() = id);

create policy closet_read on public.closet_items for select using (auth.uid() = user_id);

create policy fav_read   on public.favorites for select using (auth.uid() = user_id);
create policy fav_insert on public.favorites for insert with check (auth.uid() = user_id);
create policy fav_delete on public.favorites for delete using (auth.uid() = user_id);

create policy orders_read on public.orders for select using (auth.uid() = user_id);
create policy order_items_read on public.order_items for select
  using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));

create policy outfits_all on public.outfits for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy outfit_items_all on public.outfit_items for all
  using (exists (select 1 from public.outfits o where o.id = outfit_id and o.user_id = auth.uid()))
  with check (exists (select 1 from public.outfits o where o.id = outfit_id and o.user_id = auth.uid()));

create policy ledger_read on public.coin_ledger for select using (auth.uid() = user_id);

-- profiles.update policy above lets a user edit display_name; guard coins from
-- being raised client-side by only trusting server RPCs. A trigger clamps any
-- direct client update so coins/streak/plus can't be tampered with over REST.
create or replace function public.guard_profile_update()
returns trigger language plpgsql as $$
begin
  if current_setting('role', true) = 'authenticated' then
    new.coins            := old.coins;
    new.streak           := old.streak;
    new.best_streak      := old.best_streak;
    new.last_daily_claim := old.last_daily_claim;
    new.last_spin_date   := old.last_spin_date;
    new.is_plus          := old.is_plus;
    new.lifetime_spent   := old.lifetime_spent;
    new.items_owned      := old.items_owned;
  end if;
  return new;
end $$;
create trigger guard_profile_update before update on public.profiles
  for each row execute function public.guard_profile_update();

-- ---------------------------------------------------------------------------
-- New-user bootstrap: create a profile + welcome grant on signup.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  welcome int := 750;
begin
  insert into public.profiles (id, display_name, coins)
  values (new.id, 'Shopper', welcome)
  on conflict (id) do nothing;
  insert into public.coin_ledger (user_id, delta, reason, balance_after)
  values (new.id, welcome, 'welcome', welcome);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
