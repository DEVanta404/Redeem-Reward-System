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

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_daily_rewards_user_id ON daily_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_rewards_claimed_at ON daily_rewards(claimed_at);
CREATE INDEX IF NOT EXISTS idx_reward_settings_reward_amount ON reward_settings(reward_amount);

-- Enable Row Level Security
ALTER TABLE daily_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE reward_settings ENABLE ROW LEVEL SECURITY;

-- Daily Rewards RLS Policy: Users can only see their own records
DROP POLICY IF EXISTS "Users can view their own daily rewards" ON daily_rewards;
CREATE POLICY "Users can view their own daily rewards" ON daily_rewards
  FOR SELECT USING (auth.uid() = user_id);

-- Daily Rewards RLS Policy: Users can insert their own records
DROP POLICY IF EXISTS "Users can insert their own daily rewards" ON daily_rewards;
CREATE POLICY "Users can insert their own daily rewards" ON daily_rewards
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Daily Rewards RLS Policy: Users can update their own records
DROP POLICY IF EXISTS "Users can update their own daily rewards" ON daily_rewards;
CREATE POLICY "Users can update their own daily rewards" ON daily_rewards
  FOR UPDATE USING (auth.uid() = user_id);

-- Reward Settings RLS Policy: Everyone can view reward settings (public)
DROP POLICY IF EXISTS "Everyone can view reward settings" ON reward_settings;
CREATE POLICY "Everyone can view reward settings" ON reward_settings
  FOR SELECT USING (true);

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Profiles table RLS (make sure points can be updated)
-- Only the user themselves can update their points
DROP POLICY IF EXISTS "Users can update own profile points" ON profiles;
CREATE POLICY "Users can update own profile points" ON profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Profiles table RLS: Users can view their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Optional: create a public storage bucket named 'avatars' in Supabase
-- Then upload images to avatars/<user_id>/profile.ext and keep the public URL in avatar_url.

