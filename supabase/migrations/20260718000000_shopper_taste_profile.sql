-- Shopper taste-profile rollup, built on the denormalized taste vector that
-- every high-intent analytics event now carries (brand_id / category / slot /
-- style_tags / color / price / rarity — see Shared/Services/Analytics.swift
-- `tasteProps`). Because attributes are captured on the event itself, these
-- views never join back to the live catalog and stay correct even as the
-- catalog drifts (image regen, drop rotation, delistings).
--
-- SECURITY: like analytics_events, these are service-role-only. Supabase's
-- default privileges would otherwise grant anon/authenticated select on new
-- public views, so we revoke it explicitly below — profiles are for
-- dashboards/exports through the service role, never readable over the client
-- API.

-- One normalized row per taste-bearing event: the event's signed intent
-- weight plus the attributes pulled out of `props`. Positive weight = the
-- shopper moved toward an item; negative = they moved away.
create or replace view public.shopper_taste_signal as
select
  e.user_id,
  e.session_id,
  e.name                                    as event,
  w.weight,
  e.props->>'brand_id'                      as brand_id,
  e.props->>'category'                      as category,
  e.props->>'color'                         as color,
  e.props->>'rarity'                        as rarity,
  e.props->>'slot'                          as slot,
  nullif(e.props->>'price', '')::numeric    as price,
  e.props->'style_tags'                     as style_tags,
  e.client_timestamp
from public.analytics_events e
join (values
  ('checkout_item',   10),  -- strongest: spent real coins on it
  ('favorite',         6),
  ('add_to_cart',      5),
  ('swipe_like',       3),
  ('product_dwell',    2),
  ('product_viewed',   1),
  ('swipe_discard',   -2),  -- negative intent
  ('remove_from_cart',-3),
  ('unfavorite',      -4)
) as w(name, weight) on w.name = e.name;

comment on view public.shopper_taste_signal is
  'Normalized, signed-weight taste signals per taste-bearing analytics event. Service-role only.';

-- Per-user profile: weighted affinity maps (value -> summed intent score) for
-- each dimension, engaged-price stats, and convenience "top_*" scalars. Read a
-- shopper''s profile directly: `select * from shopper_taste_profile where
-- user_id = $1`. Anon (pre-sign-in) events have null user_id and are excluded
-- here; aggregate those from shopper_taste_signal by session_id if needed.
create or replace view public.shopper_taste_profile as
with sig as (
  select * from public.shopper_taste_signal where user_id is not null
),
totals as (
  select user_id,
         sum(weight)             as total_signal,
         count(*)                as signal_events,
         max(client_timestamp)   as last_signal_at
  from sig
  group by user_id
),
cat as (
  select user_id, jsonb_object_agg(category, score) as category_affinity
  from (select user_id, category, sum(weight) as score
        from sig where category is not null group by user_id, category) t
  group by user_id
),
brand as (
  select user_id, jsonb_object_agg(brand_id, score) as brand_affinity
  from (select user_id, brand_id, sum(weight) as score
        from sig where brand_id is not null group by user_id, brand_id) t
  group by user_id
),
color as (
  select user_id, jsonb_object_agg(color, score) as color_affinity
  from (select user_id, color, sum(weight) as score
        from sig where color is not null group by user_id, color) t
  group by user_id
),
rarity as (
  select user_id, jsonb_object_agg(rarity, score) as rarity_affinity
  from (select user_id, rarity, sum(weight) as score
        from sig where rarity is not null group by user_id, rarity) t
  group by user_id
),
style as (
  select user_id, jsonb_object_agg(tag, score) as style_affinity
  from (
    select s.user_id, jt.tag, sum(s.weight) as score
    from sig s
    cross join lateral jsonb_array_elements_text(
      coalesce(s.style_tags, '[]'::jsonb)) as jt(tag)
    group by s.user_id, jt.tag
  ) t
  group by user_id
),
price as (
  -- Weighted over positive-intent events only, so it reflects what the shopper
  -- gravitates toward, not what they rejected.
  select user_id,
         round(sum(price * weight) / nullif(sum(weight), 0), 1) as avg_engaged_price,
         min(price) as min_engaged_price,
         max(price) as max_engaged_price
  from sig
  where price is not null and weight > 0
  group by user_id
)
select
  t.user_id,
  t.total_signal,
  t.signal_events,
  t.last_signal_at,
  coalesce(cat.category_affinity,   '{}'::jsonb) as category_affinity,
  coalesce(brand.brand_affinity,    '{}'::jsonb) as brand_affinity,
  coalesce(color.color_affinity,    '{}'::jsonb) as color_affinity,
  coalesce(style.style_affinity,    '{}'::jsonb) as style_affinity,
  coalesce(rarity.rarity_affinity,  '{}'::jsonb) as rarity_affinity,
  price.avg_engaged_price,
  price.min_engaged_price,
  price.max_engaged_price,
  (select category from (
     select category, sum(weight) sc from sig s
     where s.user_id = t.user_id and category is not null
     group by category) x order by sc desc limit 1) as top_category,
  (select brand_id from (
     select brand_id, sum(weight) sc from sig s
     where s.user_id = t.user_id and brand_id is not null
     group by brand_id) x order by sc desc limit 1) as top_brand
from totals t
left join cat    on cat.user_id    = t.user_id
left join brand  on brand.user_id  = t.user_id
left join color  on color.user_id  = t.user_id
left join rarity on rarity.user_id = t.user_id
left join style  on style.user_id  = t.user_id
left join price  on price.user_id  = t.user_id;

comment on view public.shopper_taste_profile is
  'Per-user weighted taste affinities + engaged-price stats, derived from denormalized event attributes. Service-role only.';

-- Keep both views off the client API (Supabase default privileges grant these
-- on new public objects). Service role bypasses RLS/grants and still reads.
revoke all on public.shopper_taste_signal  from anon, authenticated;
revoke all on public.shopper_taste_profile from anon, authenticated;
