-- ============================================================================
-- Feature pack migration: every remaining master-prompt feature.
--   * block/report, notifications, preferences
--   * secret accusation + truth-or-lie (bluff rounds)
--   * bestie court (+ jury votes)
--   * friendship contract, confessions box
--   * silent treatment / ghosting nudge / slap wall (social pings)
--   * titles catalogue, weekly awards, friends leaderboard
--   * revenge round, punishment reroll
-- All writes are server-side SECURITY DEFINER functions re-checking auth.uid().
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_no_self check (blocker_id <> blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null
    check (reason in ('harassment', 'hate', 'spam', 'private_info', 'other')),
  note text check (note is null or char_length(note) <= 280),
  status text not null default 'open'
    check (status in ('open', 'reviewed', 'closed')),
  created_at timestamptz not null default now()
);

create index if not exists reports_created_idx on public.reports (created_at desc);

-- Secret accusation + truth-or-lie share one honest, server-owned mechanic.
create table if not exists public.bluff_rounds (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('secret_accusation', 'truth_or_lie')),
  author_id uuid not null references public.profiles (id) on delete cascade,
  target_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 8 and 200),
  options jsonb not null default '[]'::jsonb,
  answer_value integer not null check (answer_value between 0 and 3),
  guess_value integer check (guess_value between 0 and 3),
  status text not null default 'waiting'
    check (status in ('waiting', 'guessed', 'expired', 'cancelled')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '48 hours'),
  revealed_at timestamptz,
  constraint bluff_no_self check (author_id <> target_id)
);

create index if not exists bluff_target_idx
  on public.bluff_rounds (target_id, status, created_at desc);
create index if not exists bluff_author_idx
  on public.bluff_rounds (author_id, created_at desc);

create table if not exists public.court_cases (
  id uuid primary key default gen_random_uuid(),
  plaintiff_id uuid not null references public.profiles (id) on delete cascade,
  defendant_id uuid not null references public.profiles (id) on delete cascade,
  complaint text not null check (char_length(btrim(complaint)) between 8 and 240),
  response text check (response is null or char_length(response) <= 240),
  state text not null default 'awaiting_response'
    check (state in ('awaiting_response', 'voting', 'decided', 'cancelled')),
  verdict text check (verdict in ('guilty', 'not_guilty', 'split', 'dismissed')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  constraint court_no_self check (plaintiff_id <> defendant_id)
);

create index if not exists court_plaintiff_idx
  on public.court_cases (plaintiff_id, created_at desc);
create index if not exists court_defendant_idx
  on public.court_cases (defendant_id, created_at desc);

create table if not exists public.court_votes (
  case_id uuid not null references public.court_cases (id) on delete cascade,
  voter_id uuid not null references public.profiles (id) on delete cascade,
  choice text not null check (choice in ('guilty', 'not_guilty')),
  created_at timestamptz not null default now(),
  primary key (case_id, voter_id)
);

create table if not exists public.contract_templates (
  code text primary key,
  title text not null,
  clauses jsonb not null,
  enabled boolean not null default true
);

create table if not exists public.contracts (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles (id) on delete cascade,
  participant_id uuid not null references public.profiles (id) on delete cascade,
  template_code text not null references public.contract_templates (code),
  state text not null default 'pending'
    check (state in ('pending', 'active', 'declined', 'cancelled', 'expired')),
  creator_accepted boolean not null default true,
  participant_accepted boolean not null default false,
  entertainment_only boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  constraint contracts_no_self check (creator_id <> participant_id)
);

create unique index if not exists contracts_open_pair_idx
  on public.contracts (
    least(creator_id, participant_id),
    greatest(creator_id, participant_id)
  )
  where state in ('pending', 'active');

create table if not exists public.confessions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  content text not null check (char_length(btrim(content)) between 4 and 280),
  shared_with uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index if not exists confessions_owner_idx
  on public.confessions (owner_id, created_at desc);

-- Silent treatment war, ghosting reminder and virtual slap wall.
create table if not exists public.social_pings (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles (id) on delete cascade,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null
    check (kind in ('angry', 'sorry', 'reminder', 'tomato', 'slipper')),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  dismissed_at timestamptz,
  constraint pings_no_self check (sender_id <> recipient_id)
);

create index if not exists social_pings_recipient_idx
  on public.social_pings (recipient_id, created_at desc);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  type text not null
    check (type in (
      'friend_request', 'friend_accept', 'match_invite', 'match_result',
      'nudge', 'slap', 'accusation', 'truth', 'court', 'contract', 'award'
    )),
  title text not null check (char_length(title) <= 80),
  body text not null check (char_length(body) <= 160),
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

create table if not exists public.title_catalog (
  code text primary key,
  label text not null,
  description text not null,
  emoji text not null default '🏅',
  enabled boolean not null default true
);

alter table public.matches
  add column if not exists revenge_of uuid
  references public.matches (id) on delete set null;

alter table public.match_punishments
  add column if not exists reroll_count integer not null default 0
  check (reroll_count >= 0);

-- ---------------------------------------------------------------------------
-- 2. Helpers
-- ---------------------------------------------------------------------------

create or replace function public.fn_blocked(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.blocks x
    where (x.blocker_id = a and x.blocked_id = b)
       or (x.blocker_id = b and x.blocked_id = a)
  );
$$;

create or replace function public.fn_require_friends(a uuid, b uuid)
returns void
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if a = b then
    raise exception 'CANNOT_FRIEND_SELF';
  end if;
  if public.fn_blocked(a, b) then
    raise exception 'BLOCKED_RELATIONSHIP';
  end if;
  if not public.are_friends(a, b) then
    raise exception 'NOT_FRIENDS';
  end if;
end;
$$;

create or replace function public.fn_pref(p_user uuid, p_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_value text;
begin
  select p.preferences ->> p_key into v_value
  from public.profiles p where p.id = p_user;
  return coalesce(v_value, 'true') <> 'false';
end;
$$;

create or replace function public.fn_notify(
  p_recipient uuid,
  p_type text,
  p_title text,
  p_body text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient is null then
    return;
  end if;
  insert into public.notifications (recipient_id, type, title, body)
  values (p_recipient, p_type, left(p_title, 80), left(p_body, 160));
end;
$$;

create or replace function public.fn_count_pings(
  p_sender uuid,
  p_recipient uuid,
  p_kind text
)
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(*) from public.social_pings p
  where p.sender_id = p_sender
    and p.recipient_id = p_recipient
    and p.kind = p_kind
    and p.created_at > now() - interval '1 day';
$$;

-- ---------------------------------------------------------------------------
-- 3. Redefine match resolution: titles, notifications, revenge-safe
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
  v_played bigint := 0;
begin
  select * into v_match from public.matches where id = p_match_id for update;

  if not found then
    raise exception 'MATCH_NOT_FOUND';
  end if;
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
        select sum(ct.amount) from public.coin_transactions ct
        where ct.user_id = w.user_id
      ), 0),
      updated_at = now()
  where w.user_id in (v_match.player_one_id, v_match.player_two_id);

  -- Earned titles (server-verified stats only).
  select count(*) into v_played
  from public.matches m
  where m.state = 'completed'
    and (m.player_one_id = v_match.player_one_id
      or m.player_two_id = v_match.player_one_id);

  if v_played >= 1 then
    insert into public.user_titles (user_id, title_code, source_match_id)
    values (v_match.player_one_id, 'reply_ghost', p_match_id)
    on conflict (user_id, title_code) do nothing;
    insert into public.user_titles (user_id, title_code, source_match_id)
    values (v_match.player_two_id, 'reply_ghost', p_match_id)
    on conflict (user_id, title_code) do nothing;
  end if;

  if v_played >= 5 then
    insert into public.user_titles (user_id, title_code, source_match_id)
    values (v_match.player_one_id, 'drama_queen', p_match_id)
    on conflict (user_id, title_code) do nothing;
    insert into public.user_titles (user_id, title_code, source_match_id)
    values (v_match.player_two_id, 'drama_queen', p_match_id)
    on conflict (user_id, title_code) do nothing;
  end if;

  if v_winner is not null then
    update public.profiles set wins = wins + 1 where id = v_winner;

    select count(*) into v_win_count
    from public.match_results r where r.winner_id = v_winner;

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

  if v_loser is not null then
    select id into v_punishment
    from public.punishments where enabled order by random() limit 1;

    if v_punishment is not null then
      insert into public.match_punishments (
        match_id, user_id, punishment_id, status
      )
      values (p_match_id, v_loser, v_punishment, 'offered')
      on conflict (match_id, user_id) do nothing;
    end if;
  end if;

  perform public.fn_notify(
    v_match.player_one_id,
    'match_result',
    'ম্যাচ শেষ!',
    case
      when v_is_tie then 'আজকের ম্যাচ ড্র হয়েছে।'
      when v_winner = v_match.player_one_id then 'আপনি জিতেছেন! 🏆'
      else 'এবার হেরে গেছেন — রিভেঞ্জ নিন!'
    end
  );
  perform public.fn_notify(
    v_match.player_two_id,
    'match_result',
    'ম্যাচ শেষ!',
    case
      when v_is_tie then 'আজকের ম্যাচ ড্র হয়েছে।'
      when v_winner = v_match.player_two_id then 'আপনি জিতেছেন! 🏆'
      else 'এবার হেরে গেছেন — রিভেঞ্জ নিন!'
    end
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Block / report / preferences
-- ---------------------------------------------------------------------------

create or replace function public.rpc_block_user(
  p_user_id uuid,
  p_blocked boolean
)
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
  if p_user_id = v_uid then
    raise exception 'CANNOT_FRIEND_SELF';
  end if;

  if p_blocked then
    insert into public.blocks (blocker_id, blocked_id)
    values (v_uid, p_user_id)
    on conflict do nothing;

    delete from public.friendships f
    where (f.requester_id = v_uid and f.addressee_id = p_user_id)
       or (f.requester_id = p_user_id and f.addressee_id = v_uid);
  else
    delete from public.blocks b
    where b.blocker_id = v_uid and b.blocked_id = p_user_id;
  end if;
end;
$$;

create or replace function public.rpc_report_user(
  p_user_id uuid,
  p_reason text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_recent bigint := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_user_id = v_uid then
    raise exception 'CANNOT_FRIEND_SELF';
  end if;

  select count(*) into v_recent from public.reports r
  where r.reporter_id = v_uid and r.created_at > now() - interval '1 day';
  if v_recent >= 10 then
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.reports (reporter_id, target_id, reason, note)
  values (v_uid, p_user_id, p_reason, nullif(btrim(coalesce(p_note, '')), ''));
end;
$$;

create or replace function public.rpc_update_preferences(p_prefs jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_clean jsonb := '{}'::jsonb;
  v_humor text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  v_humor := p_prefs ->> 'humor';
  if v_humor is not null and v_humor not in ('gentle', 'playful', 'spicy') then
    raise exception 'INVALID_STATE';
  end if;

  if v_humor is not null then
    v_clean := v_clean || jsonb_build_object('humor', v_humor);
  end if;
  if p_prefs ? 'nudges' then
    v_clean := v_clean || jsonb_build_object('nudges', (p_prefs ->> 'nudges'));
  end if;
  if p_prefs ? 'slaps' then
    v_clean := v_clean || jsonb_build_object('slaps', (p_prefs ->> 'slaps'));
  end if;
  if p_prefs ? 'awards' then
    v_clean := v_clean || jsonb_build_object('awards', (p_prefs ->> 'awards'));
  end if;

  update public.profiles
  set preferences = coalesce(preferences, '{}'::jsonb) || v_clean
  where id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Notifications inbox
-- ---------------------------------------------------------------------------

create or replace function public.rpc_list_notifications(p_limit integer default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_limit integer;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  v_limit := least(greatest(coalesce(p_limit, 30), 1), 50);

  select coalesce(jsonb_agg(row_data), '[]'::jsonb) into v_result
  from (
    select jsonb_build_object(
      'id', n.id,
      'type', n.type,
      'title', n.title,
      'body', n.body,
      'read_at', n.read_at,
      'created_at', n.created_at
    ) as row_data
    from public.notifications n
    where n.recipient_id = v_uid
    order by n.created_at desc
    limit v_limit
  ) s;

  return v_result;
end;
$$;

create or replace function public.rpc_mark_notifications_read()
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
  update public.notifications
  set read_at = now()
  where recipient_id = v_uid and read_at is null;
end;
$$;

create or replace function public.rpc_unread_notification_count()
returns integer
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
  return (
    select count(*)::integer from public.notifications
    where recipient_id = v_uid and read_at is null
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Bluff rounds (secret accusation + truth or lie)
-- ---------------------------------------------------------------------------

create or replace function public.fn_expire_bluffs()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.bluff_rounds
  set status = 'expired'
  where status = 'waiting' and expires_at < now();
end;
$$;

create or replace function public.rpc_create_bluff_round(
  p_kind text,
  p_target_id uuid,
  p_body text,
  p_answer_value integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_open bigint := 0;
  v_id uuid;
  v_options jsonb := '[]'::jsonb;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_kind not in ('secret_accusation', 'truth_or_lie') then
    raise exception 'INVALID_STATE';
  end if;
  perform public.fn_require_friends(v_uid, p_target_id);

  if char_length(btrim(coalesce(p_body, ''))) < 8 then
    raise exception 'INVALID_STATE';
  end if;

  if p_kind = 'secret_accusation' then
    if p_answer_value not between 0 and 3 then
      raise exception 'INVALID_CHOICE';
    end if;
    v_options := jsonb_build_array(
      'একদম সত্যি', 'আধা সত্যি', 'একদম মিথ্যা', 'জানি না'
    );
  else
    if p_answer_value not between 0 and 1 then
      raise exception 'INVALID_CHOICE';
    end if;
    v_options := jsonb_build_array('সত্যি', 'মিথ্যা');
  end if;

  select count(*) into v_open from public.bluff_rounds b
  where b.author_id = v_uid
    and b.status = 'waiting'
    and b.created_at > now() - interval '1 day';
  if v_open >= 10 then
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.bluff_rounds (
    kind, author_id, target_id, body, options, answer_value
  )
  values (p_kind, v_uid, p_target_id, btrim(p_body), v_options, p_answer_value)
  returning id into v_id;

  perform public.fn_notify(
    p_target_id,
    case when p_kind = 'secret_accusation' then 'accusation' else 'truth' end,
    case when p_kind = 'secret_accusation'
      then 'নতুন গোপন অভিযোগ!' else 'সত্যি নাকি মিথ্যা?' end,
    'একটি নতুন রাউন্ড আপনার জন্য অপেক্ষা করছে।'
  );

  return jsonb_build_object('id', v_id);
end;
$$;

create or replace function public.rpc_guess_bluff_round(
  p_id uuid,
  p_guess_value integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.bluff_rounds;
  v_matched boolean;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_row from public.bluff_rounds where id = p_id for update;
  if not found then
    raise exception 'ROUND_NOT_FOUND';
  end if;
  if v_row.target_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;
  if v_row.status <> 'waiting' then
    raise exception 'INVALID_STATE';
  end if;
  if v_row.expires_at < now() then
    raise exception 'INVALID_STATE';
  end if;

  v_matched := p_guess_value = v_row.answer_value;

  update public.bluff_rounds
  set guess_value = p_guess_value,
      status = 'guessed',
      revealed_at = now()
  where id = p_id;

  if v_matched then
    insert into public.coin_transactions (
      user_id, amount, kind, idempotency_key
    )
    values (v_uid, 5, 'match_reward', 'bluff:' || p_id::text || ':reward')
    on conflict (user_id, idempotency_key) do nothing;

    update public.coin_wallets
    set balance = coalesce((
          select sum(ct.amount) from public.coin_transactions ct
          where ct.user_id = v_uid
        ), 0),
        updated_at = now()
    where user_id = v_uid;
  end if;

  perform public.fn_notify(
    v_row.author_id,
    'accusation',
    'আপনার রাউন্ডের উত্তর এসেছে!',
    'কী হয়েছিল দেখে নিন।'
  );

  return jsonb_build_object('matched', v_matched);
end;
$$;

create or replace function public.rpc_list_bluff_rounds(p_kind text)
returns jsonb
language plpgsql
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
  if p_kind is not null and p_kind not in ('secret_accusation', 'truth_or_lie') then
    raise exception 'INVALID_STATE';
  end if;

  perform public.fn_expire_bluffs();

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      jsonb_build_object(
        'id', b.id,
        'kind', b.kind,
        'author_id', b.author_id,
        'target_id', b.target_id,
        'author_name', coalesce(pa.display_name, 'Bestie'),
        'target_name', coalesce(pt.display_name, 'Bestie'),
        -- The secret stays hidden from the target until they guessed.
        'body', case
          when b.status <> 'waiting' or b.author_id = v_uid then b.body
          else null
        end,
        'options', b.options,
        'my_role', case when b.author_id = v_uid then 'author' else 'target' end,
        'status', b.status,
        'my_guess', b.guess_value,
        'answer_value', case
          when b.status <> 'waiting' then b.answer_value else null
        end,
        'is_true', case
          when b.status <> 'waiting' then (b.answer_value = 0) else null
        end,
        'created_at', b.created_at,
        'expires_at', b.expires_at
      ) as row_data,
      b.created_at
    from public.bluff_rounds b
    join public.profiles pa on pa.id = b.author_id
    join public.profiles pt on pt.id = b.target_id
    where (b.author_id = v_uid or b.target_id = v_uid)
      and (p_kind is null or b.kind = p_kind)
    order by b.created_at desc
    limit 30
  ) s;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Bestie court
-- ---------------------------------------------------------------------------

create or replace function public.fn_decide_court_case(p_case_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_case public.court_cases;
  v_guilty bigint := 0;
  v_clean bigint := 0;
  v_verdict text;
begin
  select * into v_case from public.court_cases where id = p_case_id for update;
  if not found then
    raise exception 'CASE_NOT_FOUND';
  end if;
  if v_case.state = 'decided' then
    return;
  end if;

  select
    count(*) filter (where v.choice = 'guilty'),
    count(*) filter (where v.choice = 'not_guilty')
  into v_guilty, v_clean
  from public.court_votes v where v.case_id = p_case_id;

  if v_guilty = 0 and v_clean = 0 then
    v_verdict := 'dismissed';
  elsif v_guilty > v_clean then
    v_verdict := 'guilty';
  elsif v_clean > v_guilty then
    v_verdict := 'not_guilty';
  else
    v_verdict := 'split';
  end if;

  update public.court_cases
  set state = 'decided', verdict = v_verdict, decided_at = now()
  where id = p_case_id;

  perform public.fn_notify(
    v_case.plaintiff_id, 'court', 'রায় ঘোষণা হয়েছে!',
    case v_verdict
      when 'guilty' then 'জুরি বলেছে: দোষী।'
      when 'not_guilty' then 'জুরি বলেছে: নির্দোষ।'
      when 'split' then 'জুরি বিভক্ত — মামলা খারিজ।'
      else 'কোনো ভোট পড়েনি — মামলা খারিজ।'
    end
  );
  perform public.fn_notify(
    v_case.defendant_id, 'court', 'রায় ঘোষণা হয়েছে!',
    case v_verdict
      when 'guilty' then 'জুরি বলেছে: দোষী।'
      when 'not_guilty' then 'জুরি বলেছে: নির্দোষ।'
      when 'split' then 'জুরি বিভক্ত — মামলা খারিজ।'
      else 'কোনো ভোট পড়েনি — মামলা খারিজ।'
    end
  );
end;
$$;

create or replace function public.rpc_create_court_case(
  p_defendant_id uuid,
  p_complaint text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_open bigint := 0;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  perform public.fn_require_friends(v_uid, p_defendant_id);

  if char_length(btrim(coalesce(p_complaint, ''))) < 8 then
    raise exception 'INVALID_STATE';
  end if;

  select count(*) into v_open from public.court_cases c
  where c.plaintiff_id = v_uid
    and c.state in ('awaiting_response', 'voting');
  if v_open >= 3 then
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.court_cases (plaintiff_id, defendant_id, complaint)
  values (v_uid, p_defendant_id, btrim(p_complaint))
  returning id into v_id;

  perform public.fn_notify(
    p_defendant_id, 'court', 'আদালতে ডাকা হয়েছে!',
    'আপনার বিরুদ্ধে একটি মজার অভিযোগ দায়ের হয়েছে।'
  );

  return jsonb_build_object('id', v_id);
end;
$$;

create or replace function public.rpc_respond_court_case(
  p_case_id uuid,
  p_response text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_case public.court_cases;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_case from public.court_cases where id = p_case_id for update;
  if not found then
    raise exception 'CASE_NOT_FOUND';
  end if;
  if v_case.defendant_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;
  if v_case.state <> 'awaiting_response' then
    raise exception 'INVALID_STATE';
  end if;

  update public.court_cases
  set response = nullif(btrim(coalesce(p_response, '')), ''),
      state = 'voting'
  where id = p_case_id;

  perform public.fn_notify(
    v_case.plaintiff_id, 'court', 'প্রতিবাদী উত্তর দিয়েছে!',
    'এখন জুরি হিসেবে আপনার ভোট দিন।'
  );
end;
$$;

create or replace function public.rpc_vote_court_case(
  p_case_id uuid,
  p_choice text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_case public.court_cases;
  v_votes bigint := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_choice not in ('guilty', 'not_guilty') then
    raise exception 'INVALID_CHOICE';
  end if;

  select * into v_case from public.court_cases where id = p_case_id for update;
  if not found then
    raise exception 'CASE_NOT_FOUND';
  end if;
  if v_case.plaintiff_id <> v_uid and v_case.defendant_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;
  if v_case.state <> 'voting' then
    raise exception 'INVALID_STATE';
  end if;

  begin
    insert into public.court_votes (case_id, voter_id, choice)
    values (p_case_id, v_uid, p_choice);
  exception when unique_violation then
    raise exception 'ALREADY_VOTED';
  end;

  select count(*) into v_votes from public.court_votes where case_id = p_case_id;
  if v_votes >= 2 then
    perform public.fn_decide_court_case(p_case_id);
  end if;
end;
$$;

create or replace function public.rpc_list_court_cases()
returns jsonb
language plpgsql
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

  -- Timeout policy: a stalled case is decided with the votes it has.
  perform public.fn_decide_court_case(c.id)
  from public.court_cases c
  where c.state = 'voting'
    and c.created_at < now() - interval '24 hours'
    and (c.plaintiff_id = v_uid or c.defendant_id = v_uid)
  limit 10;

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      jsonb_build_object(
        'id', c.id,
        'plaintiff_id', c.plaintiff_id,
        'defendant_id', c.defendant_id,
        'plaintiff_name', coalesce(pp.display_name, 'Bestie'),
        'defendant_name', coalesce(pd.display_name, 'Bestie'),
        'complaint', c.complaint,
        'response', c.response,
        'state', c.state,
        'verdict', c.verdict,
        'my_role', case
          when c.plaintiff_id = v_uid then 'plaintiff' else 'defendant'
        end,
        'my_vote', (
          select v.choice from public.court_votes v
          where v.case_id = c.id and v.voter_id = v_uid
        ),
        'created_at', c.created_at,
        'decided_at', c.decided_at
      ) as row_data,
      c.created_at
    from public.court_cases c
    join public.profiles pp on pp.id = c.plaintiff_id
    join public.profiles pd on pd.id = c.defendant_id
    where c.plaintiff_id = v_uid or c.defendant_id = v_uid
    order by c.created_at desc
    limit 30
  ) s;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Friendship contract
-- ---------------------------------------------------------------------------

create or replace function public.rpc_create_contract(
  p_participant_id uuid,
  p_template_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  perform public.fn_require_friends(v_uid, p_participant_id);

  if not exists (
    select 1 from public.contract_templates t
    where t.code = p_template_code and t.enabled
  ) then
    raise exception 'INVALID_STATE';
  end if;

  begin
    insert into public.contracts (
      creator_id, participant_id, template_code
    )
    values (v_uid, p_participant_id, p_template_code)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'CONTRACT_EXISTS';
  end;

  perform public.fn_notify(
    p_participant_id, 'contract', 'বন্ধুত্বের চুক্তি এসেছে!',
    'মজার চুক্তিটি পড়ে গ্রহণ করুন বা বাতিল করুন।'
  );

  return jsonb_build_object('id', v_id);
end;
$$;

create or replace function public.rpc_respond_contract(
  p_contract_id uuid,
  p_accept boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.contracts;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_row from public.contracts where id = p_contract_id for update;
  if not found then
    raise exception 'CONTRACT_NOT_FOUND';
  end if;
  if v_row.participant_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;
  if v_row.state <> 'pending' then
    raise exception 'INVALID_STATE';
  end if;

  update public.contracts
  set state = case when p_accept then 'active' else 'declined' end,
      participant_accepted = p_accept
  where id = p_contract_id;

  perform public.fn_notify(
    v_row.creator_id, 'contract',
    case when p_accept then 'চুক্তি সই হয়েছে!' else 'চুক্তি গ্রহণ করা হয়নি' end,
    'মজার জন্য, আইনি নয়।'
  );
end;
$$;

create or replace function public.rpc_cancel_contract(p_contract_id uuid)
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

  update public.contracts
  set state = 'cancelled'
  where id = p_contract_id
    and state in ('pending', 'active')
    and (creator_id = v_uid or participant_id = v_uid);
end;
$$;

create or replace function public.rpc_list_contracts()
returns jsonb
language plpgsql
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

  update public.contracts
  set state = 'expired'
  where state in ('pending', 'active')
    and expires_at < now()
    and (creator_id = v_uid or participant_id = v_uid);

  select coalesce(jsonb_agg(row_data order by created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      jsonb_build_object(
        'id', c.id,
        'creator_id', c.creator_id,
        'participant_id', c.participant_id,
        'creator_name', coalesce(pc.display_name, 'Bestie'),
        'participant_name', coalesce(pt.display_name, 'Bestie'),
        'title', coalesce(t.title, c.template_code),
        'clauses', coalesce(t.clauses, '[]'::jsonb),
        'state', c.state,
        'my_role', case
          when c.creator_id = v_uid then 'creator' else 'participant'
        end,
        'created_at', c.created_at,
        'expires_at', c.expires_at,
        'entertainment_only', c.entertainment_only
      ) as row_data,
      c.created_at
    from public.contracts c
    join public.profiles pc on pc.id = c.creator_id
    join public.profiles pt on pt.id = c.participant_id
    left join public.contract_templates t on t.code = c.template_code
    where c.creator_id = v_uid or c.participant_id = v_uid
    order by c.created_at desc
    limit 30
  ) s;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Confessions (owner-only by default, explicit sharing)
-- ---------------------------------------------------------------------------

create or replace function public.rpc_share_confession(
  p_confession_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.confessions;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_row from public.confessions where id = p_confession_id;
  if not found then
    raise exception 'CONFESSION_NOT_FOUND';
  end if;
  if v_row.owner_id <> v_uid then
    raise exception 'NOT_PARTICIPANT';
  end if;

  if p_user_id is not null then
    perform public.fn_require_friends(v_uid, p_user_id);
    perform public.fn_notify(
      p_user_id, 'contract', 'একটি গোপন কথা শেয়ার করা হয়েছে',
      'বন্ধু আপনাকে একটি কনফেশন দেখতে দিয়েছে।'
    );
  end if;

  update public.confessions
  set shared_with = p_user_id, updated_at = now()
  where id = p_confession_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Social pings: silent treatment, ghosting nudge, slap wall
-- ---------------------------------------------------------------------------

create or replace function public.rpc_send_ping(
  p_recipient_id uuid,
  p_kind text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_count bigint := 0;
  v_limit integer;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_kind not in ('angry', 'sorry', 'reminder', 'tomato', 'slipper') then
    raise exception 'INVALID_STATE';
  end if;

  perform public.fn_require_friends(v_uid, p_recipient_id);

  if p_kind in ('tomato', 'slipper') and not public.fn_pref(p_recipient_id, 'slaps') then
    raise exception 'RECIPIENT_MUTED';
  end if;
  if p_kind in ('angry', 'sorry', 'reminder')
     and not public.fn_pref(p_recipient_id, 'nudges') then
    raise exception 'RECIPIENT_MUTED';
  end if;

  v_limit := case when p_kind in ('tomato', 'slipper') then 5 else 3 end;
  v_count := public.fn_count_pings(v_uid, p_recipient_id, p_kind);
  if v_count >= v_limit then
    raise exception 'RATE_LIMITED';
  end if;

  insert into public.social_pings (sender_id, recipient_id, kind)
  values (v_uid, p_recipient_id, p_kind);

  perform public.fn_notify(
    p_recipient_id,
    case when p_kind in ('tomato', 'slipper') then 'slap' else 'nudge' end,
    case p_kind
      when 'angry' then 'বন্ধু রাগ করে আছে! 😤'
      when 'sorry' then 'একটি সখ্যতা-প্রস্তাব এসেছে 🥺'
      when 'reminder' then 'একটি মজার রিমাইন্ডার'
      when 'tomato' then 'টমেটো এসেছে! 🍅'
      else 'চপ্পল এসেছে! 🩴'
    end,
    'অ্যাপের ভেতরে দেখে নিন।'
  );
end;
$$;

create or replace function public.rpc_list_pings()
returns jsonb
language plpgsql
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
        'id', s.id,
        'kind', s.kind,
        'sender_id', s.sender_id,
        'recipient_id', s.recipient_id,
        'sender_name', coalesce(p.display_name, 'Bestie'),
        'direction', case when s.recipient_id = v_uid then 'in' else 'out' end,
        'read_at', s.read_at,
        'dismissed_at', s.dismissed_at,
        'created_at', s.created_at
      ) as row_data,
      s.created_at
    from public.social_pings s
    join public.profiles p
      on p.id = case
        when s.recipient_id = v_uid then s.sender_id else s.recipient_id
      end
    where s.recipient_id = v_uid or s.sender_id = v_uid
    order by s.created_at desc
    limit 40
  ) s;

  return v_result;
end;
$$;

create or replace function public.rpc_dismiss_ping(p_ping_id uuid)
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
  update public.social_pings
  set dismissed_at = now(), read_at = coalesce(read_at, now())
  where id = p_ping_id and recipient_id = v_uid;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Titles, leaderboard, weekly awards
-- ---------------------------------------------------------------------------

create or replace function public.rpc_my_titles()
returns jsonb
language plpgsql
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

  select coalesce(jsonb_agg(row_data order by row_data ->> 'label'), '[]'::jsonb)
  into v_result
  from (
    select jsonb_build_object(
      'code', t.code,
      'label', t.label,
      'description', t.description,
      'emoji', t.emoji,
      'earned', ut.user_id is not null,
      'active', coalesce(p.active_title_code = t.code, false)
    ) as row_data
    from public.title_catalog t
    cross join public.profiles p
    left join public.user_titles ut
      on ut.title_code = t.code and ut.user_id = v_uid
    where t.enabled and p.id = v_uid
  ) s;

  return v_result;
end;
$$;

create or replace function public.rpc_set_active_title(p_code text)
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

  if p_code is null or p_code = '' then
    update public.profiles set active_title_code = null where id = v_uid;
    return;
  end if;

  if not exists (
    select 1 from public.user_titles ut
    where ut.user_id = v_uid and ut.title_code = p_code
  ) then
    raise exception 'TITLE_NOT_EARNED';
  end if;

  update public.profiles set active_title_code = p_code where id = v_uid;
end;
$$;

create or replace function public.rpc_friends_leaderboard()
returns jsonb
language plpgsql
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

  select coalesce(jsonb_agg(row_data order by wins desc, played desc, name asc), '[]'::jsonb)
  into v_result
  from (
    select
      jsonb_build_object(
        'user_id', x.uid,
        'display_name', x.name,
        'wins', x.wins,
        'played', x.played,
        'is_me', x.uid = v_uid
      ) as row_data,
      x.wins,
      x.played,
      x.name
    from (
      select
        p.id as uid,
        p.display_name as name,
        (
          select count(*) from public.matches m
          join public.match_results r on r.match_id = m.id
          where r.winner_id = p.id
            and m.completed_at > date_trunc('week', now())
        ) as wins,
        (
          select count(*) from public.matches m
          where (m.player_one_id = p.id or m.player_two_id = p.id)
            and m.state = 'completed'
            and m.completed_at > date_trunc('week', now())
        ) as played
      from public.profiles p
      where p.id = v_uid
        or public.are_friends(v_uid, p.id)
    ) x
  ) s;

  return v_result;
end;
$$;

create or replace function public.rpc_weekly_awards()
returns jsonb
language plpgsql
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

  select coalesce(jsonb_agg(row_data), '[]'::jsonb) into v_result
  from (
    select jsonb_build_object(
      'award_code', a.code,
      'label', a.label,
      'emoji', a.emoji,
      'winner_name', a.winner_name,
      'value', a.value
    ) as row_data
    from (
      (
        select 'roast_champion'::text as code,
          'Roast Champion'::text as label,
          '🏆'::text as emoji,
          x.name as winner_name,
          x.wins as value
        from (
          select p.display_name as name,
            (select count(*) from public.match_results r
             where r.winner_id = p.id
               and r.completed_at > date_trunc('week', now())) as wins
          from public.profiles p
          where p.id = v_uid or public.are_friends(v_uid, p.id)
        ) x
        where x.wins > 0
        order by x.wins desc, x.name asc
        limit 1
      )
      union all
      (
        select 'busy_bee'::text, 'Busy Bee'::text, '🐝'::text,
          y.name, y.played
        from (
          select p.display_name as name,
            (select count(*) from public.matches m
             where (m.player_one_id = p.id or m.player_two_id = p.id)
               and m.state = 'completed'
               and m.completed_at > date_trunc('week', now())) as played
          from public.profiles p
          where p.id = v_uid or public.are_friends(v_uid, p.id)
        ) y
        where y.played > 0
        order by y.played desc, y.name asc
        limit 1
      )
      union all
      (
        select 'good_bestie'::text, 'Good Bestie'::text, '💖'::text,
          z.name, z.done
        from (
          select p.display_name as name,
            (select count(*) from public.match_punishments mp
             where mp.user_id = p.id and mp.status = 'completed') as done
          from public.profiles p
          where p.id = v_uid or public.are_friends(v_uid, p.id)
        ) z
        where z.done > 0
        order by z.done desc, z.name asc
        limit 1
      )
    ) a
  ) s;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- 12. Revenge round + punishment reroll
-- ---------------------------------------------------------------------------

create or replace function public.rpc_request_revenge(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.matches;
  v_question uuid;
  v_id uuid;
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
  if v_match.state <> 'completed' then
    raise exception 'MATCH_NOT_ACTIVE';
  end if;

  if exists (
    select 1 from public.matches m
    where m.revenge_of = p_match_id
      and m.state in ('waiting', 'active', 'voting', 'revealing')
  ) then
    raise exception 'INVALID_STATE';
  end if;

  select id into v_question from public.game_questions q
  where q.game_type = 'daily_roast' and q.locale = 'bn' and q.enabled
  order by md5(q.id::text || to_char(now(), 'YYYY-MM-DD-HH24'))
  limit 1;

  begin
    insert into public.matches (
      game_type, player_one_id, player_two_id, question_id, state, revenge_of
    )
    values (
      'daily_roast', v_uid, v_match.player_two_id, v_question, 'waiting',
      p_match_id
    )
    returning id into v_id;
  exception when unique_violation then
    raise exception 'INVALID_STATE';
  end;

  perform public.fn_notify(
    case when v_uid = v_match.player_one_id
      then v_match.player_two_id else v_match.player_one_id end,
    'match_invite', 'রিভেঞ্জ রাউন্ড!',
    'বন্ধু আবার খেলতে চায়।'
  );

  return jsonb_build_object('match_id', v_id);
end;
$$;

create or replace function public.rpc_reroll_punishment(p_punishment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.match_punishments;
  v_new uuid;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_row from public.match_punishments
  where id = p_punishment_id and user_id = v_uid
  for update;

  if not found then
    raise exception 'PUNISHMENT_NOT_FOUND';
  end if;
  if v_row.status not in ('offered', 'accepted') then
    raise exception 'INVALID_STATE';
  end if;
  if v_row.reroll_count >= 1 then
    raise exception 'INVALID_STATE';
  end if;

  select id into v_new from public.punishments
  where enabled and id <> v_row.punishment_id
  order by random()
  limit 1;

  if v_new is null then
    raise exception 'PUNISHMENT_NOT_FOUND';
  end if;

  update public.match_punishments
  set punishment_id = v_new, reroll_count = reroll_count + 1
  where id = p_punishment_id;

  return jsonb_build_object('punishment_id', v_new);
end;
$$;

-- ---------------------------------------------------------------------------
-- 13. RLS + grants for the new tables
-- ---------------------------------------------------------------------------

alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.bluff_rounds enable row level security;
alter table public.court_cases enable row level security;
alter table public.court_votes enable row level security;
alter table public.contract_templates enable row level security;
alter table public.contracts enable row level security;
alter table public.confessions enable row level security;
alter table public.social_pings enable row level security;
alter table public.notifications enable row level security;
alter table public.title_catalog enable row level security;

revoke all on public.blocks from anon, authenticated;
grant select on public.blocks to authenticated;
drop policy if exists blocks_select on public.blocks;
create policy blocks_select on public.blocks
  for select to authenticated
  using (blocker_id = auth.uid());

revoke all on public.reports from anon, authenticated;

revoke all on public.bluff_rounds from anon, authenticated;
grant select on public.bluff_rounds to authenticated;
drop policy if exists bluff_select on public.bluff_rounds;
create policy bluff_select on public.bluff_rounds
  for select to authenticated
  using (author_id = auth.uid() or target_id = auth.uid());

revoke all on public.court_cases from anon, authenticated;
grant select on public.court_cases to authenticated;
drop policy if exists court_select on public.court_cases;
create policy court_select on public.court_cases
  for select to authenticated
  using (plaintiff_id = auth.uid() or defendant_id = auth.uid());

revoke all on public.court_votes from anon, authenticated;
grant select on public.court_votes to authenticated;
drop policy if exists court_votes_select on public.court_votes;
create policy court_votes_select on public.court_votes
  for select to authenticated
  using (
    voter_id = auth.uid()
    or exists (
      select 1 from public.court_cases c
      where c.id = court_votes.case_id
        and c.state = 'decided'
        and (c.plaintiff_id = auth.uid() or c.defendant_id = auth.uid())
    )
  );

revoke all on public.contract_templates from anon, authenticated;
grant select on public.contract_templates to authenticated;
drop policy if exists contract_templates_select on public.contract_templates;
create policy contract_templates_select on public.contract_templates
  for select to authenticated
  using (enabled);

revoke all on public.contracts from anon, authenticated;
grant select on public.contracts to authenticated;
drop policy if exists contracts_select on public.contracts;
create policy contracts_select on public.contracts
  for select to authenticated
  using (creator_id = auth.uid() or participant_id = auth.uid());

-- Confessions: owner-only by default, shared row readable by the chosen friend.
revoke all on public.confessions from anon, authenticated;
grant select, insert, update, delete on public.confessions to authenticated;

drop policy if exists confessions_select on public.confessions;
create policy confessions_select on public.confessions
  for select to authenticated
  using (
    deleted_at is null
    and (owner_id = auth.uid() or shared_with = auth.uid())
  );

drop policy if exists confessions_insert on public.confessions;
create policy confessions_insert on public.confessions
  for insert to authenticated
  with check (owner_id = auth.uid() and shared_with is null);

drop policy if exists confessions_update on public.confessions;
create policy confessions_update on public.confessions
  for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists confessions_delete on public.confessions;
create policy confessions_delete on public.confessions
  for delete to authenticated
  using (owner_id = auth.uid());

revoke all on public.social_pings from anon, authenticated;
grant select on public.social_pings to authenticated;
drop policy if exists pings_select on public.social_pings;
create policy pings_select on public.social_pings
  for select to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select to authenticated
  using (recipient_id = auth.uid());

revoke all on public.title_catalog from anon, authenticated;
grant select on public.title_catalog to authenticated;
drop policy if exists title_catalog_select on public.title_catalog;
create policy title_catalog_select on public.title_catalog
  for select to authenticated
  using (enabled);

-- Function privileges.
revoke all on function public.fn_blocked(uuid, uuid) from public;
revoke all on function public.fn_require_friends(uuid, uuid) from public;
revoke all on function public.fn_pref(uuid, text) from public;
revoke all on function public.fn_notify(uuid, text, text, text) from public;
revoke all on function public.fn_count_pings(uuid, uuid, text) from public;
revoke all on function public.fn_expire_bluffs() from public;
revoke all on function public.fn_decide_court_case(uuid) from public;
grant execute on function public.fn_decide_court_case(uuid) to service_role;
grant execute on function public.fn_expire_bluffs() to service_role;

grant execute on function public.rpc_block_user(uuid, boolean) to authenticated;
grant execute on function public.rpc_report_user(uuid, text, text) to authenticated;
grant execute on function public.rpc_update_preferences(jsonb) to authenticated;
grant execute on function public.rpc_list_notifications(integer) to authenticated;
grant execute on function public.rpc_mark_notifications_read() to authenticated;
grant execute on function public.rpc_unread_notification_count() to authenticated;
grant execute on function public.rpc_create_bluff_round(text, uuid, text, integer)
  to authenticated;
grant execute on function public.rpc_guess_bluff_round(uuid, integer) to authenticated;
grant execute on function public.rpc_list_bluff_rounds(text) to authenticated;
grant execute on function public.rpc_create_court_case(uuid, text) to authenticated;
grant execute on function public.rpc_respond_court_case(uuid, text) to authenticated;
grant execute on function public.rpc_vote_court_case(uuid, text) to authenticated;
grant execute on function public.rpc_list_court_cases() to authenticated;
grant execute on function public.rpc_create_contract(uuid, text) to authenticated;
grant execute on function public.rpc_respond_contract(uuid, boolean) to authenticated;
grant execute on function public.rpc_cancel_contract(uuid) to authenticated;
grant execute on function public.rpc_list_contracts() to authenticated;
grant execute on function public.rpc_share_confession(uuid, uuid) to authenticated;
grant execute on function public.rpc_send_ping(uuid, text) to authenticated;
grant execute on function public.rpc_list_pings() to authenticated;
grant execute on function public.rpc_dismiss_ping(uuid) to authenticated;
grant execute on function public.rpc_my_titles() to authenticated;
grant execute on function public.rpc_set_active_title(text) to authenticated;
grant execute on function public.rpc_friends_leaderboard() to authenticated;
grant execute on function public.rpc_weekly_awards() to authenticated;
grant execute on function public.rpc_request_revenge(uuid) to authenticated;
grant execute on function public.rpc_reroll_punishment(uuid) to authenticated;
