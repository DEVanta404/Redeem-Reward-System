-- Review and run manually after SUPABASE_PASSWORD_NOTIFICATIONS_MIGRATION.sql.
-- This migration records counter payments only; it does not process payments.

BEGIN;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS payment_method TEXT NOT NULL DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS subtotal NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS amount_tendered NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS change_amount NUMERIC(10, 2),
  ADD COLUMN IF NOT EXISTS payment_reference TEXT,
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS receipt_no TEXT;

UPDATE public.orders
SET subtotal = total
WHERE subtotal IS NULL;

UPDATE public.orders
SET payment_status = 'paid'
WHERE status = 'completed'
  AND payment_status = 'unpaid';

ALTER TABLE public.orders
  ALTER COLUMN subtotal SET DEFAULT 0,
  ALTER COLUMN subtotal SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.orders'::regclass
      AND conname = 'orders_payment_method_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_payment_method_check
      CHECK (payment_method IN ('cash', 'gcash', 'maya', 'card'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.orders'::regclass
      AND conname = 'orders_payment_status_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_payment_status_check
      CHECK (payment_status IN ('unpaid', 'paid'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.orders'::regclass
      AND conname = 'orders_payment_amounts_check'
  ) THEN
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_payment_amounts_check
      CHECK (
        (amount_tendered IS NULL OR amount_tendered BETWEEN 0 AND 1000000)
        AND (change_amount IS NULL OR change_amount BETWEEN 0 AND 1000000)
      );
  END IF;
END;
$$;

-- Payment data is readable under the existing owner/admin SELECT policy. All
-- writes go through the security-definer order RPCs below.
REVOKE INSERT, UPDATE, DELETE
  ON TABLE public.orders FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.orders TO authenticated;

DROP FUNCTION IF EXISTS public.place_order(JSONB);

CREATE OR REPLACE FUNCTION public.place_order(
  p_items JSONB,
  p_payment_method TEXT,
  p_cash_amount NUMERIC
)
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
  points_per_unit INT;
  peso_per_unit NUMERIC(10, 2);
  points_to_earn INT := 0;
  tendered NUMERIC(10, 2);
  calculated_change NUMERIC(10, 2);
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

  IF p_payment_method IS NULL
     OR p_payment_method NOT IN ('cash', 'gcash', 'maya', 'card') THEN
    RAISE EXCEPTION 'PAYMENT_METHOD_INVALID';
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
    round(SUM(d.price * (requested.value ->> 'quantity')::INT), 2)
  INTO normalized_items, computed_total
  FROM jsonb_array_elements(p_items) AS requested(value)
  JOIN public.deals AS d ON d.id = requested.value ->> 'id'
  WHERE d.is_active = TRUE;

  IF computed_total IS NULL OR computed_total <= 0 OR computed_total > 1000000 THEN
    RAISE EXCEPTION 'ORDER_TOTAL_INVALID';
  END IF;

  tendered := NULL;
  calculated_change := NULL;
  IF p_payment_method = 'cash' THEN
    IF p_cash_amount IS NULL
       OR p_cash_amount <> round(p_cash_amount, 2)
       OR p_cash_amount < computed_total
       OR p_cash_amount > 1000000 THEN
      RAISE EXCEPTION 'CASH_AMOUNT_INVALID';
    END IF;
    tendered := p_cash_amount;
    calculated_change := p_cash_amount - computed_total;
  ELSIF p_cash_amount IS NOT NULL THEN
    RAISE EXCEPTION 'CASH_AMOUNT_NOT_ALLOWED_FOR_NON_CASH';
  END IF;

  LOOP
    generated_code := 'KPT-' || upper(substr(
      md5(random()::TEXT || clock_timestamp()::TEXT), 1, 4
    ));
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.orders WHERE order_code = generated_code
    );
  END LOOP;

  INSERT INTO public.orders (
    user_id, order_code, items, total, subtotal, payment_method,
    payment_status, amount_tendered, change_amount
  )
  VALUES (
    current_user_id, generated_code, normalized_items, computed_total,
    computed_total, p_payment_method, 'unpaid', tendered, calculated_change
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
  FROM jsonb_array_elements(normalized_items)
    WITH ORDINALITY AS item(value, ordinality)
  WHERE item.ordinality <= 2;

  IF distinct_item_count > 2 THEN
    order_summary := order_summary || format(
      ' and %s more items',
      distinct_item_count - 2
    );
  END IF;

  SELECT s.points_per_unit, s.peso_per_unit
  INTO points_per_unit, peso_per_unit
  FROM public.app_settings AS s
  WHERE s.setting_key = 'order_points';

  IF points_per_unit IS NOT NULL AND peso_per_unit IS NOT NULL
     AND peso_per_unit > 0 THEN
    points_to_earn := FLOOR(computed_total / peso_per_unit)::INT
      * points_per_unit;
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    current_user_id,
    'order_placed',
    'Order placed',
    format(
      'You ordered %s (%s). Paying with %s at the counter. Your ticket is %s. Please wait for it to be called at the counter.',
      order_summary,
      '₱' || to_char(computed_total, 'FM9999999990.00'),
      CASE p_payment_method
        WHEN 'gcash' THEN 'GCash'
        WHEN 'maya' THEN 'Maya'
        WHEN 'card' THEN 'Card'
        ELSE 'Cash'
      END,
      generated_code
    ),
    jsonb_build_object(
      'order_id', created_order.id,
      'order_code', generated_code,
      'payment_method', p_payment_method
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
        '₱' || to_char(computed_total, 'FM9999999990.00')
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
    'subtotal', created_order.subtotal,
    'payment_method', created_order.payment_method,
    'payment_status', created_order.payment_status,
    'amount_tendered', created_order.amount_tendered,
    'change_amount', created_order.change_amount,
    'points_to_earn', points_to_earn,
    'created_at', created_order.created_at
  );
END;
$$;

ALTER FUNCTION public.place_order(JSONB, TEXT, NUMERIC) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.place_order(JSONB, TEXT, NUMERIC)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.place_order(JSONB, TEXT, NUMERIC)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_order_with_payment(
  p_order_id UUID,
  p_payment_method TEXT,
  p_amount_received NUMERIC,
  p_reference TEXT DEFAULT NULL
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
  tendered NUMERIC(10, 2);
  calculated_change NUMERIC(10, 2);
  safe_reference TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;

  IF p_payment_method IS NULL
     OR p_payment_method NOT IN ('cash', 'gcash', 'maya', 'card') THEN
    RAISE EXCEPTION 'PAYMENT_METHOD_INVALID';
  END IF;

  SELECT o.* INTO target_order
  FROM public.orders AS o
  WHERE o.id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'ORDER_NOT_FOUND';
  END IF;
  IF target_order.status <> 'pending'
     OR target_order.payment_status <> 'unpaid' THEN
    RAISE EXCEPTION 'ORDER_ALREADY_PROCESSED';
  END IF;

  tendered := NULL;
  calculated_change := NULL;
  IF p_payment_method = 'cash' THEN
    IF p_amount_received IS NULL
       OR p_amount_received <> round(p_amount_received, 2)
       OR p_amount_received < target_order.total
       OR p_amount_received > 1000000 THEN
      RAISE EXCEPTION 'CASH_AMOUNT_INVALID';
    END IF;
    tendered := p_amount_received;
    calculated_change := p_amount_received - target_order.total;
  ELSE
    IF p_amount_received IS NOT NULL THEN
      RAISE EXCEPTION 'CASH_AMOUNT_NOT_ALLOWED_FOR_NON_CASH';
    END IF;
    tendered := target_order.total;
    calculated_change := 0;
  END IF;

  safe_reference := NULLIF(btrim(p_reference), '');
  IF safe_reference IS NOT NULL AND length(safe_reference) > 120 THEN
    RAISE EXCEPTION 'PAYMENT_REFERENCE_TOO_LONG';
  END IF;
  IF safe_reference IS NOT NULL
     AND p_payment_method NOT IN ('gcash', 'maya') THEN
    RAISE EXCEPTION 'PAYMENT_REFERENCE_METHOD_INVALID';
  END IF;

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

  UPDATE public.orders
  SET status = 'completed',
      payment_method = p_payment_method,
      payment_status = 'paid',
      amount_tendered = tendered,
      change_amount = calculated_change,
      payment_reference = safe_reference,
      paid_at = now(),
      points_earned = awarded_points
  WHERE id = target_order.id;

  IF awarded_points > 0 AND customer_role = 'user' THEN
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
      0, 'earned', awarded_points, target_order.id
    );
  END IF;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    target_order.user_id,
    'order_completed',
    'Order completed',
    CASE WHEN p_payment_method = 'cash' THEN
      format(
        'Order completed. You earned %s pts. Total %s; change %s.',
        awarded_points,
        '₱' || to_char(target_order.total, 'FM9999999990.00'),
        '₱' || to_char(calculated_change, 'FM9999999990.00')
      )
    ELSE
      format(
        'Order completed. You earned %s pts. Total %s.',
        awarded_points,
        '₱' || to_char(target_order.total, 'FM9999999990.00')
      )
    END,
    jsonb_build_object(
      'order_id', target_order.id,
      'order_code', target_order.order_code,
      'points_earned', awarded_points
    )
  );

  RETURN jsonb_build_object(
    'order_id', target_order.id,
    'order_code', target_order.order_code,
    'status', 'completed',
    'payment_method', p_payment_method,
    'payment_status', 'paid',
    'amount_tendered', tendered,
    'change_amount', calculated_change,
    'payment_reference', safe_reference,
    'paid_at', now(),
    'points_earned', awarded_points
  );
END;
$$;

ALTER FUNCTION public.complete_order_with_payment(UUID, TEXT, NUMERIC, TEXT)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.complete_order_with_payment(UUID, TEXT, NUMERIC, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_order_with_payment(UUID, TEXT, NUMERIC, TEXT)
  TO authenticated;

-- Keep cancellation on the existing RPC; completion must use the payment RPC.
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
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'ADMIN_REQUIRED' USING ERRCODE = '42501';
  END IF;
  IF p_new_status IS DISTINCT FROM 'cancelled' THEN
    RAISE EXCEPTION 'COMPLETION_REQUIRES_PAYMENT';
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

  UPDATE public.orders SET status = 'cancelled' WHERE id = target_order.id;

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

  RETURN jsonb_build_object(
    'order_id', target_order.id,
    'order_code', target_order.order_code,
    'status', 'cancelled'
  );
END;
$$;

ALTER FUNCTION public.update_order_status(UUID, TEXT) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.update_order_status(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_order_status(UUID, TEXT)
  TO authenticated;

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
        AND o.status = 'completed'
        AND o.payment_status = 'paid'
    ),
    (
      SELECT COALESCE(SUM(oi.quantity), 0)::BIGINT
      FROM public.order_items AS oi
      JOIN public.orders AS o ON o.id = oi.order_id
      JOIN public.profiles AS p ON p.id = o.user_id AND p.role <> 'admin'
      WHERE o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
        AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
        AND o.status = 'completed'
        AND o.payment_status = 'paid'
    ),
    (
      SELECT COALESCE(SUM(o.total), 0)::NUMERIC
      FROM public.orders AS o
      JOIN public.profiles AS p ON p.id = o.user_id AND p.role <> 'admin'
      WHERE o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
        AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
        AND o.status = 'completed'
        AND o.payment_status = 'paid'
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
    AND o.status = 'completed'
    AND o.payment_status = 'paid'
  GROUP BY oi.deal_name, oi.deal_category
  ORDER BY SUM(oi.quantity) DESC, oi.deal_name;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_payment_method_sales(
  p_from_ts TIMESTAMPTZ,
  p_to_ts TIMESTAMPTZ
)
RETURNS TABLE (
  payment_method TEXT,
  paid_orders BIGINT,
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
  WITH methods(payment_method) AS (
    VALUES ('cash'::TEXT), ('gcash'), ('maya'), ('card')
  )
  SELECT
    methods.payment_method,
    COUNT(o.id)::BIGINT,
    COALESCE(SUM(o.total), 0)::NUMERIC
  FROM methods
  LEFT JOIN public.orders AS o
    ON o.payment_method = methods.payment_method
   AND o.status = 'completed'
   AND o.payment_status = 'paid'
   AND o.created_at >= COALESCE(p_from_ts, '-infinity'::TIMESTAMPTZ)
   AND o.created_at <= COALESCE(p_to_ts, 'infinity'::TIMESTAMPTZ)
   AND EXISTS (
     SELECT 1 FROM public.profiles AS p
     WHERE p.id = o.user_id AND p.role <> 'admin'
   )
  GROUP BY methods.payment_method
  ORDER BY CASE methods.payment_method
    WHEN 'cash' THEN 1
    WHEN 'gcash' THEN 2
    WHEN 'maya' THEN 3
    ELSE 4
  END;
END;
$$;

ALTER FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ)
  OWNER TO postgres;
ALTER FUNCTION public.get_deal_sales(TIMESTAMPTZ, TIMESTAMPTZ)
  OWNER TO postgres;
ALTER FUNCTION public.get_payment_method_sales(TIMESTAMPTZ, TIMESTAMPTZ)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_deal_sales(TIMESTAMPTZ, TIMESTAMPTZ)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_payment_method_sales(TIMESTAMPTZ, TIMESTAMPTZ)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_deal_sales(TIMESTAMPTZ, TIMESTAMPTZ)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_payment_method_sales(TIMESTAMPTZ, TIMESTAMPTZ)
  TO authenticated;

COMMIT;
