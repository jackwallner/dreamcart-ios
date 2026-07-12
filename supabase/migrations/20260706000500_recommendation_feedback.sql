-- Recommendation feedback is owner-scoped and records the latest user action
-- for each product shown in recommendations.
create table if not exists public.recommendation_feedback (
  user_id    uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  action     text not null check (action in ('dismissed', 'added_to_cart')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create index if not exists recommendation_feedback_user_idx
  on public.recommendation_feedback (user_id, updated_at desc);

alter table public.recommendation_feedback enable row level security;

create policy recommendation_feedback_read on public.recommendation_feedback
  for select using (auth.uid() = user_id);
create policy recommendation_feedback_insert on public.recommendation_feedback
  for insert with check (auth.uid() = user_id);
create policy recommendation_feedback_update on public.recommendation_feedback
  for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy recommendation_feedback_delete on public.recommendation_feedback
  for delete using (auth.uid() = user_id);

create or replace function public.record_recommendation_feedback(
  p_product_id uuid,
  p_action text
)
returns public.recommendation_feedback
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_feedback public.recommendation_feedback;
begin
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if p_action is null or p_action not in ('dismissed', 'added_to_cart') then
    raise exception 'invalid recommendation feedback action' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.products
    where id = p_product_id
      and is_active
  ) then
    raise exception 'active product not found' using errcode = '22023';
  end if;

  insert into public.recommendation_feedback (user_id, product_id, action)
  values (v_user_id, p_product_id, p_action)
  on conflict (user_id, product_id) do update
    set action = excluded.action,
        updated_at = now()
  returning * into v_feedback;

  return v_feedback;
end;
$$;

revoke all on function public.record_recommendation_feedback(uuid, text)
  from public, anon, authenticated;
grant execute on function public.record_recommendation_feedback(uuid, text)
  to authenticated;
