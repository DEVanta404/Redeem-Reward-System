# IMPORTANT: Update Supabase RLS Policies

You need to run the updated SQL schema to fix the Row Level Security (RLS) policies.

## Steps:

1. Go to Supabase Console: https://app.supabase.com
2. Navigate to SQL Editor
3. Delete the old queries (or just create new ones)
4. Copy the ENTIRE content from `SUPABASE_SCHEMA.sql` in this project
5. Run it in Supabase

## What's Fixed:

- ✅ RLS policies for daily_rewards table (users can only see/insert their own)
- ✅ RLS policies for reward_settings (everyone can read)
- ✅ RLS policies for profiles (users can update their own points)
- ✅ Fixed confetti widget layout bug

## After Running SQL:

The app should work perfectly now! The daily reward system will:
- Allow users to insert their daily rewards
- Prevent access to other users' rewards
- Allow reading reward probability settings
- Update user points successfully
