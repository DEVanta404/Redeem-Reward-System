# 🎁 Daily Reward System - Quick Start

## ✅ What's Been Implemented

All Flutter code is complete! Here's what you get:

1. **Daily Reward Card** on home screen with:
   - 🔥 Streak tracking (Days 1-7)
   - ⏱️ Real-time countdown to next reward
   - ⭐ Star rating system for streak progress
   - 🎰 Beautiful animated claim button

2. **Slot Machine Animation Screen** that shows:
   - 🎰 2-second rolling animation
   - 🎉 Celebration with confetti
   - ⭐ Large reward display
   - 💰 Points added instantly

3. **Smart Reward System**:
   - 📊 Weighted random rewards (10, 20, 30, 50, 100 pts)
   - 🌟 Lucky day bonus on day 7
   - 🚫 Prevents double-claiming
   - 📈 Automatic streak tracking

4. **Database Integration**:
   - Tracks all reward claims
   - Stores streak information
   - Configurable probabilities

## 🚀 Next Step (Only 1 Thing!!)

Copy and run this SQL in your Supabase SQL Editor:

```sql
-- Daily Rewards Table
CREATE TABLE IF NOT EXISTS daily_rewards (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_points INT NOT NULL,
  streak_day INT DEFAULT 1,
  claimed_at DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(user_id, claimed_at)
);

-- Reward Settings Table
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

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_daily_rewards_user_id ON daily_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_daily_rewards_claimed_at ON daily_rewards(claimed_at);
CREATE INDEX IF NOT EXISTS idx_reward_settings_reward_amount ON reward_settings(reward_amount);
```

Then:
```bash
flutter run
```

## 📁 Files Created

- `lib/services/daily_rewards_service.dart` - Core logic
- `lib/screens/daily_reward_slot_screen.dart` - Animation screen
- `lib/app_state.dart` - Updated models (DailyRewardData, DailyRewardStreak, RewardSetting)
- `lib/screens/home_screen.dart` - Updated with daily reward card
- `SUPABASE_SCHEMA.sql` - SQL schema
- `DAILY_REWARDS_SETUP.md` - Full documentation

## 🎮 How It Works

**User presses "CLAIM REWARD":**
1. ✅ Check if already claimed today
2. 🎲 Generate weighted random reward (10-100 pts)
3. 🎰 Show slot animation for 2 seconds
4. 🎉 Display result with confetti
5. 💾 Save to database and update points
6. 🔄 Reload streak info

**Streak Logic:**
- Day 1-2: 10 pt bonus
- Day 3-4: 15 pt bonus
- Day 5-6: 20 pt bonus
- Day 7: 50 pt + Lucky Day special
- Miss a day: Resets to Day 1

## 🎨 UI Features

- Beautiful green card (gold on lucky day)
- Real-time countdown timer
- Star progress indicator (⭐☆☆☆☆☆☆)
- Responsive buttons with emoji
- Smooth animations
- Mobile-first design

## 🔧 Customization

**Change reward probabilities:**
Edit `reward_settings` table in Supabase:
- Higher 100 pts? → Increase probability
- More common rewards? → Adjust percentages

**Change colors:**
Edit `_buildDailyRewardCard()` in `lib/screens/home_screen.dart`

**Adjust animations:**
Edit durations in `daily_reward_slot_screen.dart`

## 🧪 Testing Checklist

- [ ] Run SQL schema (only 1 required step)
- [ ] `flutter run` starts without errors
- [ ] Daily reward card appears below promotions
- [ ] Click "CLAIM REWARD" shows slot animation
- [ ] After 2 seconds, result appears with points
- [ ] "Collect" button closes animation and updates points
- [ ] Day 2: streak shows "Day 2"
- [ ] Day 7: golden background appears
- [ ] Day 8: resets to "Day 1"

## 📊 Default Probabilities

| Reward | Chance | Avg per 100 claims |
|--------|--------|-------------------|
| 10 pts | 80%    | 800 pts           |
| 20 pts | 15%    | 300 pts           |
| 30 pts | 4%     | 120 pts           |
| 50 pts | 0.9%   | 45 pts            |
| 100 pts| 0.1%   | 10 pts            |
|        | Total  | **1,275 pts**     |

Average: ~12.75 pts per claim!

## 🐛 If Something Breaks

1. Check Supabase tables exist: `daily_rewards` and `reward_settings`
2. Verify user is logged in (user.id not empty)
3. Check Supabase credentials in `main.dart`
4. Review Flutter console for error messages
5. Re-run: `flutter clean && flutter pub get && flutter run`

## 💡 Pro Tips

- Users can't claim twice same day (database enforces it)
- Probabilities can change anytime in Supabase
- No app rebuild needed to change rewards
- All streaks stored permanently
- Perfect for retention (Duolingo-style addiction)

---

**That's it!** Just run the SQL and start your app. The daily reward system is ready! 🎉
