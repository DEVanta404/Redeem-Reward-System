import 'package:supabase_flutter/supabase_flutter.dart';

enum SalesPeriod { today, last7Days, last30Days, allTime }

extension SalesPeriodLabel on SalesPeriod {
  String get label => switch (this) {
    SalesPeriod.today => 'Today',
    SalesPeriod.last7Days => 'Last 7 days',
    SalesPeriod.last30Days => 'Last 30 days',
    SalesPeriod.allTime => 'All time',
  };

  DateTime? get from {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      SalesPeriod.today => today.toUtc(),
      SalesPeriod.last7Days => today.subtract(const Duration(days: 6)).toUtc(),
      SalesPeriod.last30Days =>
        today.subtract(const Duration(days: 29)).toUtc(),
      SalesPeriod.allTime => null,
    };
  }

  DateTime? get to =>
      this == SalesPeriod.allTime ? null : DateTime.now().toUtc();
}

class SalesSummary {
  final int totalOrders;
  final int totalDealsOrdered;
  final double totalRevenue;
  final int totalRewardsClaimed;

  const SalesSummary({
    this.totalOrders = 0,
    this.totalDealsOrdered = 0,
    this.totalRevenue = 0,
    this.totalRewardsClaimed = 0,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
    totalOrders: _asInt(json['total_orders']),
    totalDealsOrdered: _asInt(json['total_deals_ordered']),
    totalRevenue: _asDouble(json['total_revenue']),
    totalRewardsClaimed: _asInt(json['total_rewards_claimed']),
  );
}

class DealSalesRow {
  final String name;
  final String category;
  final int unitsSold;
  final double revenue;

  const DealSalesRow({
    required this.name,
    required this.category,
    required this.unitsSold,
    required this.revenue,
  });

  factory DealSalesRow.fromJson(Map<String, dynamic> json) => DealSalesRow(
    name: json['deal_name']?.toString() ?? 'Deal',
    category: json['category']?.toString() ?? 'General',
    unitsSold: _asInt(json['units_sold']),
    revenue: _asDouble(json['revenue']),
  );
}

class RewardClaimsRow {
  final String name;
  final int claims;
  final int pointsRedeemed;

  const RewardClaimsRow({
    required this.name,
    required this.claims,
    required this.pointsRedeemed,
  });

  factory RewardClaimsRow.fromJson(Map<String, dynamic> json) =>
      RewardClaimsRow(
        name: json['reward_name']?.toString() ?? 'Reward',
        claims: _asInt(json['claim_count']),
        pointsRedeemed: _asInt(json['points_redeemed']),
      );
}

class SalesReport {
  final SalesSummary summary;
  final List<DealSalesRow> deals;
  final List<RewardClaimsRow> rewards;

  const SalesReport({
    required this.summary,
    required this.deals,
    required this.rewards,
  });
}

class SalesService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<SalesReport> getReport(SalesPeriod period) async {
    final parameters = {
      'p_from_ts': period.from?.toIso8601String(),
      'p_to_ts': period.to?.toIso8601String(),
    };
    final results = await Future.wait<Object>([
      _client.rpc('get_sales_summary', params: parameters),
      _client.rpc('get_deal_sales', params: parameters),
      _client.rpc('get_reward_claims', params: parameters),
    ]);

    return SalesReport(
      summary: SalesSummary.fromJson(_firstRow(results[0])),
      deals: _rows(results[1]).map(DealSalesRow.fromJson).toList(),
      rewards: _rows(results[2]).map(RewardClaimsRow.fromJson).toList(),
    );
  }
}

Map<String, dynamic> _firstRow(Object response) {
  if (response is Map) return Map<String, dynamic>.from(response);
  if (response is List && response.isNotEmpty && response.first is Map) {
    return Map<String, dynamic>.from(response.first as Map);
  }
  return const {};
}

List<Map<String, dynamic>> _rows(Object response) {
  if (response is! List) return const [];
  return response
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
}

int _asInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

double _asDouble(Object? value) =>
    double.tryParse(value?.toString() ?? '') ?? 0;
