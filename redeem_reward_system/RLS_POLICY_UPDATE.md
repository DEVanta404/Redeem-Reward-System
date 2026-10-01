# Supabase Admin and RLS Migration

Review [SUPABASE_ADMIN_SECURITY_MIGRATION.sql](SUPABASE_ADMIN_SECURITY_MIGRATION.sql) and run it manually in the Supabase SQL Editor. The Flutter app does not execute migrations. Do not rerun the older `SUPABASE_SCHEMA.sql` as an RLS update; it contains permissive client point and daily-reward policies.

The migration does not delete existing rows. It assigns the admin role by matching `auth.users.id`, adds/updates deal pricing, creates `order_items` price snapshots, and replaces RLS policies for the tables used by the app. It also creates default user profiles on Auth sign-up without reading a role from user metadata and adds `deals` and `orders` to Supabase Realtime when the publication exists. Sales totals are computed in admin-only Postgres RPCs; reward claims use the existing `transactions` redemption rows.

Orders created before order-item price snapshots existed cannot have their historical price recovered. The migration preserves their existing order JSON and backfills an unknown unit price as `0.00` rather than substituting today's price.

## Important Before Applying

The current Flutter redemption path still updates `profiles.points` directly. The migration intentionally blocks that client write and includes a `redeem_reward(p_reward_id)` RPC, but the client has not been switched to call it. Update and test redemption before applying this migration to production or reward redemption will fail. Cart checkout calls `place_order(p_items)`, which reads the current server-side deal price and inserts its snapshots. The `get_sales_summary`, `get_deal_sales`, and `get_reward_claims` RPCs explicitly reject non-admin callers.

The migration is not applied automatically. Back up the project database and review the SQL before running it. Never put a Supabase service-role key in the Flutter app.
