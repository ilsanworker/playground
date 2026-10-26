-- BBANGBBANG HOTEL · Supabase schema
-- Run once in Supabase Dashboard → SQL Editor.
-- Uses RLS, server-side validation, and a database exclusion constraint to prevent overlapping active reservations.

create extension if not exists btree_gist;

create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 30),
  age integer not null check (age between 18 and 55),
  check_in date not null,
  check_out date not null,
  stay daterange generated always as (daterange(check_in, check_out, '[)')) stored,
  gender text not null check (gender = 'male'),
  dorm text not null check (dorm = 'yes'),
  memo text not null default '' check (char_length(memo) <= 300),
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled')),
  created_at timestamptz not null default now(),
  constraint valid_stay_dates check (check_in < check_out),
  constraint no_overlapping_active_reservations
    exclude using gist (stay with &&)
    where (status in ('pending','confirmed'))
);

create index if not exists reservations_created_at_idx on public.reservations (created_at desc);
create index if not exists reservations_status_idx on public.reservations (status);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.reservations enable row level security;
alter table public.admin_users enable row level security;

-- Default-deny client access. Admin access is explicitly granted below.
revoke all on table public.reservations from anon, authenticated;
grant select, update, delete on table public.reservations to authenticated;
revoke all on table public.admin_users from anon, authenticated;

-- Safe role check. The function uses an empty search_path and schema-qualified table names.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users au
    where au.user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create policy "Admins can read reservations"
on public.reservations for select
to authenticated
using ((select public.is_admin()));

create policy "Admins can update reservations"
on public.reservations for update
to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create policy "Admins can delete reservations"
on public.reservations for delete
to authenticated
using ((select public.is_admin()));

-- Public function returns only the occupied date range and status, never guest details.
create or replace function public.get_public_availability()
returns table(check_in date, check_out date, status text)
language sql
stable
security definer
set search_path = ''
as $$
  select r.check_in, r.check_out, r.status
  from public.reservations r
  where r.status in ('pending','confirmed')
  order by r.check_in;
$$;

revoke all on function public.get_public_availability() from public;
grant execute on function public.get_public_availability() to anon, authenticated;

-- Public booking endpoint. Database constraints provide the final overlap check,
-- including when two visitors submit at almost the same time.
create or replace function public.create_reservation(
  p_name text,
  p_age integer,
  p_check_in date,
  p_check_out date,
  p_gender text,
  p_dorm text,
  p_memo text default ''
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id uuid;
begin
  if p_name is null or char_length(trim(p_name)) < 1 or char_length(trim(p_name)) > 30 then
    raise exception '예약자 이름을 1~30자 사이로 입력해주세요.';
  end if;

  if p_age is null or p_age < 18 or p_age > 55 then
    raise exception '이 호텔은 만 18세부터 55세까지 이용할 수 있습니다.';
  end if;

  if p_gender is distinct from 'male' then
    raise exception '죄송합니다. 남성 투숙객만 예약할 수 있습니다.';
  end if;

  if p_dorm is distinct from 'yes' then
    raise exception '죄송합니다. 기숙사 사생만 예약할 수 있습니다.';
  end if;

  if p_check_in is null or p_check_out is null or p_check_in >= p_check_out then
    raise exception '체크인과 체크아웃 날짜를 확인해주세요.';
  end if;

  if p_check_in < current_date then
    raise exception '지난 날짜는 예약할 수 없습니다.';
  end if;

  if char_length(coalesce(p_memo, '')) > 300 then
    raise exception '전달 사항은 300자 이하로 입력해주세요.';
  end if;

  begin
    insert into public.reservations
      (name, age, check_in, check_out, gender, dorm, memo, status)
    values
      (trim(p_name), p_age, p_check_in, p_check_out, p_gender, p_dorm, coalesce(trim(p_memo), ''), 'pending')
    returning id into new_id;
  exception
    when exclusion_violation then
      raise exception '선택한 기간에 이미 신청되었거나 확정된 예약이 있습니다. 다른 날짜를 선택해주세요.';
  end;

  return new_id;
end;
$$;

revoke all on function public.create_reservation(text, integer, date, date, text, text, text) from public;
grant execute on function public.create_reservation(text, integer, date, date, text, text, text) to anon, authenticated;
