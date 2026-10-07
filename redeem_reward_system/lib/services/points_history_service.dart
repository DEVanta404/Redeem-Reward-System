import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';

enum PointsHistoryFilter {
  all('All', 'all'),
  earned('Earned', 'earned'),
  redeemed('Redeemed', 'redeemed');

  final String label;
  final String value;

  const PointsHistoryFilter(this.label, this.value);
}

class PointsHistorySummary {
  final int earned;
  final int redeemed;

  const PointsHistorySummary({this.earned = 0, this.redeemed = 0});

  factory PointsHistorySummary.fromResponse(Object? response) {
    final row = response is List && response.isNotEmpty
        ? response.first
        : response;
    if (row is! Map) {
      throw const FormatException('The points summary response was invalid.');
    }
    return PointsHistorySummary(
      earned: int.tryParse(row['total_earned']?.toString() ?? '') ?? 0,
      redeemed: int.tryParse(row['total_redeemed']?.toString() ?? '') ?? 0,
    );
  }
}

class PointsHistoryService {
  final SupabaseClient _client;

  PointsHistoryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to view points history.');
    return id;
  }

  Future<List<AppTransaction>> loadPage({
    required int offset,
    PointsHistoryFilter filter = PointsHistoryFilter.all,
    int limit = 20,
  }) async {
    var query = _client
        .from('transactions')
        .select(
          'id, user_id, reward_name, points_spent, points, transaction_type, created_at, order_id',
        )
        .eq('user_id', _userId);
    if (filter == PointsHistoryFilter.earned) {
      query = query.eq('transaction_type', 'earned');
    } else if (filter == PointsHistoryFilter.redeemed) {
      query = query.eq('transaction_type', 'redemption');
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map((row) => AppTransaction.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<PointsHistorySummary> loadSummary(
    PointsHistoryFilter filter,
  ) async => PointsHistorySummary.fromResponse(
    await _client.rpc(
      'get_points_history_summary',
      params: {'p_filter': filter.value},
    ),
  );

  RealtimeChannel watch({required void Function() onChange}) {
    final userId = _userId;
    return _client
        .channel('points-history-$userId-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
