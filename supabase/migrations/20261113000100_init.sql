-- ============================================================================
-- Roast My Bestie — initial schema, RLS policies and server-authoritative RPCs
-- ============================================================================
-- Design rules enforced here:
--   * Every exposed table has RLS enabled and least-privilege grants.
--   * Clients can only READ their own/allowed rows. Every write that affects
--     trust (matches, votes, results, coins, punishments, installs) goes
--     through a SECURITY DEFINER function which re-checks auth.uid().
--   * Realtime is a notification channel only; clients always re-fetch state.
--   * No raw IP addresses, no hardware identifiers, no service_role keys.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 1. Core tables
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null
    check (char_length(btrim(display_name)) between 2 and 24),
  avatar_path text,
  invite_code text not null unique
    check (invite_code ~ '^[A-Z0-9]{8}$'),
  wins integer not null default 0 check (wins >= 0),
  active_title_code text,
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles (id) on delete cascade,
  addressee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint friendships_no_self check (requester_id <> addressee_id)
);

-- One active relationship per pair, regardless of direction.
create unique index if not exists friendships_active_pair_idx
  on public.friendships (
    least(requester_id, addressee_id),
    greatest(requester_id, addressee_id)
  )
  where status in ('pending', 'accepted', 'blocked');

create index if not exists friendships_requester_idx
  on public.friendships (requester_id, created_at desc);
create index if not exists friendships_addressee_idx
  on public.friendships (addressee_id, created_at desc);

create table if not exists public.game_questions (
  id uuid primary key default gen_random_uuid(),
  game_type text not null default 'daily_roast'
    check (game_type in ('daily_roast', 'truth_or_lie', 'bestie_court')),
  prompt text not null check (char_length(btrim(prompt)) between 5 and 200),
  category text not null default 'everyday'
    check (category in ('everyday', 'food', 'habits', 'drama', 'gentle')),
  locale text not null default 'bn',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  constraint game_questions_unique_prompt unique (game_type, locale, prompt)
);

create index if not exists game_questions_pick_idx
  on public.game_questions (game_type, locale)
  where enabled;

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  game_type text not null default 'daily_roast'
    check (game_type in ('daily_roast', 'truth_or_lie', 'bestie_court')),
  player_one_id uuid not null references public.profiles (id) on delete cascade,
  player_two_id uuid not null references public.profiles (id) on delete cascade,
  question_id uuid references public.game_questions (id) on delete set null,
  state text not null default 'waiting'
    check (state in (
      'waiting', 'active', 'voting', 'revealing',
      'completed', 'cancelled', 'expired'
    )),
  created_at timestamptz not null default now(),
  started_at timestamptz,
  voting_deadline timestamptz,
  completed_at timestamptz,
  constraint matches_distinct_players check (player_one_id <> player_two_id)
);

create index if not exists matches_player_one_idx
  on public.matches (player_one_id, created_at desc, id desc);
create index if not exists matches_player_two_idx
  on public.matches (player_two_id, created_at desc, id desc);

-- Abuse guard: at most one open match per friend pair.
create unique index if not exists matches_open_pair_idx
  on public.matches (
    game_type,
    least(player_one_id, player_two_id),
    greatest(player_one_id, player_two_id)
  )
  where state in ('waiting', 'active', 'voting', 'revealing');

create table if not exists public.match_votes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  voted_for_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint match_votes_one_per_player unique (match_id, user_id)
);

create index if not exists match_votes_match_idx
  on public.match_votes (match_id);

create table if not exists public.match_results (
  match_id uuid primary key references public.matches (id) on delete cascade,
  winner_id uuid references public.profiles (id) on delete set null,
  is_tie boolean not null default false,
  result_payload jsonb not null default '{}'::jsonb,
  completed_at timestamptz not null default now()
);

create table if not exists public.punishments (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  display_text text not null,
  category text not null default 'fun',
  coin_cost integer not null default 15 check (coin_cost >= 0),
  enabled boolean not null default true
);

create table if not exists public.match_punishments (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  punishment_id uuid not null references public.punishments (id) on delete restrict,
  status text not null default 'offered'
    check (status in ('offered', 'accepted', 'completed', 'skipped', 'declined')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  completed_at timestamptz,
  skipped_at timestamptz,
  constraint match_punishments_one_per_player unique (match_id, user_id)
);

create table if not exists public.coin_wallets (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  balance integer not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.coin_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  amount integer not null check (amount <> 0),
  kind text not null
    check (kind in ('signup_bonus', 'match_reward', 'punishment_skip', 'weekly_award')),
  idempotency_key text not null,
  source_match_id uuid references public.matches (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint coin_transactions_idempotent unique (user_id, idempotency_key)
);

create index if not exists coin_transactions_user_idx
  on public.coin_transactions (user_id, created_at desc);

create table if not exists public.user_titles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  title_code text not null
    check (title_code in ('roast_champion', 'reply_ghost', 'drama_queen')),
  source_match_id uuid references public.matches (id) on delete set null,
  earned_at timestamptz not null default now(),
  constraint user_titles_unique unique (user_id, title_code)
);

create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform text not null default 'android'
    check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

-- Part 24: app-scoped, randomly generated installation id (NOT a hardware id).
create table if not exists public.user_installations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete cascade,
  installation_id text not null
    check (char_length(btrim(installation_id)) between 8 and 64),
  platform text not null default 'unknown'
    check (platform in ('android', 'ios', 'unknown')),
  android_version text,
  sdk_int integer,
  manufacturer text,
  model_name text,
  app_version text,
  integrity_status text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint user_installations_unique unique (user_id, installation_id)
);

create index if not exists user_installations_seen_idx
  on public.user_installations (user_id, last_seen_at desc);

-- Server-only risk log. Deliberately stores no raw IP address.
create table if not exists public.abuse_risk_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  installation_id text,
  event_type text not null
    check (event_type in (
      'installation_registered', 'rate_limit_hit',
      'duplicate_vote_attempt', 'invalid_state_attempt'
    )),
  risk_score integer not null default 0 check (risk_score between 0 and 100),
  action_taken text not null default 'none'
    check (action_taken in ('none', 'rate_limited', 'held', 'review')),
  created_at timestamptz not null default now()
);

create index if not exists abuse_risk_events_created_idx
  on public.abuse_risk_events (created_at desc);

-- ---------------------------------------------------------------------------
-- 2. Utility triggers / helpers
-- ---------------------------------------------------------------------------

create or replace function public.fn_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.fn_touch_updated_at();

drop trigger if exists trg_friendships_updated_at on public.friendships;
create trigger trg_friendships_updated_at
  before update on public.friendships
  for each row execute function public.fn_touch_updated_at();

create or replace function public.fn_generate_invite_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_attempt integer := 0;
begin
  loop
    v_attempt := v_attempt + 1;
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1 from public.profiles p where p.invite_code = v_code
    );
    if v_attempt > 25 then
      raise exception 'INVITE_CODE_GENERATION_FAILED';
    end if;
  end loop;
  return v_code;
end;
$$;

-- Creates the profile + wallet (+ signup bonus ledger entry) for a new user.
create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  v_name := btrim(
    coalesce(
      new.raw_user_meta_data ->> 'display_name',
      split_part(coalesce(new.email, 'bestie'), '@', 1)
    )
  );
  if char_length(v_name) < 2 then
    v_name := 'Bestie';
  end if;
  v_name := left(v_name, 24);

  insert into public.profiles (id, display_name, invite_code)
  values (new.id, v_name, public.fn_generate_invite_code())
  on conflict (id) do nothing;

  insert into public.coin_wallets (user_id, balance)
  values (new.id, 20)
  on conflict (user_id) do nothing;

  insert into public.coin_transactions (user_id, amount, kind, idempotency_key)
  values (new.id, 20, 'signup_bonus', 'signup')
  on conflict (user_id, idempotency_key) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_auth_user_created on auth.users;
create trigger trg_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_user();

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and (
        (f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a)
      )
  );
$$;

create or replace function public.is_match_participant(
  p_match_id uuid,
  p_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.matches m
    where m.id = p_match_id
      and (m.player_one_id = p_user_id or m.player_two_id = p_user_id)
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Server-authoritative match resolution
-- ---------------------------------------------------------------------------

create or replace function public.fn_resolve_match(
  p_match_id uuid,
  p_reason text default 'both_voted'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_match public.matches;
  v_votes_one bigint := 0;
  v_votes_two bigint := 0;
  v_winner uuid;
  v_loser uuid;
  v_is_tie boolean := false;
  v_punishment uuid;
  v_win_count bigint := 0;
begin
  select * into v_match
  from public.matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'MATCH_NOT_FOUND';
  end if;

  -- Idempotent: never resolve twice, never reward twice.
  if v_match.state in ('completed', 'cancelled', 'expired') then
    return;
  end if;

  select
    count(*) filter (where v.voted_for_id = v_match.player_one_id),
    count(*) filter (where v.voted_for_id = v_match.player_two_id)
  into v_votes_one, v_votes_two
  from public.match_votes v
  where v.match_id = p_match_id;

  if v_votes_one > v_votes_two then
    v_winner := v_match.player_one_id;
  elsif v_votes_two > v_votes_one then
    v_winner := v_match.player_two_id;
  else
    v_winner := null;
    v_is_tie := true;
  end if;

  insert into public.match_results (
    match_id, winner_id, is_tie, result_payload, completed_at
  )
  values (
    p_match_id,
    v_winner,
    v_is_tie,
    jsonb_build_object(
      'votes_for_player_one', v_votes_one,
      'votes_for_player_two', v_votes_two,
      'reason', p_reason
    ),
    now()
  )
  on conflict (match_id) do nothing;

  update public.matches
  set state = 'completed', completed_at = now()
  where id = p_match_id;

  -- Coin reward for participating in a fairly completed match.
  insert into public.coin_transactions (
    user_id, amount, kind, idempotency_key, source_match_id
  )
  select
    t.uid,
    10,
    'match_reward',
    'match:' || p_match_id::text || ':reward:' || t.uid::text,
    p_match_id
  from (
    values (v_match.player_one_id), (v_match.player_two_id)
  ) as t(uid)
  on conflict (user_id, idempotency_key) do nothing;

  update public.coin_wallets w
  set balance = coalesce((
        select sum(ct.amount)
        from public.coin_transactions ct
        where ct.user_id = w.user_id
      ), 0),
      updated_at = now()
  where w.user_id in (v_match.player_one_id, v_match.player_two_id);

  if v_winner is not null then
    update public.profiles
    set wins = wins + 1
    where id = v_winner;

    select count(*) into v_win_count
    from public.match_results r
    where r.winner_id = v_winner;

    if v_win_count >= 3 then
      insert into public.user_titles (user_id, title_code, source_match_id)
      values (v_winner, 'roast_champion', p_match_id)
      on conflict (user_id, title_code) do nothing;

      update public.profiles
      set active_title_code = 'roast_champion'
      where id = v_winner and active_title_code is null;
    end if;

    v_loser := case
      when v_winner = v_match.player_one_id then v_match.player_two_id
      else v_match.player_one_id
    end;
  end if;

  -- Harmless, optional punishment for the loser. Ties get none.
  if v_loser is not null then
    select id into v_punishment
    from public.punishments
    where enabled
    order by random()
    limit 1;

    if v_punishment is not null then
      insert into public.match_punishments (
        match_id, user_id, punishment_id, status
      )
      values (p_match_id, v_loser, v_punishment, 'offered')
      on conflict (match_id, user_id) do nothing;
    end if;
  end if;
end;
$$;

create or replace function public.fn_expire_stale_matches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
begin
  -- Voting window closed: resolve with the timeout policy (never hangs).
  for v_row in
    select m.id
    from public.matches m
    where m.state = 'voting'
      and m.voting_deadline is not null
      and m.voting_deadline < now()
    order by m.voting_deadline
    limit 25
  loop
    perform public.fn_resolve_match(v_row.id, 'timeout');
  end loop;

  -- Nobody joined within 24h.
  update public.matches
  set state = 'expired'
  where state = 'waiting'
    and created_at < now() - interval '24 hours';
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Client-facing RPCs (SECURITY DEFINER, all re-check auth.uid())
-- ---------------------------------------------------------------------------

create or replace function public.rpc_list_friends()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      jsonb_build_object(
        'friendship_id', f.id,
        'user_id', case
          when f.requester_id = v_uid then f.addressee_id
          else f.requester_id
        end,
        'display_name', coalesce(p.display_name, 'Bestie'),
        'status', f.status,
        'direction', case
          when f.status = 'accepted' then 'mutual'
          when f.requester_id = v_uid then 'outgoing'
          else 'incoming'
        end
      ) as row_data,
      f.created_at
    from public.friendships f
    join public.profiles p
      on p.id = case
        when f.requester_id = v_uid then f.addressee_id
        else f.requester_id
      end
    where (f.requester_id = v_uid or f.addressee_id = v_uid)
      and f.status <> 'rejected'
  ) s;

  return v_result;
end;
$$;

create or replace function public.rpc_lookup_invite_code(p_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
  v_lookups bigint := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select count(*) into v_lookups
  from public.abuse_risk_events e
  where e.user_id = v_uid
    and e.event_type = 'rate_limit_hit'
    and e.created_at > now() - interval '1 minute';
  if v_lookups > 20 then
    raise exception 'RATE_LIMITED';
  end if;

  select * into v_profile
  from public.profiles p
  where p.invite_code = upper(btrim(p_code));

  if not found then
    return '{}'::jsonb;
  end if;

  if v_profile.id = v_uid then
    raise exception 'CANNOT_FRIEND_SELF';
  end if;

  return jsonb_build_object(
    'user_id', v_profile.id,
    'display_name', v_profile.display_name,
    'already_friends', public.are_friends(v_uid, v_profile.id)
  );
end;
$$;

create or replace function public.rpc_send_friend_request_by_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_target uuid;
  v_recent bigint := 0;
  v_blocked boolean := false;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select id into v_target
  from public.profiles
  where invite_code = upper(btrim(p_code));

  if v_target is null then
    raise exception 'INVITE_NOT_FOUND';
  end if;
  if v_target = v_uid then
    raise exception 'CANNOT_FRIEND_SELF';
  end if;

  select exists (
    select 1 from public.friendships f
    where f.status = 'blocked'
      and (
        (f.requester_id = v_uid and f.addressee_id = v_target)
        or (f.requester_id = v_target and f.addressee_id = v_uid)
      )
  ) into v_blocked;
  if v_blocked then
    raise exception 'BLOCKED_RELATIONSHIP';
  end if;

  if public.are_friends(v_uid, v_target) then
    raise exception 'ALREADY_FRIENDS';
  end if;

  select count(*) into v_recent
  from public.friendships
  where requester_id = v_uid
    and created_at > now() - interval '60 seconds';
  if v_recent >= 10 then
    insert into public.abuse_risk_events (
      user_id, event_type, risk_score, action_taken
    )
    values (v_uid, 'rate_limit_hit', 30, 'rate_limited');
    raise exception 'RATE_LIMITED';
  end if;

  begin
    insert into public.friendships (requester_id, addressee_id, status)
    values (v_uid, v_target, 'pending');
  exception when unique_violation then
    raise exception 'ALREADY_REQUESTED';
  end;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.rpc_respond_friend_request(
  p_friendship_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.friendships;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_row
  from public.friendships f
  where f.id = p_friendship_id
    and f.addressee_id = v_uid
    and f.status = 'pending'
  for update;

  if not found then
    raise exception 'REQUEST_NOT_FOUND';
  end if;

  update public.friendships
  set status = case when p_accept then 'accepted' else 'rejected' end
  where id = v_row.id;
end;
$$;

create or replace function public.rpc_remove_friendship(p_friendship_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  delete from public.friendships f
  where f.id = p_friendship_id
    and (f.requester_id = v_uid or f.addressee_id = v_uid);
end;
$$;

create or replace function public.rpc_create_match(p_friend_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_question uuid;
  v_match_id uuid;
  v_recent bigint := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if p_friend_id = v_uid then
    raise exception 'CANNOT_FRIEND_SELF';
  end if;

  if not public.are_friends(v_uid, p_friend_id) then
    raise exception 'NOT_FRIENDS';
  end if;

  select count(*) into v_recent
  from public.matches
  where player_one_id = v_uid
    and created_at > now() - interval '10 minutes';
  if v_recent >= 5 then
    raise exception 'RATE_LIMITED';
  end if;

  -- Daily, server-selected question (client cannot choose or manipulate it).
  select id into v_question
  from public.game_questions q
  where q.game_type = 'daily_roast'
    and q.locale = 'bn'
    and q.enabled
  order by md5(q.id::text || to_char((now() at time zone 'utc'), 'YYYY-MM-DD'))
  limit 1;

  if v_question is null then
    raise exception 'INVALID_STATE';
  end if;

  begin
    insert into public.matches (
      game_type, player_one_id, player_two_id, question_id, state
    )
    values ('daily_roast', v_uid, p_friend_id, v_question, 'waiting')
    returning id into v_match_id;
  exception when unique_violation then
    raise exception 'INVALID_STATE';
  end;

  return jsonb_build_object('match_id', v_match_id);
end;
$$;

create or replace function public.rpc_join_match(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_match
  from public.matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'MATCH_NOT_FOUND';
  end if;
  if v_match.player_two_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;
  if v_match.state <> 'waiting' then
    raise exception 'MATCH_NOT_JOINABLE';
  end if;

  update public.matches
  set state = 'voting',
      started_at = now(),
      voting_deadline = now() + interval '10 minutes'
  where id = p_match_id;
end;
$$;

create or replace function public.rpc_submit_vote(
  p_match_id uuid,
  p_voted_for_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_vote_count bigint := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_match
  from public.matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'MATCH_NOT_FOUND';
  end if;
  if v_match.player_one_id <> v_uid and v_match.player_two_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;
  if v_match.state <> 'voting' then
    raise exception 'MATCH_NOT_ACTIVE';
  end if;

  if v_match.voting_deadline is not null and now() > v_match.voting_deadline then
    perform public.fn_resolve_match(p_match_id, 'timeout');
    raise exception 'VOTING_CLOSED';
  end if;

  if p_voted_for_id <> v_match.player_one_id
     and p_voted_for_id <> v_match.player_two_id then
    raise exception 'INVALID_CHOICE';
  end if;

  begin
    insert into public.match_votes (match_id, user_id, voted_for_id)
    values (p_match_id, v_uid, p_voted_for_id);
  exception when unique_violation then
    raise exception 'ALREADY_VOTED';
  end;

  select count(*) into v_vote_count
  from public.match_votes
  where match_id = p_match_id;

  if v_vote_count >= 2 then
    perform public.fn_resolve_match(p_match_id, 'both_voted');
  end if;
end;
$$;

create or replace function public.rpc_get_match(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_question text := '';
  v_p1 text := 'Bestie 1';
  v_p2 text := 'Bestie 2';
  v_my_vote uuid;
  v_opp_vote uuid;
  v_result public.match_results;
  v_punish jsonb;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_match from public.matches where id = p_match_id;
  if not found then
    raise exception 'MATCH_NOT_FOUND';
  end if;
  if v_match.player_one_id <> v_uid and v_match.player_two_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;

  -- Apply the documented timeout policy lazily, then re-read.
  if v_match.state = 'voting'
     and v_match.voting_deadline is not null
     and v_match.voting_deadline < now() then
    perform public.fn_resolve_match(p_match_id, 'timeout');
    select * into v_match from public.matches where id = p_match_id;
  end if;

  select coalesce(q.prompt, '') into v_question
  from public.game_questions q
  where q.id = v_match.question_id;

  select display_name into v_p1 from public.profiles
  where id = v_match.player_one_id;
  select display_name into v_p2 from public.profiles
  where id = v_match.player_two_id;

  select voted_for_id into v_my_vote
  from public.match_votes
  where match_id = p_match_id and user_id = v_uid;

  -- The opponent's vote is NEVER exposed before the match is resolved.
  if v_match.state = 'completed' then
    select voted_for_id into v_opp_vote
    from public.match_votes
    where match_id = p_match_id and user_id <> v_uid
    limit 1;
  end if;

  select * into v_result from public.match_results where match_id = p_match_id;

  select jsonb_build_object(
    'id', mp.id,
    'display_text', pu.display_text,
    'status', mp.status,
    'coin_cost', pu.coin_cost
  )
  into v_punish
  from public.match_punishments mp
  join public.punishments pu on pu.id = mp.punishment_id
  where mp.match_id = p_match_id and mp.user_id = v_uid
  limit 1;

  return jsonb_build_object(
    'id', v_match.id,
    'state', v_match.state,
    'question_prompt', coalesce(v_question, ''),
    'player_one_id', v_match.player_one_id,
    'player_two_id', v_match.player_two_id,
    'player_one_name', coalesce(v_p1, 'Bestie 1'),
    'player_two_name', coalesce(v_p2, 'Bestie 2'),
    'my_user_id', v_uid,
    'my_vote_for_id', v_my_vote,
    'opponent_vote_for_id', v_opp_vote,
    'winner_id', v_result.winner_id,
    'is_tie', coalesce(v_result.is_tie, false),
    'voting_deadline', v_match.voting_deadline,
    'punishment', v_punish
  );
end;
$$;

create or replace function public.rpc_list_matches(
  p_limit integer default 20,
  p_only_open boolean default false,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_page_limit integer;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Server-side clamp: never trust a client-provided limit.
  v_page_limit := least(greatest(coalesce(p_limit, 20), 1), 51);

  perform public.fn_expire_stale_matches();

  select coalesce(jsonb_agg(row_data), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'id', m.id,
      'state', m.state,
      'question_prompt', coalesce(q.prompt, ''),
      'opponent_name', coalesce(p.display_name, 'Bestie'),
      'i_am_player_one', m.player_one_id = v_uid,
      'created_at', m.created_at,
      'winner_id', r.winner_id,
      'is_tie', coalesce(r.is_tie, false)
    ) as row_data
    from public.matches m
    left join public.game_questions q on q.id = m.question_id
    left join public.match_results r on r.match_id = m.id
    left join public.profiles p
      on p.id = case
        when m.player_one_id = v_uid then m.player_two_id
        else m.player_one_id
      end
    where (m.player_one_id = v_uid or m.player_two_id = v_uid)
      and (
        not p_only_open
        or m.state in ('waiting', 'active', 'voting', 'revealing')
      )
      and (
        p_before_created_at is null
        or (
          p_before_id is not null
          and (m.created_at, m.id) < (p_before_created_at, p_before_id)
        )
      )
    order by m.created_at desc, m.id desc
    limit v_page_limit
  ) s;

  return v_result;
end;
$$;

create or replace function public.rpc_set_punishment_status(
  p_punishment_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.match_punishments;
  v_cost integer := 0;
  v_balance integer := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if p_status not in ('accepted', 'completed', 'skipped') then
    raise exception 'INVALID_STATE';
  end if;

  select * into v_row
  from public.match_punishments mp
  where mp.id = p_punishment_id and mp.user_id = v_uid
  for update;

  if not found then
    raise exception 'PUNISHMENT_NOT_FOUND';
  end if;
  if v_row.status in ('completed', 'skipped', 'declined') then
    raise exception 'INVALID_STATE';
  end if;

  if p_status = 'accepted' then
    update public.match_punishments
    set status = 'accepted', accepted_at = now()
    where id = v_row.id;
    return;
  end if;

  if p_status = 'completed' then
    update public.match_punishments
    set status = 'completed', completed_at = now()
    where id = v_row.id;
    return;
  end if;

  -- Skipping costs coins; price comes from the server catalogue.
  select coin_cost into v_cost
  from public.punishments
  where id = v_row.punishment_id;

  select balance into v_balance
  from public.coin_wallets
  where user_id = v_uid
  for update;

  if coalesce(v_balance, 0) < coalesce(v_cost, 0) then
    raise exception 'INSUFFICIENT_COINS';
  end if;

  insert into public.coin_transactions (
    user_id, amount, kind, idempotency_key, source_match_id
  )
  values (
    v_uid,
    -coalesce(v_cost, 0),
    'punishment_skip',
    'punish:' || v_row.id::text || ':skip',
    v_row.match_id
  )
  on conflict (user_id, idempotency_key) do nothing;

  update public.coin_wallets
  set balance = coalesce(v_balance, 0) - coalesce(v_cost, 0),
      updated_at = now()
  where user_id = v_uid;

  update public.match_punishments
  set status = 'skipped', skipped_at = now()
  where id = v_row.id;
end;
$$;

create or replace function public.rpc_register_installation(
  p_installation_id text,
  p_platform text,
  p_android_version text,
  p_sdk_int integer,
  p_manufacturer text,
  p_model_name text,
  p_app_version text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_recent bigint := 0;
  v_install text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  v_install := left(btrim(coalesce(p_installation_id, '')), 64);
  if char_length(v_install) < 8 then
    raise exception 'INVALID_STATE';
  end if;

  select count(*) into v_recent
  from public.user_installations
  where user_id = v_uid
    and last_seen_at > now() - interval '1 day';

  if v_recent > 10 then
    insert into public.abuse_risk_events (
      user_id, installation_id, event_type, risk_score, action_taken
    )
    values (v_uid, v_install, 'rate_limit_hit', 40, 'held');
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.user_installations (
    user_id, installation_id, platform, android_version, sdk_int,
    manufacturer, model_name, app_version
  )
  values (
    v_uid,
    v_install,
    case
      when p_platform in ('android', 'ios') then p_platform
      else 'unknown'
    end,
    left(coalesce(p_android_version, ''), 32),
    p_sdk_int,
    left(coalesce(p_manufacturer, ''), 48),
    left(coalesce(p_model_name, ''), 48),
    left(coalesce(p_app_version, ''), 32)
  )
  on conflict (user_id, installation_id) do update
    set last_seen_at = now(),
        app_version = excluded.app_version;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Grants (least privilege) and RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.game_questions enable row level security;
alter table public.matches enable row level security;
alter table public.match_votes enable row level security;
alter table public.match_results enable row level security;
alter table public.punishments enable row level security;
alter table public.match_punishments enable row level security;
alter table public.coin_wallets enable row level security;
alter table public.coin_transactions enable row level security;
alter table public.user_titles enable row level security;
alter table public.device_tokens enable row level security;
alter table public.user_installations enable row level security;
alter table public.abuse_risk_events enable row level security;

-- profiles: read own + friends, update own safe columns only.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, avatar_path, preferences, active_title_code)
  on public.profiles to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.are_friends(auth.uid(), id));

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- friendships: read own rows; all writes go through RPCs.
revoke all on public.friendships from anon, authenticated;
grant select on public.friendships to authenticated;

drop policy if exists friendships_select on public.friendships;
create policy friendships_select on public.friendships
  for select to authenticated
  using (requester_id = auth.uid() or addressee_id = auth.uid());

-- question / punishment catalogues: read-only, enabled rows only.
revoke all on public.game_questions from anon, authenticated;
grant select on public.game_questions to authenticated;

drop policy if exists game_questions_select on public.game_questions;
create policy game_questions_select on public.game_questions
  for select to authenticated
  using (enabled);

revoke all on public.punishments from anon, authenticated;
grant select on public.punishments to authenticated;

drop policy if exists punishments_select on public.punishments;
create policy punishments_select on public.punishments
  for select to authenticated
  using (enabled);

-- matches / votes / results / punishments: participants read only.
revoke all on public.matches from anon, authenticated;
grant select on public.matches to authenticated;

drop policy if exists matches_select on public.matches;
create policy matches_select on public.matches
  for select to authenticated
  using (
    player_one_id = auth.uid() or player_two_id = auth.uid()
  );

revoke all on public.match_votes from anon, authenticated;
grant select on public.match_votes to authenticated;

drop policy if exists match_votes_select on public.match_votes;
create policy match_votes_select on public.match_votes
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.matches m
      where m.id = match_votes.match_id
        and m.state = 'completed'
        and (m.player_one_id = auth.uid() or m.player_two_id = auth.uid())
    )
  );

revoke all on public.match_results from anon, authenticated;
grant select on public.match_results to authenticated;

drop policy if exists match_results_select on public.match_results;
create policy match_results_select on public.match_results
  for select to authenticated
  using (
    exists (
      select 1 from public.matches m
      where m.id = match_results.match_id
        and (m.player_one_id = auth.uid() or m.player_two_id = auth.uid())
    )
  );

revoke all on public.match_punishments from anon, authenticated;
grant select on public.match_punishments to authenticated;

drop policy if exists match_punishments_select on public.match_punishments;
create policy match_punishments_select on public.match_punishments
  for select to authenticated
  using (
    user_id = auth.uid()
    and exists (
      select 1 from public.matches m
      where m.id = match_punishments.match_id
        and (m.player_one_id = auth.uid() or m.player_two_id = auth.uid())
    )
  );

-- coins: read-only mirrors of the server ledger. Client can never write.
revoke all on public.coin_wallets from anon, authenticated;
grant select on public.coin_wallets to authenticated;

drop policy if exists coin_wallets_select on public.coin_wallets;
create policy coin_wallets_select on public.coin_wallets
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.coin_transactions from anon, authenticated;
grant select on public.coin_transactions to authenticated;

drop policy if exists coin_transactions_select on public.coin_transactions;
create policy coin_transactions_select on public.coin_transactions
  for select to authenticated
  using (user_id = auth.uid());

-- titles: own + friends.
revoke all on public.user_titles from anon, authenticated;
grant select on public.user_titles to authenticated;

drop policy if exists user_titles_select on public.user_titles;
create policy user_titles_select on public.user_titles
  for select to authenticated
  using (user_id = auth.uid() or public.are_friends(auth.uid(), user_id));

-- FCM device tokens: owner-only CRUD (push sending happens server-side).
revoke all on public.device_tokens from anon, authenticated;
grant select, insert, update, delete on public.device_tokens to authenticated;

drop policy if exists device_tokens_all on public.device_tokens;
create policy device_tokens_all on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- installations: own safe summary only; writes via RPC.
revoke all on public.user_installations from anon, authenticated;
grant select (id, platform, app_version, first_seen_at, last_seen_at)
  on public.user_installations to authenticated;

drop policy if exists user_installations_select on public.user_installations;
create policy user_installations_select on public.user_installations
  for select to authenticated
  using (user_id = auth.uid());

-- risk events: no client access at all (no grants, no policies).
revoke all on public.abuse_risk_events from anon, authenticated;

-- Function execution privileges: internal helpers must not be callable.
revoke all on function public.fn_resolve_match(uuid, text) from public;
revoke all on function public.fn_expire_stale_matches() from public;
revoke all on function public.fn_generate_invite_code() from public;
revoke all on function public.fn_handle_new_user() from public;
grant execute on function public.fn_resolve_match(uuid, text) to service_role;
grant execute on function public.fn_expire_stale_matches() to service_role;

grant execute on function public.rpc_list_friends() to authenticated;
grant execute on function public.rpc_lookup_invite_code(text) to authenticated;
grant execute on function public.rpc_send_friend_request_by_code(text)
  to authenticated;
grant execute on function public.rpc_respond_friend_request(uuid, boolean)
  to authenticated;
grant execute on function public.rpc_remove_friendship(uuid) to authenticated;
grant execute on function public.rpc_create_match(uuid) to authenticated;
grant execute on function public.rpc_join_match(uuid) to authenticated;
grant execute on function public.rpc_submit_vote(uuid, uuid) to authenticated;
grant execute on function public.rpc_get_match(uuid) to authenticated;
grant execute on function public.rpc_list_matches(integer, boolean, timestamptz, uuid)
  to authenticated;
grant execute on function public.rpc_set_punishment_status(uuid, text)
  to authenticated;
grant execute on function public.rpc_register_installation(
  text, text, text, integer, text, text, text
) to authenticated;
