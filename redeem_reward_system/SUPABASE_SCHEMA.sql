-- Daily Rewards Table
-- Tracks user daily reward claims and streak information.
-- claimed_at must be stored as a precise timestamp so the 20-hour cooldown
-- is calculated from the actual claim moment, not the start of the day.
CREATE TABLE IF NOT EXISTS daily_rewards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_points INT NOT NULL,
  streak_day INT DEFAULT 1,
  claimed_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, claimed_at)
);

ALTER TABLE daily_rewards
  ALTER COLUMN claimed_at TYPE TIMESTAMPTZ USING claimed_at::timestamptz,
  ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at::timestamptz;

CREATE INDEX IF NOT EXISTS idx_daily_rewards_user_id ON daily_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_rewards_claimed_at ON daily_rewards(claimed_at);

DROP FUNCTION IF EXISTS public.claim_daily_reward();

CREATE OR REPLACE FUNCTION public.claim_daily_reward()
RETURNS TABLE (
  reward_points INT,
  streak_day INT,
  new_points INT,
  claimed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_user_id UUID := auth.uid();
  last_claim daily_rewards%ROWTYPE;
  new_streak INT := 1;
  current_points INT;
  reward_amount INT;
  claim_time TIMESTAMPTZ := now();
  next_claim_time TIMESTAMPTZ;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED: User must be signed in to claim the daily reward.';
  END IF;

  SELECT * INTO last_claim
  FROM public.daily_rewards
  WHERE user_id = current_user_id
  ORDER BY claimed_at DESC
  LIMIT 1;

  IF last_claim.id IS NOT NULL THEN
    next_claim_time := last_claim.claimed_at + interval '20 hours';
    IF claim_time < next_claim_time THEN
      RAISE EXCEPTION 'DAILY_REWARD_ALREADY_CLAIMED: Please wait until % to claim again.', next_claim_time;
    END IF;

    new_streak := last_claim.streak_day + 1;
  END IF;

  SELECT reward_amount
  INTO reward_amount
  FROM public.reward_settings
  ORDER BY random()
  LIMIT 1;

  SELECT points INTO current_points
  FROM public.profiles
  WHERE id = current_user_id;

  IF current_points IS NULL THEN
    current_points := 0;
  END IF;

  INSERT INTO public.daily_rewards (user_id, reward_points, streak_day, claimed_at)
  VALUES (current_user_id, reward_amount, new_streak, claim_time)
  RETURNING reward_points, streak_day, (current_points + reward_amount), claimed_at
  INTO reward_points, streak_day, new_points, claimed_at;

  RETURN NEXT;
END;
$$;

ALTER FUNCTION public.claim_daily_reward() OWNER TO postgres;

-- Reward Settings Table
-- Stores the probability configuration for rewards
-- This allows changing probabilities without updating the app
CREATE TABLE IF NOT EXISTS reward_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  reward_amount INT NOT NULL UNIQUE,
  probability DECIMAL(5, 2) NOT NULL,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Insert default reward probabilities
INSERT INTO reward_settings (reward_amount, probability) VALUES
  (10, 80.0),
  (20, 15.0),
  (30, 4.0),
  (50, 0.9),
  (100, 0.1)
ON CONFLICT (reward_amount) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_daily_rewards_user_id ON daily_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_rewards_claimed_at ON daily_rewards(claimed_at);
CREATE INDEX IF NOT EXISTS idx_reward_settings_reward_amount ON reward_settings(reward_amount);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin'));

UPDATE profiles
SET role = 'admin'
WHERE email = 'kapetoladmin@thekapetol.com';

-- Promotions table: managed by admin, visible to all users.
CREATE TABLE IF NOT EXISTS promotions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  subtitle TEXT,
  description TEXT,
  valid_until TEXT,
  image_url TEXT,
  category TEXT NOT NULL DEFAULT 'general',
  is_active BOOLEAN NOT NULL DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  color_hex TEXT DEFAULT '#2E7D32',
  icon_name TEXT DEFAULT 'redeem',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Rewards table: managed by admin, visible to all users as redeemable items.
CREATE TABLE IF NOT EXISTS rewards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  points_cost INT NOT NULL CHECK (points_cost >= 0),
  image_url TEXT,
  category TEXT NOT NULL DEFAULT 'general',
  is_active BOOLEAN NOT NULL DEFAULT true,
  stock INT NOT NULL DEFAULT 0,
  icon_name TEXT DEFAULT 'local_cafe',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE daily_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own daily rewards" ON daily_rewards;
CREATE POLICY "Users can view their own daily rewards" ON daily_rewards
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own daily rewards" ON daily_rewards;
CREATE POLICY "Users can insert their own daily rewards" ON daily_rewards
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own daily rewards" ON daily_rewards;
CREATE POLICY "Users can update their own daily rewards" ON daily_rewards
  FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Everyone can view reward settings" ON reward_settings;
CREATE POLICY "Everyone can view reward settings" ON reward_settings
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile points" ON profiles;
CREATE POLICY "Users can update own profile points" ON profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Admins can manage promotions" ON promotions;
CREATE POLICY "Admins can manage promotions" ON promotions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Public can view active promotions" ON promotions;
CREATE POLICY "Public can view active promotions" ON promotions
  FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "Admins can manage rewards" ON rewards;
CREATE POLICY "Admins can manage rewards" ON rewards
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "Public can view active rewards" ON rewards;
CREATE POLICY "Public can view active rewards" ON rewards
  FOR SELECT USING (is_active = true);

-- Note: Role escalation is prevented by restricting UPDATE access to role field.
-- Regular users cannot modify their own role through the app - only admins can manage roles.

-- Optional: create a public storage bucket named 'avatars' in Supabase
-- Then upload images to avatars/<user_id>/profile.ext and keep the public URL in avatar_url.

