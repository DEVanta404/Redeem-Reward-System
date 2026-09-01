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
  String role;

  UserProfile({
    this.id = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.birthday,
    this.avatarPath = '',
    this.avatarUrl = '',
    this.role = 'user',
  });

  bool get isAdmin => role == 'admin';

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? birthday,
    String? avatarPath,
    String? avatarUrl,
    String? role,
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    birthday: birthday ?? this.birthday,
    avatarPath: avatarPath ?? this.avatarPath,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    role: role ?? this.role,
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
  final String id;
  final String name;
  final int pointsCost;
  final IconData icon;
  final String description;
  final String imageUrl;
  final String category;
  final bool isActive;
  final int stock;

  const RewardItem({
    this.id = '',
    required this.name,
    required this.pointsCost,
    this.icon = Icons.local_cafe,
    this.description = '',
    this.imageUrl = '',
    this.category = 'general',
    this.isActive = true,
    this.stock = 0,
  });

  factory RewardItem.fromMap(Map<String, dynamic> map) {
    final iconName = (map['icon_name'] ?? map['icon'] ?? 'local_cafe').toString();
    final icon = iconFromName(iconName);

    return RewardItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Reward',
      pointsCost: int.tryParse(map['points_cost']?.toString() ?? map['pointsCost']?.toString() ?? '0') ?? 0,
      icon: icon,
      description: map['description']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      isActive: map['is_active'] == true || map['isActive'] == true,
      stock: int.tryParse(map['stock']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'points_cost': pointsCost,
    'description': description,
    'image_url': imageUrl,
    'category': category,
    'is_active': isActive,
    'stock': stock,
    'icon_name': iconName(icon),
  };

  static String iconName(IconData icon) {
    if (icon == Icons.redeem) return 'redeem';
    if (icon == Icons.local_offer) return 'local_offer';
    if (icon == Icons.star) return 'star';
    if (icon == Icons.cake) return 'cake';
    if (icon == Icons.access_time) return 'access_time';
    if (icon == Icons.coffee) return 'coffee';
    if (icon == Icons.local_cafe) return 'local_cafe';
    if (icon == Icons.bakery_dining) return 'bakery_dining';
    if (icon == Icons.local_bar) return 'local_bar';
    if (icon == Icons.stars) return 'stars';
    return 'local_cafe';
  }

  static IconData iconFromName(String value) {
    final normalized = value.trim();
    final legacyCode = int.tryParse(normalized);
    if (legacyCode != null) {
      return _iconFromLegacyCodePoint(legacyCode);
    }

    switch (normalized.toLowerCase()) {
      case 'redeem':
        return Icons.redeem;
      case 'local_offer':
        return Icons.local_offer;
      case 'star':
        return Icons.star;
      case 'cake':
        return Icons.cake;
      case 'access_time':
        return Icons.access_time;
      case 'coffee':
        return Icons.coffee;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'local_bar':
        return Icons.local_bar;
      case 'stars':
        return Icons.stars;
      default:
        return Icons.local_cafe;
    }
  }

  static IconData _iconFromLegacyCodePoint(int codePoint) {
    switch (codePoint) {
      case 0xe8b5:
        return Icons.redeem;
      case 0xe87e:
        return Icons.local_offer;
      case 0xe838:
        return Icons.star;
      case 0xe7e9:
        return Icons.cake;
      case 0xe425:
        return Icons.access_time;
      case 0xe61d:
        return Icons.coffee;
      case 0xeb44:
      case 0xe6a3:
        return Icons.local_cafe;
      case 0xe7f0:
        return Icons.bakery_dining;
      case 0xe3a7:
        return Icons.local_bar;
      case 0xe6a9:
        return Icons.stars;
      default:
        return Icons.local_cafe;
    }
  }
}

class Promotion {
  final String id;
  final String title;
  final String subtitle;
  final String validUntil;
  final Color color;
  final IconData icon;
  final String description;
  final String imageUrl;
  final String category;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool claimedByCurrentUser;

  static const List<IconData> adminIconOptions = [
    Icons.redeem,
    Icons.local_offer,
    Icons.star,
    Icons.cake,
    Icons.access_time,
    Icons.coffee,
    Icons.local_cafe,
    Icons.bakery_dining,
    Icons.local_bar,
    Icons.stars,
  ];

  static String iconLabel(IconData icon) {
    if (icon == Icons.redeem) return 'Gift';
    if (icon == Icons.local_offer) return 'Discount';
    if (icon == Icons.star) return 'Featured';
    if (icon == Icons.cake) return 'Birthday';
    if (icon == Icons.access_time) return 'Limited Time';
    if (icon == Icons.coffee) return 'Coffee';
    if (icon == Icons.local_cafe) return 'Drinks';
    if (icon == Icons.bakery_dining) return 'Celebration';
    if (icon == Icons.local_bar) return 'Special Offer';
    if (icon == Icons.stars) return 'Premium';
    return 'Gift';
  }

  static String formatDateForDisplay(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);
    return '$month/$day/$year';
  }

  static DateTime? parseDateInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split('/');
    if (parts.length != 3) return null;

    int month;
    int day;
    int year;

    try {
      month = int.parse(parts[0]);
      day = int.parse(parts[1]);
      year = int.parse(parts[2]);
    } catch (_) {
      return null;
    }

    if (year < 100) {
      year += year < 50 ? 2000 : 1900;
    }

    try {
      final date = DateTime(year, month, day);
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }

  const Promotion({
    this.id = '',
    required this.title,
    required this.subtitle,
    required this.validUntil,
    required this.color,
    required this.icon,
    this.description = '',
    this.imageUrl = '',
    this.category = 'general',
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.claimedByCurrentUser = false,
  });

  factory Promotion.fromMap(Map<String, dynamic> map) {
    final iconName = (map['icon_name'] ?? map['icon'] ?? 'redeem').toString();
    final colorHex = map['color_hex']?.toString() ?? map['color']?.toString() ?? '#2E7D32';

    return Promotion(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Promotion',
      subtitle: map['subtitle']?.toString() ?? map['description']?.toString() ?? '',
      validUntil: map['valid_until']?.toString() ?? map['ends_at']?.toString() ?? 'Ongoing',
      color: _colorFromHex(colorHex),
      icon: iconFromName(iconName),
      description: map['description']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      isActive: map['is_active'] == true || map['isActive'] == true,
      startDate: map['starts_at'] != null ? DateTime.tryParse(map['starts_at'].toString()) : null,
      endDate: map['ends_at'] != null ? DateTime.tryParse(map['ends_at'].toString()) : null,
      claimedByCurrentUser: map['claimed_by_current_user'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'valid_until': validUntil,
    'image_url': imageUrl,
    'category': category,
    'is_active': isActive,
    'starts_at': startDate?.toUtc().toIso8601String(),
    'ends_at': endDate?.toUtc().toIso8601String(),
    'icon_name': iconName(icon),
    'color_hex': '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
  };

  static String iconName(IconData icon) {
    if (icon == Icons.redeem) return 'redeem';
    if (icon == Icons.local_offer) return 'local_offer';
    if (icon == Icons.star) return 'star';
    if (icon == Icons.cake) return 'cake';
    if (icon == Icons.access_time) return 'access_time';
    if (icon == Icons.coffee) return 'coffee';
    if (icon == Icons.local_cafe) return 'local_cafe';
    if (icon == Icons.bakery_dining) return 'bakery_dining';
    if (icon == Icons.local_bar) return 'local_bar';
    if (icon == Icons.stars) return 'stars';
    return 'redeem';
  }

  static IconData iconFromName(String value) {
    final normalized = value.trim();
    final legacyCode = int.tryParse(normalized);
    if (legacyCode != null) {
      return _iconFromLegacyCodePoint(legacyCode);
    }

    switch (normalized.toLowerCase()) {
      case 'redeem':
        return Icons.redeem;
      case 'local_offer':
        return Icons.local_offer;
      case 'star':
        return Icons.star;
      case 'cake':
        return Icons.cake;
      case 'access_time':
        return Icons.access_time;
      case 'coffee':
        return Icons.coffee;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'local_bar':
        return Icons.local_bar;
      case 'stars':
        return Icons.stars;
      default:
        return Icons.redeem;
    }
  }

  static IconData _iconFromLegacyCodePoint(int codePoint) {
    switch (codePoint) {
      case 0xe8b5:
        return Icons.redeem;
      case 0xe87e:
        return Icons.local_offer;
      case 0xe838:
        return Icons.star;
      case 0xe7e9:
        return Icons.cake;
      case 0xe425:
        return Icons.access_time;
      case 0xe61d:
        return Icons.coffee;
      case 0xeb44:
      case 0xe6a3:
        return Icons.local_cafe;
      case 0xe7f0:
        return Icons.bakery_dining;
      case 0xe3a7:
        return Icons.local_bar;
      case 0xe6a9:
        return Icons.stars;
      default:
        return Icons.redeem;
    }
  }

  static Color _colorFromHex(String value) {
    final hex = value.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF2E7D32);
  }

  /// Check if this promotion has expired based on endDate
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Check if this promotion is currently active and not expired
  bool get isCurrentlyActive => isActive && !isExpired;
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
  List<RewardItem> rewards = const [
    RewardItem(name: 'Free Espresso', pointsCost: 100, icon: Icons.local_cafe),
    RewardItem(name: 'Free Latte', pointsCost: 250, icon: Icons.coffee),
    RewardItem(name: '20% Discount', pointsCost: 400, icon: Icons.local_offer),
    RewardItem(name: 'Free Pastry', pointsCost: 500, icon: Icons.bakery_dining),
    RewardItem(name: 'Free Cold Brew', pointsCost: 700, icon: Icons.local_bar),
  ];
  List<Promotion> promotions = const [
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

  // Daily reward state
  int dailyRewardStreak = 0;
  DateTime? lastDailyRewardDate;
  bool dailyRewardClaimedToday = false;

  bool get isAdmin => user.isAdmin;

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

  List<RewardItem> get defaultRewards => const [
    RewardItem(name: 'Free Espresso', pointsCost: 100, icon: Icons.local_cafe),
    RewardItem(name: 'Free Latte', pointsCost: 250, icon: Icons.coffee),
    RewardItem(name: '20% Discount', pointsCost: 400, icon: Icons.local_offer),
    RewardItem(name: 'Free Pastry', pointsCost: 500, icon: Icons.bakery_dining),
    RewardItem(name: 'Free Cold Brew', pointsCost: 700, icon: Icons.local_bar),
  ];

  List<Promotion> get defaultPromotions => const [
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
    if (rewards.isEmpty) {
      return defaultRewards.firstWhere(
        (r) => r.pointsCost > points,
        orElse: () => defaultRewards.last,
      );
    }

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
