-- Review and run manually after SUPABASE_POS_CHECKOUT_MIGRATION.sql.
-- Enable pg_cron in the Supabase Dashboard before running this migration to
-- install the scheduled jobs. The Flutter app never applies SQL.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS notification_preferences JSONB NOT NULL
    DEFAULT '{"orders":true,"promotions":true,"streaks":true}'::JSONB,
  ADD COLUMN IF NOT EXISTS lifetime_points INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_streak_ready_claimed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_streak_reminder_claimed_at TIMESTAMPTZ;

UPDATE public.profiles AS profile
SET lifetime_points = GREATEST(
  COALESCE(profile.lifetime_points, 0)::BIGINT,
  COALESCE(profile.points, 0)::BIGINT,
  COALESCE((
    SELECT SUM(
      COALESCE(NULLIF(ABS(transaction_row.points), 0), transaction_row.points_spent, 0)
    )
    FROM public.transactions AS transaction_row
    WHERE transaction_row.user_id = profile.id
      AND transaction_row.transaction_type = 'earned'
  ), 0)
  + COALESCE((
    SELECT SUM(daily_reward.reward_points)
    FROM public.daily_rewards AS daily_reward
    WHERE daily_reward.user_id = profile.id
  ), 0)
)::INT;

UPDATE public.profiles
SET notification_preferences =
  '{"orders":true,"promotions":true,"streaks":true}'::JSONB
WHERE notification_preferences IS NULL;

ALTER TABLE public.profiles
  ALTER COLUMN notification_preferences SET DEFAULT
    '{"orders":true,"promotions":true,"streaks":true}'::JSONB,
  ALTER COLUMN notification_preferences SET NOT NULL;

GRANT UPDATE (notification_preferences)
  ON public.profiles TO authenticated;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IN (
      'welcome',
      'order_placed',
      'order_completed',
      'order_cancelled',
      'points_earned',
      'reward_redeemed',
      'new_order_admin',
      'promo_new',
      'promo_ending',
      'streak_ready'
    )
  );

CREATE UNIQUE INDEX IF NOT EXISTS notifications_promo_dedupe_idx
  ON public.notifications (user_id, type, (data ->> 'promo_id'))
  WHERE type IN ('promo_new', 'promo_ending');

CREATE UNIQUE INDEX IF NOT EXISTS notifications_streak_cycle_dedupe_idx
  ON public.notifications (
    user_id,
    type,
    (data ->> 'cycle_at'),
    (data ->> 'kind')
  )
  WHERE type = 'streak_ready';

CREATE INDEX IF NOT EXISTS transactions_user_type_created_idx
  ON public.transactions (user_id, transaction_type, created_at DESC);
CREATE INDEX IF NOT EXISTS daily_rewards_user_claimed_idx
  ON public.daily_rewards (user_id, claimed_at DESC);

-- Promo notifications are produced by a trigger so direct admin writes and
-- future server-side writes share the same one-time behavior.
CREATE OR REPLACE FUNCTION public.notify_users_of_active_promotion()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  promo_description TEXT;
  notification_body TEXT;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.is_active IS TRUE THEN
    RETURN NEW;
  END IF;
  IF NEW.is_active IS NOT TRUE
     OR (NEW.starts_at IS NOT NULL AND NEW.starts_at > now())
     OR (
       NEW.ends_at IS NOT NULL
       AND (NEW.ends_at AT TIME ZONE 'Asia/Manila')::DATE
         < (now() AT TIME ZONE 'Asia/Manila')::DATE
     ) THEN
    RETURN NEW;
  END IF;

  promo_description := NULLIF(
    btrim(COALESCE(NEW.description, NEW.subtitle, '')),
    ''
  );
  notification_body := COALESCE(promo_description, 'A new Kapetol promotion is available.');
  IF NEW.ends_at IS NOT NULL THEN
    notification_body := notification_body || format(
      ' Until %s.',
      to_char(
        (NEW.ends_at AT TIME ZONE 'Asia/Manila')::DATE,
        'Mon FMDD, YYYY'
      )
    );
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT
    p.id,
    'promo_new',
    'New promo: ' || NEW.title,
    notification_body,
    jsonb_build_object('promo_id', NEW.id)
  FROM public.profiles AS p
  WHERE p.role <> 'admin'
    AND COALESCE(p.notification_preferences ->> 'promotions', 'true') <> 'false'
  ON CONFLICT (user_id, type, (data ->> 'promo_id'))
    WHERE type IN ('promo_new', 'promo_ending')
    DO NOTHING;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_users_of_active_promotion() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_users_of_active_promotion()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS promotions_notify_on_activation ON public.promotions;
CREATE TRIGGER promotions_notify_on_activation
  AFTER INSERT OR UPDATE OF is_active ON public.promotions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_users_of_active_promotion();

CREATE OR REPLACE FUNCTION public.notify_users_of_promotions_ending()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (user_id, type, title, body, data)
  SELECT
    p.id,
    'promo_ending',
    'Promo ending soon',
    format('%s ends tomorrow. Don''t miss it!', promo.title),
    jsonb_build_object('promo_id', promo.id)
  FROM public.promotions AS promo
  JOIN public.profiles AS p
    ON p.role <> 'admin'
   AND COALESCE(p.notification_preferences ->> 'promotions', 'true') <> 'false'
  WHERE promo.is_active IS TRUE
    AND promo.ends_at IS NOT NULL
    AND (promo.starts_at IS NULL OR promo.starts_at <= now())
    AND (promo.ends_at AT TIME ZONE 'Asia/Manila')::DATE
      = (now() AT TIME ZONE 'Asia/Manila')::DATE + 1
  ON CONFLICT (user_id, type, (data ->> 'promo_id'))
    WHERE type IN ('promo_new', 'promo_ending')
    DO NOTHING;
END;
$$;

ALTER FUNCTION public.notify_users_of_promotions_ending() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_users_of_promotions_ending()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.notify_users_of_lucky_bean()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  WITH latest_claim AS (
    SELECT DISTINCT ON (dr.user_id)
      dr.user_id,
      dr.claimed_at,
      dr.streak_day,
      dr.claimed_at + INTERVAL '20 hours' AS next_claim_at
    FROM public.daily_rewards AS dr
    ORDER BY dr.user_id, dr.claimed_at DESC
  ),
  eligible_ready AS (
    SELECT claim.*
    FROM latest_claim AS claim
    JOIN public.profiles AS profile ON profile.id = claim.user_id
    WHERE profile.role <> 'admin'
      AND COALESCE(profile.notification_preferences ->> 'streaks', 'true') <> 'false'
      AND claim.next_claim_at <= now()
      AND profile.last_streak_ready_claimed_at IS DISTINCT FROM claim.claimed_at
  ),
  inserted_ready AS (
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT
      ready.user_id,
      'streak_ready',
      'Lucky Bean is ready! ☕',
      format(
        'Your daily reward is waiting. Claim it to keep your Day %s streak going.',
        ready.streak_day + 1
      ),
      jsonb_build_object(
        'kind', 'ready',
        'cycle_at', ready.claimed_at,
        'next_claim_at', ready.next_claim_at
      )
    FROM eligible_ready AS ready
    ON CONFLICT (user_id, type, (data ->> 'cycle_at'), (data ->> 'kind'))
      WHERE type = 'streak_ready'
      DO NOTHING
    RETURNING user_id, (data ->> 'cycle_at')::TIMESTAMPTZ AS claimed_at
  )
  UPDATE public.profiles AS profile
  SET last_streak_ready_claimed_at = ready.claimed_at
  FROM eligible_ready AS ready
  WHERE profile.id = ready.user_id
    AND profile.last_streak_ready_claimed_at IS DISTINCT FROM ready.claimed_at;

  WITH latest_claim AS (
    SELECT DISTINCT ON (dr.user_id)
      dr.user_id,
      dr.claimed_at,
      dr.streak_day,
      dr.claimed_at + INTERVAL '20 hours' AS next_claim_at
    FROM public.daily_rewards AS dr
    ORDER BY dr.user_id, dr.claimed_at DESC
  ),
  eligible_reminder AS (
    SELECT claim.*
    FROM latest_claim AS claim
    JOIN public.profiles AS profile ON profile.id = claim.user_id
    WHERE profile.role <> 'admin'
      AND COALESCE(profile.notification_preferences ->> 'streaks', 'true') <> 'false'
      AND claim.streak_day >= 2
      AND now() >= claim.next_claim_at - INTERVAL '3 hours'
      AND now() < claim.next_claim_at
      AND profile.last_streak_reminder_claimed_at IS DISTINCT FROM claim.claimed_at
  ),
  inserted_reminders AS (
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT
      reminder.user_id,
      'streak_ready',
      'Your streak is about to end!',
      format(
        'Your %s-day streak is about to end. Claim today to keep it.',
        reminder.streak_day
      ),
      jsonb_build_object(
        'kind', 'ending',
        'cycle_at', reminder.claimed_at,
        'next_claim_at', reminder.next_claim_at,
        'streak_day', reminder.streak_day
      )
    FROM eligible_reminder AS reminder
    ON CONFLICT (user_id, type, (data ->> 'cycle_at'), (data ->> 'kind'))
      WHERE type = 'streak_ready'
      DO NOTHING
    RETURNING user_id, (data ->> 'cycle_at')::TIMESTAMPTZ AS claimed_at
  )
  UPDATE public.profiles AS profile
  SET last_streak_reminder_claimed_at = reminder.claimed_at
  FROM eligible_reminder AS reminder
  WHERE profile.id = reminder.user_id
    AND profile.last_streak_reminder_claimed_at IS DISTINCT FROM reminder.claimed_at;
END;
$$;

ALTER FUNCTION public.notify_users_of_lucky_bean() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_users_of_lucky_bean()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_points_history_summary(p_filter TEXT DEFAULT 'all')
RETURNS TABLE (total_earned BIGINT, total_redeemed BIGINT)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_filter NOT IN ('all', 'earned', 'redeemed') THEN
    RAISE EXCEPTION 'POINTS_FILTER_INVALID';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(SUM(
      CASE
        WHEN transaction_type = 'earned'
         AND p_filter IN ('all', 'earned')
        THEN COALESCE(NULLIF(points, 0), points_spent)
        ELSE 0
      END
    ), 0)::BIGINT,
    COALESCE(SUM(
      CASE
        WHEN transaction_type IN ('redemption', 'redeemed')
         AND p_filter IN ('all', 'redeemed')
        THEN COALESCE(NULLIF(ABS(points), 0), points_spent)
        ELSE 0
      END
    ), 0)::BIGINT
  FROM public.transactions
  WHERE user_id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.get_points_history_summary(TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_points_history_summary(TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_points_overview(
  p_period TEXT DEFAULT 'week'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  current_balance BIGINT;
  lifetime_earned BIGINT;
  redeemed_total BIGINT;
  earned_current_month BIGINT;
  earned_previous_month BIGINT;
  local_now TIMESTAMP := now() AT TIME ZONE 'Asia/Manila';
  month_start TIMESTAMP;
  bucket_start TIMESTAMP;
  bucket_interval INTERVAL;
  buckets JSONB;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_period IS NULL OR p_period NOT IN ('week', 'month') THEN
    RAISE EXCEPTION 'POINTS_PERIOD_INVALID';
  END IF;

  SELECT p.points, p.lifetime_points
  INTO current_balance, lifetime_earned
  FROM public.profiles AS p
  WHERE p.id = current_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'PROFILE_NOT_FOUND';
  END IF;

  month_start := date_trunc('month', local_now);
  bucket_interval := CASE
    WHEN p_period = 'week' THEN INTERVAL '1 week'
    ELSE INTERVAL '1 month'
  END;
  bucket_start := CASE
    WHEN p_period = 'week' THEN date_trunc('week', local_now)
    ELSE month_start
  END;

  WITH earned_events AS (
    SELECT
      t.created_at AT TIME ZONE 'Asia/Manila' AS event_time,
      COALESCE(NULLIF(ABS(t.points), 0), t.points_spent)::BIGINT AS points
    FROM public.transactions AS t
    WHERE t.user_id = current_user_id
      AND t.transaction_type = 'earned'
    UNION ALL
    SELECT
      dr.claimed_at AT TIME ZONE 'Asia/Manila',
      dr.reward_points::BIGINT
    FROM public.daily_rewards AS dr
    WHERE dr.user_id = current_user_id
  ),
  redeemed_events AS (
    SELECT
      t.created_at AT TIME ZONE 'Asia/Manila' AS event_time,
      COALESCE(NULLIF(ABS(t.points), 0), t.points_spent)::BIGINT AS points
    FROM public.transactions AS t
    WHERE t.user_id = current_user_id
      AND t.transaction_type IN ('redemption', 'redeemed')
  )
  SELECT
    COALESCE((
      SELECT SUM(event.points)
      FROM redeemed_events AS event
    ), 0)::BIGINT,
    COALESCE((
      SELECT SUM(event.points)
      FROM earned_events AS event
      WHERE event.event_time >= month_start
        AND event.event_time < month_start + INTERVAL '1 month'
    ), 0)::BIGINT,
    COALESCE((
      SELECT SUM(event.points)
      FROM earned_events AS event
      WHERE event.event_time >= month_start - INTERVAL '1 month'
        AND event.event_time < month_start
    ), 0)::BIGINT
  INTO redeemed_total, earned_current_month, earned_previous_month;

  WITH earned_events AS (
    SELECT
      t.created_at AT TIME ZONE 'Asia/Manila' AS event_time,
      COALESCE(NULLIF(ABS(t.points), 0), t.points_spent)::BIGINT AS points
    FROM public.transactions AS t
    WHERE t.user_id = current_user_id
      AND t.transaction_type = 'earned'
    UNION ALL
    SELECT
      dr.claimed_at AT TIME ZONE 'Asia/Manila',
      dr.reward_points::BIGINT
    FROM public.daily_rewards AS dr
    WHERE dr.user_id = current_user_id
  ),
  redeemed_events AS (
    SELECT
      t.created_at AT TIME ZONE 'Asia/Manila' AS event_time,
      COALESCE(NULLIF(ABS(t.points), 0), t.points_spent)::BIGINT AS points
    FROM public.transactions AS t
    WHERE t.user_id = current_user_id
      AND t.transaction_type IN ('redemption', 'redeemed')
  ),
  bucket_windows AS (
    SELECT
      series.bucket_number,
      bucket_start - ((5 - series.bucket_number) * bucket_interval) AS starts_at
    FROM generate_series(0, 5) AS series(bucket_number)
  )
  SELECT jsonb_agg(
    jsonb_build_object(
      'label',
      CASE WHEN p_period = 'week'
        THEN to_char(bucket.starts_at, 'Mon FMDD')
        ELSE to_char(bucket.starts_at, 'Mon')
      END,
      'earned',
      COALESCE((
        SELECT SUM(event.points)
        FROM earned_events AS event
        WHERE event.event_time >= bucket.starts_at
          AND event.event_time < bucket.starts_at + bucket_interval
      ), 0),
      'redeemed',
      COALESCE((
        SELECT SUM(event.points)
        FROM redeemed_events AS event
        WHERE event.event_time >= bucket.starts_at
          AND event.event_time < bucket.starts_at + bucket_interval
      ), 0)
    )
    ORDER BY bucket.bucket_number
  )
  INTO buckets
  FROM bucket_windows AS bucket;

  RETURN jsonb_build_object(
    'balance', COALESCE(current_balance, 0),
    'lifetime_earned', COALESCE(lifetime_earned, 0),
    'total_redeemed', redeemed_total,
    'earned_this_month', earned_current_month,
    'earned_last_month', earned_previous_month,
    'buckets', COALESCE(buckets, '[]'::JSONB)
  );
END;
$$;

ALTER FUNCTION public.get_points_overview(TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_points_overview(TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_points_overview(TEXT)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.redeem_reward(p_reward_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  account_role TEXT;
  current_points INT;
  updated_points INT;
  selected_reward public.rewards%ROWTYPE;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be signed in.';
  END IF;

  SELECT p.role, p.points
  INTO account_role, current_points
  FROM public.profiles AS p
  WHERE p.id = current_user_id
  FOR UPDATE;

  IF account_role IS DISTINCT FROM 'user' THEN
    RAISE EXCEPTION 'REDEMPTION_FORBIDDEN: Only user accounts may redeem rewards.'
      USING ERRCODE = '42501';
  END IF;

  SELECT r.* INTO selected_reward
  FROM public.rewards AS r
  WHERE r.id = p_reward_id AND r.is_active IS TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REWARD_UNAVAILABLE';
  END IF;
  IF current_points < selected_reward.points_cost THEN
    RAISE EXCEPTION 'INSUFFICIENT_POINTS';
  END IF;

  updated_points := current_points - selected_reward.points_cost;
  PERFORM set_config('app.allow_points_update', 'on', TRUE);
  UPDATE public.profiles
  SET points = updated_points
  WHERE id = current_user_id;
  PERFORM set_config('app.allow_points_update', 'off', TRUE);

  INSERT INTO public.transactions (
    user_id, reward_name, points_spent, transaction_type, points
  ) VALUES (
    current_user_id,
    selected_reward.name,
    selected_reward.points_cost,
    'redemption',
    -selected_reward.points_cost
  );

  INSERT INTO public.notifications (
    user_id, type, title, body, data
  ) VALUES (
    current_user_id,
    'reward_redeemed',
    'Reward redeemed',
    format(
      'You redeemed %s for %s pts.',
      selected_reward.name,
      selected_reward.points_cost
    ),
    jsonb_build_object(
      'reward_id', selected_reward.id,
      'reward_name', selected_reward.name,
      'points_spent', selected_reward.points_cost
    )
  );

  RETURN jsonb_build_object('points', updated_points);
END;
$$;

ALTER FUNCTION public.redeem_reward(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.redeem_reward(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_reward(UUID) TO authenticated;

-- Transactions Realtime drives the Rewards preview refresh.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
  END IF;
END;
$$;

-- Optional historical repair. Review the affected rows first and run this
-- separately only if old redemptions really do have points = 0:
-- UPDATE public.transactions
-- SET points = -points_spent
-- WHERE transaction_type = 'redemption'
--   AND points = 0
--   AND points_spent > 0;

-- The job times are UTC. 16:05 UTC is 00:05 the following day in Manila.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule(jobid)
    FROM cron.job
    WHERE jobname IN (
      'kapetol-promotion-ending-notifications',
      'kapetol-lucky-bean-notifications'
    );

    PERFORM cron.schedule(
      'kapetol-promotion-ending-notifications',
      '5 16 * * *',
      'SELECT public.notify_users_of_promotions_ending();'
    );
    PERFORM cron.schedule(
      'kapetol-lucky-bean-notifications',
      '*/5 * * * *',
      'SELECT public.notify_users_of_lucky_bean();'
    );
  ELSE
    RAISE NOTICE 'pg_cron is not enabled; enable it in Supabase Dashboard and rerun the job registration block.';
  END IF;
END;
$$;

COMMIT;
