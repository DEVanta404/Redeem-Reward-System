-- Review and run manually in the Supabase SQL Editor. This migration is not
-- executed by the Flutter app and does not drop existing rows.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user',
  ADD COLUMN IF NOT EXISTS lifetime_points INT NOT NULL DEFAULT 0;

ALTER TABLE public.profiles
  ALTER COLUMN role SET DEFAULT 'user',
  ALTER COLUMN role SET NOT NULL,
  ALTER COLUMN points SET DEFAULT 0,
  ALTER COLUMN lifetime_points SET DEFAULT 0;

DROP TRIGGER IF EXISTS protect_profile_privileges ON public.profiles;

CREATE OR REPLACE FUNCTION public.create_profile_for_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id, name, email, phone, role, points, lifetime_points
  ) VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'name', ''), split_part(COALESCE(NEW.email, ''), '@', 1)),
    COALESCE(NEW.email, ''),
    '',
    'user',
    0,
    0
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.create_profile_for_auth_user() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_profile_for_auth_user()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created_create_profile ON auth.users;
CREATE TRIGGER on_auth_user_created_create_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.create_profile_for_auth_user();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_role_allowed_check'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_role_allowed_check
      CHECK (role IN ('user', 'admin'));
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.deals (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL DEFAULT 'General',
  badge TEXT NOT NULL DEFAULT 'NEW',
  icon_name TEXT NOT NULL DEFAULT 'local_cafe',
  price NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (price >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.deals
  ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) NOT NULL DEFAULT 0;

UPDATE public.deals SET price = 0 WHERE price IS NULL;
ALTER TABLE public.deals
  ALTER COLUMN price SET DEFAULT 0,
  ALTER COLUMN price SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'deals_price_nonnegative_check'
      AND conrelid = 'public.deals'::regclass
  ) THEN
    ALTER TABLE public.deals
      ADD CONSTRAINT deals_price_nonnegative_check CHECK (price >= 0);
  END IF;
END;
$$;

INSERT INTO public.deals (id, name, description, category, badge, icon_name)
VALUES
  ('brown-sugar-oat-latte', 'Brown Sugar Oat Latte', 'Espresso, oat milk, and brown sugar over ice.', 'Special Drinks', 'NEW', 'local_cafe'),
  ('baristas-choice', 'Barista''s Choice', 'A handcrafted surprise selected by today''s barista.', 'Barista''s Choice', 'TODAY', 'auto_awesome'),
  ('seasonal-cold-brew', 'Seasonal Cold Brew', 'Our limited seasonal flavor, served chilled.', 'Seasonal', 'LIMITED', 'local_bar'),
  ('coffee-break-bundle', 'Coffee Break Bundle', 'Two drinks and two pastries for sharing.', 'Bundles', 'BUNDLE', 'bakery_dining'),
  ('breakfast-pair', 'Breakfast Pair', 'A fresh pastry paired with your choice of coffee.', 'Food', 'FRESH', 'free_breakfast')
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_code TEXT NOT NULL UNIQUE,
  items JSONB NOT NULL CHECK (jsonb_typeof(items) = 'array'),
  total NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  points_earned INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS total NUMERIC(10, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS points_earned INT NOT NULL DEFAULT 0;

DO $$
DECLARE
  status_constraint RECORD;
BEGIN
  FOR status_constraint IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.orders'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%status%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.orders DROP CONSTRAINT %I',
      status_constraint.conname
    );
  END LOOP;
END;
$$;

UPDATE public.orders
SET status = CASE
  WHEN status IN ('placed', 'preparing', 'ready') THEN 'pending'
  ELSE status
END;

ALTER TABLE public.orders
  ALTER COLUMN status SET DEFAULT 'pending',
  ALTER COLUMN points_earned SET DEFAULT 0,
  ALTER COLUMN points_earned SET NOT NULL,
  DROP CONSTRAINT IF EXISTS orders_status_allowed_check,
  DROP CONSTRAINT IF EXISTS orders_points_earned_nonnegative_check,
  ADD CONSTRAINT orders_status_allowed_check
    CHECK (status IN ('pending', 'completed', 'cancelled')),
  ADD CONSTRAINT orders_points_earned_nonnegative_check
    CHECK (points_earned >= 0);

CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  deal_id TEXT REFERENCES public.deals(id) ON DELETE SET NULL,
  deal_name TEXT NOT NULL,
  deal_category TEXT NOT NULL DEFAULT 'General',
  unit_price NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  quantity INT NOT NULL CHECK (quantity BETWEEN 1 AND 10),
  UNIQUE (order_id, deal_id)
);

CREATE TABLE IF NOT EXISTS public.app_settings (
  setting_key TEXT PRIMARY KEY,
  points_per_unit INT NOT NULL CHECK (points_per_unit > 0),
  peso_per_unit NUMERIC(10, 2) NOT NULL CHECK (peso_per_unit > 0)
);

INSERT INTO public.app_settings (setting_key, points_per_unit, peso_per_unit)
VALUES ('order_points', 10, 100)
ON CONFLICT (setting_key) DO NOTHING;

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS points INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL;

UPDATE public.transactions
SET points = CASE
  WHEN transaction_type = 'earned' THEN points_spent
  ELSE -points_spent
END
WHERE points = 0 AND points_spent > 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_earned_order_unique
  ON public.transactions(order_id)
  WHERE transaction_type = 'earned' AND order_id IS NOT NULL;

-- Old order JSON did not snapshot prices. Backfill the rows without deleting
-- or rewriting their original JSON; unknown historical prices use 0.
INSERT INTO public.order_items (
  order_id, deal_id, deal_name, deal_category, unit_price, quantity
)
SELECT
  o.id,
  CASE WHEN d.id IS NOT NULL THEN NULLIF(item.value ->> 'id', '') END,
  COALESCE(NULLIF(item.value ->> 'name', ''), d.name, 'Deal'),
  COALESCE(NULLIF(item.value ->> 'category', ''), d.category, 'General'),
  COALESCE(NULLIF(item.value ->> 'unit_price', '')::NUMERIC, 0),
  LEAST(10, GREATEST(1, COALESCE(NULLIF(item.value ->> 'quantity', '')::INT, 1)))
FROM public.orders AS o
CROSS JOIN LATERAL jsonb_array_elements(o.items) AS item(value)
LEFT JOIN public.deals AS d ON d.id = item.value ->> 'id'
ON CONFLICT (order_id, deal_id) DO NOTHING;

UPDATE public.orders AS o
SET total = COALESCE((
  SELECT SUM(oi.unit_price * oi.quantity)
  FROM public.order_items AS oi
  WHERE oi.order_id = o.id
), 0)
WHERE o.total = 0;

CREATE INDEX IF NOT EXISTS idx_orders_user_created_at
  ON public.orders(user_id, created_at DESC);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'deals'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.deals';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'orders'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.orders';
  END IF;
END;
$$;

-- Assign the administrator using the auth.users UUID, never user-editable
-- user_metadata. Run this only for the intended administrator account.
UPDATE public.profiles AS p
SET role = 'admin'
FROM auth.users AS u
WHERE p.id = u.id
  AND lower(u.email) = lower('kapetoladmin@thekapetol.com');

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  );
$$;

ALTER FUNCTION public.is_admin() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_profile_privileges()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF NEW.role IS DISTINCT FROM OLD.role
      AND current_user <> 'postgres'
      AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only an administrator may change a profile role.'
      USING ERRCODE = '42501';
  END IF;

  IF (
    NEW.points IS DISTINCT FROM OLD.points
    OR NEW.lifetime_points IS DISTINCT FROM OLD.lifetime_points
  )
  AND NOT public.is_admin()
  AND NOT (
    current_user = 'postgres'
    AND current_setting('app.allow_points_update', TRUE) = 'on'
  ) THEN
    RAISE EXCEPTION 'Points may only be changed by a trusted server function.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_privileges ON public.profiles;
CREATE TRIGGER protect_profile_privileges
BEFORE UPDATE OF role, points, lifetime_points ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.protect_profile_privileges();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotion_claims ENABLE ROW LEVEL SECURITY;

-- Remove old permissive policies on these tables before installing the
-- restrictive replacements. No table rows are deleted by this block.
DO $$
DECLARE
  existing_policy RECORD;
BEGIN
  FOR existing_policy IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY (ARRAY[
        'profiles', 'promotions', 'rewards', 'deals', 'orders', 'order_items',
        'transactions', 'daily_rewards', 'reward_settings', 'promotion_claims',
        'app_settings'
      ])
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON %I.%I',
      existing_policy.policyname,
      existing_policy.schemaname,
      existing_policy.tablename
    );
  END LOOP;
END;
$$;

REVOKE ALL PRIVILEGES ON TABLE
  public.profiles,
  public.promotions,
  public.rewards,
  public.deals,
  public.orders,
  public.order_items,
  public.app_settings,
  public.transactions,
  public.daily_rewards,
  public.reward_settings,
  public.promotion_claims
FROM PUBLIC, anon, authenticated;

GRANT SELECT ON TABLE
  public.profiles,
  public.promotions,
  public.rewards,
  public.deals,
  public.orders,
  public.order_items,
  public.app_settings,
  public.transactions,
  public.daily_rewards,
  public.reward_settings,
  public.promotion_claims
TO authenticated;

GRANT INSERT (id, name, email, phone, birthday, avatar_url)
  ON public.profiles TO authenticated;
GRANT UPDATE (name, email, phone, birthday, avatar_url)
  ON public.profiles TO authenticated;

GRANT INSERT, UPDATE, DELETE
  ON public.promotions, public.rewards, public.deals TO authenticated;
GRANT INSERT ON public.promotion_claims TO authenticated;

CREATE POLICY profiles_select_self_or_admin ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR public.is_admin());

CREATE POLICY profiles_insert_self_as_user ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND role = 'user'
    AND COALESCE(points, 0) = 0
    AND COALESCE(lifetime_points, 0) = 0
  );

CREATE POLICY profiles_update_self ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY promotions_read_active_or_admin ON public.promotions
  FOR SELECT TO authenticated
  USING (is_active = TRUE OR public.is_admin());
CREATE POLICY promotions_admin_write ON public.promotions
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY rewards_read_active_or_admin ON public.rewards
  FOR SELECT TO authenticated
  USING (is_active = TRUE OR public.is_admin());
CREATE POLICY rewards_admin_write ON public.rewards
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY deals_read_active_or_admin ON public.deals
  FOR SELECT TO authenticated
  USING (is_active = TRUE OR public.is_admin());
CREATE POLICY deals_admin_write ON public.deals
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY orders_read_own_or_admin ON public.orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());
CREATE POLICY orders_insert_own_user ON public.orders
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND NOT public.is_admin());
CREATE POLICY order_items_read_own_or_admin ON public.order_items
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.orders AS o
      WHERE o.id = order_items.order_id
        AND o.user_id = auth.uid()
    )
  );

CREATE POLICY app_settings_read_authenticated ON public.app_settings
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY transactions_read_own_or_admin ON public.transactions
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY daily_rewards_read_own ON public.daily_rewards
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY reward_settings_read_authenticated ON public.reward_settings
  FOR SELECT TO authenticated
  USING (TRUE);

CREATE POLICY promotion_claims_read_own ON public.promotion_claims
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY promotion_claims_insert_own_user ON public.promotion_claims
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND NOT public.is_admin());

CREATE OR REPLACE FUNCTION public.claim_daily_reward()
RETURNS TABLE (
  reward_points INT,
  streak_day INT,
  new_points INT,
  claimed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  account_role TEXT;
  last_claim public.daily_rewards%ROWTYPE;
  new_streak INT := 1;
  current_points INT;
  current_lifetime_points INT;
  selected_reward_amount INT;
  claim_time TIMESTAMPTZ := now();
  next_claim_time TIMESTAMPTZ;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be signed in.';
  END IF;

  SELECT p.role, p.points, p.lifetime_points
  INTO account_role, current_points, current_lifetime_points
  FROM public.profiles AS p
  WHERE p.id = current_user_id;

  IF account_role IS DISTINCT FROM 'user' THEN
    RAISE EXCEPTION 'DAILY_REWARD_FORBIDDEN: Only user accounts may claim rewards.'
      USING ERRCODE = '42501';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(current_user_id::TEXT));

  SELECT dr.* INTO last_claim
  FROM public.daily_rewards AS dr
  WHERE dr.user_id = current_user_id
  ORDER BY dr.claimed_at DESC
  LIMIT 1;

  IF last_claim.id IS NOT NULL THEN
    next_claim_time := last_claim.claimed_at + INTERVAL '20 hours';
    IF claim_time < next_claim_time THEN
      RAISE EXCEPTION 'DAILY_REWARD_ALREADY_CLAIMED: Please wait until %.', next_claim_time;
    END IF;
    new_streak := last_claim.streak_day + 1;
  END IF;

  SELECT rs.reward_amount
  INTO selected_reward_amount
  FROM public.reward_settings AS rs
  ORDER BY random()
  LIMIT 1;
  selected_reward_amount := COALESCE(selected_reward_amount, 10);

  current_points := COALESCE(current_points, 0);
  current_lifetime_points := GREATEST(
    COALESCE(current_lifetime_points, 0), current_points
  );

  PERFORM set_config('app.allow_points_update', 'on', TRUE);
  UPDATE public.profiles
  SET points = current_points + selected_reward_amount,
      lifetime_points = current_lifetime_points + selected_reward_amount
  WHERE id = current_user_id;
  PERFORM set_config('app.allow_points_update', 'off', TRUE);

  INSERT INTO public.daily_rewards AS inserted_reward (
    user_id, reward_points, streak_day, claimed_at
  )
  VALUES (current_user_id, selected_reward_amount, new_streak, claim_time)
  RETURNING inserted_reward.claimed_at INTO claimed_at;

  reward_points := selected_reward_amount;
  streak_day := new_streak;
  new_points := current_points + selected_reward_amount;
  RETURN NEXT;
END;
$$;

ALTER FUNCTION public.claim_daily_reward() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.claim_daily_reward() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_daily_reward() TO authenticated;

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
  WHERE r.id = p_reward_id AND r.is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'REWARD_UNAVAILABLE';
  END IF;
  IF current_points < selected_reward.points_cost THEN
    RAISE EXCEPTION 'INSUFFICIENT_POINTS';
  END IF;
  updated_points := current_points - selected_reward.points_cost;
  PERFORM set_config('app.allow_points_update', 'on', TRUE);
  UPDATE public.profiles SET points = updated_points
  WHERE id = current_user_id;
  PERFORM set_config('app.allow_points_update', 'off', TRUE);

  INSERT INTO public.transactions (
    user_id, reward_name, points_spent, transaction_type
  ) VALUES (
    current_user_id, selected_reward.name,
    selected_reward.points_cost, 'redemption'
  );

  RETURN jsonb_build_object('points', updated_points);
END;
$$;

ALTER FUNCTION public.redeem_reward(UUID) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.redeem_reward(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.redeem_reward(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.place_order(p_items JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  account_role TEXT;
  requested_count INT;
  normalized_items JSONB;
  computed_total NUMERIC(10, 2);
  generated_code TEXT;
  created_order public.orders%ROWTYPE;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be signed in.';
  END IF;

  SELECT p.role INTO account_role
  FROM public.profiles AS p
  WHERE p.id = current_user_id;

  IF account_role IS DISTINCT FROM 'user' THEN
    RAISE EXCEPTION 'ORDER_FORBIDDEN: Only user accounts may place orders.'
      USING ERRCODE = '42501';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RAISE EXCEPTION 'ORDER_INVALID: Items must be a JSON array.';
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'ORDER_EMPTY: Add an item before placing an order.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS requested(value)
    WHERE jsonb_typeof(requested.value) <> 'object'
       OR COALESCE(requested.value ->> 'id', '') = ''
       OR COALESCE(requested.value ->> 'quantity', '') !~ '^[0-9]+$'
       OR CASE
            WHEN COALESCE(requested.value ->> 'quantity', '') ~ '^[0-9]+$'
            THEN (requested.value ->> 'quantity')::INT NOT BETWEEN 1 AND 10
            ELSE TRUE
          END
  ) THEN
    RAISE EXCEPTION 'ORDER_INVALID: Item quantities must be from 1 to 10.';
  END IF;

  SELECT COUNT(*) INTO requested_count
  FROM jsonb_array_elements(p_items);

  IF requested_count <> (
    SELECT COUNT(DISTINCT requested.value ->> 'id')
    FROM jsonb_array_elements(p_items) AS requested(value)
  ) THEN
    RAISE EXCEPTION 'ORDER_INVALID: Each deal may appear only once.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_items) AS requested(value)
    LEFT JOIN public.deals AS d ON d.id = requested.value ->> 'id'
    WHERE d.id IS NULL OR d.is_active IS NOT TRUE
  ) THEN
    RAISE EXCEPTION 'ORDER_INVALID: One or more deals are unavailable.';
  END IF;

  SELECT
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'deal_name', d.name,
        'category', d.category,
        'quantity', (requested.value ->> 'quantity')::INT,
        'unit_price', d.price,
        'line_total', round(d.price * (requested.value ->> 'quantity')::INT, 2)
      ) ORDER BY d.created_at, d.id
    ),
    SUM(d.price * (requested.value ->> 'quantity')::INT)
  INTO normalized_items, computed_total
  FROM jsonb_array_elements(p_items) AS requested(value)
  JOIN public.deals AS d ON d.id = requested.value ->> 'id'
  WHERE d.is_active = TRUE;

  LOOP
    generated_code := 'KPT-' || upper(substr(
      md5(random()::TEXT || clock_timestamp()::TEXT), 1, 4
    ));
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.orders WHERE order_code = generated_code
    );
  END LOOP;

  INSERT INTO public.orders (user_id, order_code, items, total)
  VALUES (
    current_user_id,
    generated_code,
    normalized_items,
    COALESCE(computed_total, 0)
  )
  RETURNING * INTO created_order;

  INSERT INTO public.order_items (
    order_id, deal_id, deal_name, deal_category, unit_price, quantity
  )
  SELECT
    created_order.id,
    item.value ->> 'id',
    item.value ->> 'deal_name',
    item.value ->> 'category',
    (item.value ->> 'unit_price')::NUMERIC(10, 2),
    (item.value ->> 'quantity')::INT
  FROM jsonb_array_elements(normalized_items) AS item(value);

  RETURN jsonb_build_object(
    'order_id', created_order.id,
    'order_code', created_order.order_code,
    'items', created_order.items,
    'total', created_order.total,
    'created_at', created_order.created_at
  );
END;
$$;

ALTER FUNCTION public.place_order(JSONB) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.place_order(JSONB) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_order(JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.update_order_status(
  p_order_id UUID,
  p_new_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_order public.orders%ROWTYPE;
  customer_role TEXT;
  current_points INT;
  current_lifetime_points INT;
  points_per_unit INT;
  peso_per_unit NUMERIC(10, 2);
  awarded_points INT := 0;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_new_status NOT IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'INVALID_STATUS: Only completed or cancelled is allowed.';
  END IF;

  SELECT o.* INTO target_order
  FROM public.orders AS o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;
  IF target_order.status <> 'pending' THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PROCESSED';
  END IF;

  IF p_new_status = 'completed' THEN
    SELECT p.role, p.points, p.lifetime_points
    INTO customer_role, current_points, current_lifetime_points
    FROM public.profiles AS p
    WHERE p.id = target_order.user_id
    FOR UPDATE;

    IF customer_role = 'user' THEN
      SELECT s.points_per_unit, s.peso_per_unit
      INTO points_per_unit, peso_per_unit
      FROM public.app_settings AS s
      WHERE s.setting_key = 'order_points';

      IF points_per_unit IS NULL OR peso_per_unit IS NULL OR peso_per_unit <= 0 THEN
        RAISE EXCEPTION 'ORDER_POINTS_SETTINGS_MISSING';
      END IF;

      awarded_points :=
          FLOOR(target_order.total / peso_per_unit)::INT * points_per_unit;
    END IF;
  END IF;

  UPDATE public.orders
  SET status = p_new_status,
      points_earned = awarded_points
  WHERE id = target_order.id;

  IF p_new_status = 'completed' AND awarded_points > 0
     AND customer_role = 'user' THEN
    PERFORM set_config('app.allow_points_update', 'on', TRUE);
    UPDATE public.profiles
    SET points = COALESCE(current_points, 0) + awarded_points,
        lifetime_points = GREATEST(
          COALESCE(current_lifetime_points, 0), COALESCE(current_points, 0)
        ) + awarded_points
    WHERE id = target_order.user_id;
    PERFORM set_config('app.allow_points_update', 'off', TRUE);

    INSERT INTO public.transactions (
      user_id, reward_name, points_spent, transaction_type, points, order_id
    ) VALUES (
      target_order.user_id,
      format('Order %s (+%s pts)', target_order.order_code, awarded_points),
      0,
      'earned',
      awarded_points,
      target_order.id
    );
  END IF;

  RETURN jsonb_build_object(
    'order_id', target_order.id,
    'order_code', target_order.order_code,
    'status', p_new_status,
    'points_earned', awarded_points
  );
END;
$$;

ALTER FUNCTION public.update_order_status(UUID, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.update_order_status(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_order_status(UUID, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_sales_summary(
  p_from_ts TIMESTAMPTZ,
  p_to_ts TIMESTAMPTZ
)
RETURNS TABLE (
  total_orders BIGINT,
  total_deals_ordered BIGINT,
  total_revenue NUMERIC,
  total_rewards_claimed BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    (
      SELECT COUNT(*)
      FROM public.orders AS o
      JOIN public.profiles AS p ON p.id = o.user_id AND p.role <> 'admin'
      WHERE o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
        AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
        AND o.status <> 'cancelled'
    ),
    (
      SELECT COALESCE(SUM(oi.quantity), 0)::BIGINT
      FROM public.order_items AS oi
      JOIN public.orders AS o ON o.id = oi.order_id
      JOIN public.profiles AS p ON p.id = o.user_id AND p.role <> 'admin'
      WHERE o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
        AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
        AND o.status <> 'cancelled'
    ),
    (
      SELECT COALESCE(SUM(oi.unit_price * oi.quantity), 0)::NUMERIC
      FROM public.order_items AS oi
      JOIN public.orders AS o ON o.id = oi.order_id
      JOIN public.profiles AS p ON p.id = o.user_id AND p.role <> 'admin'
      WHERE o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
        AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
        AND o.status <> 'cancelled'
    ),
    (
      SELECT COUNT(*)
      FROM public.transactions AS t
      JOIN public.profiles AS p ON p.id = t.user_id AND p.role <> 'admin'
      WHERE t.transaction_type = 'redemption'
        AND t.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
        AND t.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_deal_sales(
  p_from_ts TIMESTAMPTZ,
  p_to_ts TIMESTAMPTZ
)
RETURNS TABLE (
  deal_name TEXT,
  category TEXT,
  units_sold BIGINT,
  revenue NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    oi.deal_name,
    oi.deal_category,
    SUM(oi.quantity)::BIGINT,
    SUM(oi.unit_price * oi.quantity)::NUMERIC
  FROM public.order_items AS oi
  JOIN public.orders AS o ON o.id = oi.order_id
  JOIN public.profiles AS p ON p.id = o.user_id AND p.role <> 'admin'
  WHERE o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
    AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
    AND o.status <> 'cancelled'
  GROUP BY oi.deal_name, oi.deal_category
  ORDER BY SUM(oi.quantity) DESC, oi.deal_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_reward_claims(
  p_from_ts TIMESTAMPTZ,
  p_to_ts TIMESTAMPTZ
)
RETURNS TABLE (
  reward_name TEXT,
  claim_count BIGINT,
  points_redeemed BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    t.reward_name,
    COUNT(*)::BIGINT,
    SUM(t.points_spent)::BIGINT
  FROM public.transactions AS t
  JOIN public.profiles AS p ON p.id = t.user_id AND p.role <> 'admin'
  WHERE t.transaction_type = 'redemption'
    AND t.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
    AND t.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
  GROUP BY t.reward_name
  ORDER BY COUNT(*) DESC, t.reward_name;
END;
$$;

ALTER FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO postgres;
ALTER FUNCTION public.get_deal_sales(TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO postgres;
ALTER FUNCTION public.get_reward_claims(TIMESTAMPTZ, TIMESTAMPTZ) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_deal_sales(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_reward_claims(TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_deal_sales(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reward_claims(TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

COMMIT;

-- The current Flutter redemption path still writes profiles.points directly
-- through SupabaseProfilesService.persistRedemption. This migration blocks
-- that write. Before running it in production, switch that client method to
-- call redeem_reward(p_reward_id) and pass the selected reward's UUID.
-- The cart calls place_order(p_items); the server snapshots current prices.
-- Existing orders created before price tracking cannot recover historical
-- prices, so their backfilled order-item prices use 0 when no snapshot exists.