# Daily Reward System - Implementation Guide

## Overview
This document guides you through setting up the complete daily reward system with streak tracking, lucky day bonuses, and slot machine animation.

## Files Created/Modified

### New Files
1. **lib/services/daily_rewards_service.dart** - Core service for reward logic
2. **lib/screens/daily_reward_slot_screen.dart** - Slot machine animation screen
3. **SUPABASE_SCHEMA.sql** - Database schema SQL (run in Supabase console)

### Modified Files
1. **lib/app_state.dart** - Added DailyRewardData, DailyRewardStreak, RewardSetting models
2. **lib/screens/home_screen.dart** - Added daily reward card and claim logic (now StatefulWidget)

## Setup Steps

### Step 1: Create Database Tables in Supabase

1. Open your Supabase project: https://app.supabase.com
2. Navigate to SQL Editor
3. Create a new query
4. Copy and paste the contents of `SUPABASE_SCHEMA.sql`
5. Click "Run" to execute

This creates two tables:
- **daily_rewards** - Tracks user reward claims and streak days
- **reward_settings** - Stores reward probability configuration

### Step 2: Verify Reward Probabilities

In Supabase, go to:
SQL Editor → Browse "reward_settings" table

You should see:
```
reward_amount | probability
10            | 80.0
20            | 15.0
30            | 4.0
50            | 0.9
100           | 0.1
```

You can edit these probabilities directly in the table without rebuilding the app!

### Step 3: Build and Run

```bash
flutter pub get
flutter run
```

## Features Implemented

### 🎁 Daily Reward Card
- New card added to home screen below quick cards
- Shows current streak with star ratings
- Displays time until next reward claim
- Beautiful gradient styling with green color (or gold on lucky days)

### 🎰 Slot Machine Animation
When user clicks "CLAIM REWARD":
1. Navigates to new slot screen
2. Shows 2-second rolling animation with 3 reels
3. Displays result with confetti animation
4. Shows reward amount with special styling on lucky days
5. "Collect" button adds points to user's account

### 🔥 Streak System
- Tracks consecutive daily claims
- Day 1-2: 10 pt bonus
- Day 3-4: 15 pt bonus  
- Day 5-6: 20 pt bonus
- Day 7: 50 pt bonus + Lucky Day special event
- Missing one day resets streak
- Displayed as ⭐☆☆☆☆☆☆ format

### 🌟 Lucky Day (7th Day)
- Every 7th consecutive day gets special rewards
- Special golden gradient on card
- Higher point rewards
- Can hit 20, 50, 100, or 100 points (weighted)

### 🎲 Weighted Random Rewards
- Uses probability-based weighted selection
- Ensures exact percentages (not truly random)
- Default: 10pts(80%), 20pts(15%), 30pts(4%), 50pts(0.9%), 100pts(0.1%)
- Easily adjustable via reward_settings table

### ✔️ Prevent Double-Claiming
- Checks if user already claimed today
- Button shows "✔ Already Claimed" after claiming
- Countdown timer shows time until next reward
- Updates in real-time

## Database Schema

### daily_rewards table
```
id (UUID) - Primary key
user_id (UUID) - Foreign key to auth.users
reward_points (INT) - Points earned
streak_day (INT) - Which day of streak (1-7)
claimed_at (DATE) - Date of claim
created_at (TIMESTAMP) - Record creation time
```

### reward_settings table
```
id (UUID) - Primary key
reward_amount (INT) - Points value
probability (DECIMAL) - Probability percentage
created_at (TIMESTAMP) - Record creation time
updated_at (TIMESTAMP) - Last update time
```

## Code Architecture

### DailyRewardsService Methods

**getRewardSettings()** 
- Fetches probability config from database
- Returns List<RewardSetting>

**getTodaysClaim(userId)**
- Checks if user claimed today
- Returns DailyRewardData or null

**getLastClaim(userId)**
- Gets most recent claim record
- Used for streak calculation

**calculateStreak(userId)**
- Computes current streak status
- Returns DailyRewardStreak with streak day and can-claim status

**generateReward(isLuckyDay)**
- Creates weighted random reward
- Returns points value (10, 20, 30, 50, or 100)

**claimDailyReward(userId, rewardPoints, streakDay)**
- Records claim in database
- Updates user's points in profiles table
- Returns DailyRewardData

**getTimeUntilNextReward()**
- Returns Duration until next claim available
- Updates every second on home screen

**formatTimeRemaining(Duration)**
- Formats as HH:MM:SS string
- Shown in reward card countdown

## UI Components

### _buildDailyRewardCard()
Main reward card displayed on home screen with:
- Title and description
- Streak indicator (⭐☆☆☆☆☆☆)
- Time remaining or "Claim now!"
- Beautiful colored button

### DailyRewardSlotScreen
New full-screen modal showing:
- 3 animated reels rolling for 2 seconds
- Result display with large point amount
- Confetti celebration animation
- "Collect" button to confirm and return

## Customization

### Change Reward Probabilities
Edit SUPABASE_SCHEMA.sql INSERT values or edit reward_settings table directly in Supabase

### Adjust Colors
- Lucky day gradient: Line 300 in home_screen.dart
- Normal day gradient: Green colors
- Button colors: Lines in _buildDailyRewardCard()

### Modify Animations
- Slot duration: Line 19 in daily_reward_slot_screen.dart
- Celebration duration: Line 27
- Animation curves: Lines 100-120

### Change Streak Bonuses
Edit `_getStreakBonus()` method in daily_rewards_service.dart (line 188)

## Testing

### Test Streaks
1. Claim reward on Day 1 - should show "Day 1"
2. Next day: should show "Day 2" 
3. Skip a day: should reset to "Start your streak!"

### Test Lucky Day
1. Claim rewards for 7 consecutive days
2. 7th day should show ✨ LUCKY DAY ✨ 
3. Card should have golden gradient
4. Rewards should be higher

### Test Probabilities
Claim 100 times and track distribution:
- 10 pts: ~80 times
- 20 pts: ~15 times
- 30 pts: ~4 times
- 50 pts: ~0-1 times
- 100 pts: ~0-1 times

## Troubleshooting

### "Error claiming reward"
- Check user ID is set (not empty)
- Verify database tables exist in Supabase
- Check Supabase credentials in main.dart

### Countdown timer doesn't update
- Timer should start in initState
- Make sure dispose() cancels timer
- Check setState() is being called

### Slot animation doesn't play
- Verify daily_reward_slot_screen.dart is imported
- Check Navigator.push is working
- Ensure AnimationController is initialized

### Button stays disabled after claiming
- Reload the home screen to refresh state
- Check _loadDailyRewardState() completes
- Verify Supabase record was inserted

## Points Calculation

When reward is claimed:
1. Generate random reward (10-100 pts)
2. Add to database daily_rewards table
3. Fetch current points from profiles table
4. Calculate: newPoints = currentPoints + rewardPoints
5. Update profiles table with newPoints
6. Update AppState.points immediately
7. Show animation with result

## Security Notes

- Daily rewards uses user_id from auth session
- Database constraints prevent duplicate claims same day
- Points only updated after reward recorded
- No client-side validation required (DB handles it)

## Future Enhancements

- Wheel spinner animation instead of slots
- Sound effects on claim
- Share streak achievement
- Streak badges/milestones
- Bonus multiplier days
- Energy system
- Daily challenges

## Support

For issues or questions:
1. Check Supabase console for database errors
2. Review debug logs in Flutter console
3. Verify all imports are correct
4. Ensure user is authenticated before claiming
