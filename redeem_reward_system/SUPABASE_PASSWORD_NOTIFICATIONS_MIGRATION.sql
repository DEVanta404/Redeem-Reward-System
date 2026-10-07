-- Review and run manually after SUPABASE_ADMIN_SECURITY_MIGRATION.sql.
-- The Flutter app never applies SQL and must never contain a service-role key.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (
    type IN (
      'welcome',
      'order_placed',
      'order_completed',
      'order_cancelled',
      'points_earned',
      'reward_redeemed',
      'new_order_admin'
    )
  ),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}'::JSONB,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notifications_user_read_created_idx
  ON public.notifications (user_id, is_read, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own
  ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_own_read_state
  ON public.notifications;
CREATE POLICY notifications_update_own_read_state
  ON public.notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

REVOKE ALL ON TABLE public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.notifications TO authenticated;
GRANT UPDATE (is_read) ON TABLE public.notifications TO authenticated;

CREATE OR REPLACE FUNCTION public.create_welcome_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  display_name TEXT;
BEGIN
  IF NEW.role = 'admin' THEN
    RETURN NEW;
  END IF;

  display_name := COALESCE(NULLIF(btrim(NEW.name), ''), 'there');
  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.id,
    'welcome',
    'Welcome to Kapetol! ☕',
    format(
      'Congrats, %s! Your Kapetol account is ready. Order from Deals and earn points on every order.',
      display_name
    ),
    jsonb_build_object('profile_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.create_welcome_notification() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.create_welcome_notification()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS profiles_create_welcome_notification
  ON public.profiles;
CREATE TRIGGER profiles_create_welcome_notification
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.create_welcome_notification();

CREATE OR REPLACE FUNCTION public.remove_welcome_notification_for_admin()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.role IS DISTINCT FROM 'admin' AND NEW.role = 'admin' THEN
    DELETE FROM public.notifications
    WHERE user_id = NEW.id AND type = 'welcome';
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.remove_welcome_notification_for_admin() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.remove_welcome_notification_for_admin()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS profiles_remove_welcome_notification_for_admin
  ON public.profiles;
CREATE TRIGGER profiles_remove_welcome_notification_for_admin
  AFTER UPDATE OF role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.remove_welcome_notification_for_admin();

CREATE OR REPLACE FUNCTION public.clear_password_flag_after_auth_password_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.encrypted_password IS DISTINCT FROM NEW.encrypted_password THEN
    UPDATE public.profiles
    SET must_change_password = FALSE
    WHERE id = NEW.id AND must_change_password = TRUE;
  END IF;
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.clear_password_flag_after_auth_password_change()
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.clear_password_flag_after_auth_password_change()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS auth_password_change_clears_profile_flag ON auth.users;
CREATE TRIGGER auth_password_change_clears_profile_flag
  AFTER UPDATE OF encrypted_password ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.clear_password_flag_after_auth_password_change();

CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS BIGINT
LANGUAGE SQL
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT count(*)
  FROM public.notifications
  WHERE user_id = auth.uid()
    AND is_read = FALSE;
$$;

REVOKE ALL ON FUNCTION public.get_unread_notification_count()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_unread_notification_count()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_pending_order_count()
RETURNS BIGINT
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pending_count BIGINT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO pending_count
  FROM public.orders
  WHERE status = 'pending';
  RETURN pending_count;
END;
$$;

ALTER FUNCTION public.get_pending_order_count() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_pending_order_count()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_pending_order_count()
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
  UPDATE public.profiles
  SET points = updated_points
  WHERE id = current_user_id;
  PERFORM set_config('app.allow_points_update', 'off', TRUE);

  INSERT INTO public.transactions (
    user_id, reward_name, points_spent, transaction_type
  ) VALUES (
    current_user_id,
    selected_reward.name,
    selected_reward.points_cost,
    'redemption'
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

CREATE OR REPLACE FUNCTION public.place_order(p_items JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  account_role TEXT;
  customer_name TEXT;
  requested_count INT;
  normalized_items JSONB;
  computed_total NUMERIC(10, 2);
  generated_code TEXT;
  order_summary TEXT;
  distinct_item_count INT;
  total_item_count INT;
  created_order public.orders%ROWTYPE;
  admin_profile RECORD;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be signed in.';
  END IF;

  SELECT p.role, COALESCE(NULLIF(btrim(p.name), ''), 'A customer')
  INTO account_role, customer_name
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

  SELECT count(*), COALESCE(sum((item.value ->> 'quantity')::INT), 0)
  INTO distinct_item_count, total_item_count
  FROM jsonb_array_elements(normalized_items) AS item(value);

  SELECT string_agg(
    format('%sx %s', item.value ->> 'quantity', item.value ->> 'deal_name'),
    ', ' ORDER BY item.ordinality
  )
  INTO order_summary
  FROM jsonb_array_elements(normalized_items) WITH ORDINALITY AS item(value, ordinality)
  WHERE item.ordinality <= 2;

  IF distinct_item_count > 2 THEN
    order_summary := order_summary || format(
      ' and %s more items',
      distinct_item_count - 2
    );
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    current_user_id,
    'order_placed',
    'Order placed',
    format(
      'You ordered %s (%s). Your code is %s. Show it at the counter.',
      order_summary,
      '₱' || to_char(created_order.total, 'FM9999999990.00'),
      generated_code
    ),
    jsonb_build_object(
      'order_id', created_order.id,
      'order_code', generated_code
    )
  );

  FOR admin_profile IN
    SELECT p.id
    FROM public.profiles AS p
    WHERE p.role = 'admin'
  LOOP
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      admin_profile.id,
      'new_order_admin',
      format('New order %s', generated_code),
      format(
        '%s ordered %s items (%s). Pending.',
        customer_name,
        total_item_count,
        '₱' || to_char(created_order.total, 'FM9999999990.00')
      ),
      jsonb_build_object(
        'order_id', created_order.id,
        'order_code', generated_code
      )
    );
  END LOOP;

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

  SELECT p.role INTO customer_role
  FROM public.profiles AS p
  WHERE p.id = target_order.user_id;

  IF p_new_status = 'completed' THEN
    SELECT p.points, p.lifetime_points
    INTO current_points, current_lifetime_points
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

  IF customer_role = 'user' AND p_new_status = 'completed' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      target_order.user_id,
      'order_completed',
      'Order completed',
      format('Order completed. You earned %s pts.', awarded_points),
      jsonb_build_object(
        'order_id', target_order.id,
        'order_code', target_order.order_code,
        'points_earned', awarded_points
      )
    );
  ELSIF customer_role = 'user' AND p_new_status = 'cancelled' THEN
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      target_order.user_id,
      'order_cancelled',
      'Order cancelled',
      format('Order %s was cancelled.', target_order.order_code),
      jsonb_build_object(
        'order_id', target_order.id,
        'order_code', target_order.order_code
      )
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

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;

COMMIT;
