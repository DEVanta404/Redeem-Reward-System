import 'package:flutter/material.dart';
import 'services/supabase_profiles.dart';

class UserProfile {
  String id;
  String name;
  String email;
  String phone;
  String birthday;
  String avatarPath;
  String avatarUrl;

  UserProfile({
    this.id = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.birthday,
    this.avatarPath = '',
    this.avatarUrl = '',
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? birthday,
    String? avatarPath,
    String? avatarUrl,
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    birthday: birthday ?? this.birthday,
    avatarPath: avatarPath ?? this.avatarPath,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );
}

class AppTransaction {
  final DateTime date;
  final int points;
  final String description;

  const AppTransaction({
    required this.date,
    required this.points,
    required this.description,
  });
}

class RewardItem {
  final String name;
  final int pointsCost;
  final IconData icon;

  const RewardItem({
    required this.name,
    required this.pointsCost,
    required this.icon,
  });
}

class Promotion {
  final String title;
  final String subtitle;
  final String validUntil;
  final Color color;
  final IconData icon;

  const Promotion({
    required this.title,
    required this.subtitle,
    required this.validUntil,
    required this.color,
    required this.icon,
  });
}

/// Daily Reward Data Model
class DailyRewardData {
  final String id;
  final String userId;
  final int rewardPoints;
  final int streakDay;
  final DateTime claimedAt;
  final DateTime createdAt;

  DailyRewardData({
    required this.id,
    required this.userId,
    required this.rewardPoints,
    required this.streakDay,
    required this.claimedAt,
    required this.createdAt,
  });

  factory DailyRewardData.fromMap(Map<String, dynamic> map) {
    return DailyRewardData(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      rewardPoints: map['reward_points'] ?? 0,
      streakDay: map['streak_day'] ?? 1,
      claimedAt: DateTime.parse(
        (map['claimed_at'] ?? DateTime.now().toUtc().toIso8601String())
            .toString(),
      ),
      createdAt: DateTime.parse(
        (map['created_at'] ?? DateTime.now().toUtc().toIso8601String())
            .toString(),
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'reward_points': rewardPoints,
    'streak_day': streakDay,
    'claimed_at': claimedAt.toUtc().toIso8601String(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

/// Daily Reward Streak Information
class DailyRewardStreak {
  final int currentStreak;
  final DateTime? lastClaimDate;
  final bool canClaimToday;
  final int nextStreakBonus;

  const DailyRewardStreak({
    required this.currentStreak,
    required this.lastClaimDate,
    required this.canClaimToday,
    required this.nextStreakBonus,
  });

  bool get isLuckyDay => currentStreak % 7 == 0;
}

/// Reward setting for probability configuration
class RewardSetting {
  final int rewardAmount;
  final double probability;

  RewardSetting({required this.rewardAmount, required this.probability});

  factory RewardSetting.fromMap(Map<String, dynamic> map) {
    return RewardSetting(
      rewardAmount: map['reward_amount'] ?? 0,
      probability:
          double.tryParse(map['probability']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class AppState {
  UserProfile user = UserProfile(
    id: '',
    name: 'New Customer',
    email: 'newcustomer@email.com',
    phone: '',
    birthday: '',
    avatarPath: '',
    avatarUrl: '',
  );

  int points = 0;
  int pointsEarnedToday = 0;

  // Daily reward state
  int dailyRewardStreak = 0;
  DateTime? lastDailyRewardDate;
  bool dailyRewardClaimedToday = false;

  String get membership {
    if (points >= 1000) return 'Gold';
    if (points >= 500) return 'Silver';
    return 'Bronze';
  }

  bool get isLuckyDay => dailyRewardStreak % 7 == 0;

  int get nextStreakBonus {
    if (dailyRewardStreak < 3) return 10;
    if (dailyRewardStreak < 5) return 15;
    if (dailyRewardStreak < 7) return 20;
    return 50; // Lucky day bonus
  }

  List<AppTransaction> transactions = [];

  final List<RewardItem> rewards = const [
    RewardItem(name: 'Free Espresso', pointsCost: 100, icon: Icons.local_cafe),
    RewardItem(name: 'Free Latte', pointsCost: 250, icon: Icons.coffee),
    RewardItem(name: '20% Discount', pointsCost: 400, icon: Icons.local_offer),
    RewardItem(name: 'Free Pastry', pointsCost: 500, icon: Icons.bakery_dining),
    RewardItem(name: 'Free Cold Brew', pointsCost: 700, icon: Icons.local_bar),
  ];

  final List<Promotion> promotions = const [
    Promotion(
      title: 'Buy 1 Get 1',
      subtitle: 'On all espresso drinks',
      validUntil: 'July 31',
      color: Color(0xFF2E7D32),
      icon: Icons.redeem,
    ),
    Promotion(
      title: 'Happy Hour',
      subtitle: '50% off from 2PM – 4PM',
      validUntil: 'August 15',
      color: Color(0xFFBF360C),
      icon: Icons.access_time,
    ),
    Promotion(
      title: 'Double Points',
      subtitle: 'Earn 2× points on every purchase',
      validUntil: 'July 20',
      color: Color(0xFF1565C0),
      icon: Icons.star,
    ),
    Promotion(
      title: 'Birthday Treat',
      subtitle: 'Free drink on your birthday',
      validUntil: 'Ongoing',
      color: Color(0xFF6A1B9A),
      icon: Icons.cake,
    ),
  ];

  RewardItem get nextReward {
    return rewards.firstWhere(
      (r) => r.pointsCost > points,
      orElse: () => rewards.last,
    );
  }

  Future<void> redeemReward(RewardItem reward) async {
    points -= reward.pointsCost;
    transactions.insert(
      0,
      AppTransaction(
        date: DateTime.now(),
        points: -reward.pointsCost,
        description: 'Redeemed ${reward.name}',
      ),
    );

    // Persist updated points to Supabase if we have a user id.
    if (user.id.isNotEmpty) {
      try {
        await SupabaseProfilesService().updatePoints(
          userId: user.id,
          points: points,
        );

        // Optionally re-fetch profile to ensure local state matches DB.
        final profile = await SupabaseProfilesService().getProfile(user.id);
        if (profile != null) {
          points =
              int.tryParse(
                profile['points']?.toString() ?? points.toString(),
              ) ??
              points;
        }
      } catch (e) {
        debugPrint('Error persisting redeemed points: $e');
      }
    }
  }

  void updateProfile(UserProfile updated) {
    user = updated;
  }
}
