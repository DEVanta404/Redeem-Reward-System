import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/app_state.dart';
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

  test('RewardItem saves and reloads icon names instead of code points', () {
    final reward = RewardItem(
      name: 'Coffee reward',
      pointsCost: 120,
      icon: Icons.coffee,
    );

    final payload = reward.toMap();

    expect(payload['icon_name'], 'coffee');
    expect(RewardItem.fromMap(payload).icon, Icons.coffee);
  });

  test('Promotion saves and reloads icon names instead of code points', () {
    final promotion = Promotion(
      title: 'Morning perk',
      subtitle: 'Free coffee',
      validUntil: '2026-09-30',
      color: Colors.orange,
      icon: Icons.local_cafe,
    );

    final payload = promotion.toMap();

    expect(payload['icon_name'], 'local_cafe');
    expect(Promotion.fromMap(payload).icon, Icons.local_cafe);
  });
}
