-- ============================================================================
-- Server-side smoke test for the Roast My Bestie schema.
-- Runs on a plain PostgreSQL with the Supabase `auth` schema stubbed
-- (see .github/workflows/android-apk.yml -> job "sql-check").
--
-- It exercises the real RPCs as the *authenticated* role (least privilege),
-- then verifies the results as the owner. Any violated rule raises and the
-- step fails, so a broken migration cannot be shipped silently.
-- ============================================================================
\set ON_ERROR_STOP on

-- 1. Three users. The auth trigger must create profile + wallet + signup bonus.
insert into auth.users (id, email, raw_user_meta_data) values
  (
    '11111111-1111-1111-1111-111111111111',
    'rafi@example.com',
    '{"display_name": "Rafi"}'::jsonb
  ),
  (
    '22222222-2222-2222-2222-222222222222',
    'nadia@example.com',
    '{"display_name": "Nadia"}'::jsonb
  ),
  (
    '33333333-3333-3333-3333-333333333333',
    'third@example.com',
    '{"display_name": "Third"}'::jsonb
  );

select invite_code as code_rafi
from public.profiles
where id = '11111111-1111-1111-1111-111111111111'
\gset

select invite_code as code_nadia
from public.profiles
where id = '22222222-2222-2222-2222-222222222222'
\gset

select set_config('smoke.code_rafi', :'code_rafi', false);
select set_config('smoke.code_nadia', :'code_nadia', false);

do $$
begin
  if (select count(*) from public.profiles) <> 3 then
    raise exception 'FAIL: auth trigger did not create 3 profiles';
  end if;
  if (
    select balance from public.coin_wallets
    where user_id = '11111111-1111-1111-1111-111111111111'
  ) <> 20 then
    raise exception 'FAIL: signup bonus / wallet not initialized';
  end if;
  if (
    select invite_code from public.profiles
    where id = '11111111-1111-1111-1111-111111111111'
  ) !~ '^[A-Z0-9]{8}$' then
    raise exception 'FAIL: invite code format';
  end if;
end $$;

-- 2. Act as Rafi (least privilege).
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
begin
  -- self friend request must be rejected
  begin
    perform public.rpc_send_friend_request_by_code(
      current_setting('smoke.code_rafi')
    );
    raise exception 'FAIL: self friend request was allowed';
  exception when others then
    if sqlerrm <> 'CANNOT_FRIEND_SELF' then
      raise;
    end if;
  end;

  -- internal resolver must not be callable by a client
  begin
    perform public.fn_resolve_match(
      '00000000-0000-0000-0000-000000000000'::uuid
    );
    raise exception 'FAIL: fn_resolve_match callable by client';
  exception when others then
    if sqlerrm not ilike '%permission denied%' then
      raise;
    end if;
  end;
end $$;

do $$
declare
  v jsonb;
begin
  v := public.rpc_lookup_invite_code(current_setting('smoke.code_nadia'));
  if (v ->> 'display_name') <> 'Nadia' then
    raise exception 'FAIL: invite lookup returned %', v;
  end if;
  if (v ->> 'already_friends')::boolean then
    raise exception 'FAIL: strangers reported as friends';
  end if;
end $$;

select public.rpc_send_friend_request_by_code(
  current_setting('smoke.code_nadia')
);

-- 3. Nadia accepts.
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare
  v_list jsonb;
  v_id uuid;
begin
  v_list := public.rpc_list_friends();
  select (item ->> 'friendship_id')::uuid into v_id
  from jsonb_array_elements(v_list) as item
  where (item ->> 'status') = 'pending'
    and (item ->> 'direction') = 'incoming'
  limit 1;

  if v_id is null then
    raise exception 'FAIL: incoming request missing for addressee';
  end if;

  perform public.rpc_respond_friend_request(v_id, true);

  if not public.are_friends(
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222'
  ) then
    raise exception 'FAIL: friendship not accepted';
  end if;
end $$;

-- 4. Rafi creates the daily match, Nadia joins.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select (public.rpc_create_match('22222222-2222-2222-2222-222222222222')
  ->> 'match_id') as match_id
\gset
select set_config('smoke.match_id', :'match_id', false);

do $$
declare
  v jsonb;
begin
  v := public.rpc_get_match(current_setting('smoke.match_id')::uuid);
  if (v ->> 'state') <> 'waiting' then
    raise exception 'FAIL: new match state is %', v ->> 'state';
  end if;
  if coalesce(v ->> 'question_prompt', '') = '' then
    raise exception 'FAIL: no daily question assigned (seed missing?)';
  end if;
end $$;

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_join_match(:'match_id'::uuid);
select set_config(
  'smoke.match_id',
  :'match_id',
  false
);

do $$
begin
  if (
    select state from public.matches
    where id = current_setting('smoke.match_id')::uuid
  ) <> 'voting' then
    raise exception 'FAIL: join did not open voting';
  end if;
end $$;

-- 5. Rafi votes for Nadia. Opponent's vote must stay hidden.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select public.rpc_submit_vote(
  :'match_id'::uuid,
  '22222222-2222-2222-2222-222222222222'::uuid
);

do $$
declare
  v jsonb;
begin
  v := public.rpc_get_match(current_setting('smoke.match_id')::uuid);
  if (v ->> 'my_vote_for_id') is null then
    raise exception 'FAIL: own vote not returned';
  end if;
  if (v ->> 'opponent_vote_for_id') is not null then
    raise exception 'FAIL: opponent vote leaked before reveal';
  end if;
  if (v ->> 'winner_id') is not null then
    raise exception 'FAIL: winner exposed before resolution';
  end if;

  -- duplicate vote must be rejected
  begin
    perform public.rpc_submit_vote(
      current_setting('smoke.match_id')::uuid,
      '11111111-1111-1111-1111-111111111111'::uuid
    );
    raise exception 'FAIL: duplicate vote allowed';
  exception when others then
    if sqlerrm <> 'ALREADY_VOTED' then
      raise;
    end if;
  end;
end $$;

-- 6. Nadia votes for Nadia -> server resolves 2-0 in her favour.
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_submit_vote(
  :'match_id'::uuid,
  '22222222-2222-2222-2222-222222222222'::uuid
);

reset role;

do $$
declare
  v_match uuid := current_setting('smoke.match_id')::uuid;
  v_state text;
  v_winner uuid;
  v_balance int;
  v_punishment uuid;
  v_payload jsonb;
begin
  select state into v_state from public.matches where id = v_match;
  if v_state <> 'completed' then
    raise exception 'FAIL: match not completed (state=%)', v_state;
  end if;

  select winner_id, result_payload into v_winner, v_payload
  from public.match_results where match_id = v_match;
  if v_winner <> '22222222-2222-2222-2222-222222222222' then
    raise exception 'FAIL: wrong winner %', v_winner;
  end if;
  if (v_payload ->> 'votes_for_player_two')::int <> 2 then
    raise exception 'FAIL: vote tally wrong: %', v_payload;
  end if;

  -- idempotency: resolving twice must not double-reward
  perform public.fn_resolve_match(v_match, 'smoke_repeat');

  select balance into v_balance from public.coin_wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_balance <> 30 then
    raise exception 'FAIL: reward not exactly once (balance=%)', v_balance;
  end if;

  if (
    select count(*) from public.coin_transactions
    where user_id = '11111111-1111-1111-1111-111111111111'
      and kind = 'match_reward'
  ) <> 1 then
    raise exception 'FAIL: duplicate reward ledger row (idempotency)';
  end if;

  select id into v_punishment from public.match_punishments
  where match_id = v_match
    and user_id = '11111111-1111-1111-1111-111111111111';
  if v_punishment is null then
    raise exception 'FAIL: loser got no punishment offer';
  end if;

  if (
    select wins from public.profiles
    where id = '22222222-2222-2222-2222-222222222222'
  ) <> 1 then
    raise exception 'FAIL: winner win-count not incremented';
  end if;
end $$;

select id as punishment_id
from public.match_punishments
where match_id = current_setting('smoke.match_id')::uuid
  and user_id = '11111111-1111-1111-1111-111111111111'
\gset
select set_config('smoke.punishment_id', :'punishment_id', false);

-- 7. Non-participant and RLS isolation checks.
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';

do $$
declare
  v_leak int;
begin
  begin
    perform public.rpc_get_match(current_setting('smoke.match_id')::uuid);
    raise exception 'FAIL: stranger could read the match';
  exception when others then
    if sqlerrm <> 'NOT_PARTICIPANT' then
      raise;
    end if;
  end;

  select count(*) into v_leak from public.coin_wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_leak <> 0 then
    raise exception 'FAIL: RLS leaked another wallet';
  end if;

  select count(*) into v_leak from public.profiles
  where id = '11111111-1111-1111-1111-111111111111';
  if v_leak <> 0 then
    raise exception 'FAIL: RLS leaked a stranger profile';
  end if;

  begin
    insert into public.coin_transactions (user_id, amount, kind, idempotency_key)
    values (
      '33333333-3333-3333-3333-333333333333', 999, 'match_reward', 'hack'
    );
    raise exception 'FAIL: client could insert a coin transaction';
  exception when others then
    if sqlerrm not ilike '%permission denied%' then
      raise;
    end if;
  end;
end $$;

-- 8. Loser skips the punishment: coins are charged exactly once.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select public.rpc_set_punishment_status(
  current_setting('smoke.punishment_id')::uuid,
  'skipped'
);

reset role;

do $$
declare
  v_balance int;
  v_status text;
begin
  select balance into v_balance from public.coin_wallets
  where user_id = '11111111-1111-1111-1111-111111111111';
  if v_balance <> 15 then
    raise exception 'FAIL: skip price not charged once (balance=%)', v_balance;
  end if;

  select status into v_status from public.match_punishments
  where id = current_setting('smoke.punishment_id')::uuid;
  if v_status <> 'skipped' then
    raise exception 'FAIL: punishment status % instead of skipped', v_status;
  end if;
end $$;

-- 9. Insufficient coins are rejected (no negative balance possible).
insert into auth.users (id, email, raw_user_meta_data) values
  (
    '44444444-4444-4444-4444-444444444444',
    'fourth@example.com',
    '{"display_name": "Fourth"}'::jsonb
  );

insert into public.friendships (requester_id, addressee_id, status)
values (
  '44444444-4444-4444-4444-444444444444',
  '22222222-2222-2222-2222-222222222222',
  'accepted'
);

set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';

select (public.rpc_create_match('22222222-2222-2222-2222-222222222222')
  ->> 'match_id') as match2
\gset

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_join_match(:'match2'::uuid);
select public.rpc_submit_vote(
  :'match2'::uuid,
  '22222222-2222-2222-2222-222222222222'::uuid
);

set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
select public.rpc_submit_vote(
  :'match2'::uuid,
  '22222222-2222-2222-2222-222222222222'::uuid
);

reset role;

select id as punishment2
from public.match_punishments
where match_id = :'match2'::uuid
  and user_id = '44444444-4444-4444-4444-444444444444'
\gset
select set_config('smoke.punishment2', :'punishment2', false);

-- Simulate an almost-empty wallet *after* the match reward has been paid.
update public.coin_wallets
set balance = 5
where user_id = '44444444-4444-4444-4444-444444444444';

set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';

do $$
declare
  v_id uuid := current_setting('smoke.punishment2')::uuid;
begin
  begin
    perform public.rpc_set_punishment_status(v_id, 'skipped');
    raise exception 'FAIL: skip allowed with insufficient coins';
  exception when others then
    if sqlerrm <> 'INSUFFICIENT_COINS' then
      raise;
    end if;
  end;
end $$;

reset role;

do $$
begin
  if (
    select balance from public.coin_wallets
    where user_id = '44444444-4444-4444-4444-444444444444'
  ) <> 5 then
    raise exception 'FAIL: failed skip changed the balance';
  end if;
  if exists (select 1 from public.coin_wallets where balance < 0) then
    raise exception 'FAIL: negative coin balance exists';
  end if;
end $$;

-- 10. Timeout policy: a match nobody votes in must resolve, never hang.
set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';

select (public.rpc_create_match('22222222-2222-2222-2222-222222222222')
  ->> 'match_id') as match3
\gset
select set_config('smoke.match3', :'match3', false);

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_join_match(:'match3'::uuid);

reset role;

update public.matches
set voting_deadline = now() - interval '1 minute'
where id = current_setting('smoke.match3')::uuid;

do $$
declare
  v_state text;
  v_tie boolean;
begin
  perform public.fn_expire_stale_matches();

  select state into v_state from public.matches
  where id = current_setting('smoke.match3')::uuid;
  if v_state <> 'completed' then
    raise exception 'FAIL: timeout policy did not resolve the match (%)',
      v_state;
  end if;

  select is_tie into v_tie from public.match_results
  where match_id = current_setting('smoke.match3')::uuid;
  if v_tie is null or v_tie is false then
    raise exception 'FAIL: zero-vote timeout should be a tie';
  end if;

  if exists (
    select 1 from public.match_punishments
    where match_id = current_setting('smoke.match3')::uuid
  ) then
    raise exception 'FAIL: a tie must not assign a punishment';
  end if;
end $$;


-- 11. Secret accusation / truth-or-lie (bluff rounds).
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select (public.rpc_create_bluff_round(
  'secret_accusation',
  '22222222-2222-2222-2222-222222222222',
  'সে লুকিয়ে আমার স্ন্যাকস খেয়েছে',
  1
) ->> 'id') as bluff_id
\gset
select set_config('smoke.bluff_id', :'bluff_id', false);

do $$
declare
  v jsonb;
  v_body text;
begin
  -- the author sees the text, the target must not (server-side hiding)
  v := public.rpc_list_bluff_rounds('secret_accusation');
  select (item ->> 'body') into v_body
  from jsonb_array_elements(v) as item
  where (item ->> 'id') = current_setting('smoke.bluff_id');
  if v_body is null then
    raise exception 'FAIL: author could not read own accusation';
  end if;
end $$;

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';

do $$
declare
  v jsonb;
  v_body text;
  v_options jsonb;
begin
  v := public.rpc_list_bluff_rounds('secret_accusation');
  select (item ->> 'body'), (item -> 'options')
  into v_body, v_options
  from jsonb_array_elements(v) as item
  where (item ->> 'id') = current_setting('smoke.bluff_id');

  if v_body is not null then
    raise exception 'FAIL: secret accusation leaked to the target';
  end if;
  if jsonb_array_length(v_options) <> 4 then
    raise exception 'FAIL: accusation options missing';
  end if;

  -- wrong guess reveals the round but does not match
  perform public.rpc_guess_bluff_round(
    current_setting('smoke.bluff_id')::uuid, 0
  );

  select (item ->> 'body') into v_body
  from jsonb_array_elements(public.rpc_list_bluff_rounds('secret_accusation'))
    as item
  where (item ->> 'id') = current_setting('smoke.bluff_id');
  if v_body is null then
    raise exception 'FAIL: accusation not revealed after the guess';
  end if;

  -- guessing twice is not allowed
  begin
    perform public.rpc_guess_bluff_round(
      current_setting('smoke.bluff_id')::uuid, 1
    );
    raise exception 'FAIL: bluff round guessed twice';
  exception when others then
    if sqlerrm <> 'INVALID_STATE' then raise; end if;
  end;
end $$;

-- 12. Bestie court: file -> respond -> both vote -> server verdict.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select (public.rpc_create_court_case(
  '22222222-2222-2222-2222-222222222222',
  'শেষ পিৎজা স্লাইস সে-ই খেয়েছে'
) ->> 'id') as case_id
\gset
select set_config('smoke.case_id', :'case_id', false);

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_respond_court_case(
  current_setting('smoke.case_id')::uuid,
  'আমি নির্দোষ, বিড়ালটা খেয়েছে'
);

do $$
begin
  perform public.rpc_vote_court_case(
    current_setting('smoke.case_id')::uuid, 'guilty'
  );
end $$;

set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select public.rpc_vote_court_case(
  current_setting('smoke.case_id')::uuid,
  'guilty'
);

reset role;
do $$
declare
  v_state text;
  v_verdict text;
begin
  select state, verdict into v_state, v_verdict
  from public.court_cases where id = current_setting('smoke.case_id')::uuid;
  if v_state <> 'decided' or v_verdict <> 'guilty' then
    raise exception 'FAIL: court verdict % / %', v_state, v_verdict;
  end if;
end $$;

-- 13. Friendship contract needs both signatures.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select (public.rpc_create_contract(
  '22222222-2222-2222-2222-222222222222',
  'fries_pact'
) ->> 'id') as contract_id
\gset
select set_config('smoke.contract_id', :'contract_id', false);

do $$
declare
  v_state text;
begin
  select state into v_state from public.contracts
  where id = current_setting('smoke.contract_id')::uuid;
  if v_state <> 'pending' then
    raise exception 'FAIL: contract should start pending';
  end if;
end $$;

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_respond_contract(
  current_setting('smoke.contract_id')::uuid, true
);

reset role;
do $$
begin
  if (
    select state from public.contracts
    where id = current_setting('smoke.contract_id')::uuid
  ) <> 'active' then
    raise exception 'FAIL: contract not activated after both accepted';
  end if;
end $$;

-- 14. Confessions: private by default, readable only when shared.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

insert into public.confessions (owner_id, content)
values (
  '11111111-1111-1111-1111-111111111111',
  'আমি লুকিয়ে বন্ধুর ফ্রাইস খেয়েছি'
);

select id as confession_id from public.confessions
where owner_id = '11111111-1111-1111-1111-111111111111'
limit 1
\gset
select set_config('smoke.confession_id', :'confession_id', false);

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare
  v_count int;
begin
  select count(*) into v_count from public.confessions
  where id = current_setting('smoke.confession_id')::uuid;
  if v_count <> 0 then
    raise exception 'FAIL: private confession visible to a friend';
  end if;
end $$;

set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
select public.rpc_share_confession(
  current_setting('smoke.confession_id')::uuid,
  '22222222-2222-2222-2222-222222222222'
);

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$
declare
  v_count int;
begin
  select count(*) into v_count from public.confessions
  where id = current_setting('smoke.confession_id')::uuid;
  if v_count <> 1 then
    raise exception 'FAIL: shared confession not readable by the friend';
  end if;
end $$;

-- 15. Social pings: rate limit + recipient mute preference.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
begin
  perform public.rpc_send_ping(
    '22222222-2222-2222-2222-222222222222', 'angry'
  );
  perform public.rpc_send_ping(
    '22222222-2222-2222-2222-222222222222', 'angry'
  );
  perform public.rpc_send_ping(
    '22222222-2222-2222-2222-222222222222', 'angry'
  );
  begin
    perform public.rpc_send_ping(
      '22222222-2222-2222-2222-222222222222', 'angry'
    );
    raise exception 'FAIL: nudge rate limit not enforced';
  exception when others then
    if sqlerrm <> 'RATE_LIMITED' then raise; end if;
  end;
end $$;

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_update_preferences('{"nudges":"false"}'::jsonb);

set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
do $$
begin
  begin
    perform public.rpc_send_ping(
      '22222222-2222-2222-2222-222222222222', 'sorry'
    );
    raise exception 'FAIL: muted recipient still received a ping';
  exception when others then
    if sqlerrm <> 'RECIPIENT_MUTED' then raise; end if;
  end;
end $$;

set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
select public.rpc_update_preferences('{"nudges":"true"}'::jsonb);

-- 16. Inbox, titles, leaderboard, weekly awards.
do $$
declare
  v_unread int;
  v_list jsonb;
begin
  v_unread := public.rpc_unread_notification_count();
  if v_unread < 1 then
    raise exception 'FAIL: inbox did not receive notifications';
  end if;

  v_list := public.rpc_list_notifications(10);
  if jsonb_array_length(v_list) < 1 then
    raise exception 'FAIL: notification list empty';
  end if;

  perform public.rpc_mark_notifications_read();
  if public.rpc_unread_notification_count() <> 0 then
    raise exception 'FAIL: mark-all-read did not clear the badge';
  end if;
end $$;

do $$
declare
  v jsonb;
begin
  v := public.rpc_my_titles();
  if jsonb_array_length(v) < 1 then
    raise exception 'FAIL: title catalogue missing (seed?)';
  end if;

  v := public.rpc_friends_leaderboard();
  if jsonb_array_length(v) < 1 then
    raise exception 'FAIL: leaderboard empty';
  end if;

  v := public.rpc_weekly_awards();
  if v is null then
    raise exception 'FAIL: weekly awards returned null';
  end if;
end $$;

-- 17. Revenge round from a completed match.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

select (public.rpc_request_revenge(
  current_setting('smoke.match_id')::uuid
) ->> 'match_id') as revenge_id
\gset
select set_config('smoke.revenge_id', :'revenge_id', false);

do $$
begin
  if (
    select revenge_of from public.matches
    where id = current_setting('smoke.revenge_id')::uuid
  ) <> current_setting('smoke.match_id')::uuid then
    raise exception 'FAIL: revenge match not linked to the original';
  end if;
end $$;

-- 18. Punishment reroll is allowed exactly once.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

do $$
begin
  begin
    perform public.rpc_reroll_punishment(
      current_setting('smoke.punishment_id')::uuid
    );
    raise exception 'FAIL: reroll allowed on an already-skipped punishment';
  exception when others then
    if sqlerrm <> 'INVALID_STATE' then raise; end if;
  end;
end $$;

-- 19. Block removes friendship and stops new pair interactions.
select public.rpc_block_user(
  '22222222-2222-2222-2222-222222222222', true
);

do $$
begin
  if public.are_friends(
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222'
  ) then
    raise exception 'FAIL: blocking did not remove the friendship';
  end if;

  begin
    perform public.rpc_create_bluff_round(
      'truth_or_lie',
      '22222222-2222-2222-2222-222222222222',
      'আমি কখনো পিৎজা শেয়ার করি না',
      0
    );
    raise exception 'FAIL: blocked pair could start a new round';
  exception when others then
    if sqlerrm not in ('NOT_FRIENDS', 'BLOCKED_RELATIONSHIP') then raise; end if;
  end;
end $$;

-- 20. Reports are recorded and rate limited per day.
do $$
begin
  perform public.rpc_report_user(
    '33333333-3333-3333-3333-333333333333', 'spam', 'smoke test'
  );
end $$;

reset role;

do $$
begin
  if (
    select count(*) from public.reports
    where reporter_id = '11111111-1111-1111-1111-111111111111'
  ) < 1 then
    raise exception 'FAIL: report not stored';
  end if;
  if exists (select 1 from public.coin_wallets where balance < 0) then
    raise exception 'FAIL: negative coin balance exists';
  end if;
end $$;

\echo 'SQL SMOKE TEST PASSED'
