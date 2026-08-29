import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import 'dart:math';

class DailyRewardsService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get the current reward settings from the database
  /// Returns list of RewardSetting objects with probabilities
  static final List<RewardSetting> _defaultRewardSettings = [
    RewardSetting(rewardAmount: 10, probability: 80.0),
    RewardSetting(rewardAmount: 20, probability: 15.0),
    RewardSetting(rewardAmount: 30, probability: 4.0),
    RewardSetting(rewardAmount: 50, probability: 0.9),
    RewardSetting(rewardAmount: 100, probability: 0.1),
  ];

  Future<List<RewardSetting>> getRewardSettings() async {
    try {
      debugPrint("========== getRewardSettings ==========");
      final response = await _client
          .from('reward_settings')
          .select()
          .order('reward_amount', ascending: true);

      debugPrint("Reward settings response: $response");
      final settings = (response as List)
          .map((setting) => RewardSetting.fromMap(setting))
          .toList();

      if (settings.isEmpty) {
        return _defaultRewardSettings;
      }

      return settings;
    } catch (error, stackTrace) {
      debugPrint('Error fetching reward settings: $error');
      debugPrint(stackTrace.toString());
      return _defaultRewardSettings;
    }
  }

  /// Check if the user's most recent claim is still within a 20-hour cooldown window.
  Future<DailyRewardData?> getTodaysClaim(String userId) async {
    try {
      debugPrint("========== getTodaysClaim ==========");
      debugPrint("userId: $userId");

      final lastClaim = await getLastClaim(userId);
      if (lastClaim == null) {
        return null;
      }

      final nextClaimTime = lastClaim.claimedAt.add(const Duration(hours: 20));
      if (nextClaimTime.isAfter(DateTime.now())) {
        return lastClaim;
      }

      return null;
    } catch (error, stackTrace) {
      debugPrint('Error checking today\'s claim: $error');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Get the latest claim record from Supabase. This is the authoritative timestamp source.
  Future<DailyRewardData?> getLastClaim(String userId) async {
    try {
      debugPrint("========== getLastClaim ==========");
      debugPrint("userId: $userId");

      final response = await _client
          .from('daily_rewards')
          .select()
          .eq('user_id', userId)
          .order('claimed_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        debugPrint("Last claim found: $response");
        return DailyRewardData.fromMap(response);
      }
      return null;
    } catch (error, stackTrace) {
      debugPrint('Error fetching last claim: $error');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Calculate the current streak for a user
  /// Returns the streak day (1-7 repeating) and whether streak is active
  Future<DailyRewardStreak> calculateStreak(String userId) async {
    try {
      debugPrint("========== calculateStreak ==========");

      final lastClaim = await getLastClaim(userId);
      if (lastClaim == null) {
        return const DailyRewardStreak(
          currentStreak: 0,
          lastClaimDate: null,
          canClaimToday: true,
          nextStreakBonus: 10,
        );
      }

      final today = DateTime.now();
      final lastClaimDate = lastClaim.claimedAt;
      final daysSinceLastClaim = today.difference(lastClaimDate).inDays;

      debugPrint("Last claim date: $lastClaimDate");
      debugPrint("Today: $today");
      debugPrint("Days since last claim: $daysSinceLastClaim");

      // If claimed today, streak continues
      if (daysSinceLastClaim == 0) {
        return DailyRewardStreak(
          currentStreak: lastClaim.streakDay,
          lastClaimDate: lastClaimDate,
          canClaimToday: false,
          nextStreakBonus: _getStreakBonus(lastClaim.streakDay),
        );
      }

      // If missed yesterday, streak resets
      if (daysSinceLastClaim >= 2) {
        return const DailyRewardStreak(
          currentStreak: 0,
          lastClaimDate: null,
          canClaimToday: true,
          nextStreakBonus: 10,
        );
      }

      // Missed one day, streak continues tomorrow (can claim today)
      return DailyRewardStreak(
        currentStreak: lastClaim.streakDay,
        lastClaimDate: lastClaimDate,
        canClaimToday: true,
        nextStreakBonus: _getStreakBonus(lastClaim.streakDay),
      );
    } catch (error, stackTrace) {
      debugPrint('Error calculating streak: $error');
      debugPrint(stackTrace.toString());
      return const DailyRewardStreak(
        currentStreak: 0,
        lastClaimDate: null,
        canClaimToday: true,
        nextStreakBonus: 10,
      );
    }
  }

  /// Generate a weighted random reward based on probabilities
  Future<int> generateReward({bool isLuckyDay = false}) async {
    try {
      debugPrint("========== generateReward ==========");
      debugPrint("isLuckyDay: $isLuckyDay");

      if (isLuckyDay) {
        // On lucky day, give special rewards
        final luckyRewards = [20, 50, 100, 100]; // Extra 100 for 7th day
        return luckyRewards[Random().nextInt(luckyRewards.length)];
      }

      final settings = await getRewardSettings();
      if (settings.isEmpty) {
        return 10;
      }

      debugPrint(
        "Reward settings: ${settings.map((s) => '${s.rewardAmount}pts:${s.probability}%').join(', ')}",
      );

      final random = Random();
      final roll = random.nextDouble() * 100;

      debugPrint("Random roll: $roll");

      double cumulative = 0;
      for (final setting in settings) {
        cumulative += setting.probability;
        if (roll < cumulative) {
          debugPrint("Selected reward: ${setting.rewardAmount}");
          return setting.rewardAmount;
        }
      }

      return settings.last.rewardAmount;
    } catch (error, stackTrace) {
      debugPrint('Error generating reward: $error');
      debugPrint(stackTrace.toString());
      return 10; // Default to 10 points on error
    }
  }

  Future<Map<String, dynamic>?> claimDailyReward() async {
    try {
      debugPrint('========== claimDailyReward ==========');
      final user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found.');
        return null;
      }
      debugPrint('Authenticated user ID: ${user.id}');

      final response = await _client.rpc('claim_daily_reward');
      debugPrint('RPC response: $response');

      if (response is Map<String, dynamic>) {
        return response;
      }
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      debugPrint('Unexpected RPC response: $response');
      return null;
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('========== DAILY REWARD RPC ERROR ==========');
      debugPrint('Code: ${error.code}');
      debugPrint('Message: ${error.message}');
      debugPrint('Details: ${error.details}');
      debugPrint('Hint: ${error.hint}');
      debugPrint(stackTrace.toString());
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Error claiming daily reward: $error');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  Future<int?> getCurrentPoints(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('points')
          .eq('id', userId)
          .single();
      return response['points'] as int?;
    } catch (error, stackTrace) {
      debugPrint('Error fetching current points: $error');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  /// Returns the remaining time until the next claim becomes available.
  /// The cooldown is always anchored to the actual timestamp of the last claim.
  static Duration getCooldownRemainingForClaim({
    required DateTime claimTime,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final nextClaimTime = claimTime.add(const Duration(hours: 20));
    final remaining = nextClaimTime.difference(currentTime);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get the remaining time until the next reward is available.
  /// If a claim timestamp is provided, the timer is based on that actual claim time.
  /// Otherwise, it uses a default 20-hour window for a first-time reward check.
  Duration getTimeUntilNextReward({DateTime? lastClaimAt}) {
    final anchor = lastClaimAt ?? DateTime.now();
    return getCooldownRemainingForClaim(claimTime: anchor, now: DateTime.now());
  }

  /// Format duration as HH:MM:SS
  String formatTimeRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Private helper to get streak bonus
  int _getStreakBonus(int streakDay) {
    if (streakDay < 3) return 10;
    if (streakDay < 5) return 15;
    if (streakDay < 7) return 20;
    return 50; // 7th day lucky day bonus
  }
}
