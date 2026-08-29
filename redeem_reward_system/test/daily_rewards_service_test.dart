import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/services/daily_rewards_service.dart';

void main() {
  test('uses the actual claim timestamp for a 20-hour cooldown', () {
    final claimTime = DateTime(2026, 8, 29, 20, 30, 0);
    final now = DateTime(2026, 8, 29, 21, 0, 0);

    final remaining = DailyRewardsService.getCooldownRemainingForClaim(
      claimTime: claimTime,
      now: now,
    );

    expect(remaining, const Duration(hours: 19, minutes: 30));
  });

  test('treats a claim that has expired as ready to claim again', () {
    final claimTime = DateTime(2026, 8, 29, 20, 30, 0);
    final now = DateTime(2026, 8, 30, 17, 0, 0);

    final remaining = DailyRewardsService.getCooldownRemainingForClaim(
      claimTime: claimTime,
      now: now,
    );

    expect(remaining, Duration.zero);
  });
}
