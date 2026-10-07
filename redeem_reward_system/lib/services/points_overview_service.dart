import 'package:supabase_flutter/supabase_flutter.dart';

enum PointsChartPeriod {
  week('Week', 'week'),
  month('Month', 'month');

  final String label;
  final String value;
  const PointsChartPeriod(this.label, this.value);
}

class PointsOverviewBucket {
  final String label;
  final int earned;
  final int redeemed;

  const PointsOverviewBucket({
    required this.label,
    required this.earned,
    required this.redeemed,
  });

  factory PointsOverviewBucket.fromMap(Map<String, dynamic> map) =>
      PointsOverviewBucket(
        label: map['label']?.toString() ?? '',
        earned: _intValue(map['earned']),
        redeemed: _intValue(map['redeemed']),
      );
}

class PointsOverview {
  final int balance;
  final int lifetimeEarned;
  final int totalRedeemed;
  final int earnedThisMonth;
  final int earnedLastMonth;
  final List<PointsOverviewBucket> buckets;

  const PointsOverview({
    required this.balance,
    required this.lifetimeEarned,
    required this.totalRedeemed,
    required this.earnedThisMonth,
    required this.earnedLastMonth,
    required this.buckets,
  });

  bool get hasChartData =>
      buckets.any((bucket) => bucket.earned > 0 || bucket.redeemed > 0);

  factory PointsOverview.fromResponse(Object? response) {
    final row = response is List && response.isNotEmpty
        ? response.first
        : response;
    if (row is! Map) {
      throw const FormatException('The points overview response was invalid.');
    }
    final map = Map<String, dynamic>.from(row);
    final rawBuckets = map['buckets'];
    if (rawBuckets is! List) {
      throw const FormatException('The points overview chart was invalid.');
    }
    return PointsOverview(
      balance: _intValue(map['balance']),
      lifetimeEarned: _intValue(map['lifetime_earned']),
      totalRedeemed: _intValue(map['total_redeemed']),
      earnedThisMonth: _intValue(map['earned_this_month']),
      earnedLastMonth: _intValue(map['earned_last_month']),
      buckets: rawBuckets
          .whereType<Map>()
          .map(
            (bucket) => PointsOverviewBucket.fromMap(
              Map<String, dynamic>.from(bucket),
            ),
          )
          .toList(growable: false),
    );
  }
}

class PointsOverviewService {
  final SupabaseClient _client;

  PointsOverviewService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<PointsOverview> load({
    PointsChartPeriod period = PointsChartPeriod.week,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Sign in to view your points overview.');
    }
    return PointsOverview.fromResponse(
      await _client.rpc(
        'get_points_overview',
        params: {'p_period': period.value},
      ),
    );
  }
}

int _intValue(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;
