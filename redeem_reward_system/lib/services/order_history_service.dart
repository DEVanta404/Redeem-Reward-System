import 'package:supabase_flutter/supabase_flutter.dart';

class OrderHistoryItem {
  final String dealId;
  final String name;
  final String category;
  final int quantity;
  final double unitPrice;

  const OrderHistoryItem({
    required this.dealId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
  });

  double get lineTotal => unitPrice * quantity;

  factory OrderHistoryItem.fromMap(Map<String, dynamic> map) =>
      OrderHistoryItem(
        dealId: map['deal_id']?.toString() ?? map['id']?.toString() ?? '',
        name: map['deal_name']?.toString() ?? map['name']?.toString() ?? 'Deal',
        category:
            map['deal_category']?.toString() ??
            map['category']?.toString() ??
            'General',
        quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 0,
        unitPrice: double.tryParse(map['unit_price']?.toString() ?? '') ?? 0,
      );
}

class OrderHistoryEntry {
  final String id;
  final String userId;
  final String orderCode;
  final double total;
  final String status;
  final int pointsEarned;
  final DateTime createdAt;
  final List<OrderHistoryItem> items;

  const OrderHistoryEntry({
    required this.id,
    this.userId = '',
    required this.orderCode,
    required this.total,
    required this.status,
    this.pointsEarned = 0,
    required this.createdAt,
    required this.items,
  });

  int get itemCount => items.fold(0, (count, item) => count + item.quantity);

  String get shortSummary =>
      items.map((item) => '${item.quantity}x ${item.name}').join(', ');

  factory OrderHistoryEntry.fromMap(Map<String, dynamic> map) {
    final rawItems = map['order_items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    OrderHistoryItem.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <OrderHistoryItem>[];

    if (items.isEmpty && map['items'] is List) {
      items.addAll(
        (map['items'] as List).whereType<Map>().map(
          (item) => OrderHistoryItem.fromMap(Map<String, dynamic>.from(item)),
        ),
      );
    }

    return OrderHistoryEntry(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      orderCode: map['order_code']?.toString() ?? '',
      total:
          double.tryParse(map['total']?.toString() ?? '') ??
          items.fold(0, (sum, item) => sum + item.lineTotal),
      status: map['status']?.toString() ?? 'placed',
      pointsEarned: int.tryParse(map['points_earned']?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      items: items,
    );
  }
}

class OrderPointsRate {
  final int pointsPerUnit;
  final double pesoPerUnit;

  const OrderPointsRate({
    required this.pointsPerUnit,
    required this.pesoPerUnit,
  });

  int pointsForTotal(double total) =>
      (total / pesoPerUnit).floor() * pointsPerUnit;
}

class OrderHistoryService {
  final SupabaseClient _client;

  OrderHistoryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<OrderHistoryEntry>> getOrders(String userId) async {
    final rows = await _client
        .from('orders')
        .select(
          'id, user_id, order_code, total, status, points_earned, created_at, items, order_items(id, deal_id, deal_name, deal_category, unit_price, quantity)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List<dynamic>)
        .map((row) => OrderHistoryEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<OrderHistoryEntry>> getAdminOrders({
    required String status,
    required int offset,
    String search = '',
    int limit = 50,
  }) async {
    var query = _client
        .from('orders')
        .select(
          'id, user_id, order_code, total, status, points_earned, created_at, items, order_items(id, deal_id, deal_name, deal_category, unit_price, quantity)',
        );
    if (status != 'All') query = query.eq('status', status.toLowerCase());
    if (search.trim().isNotEmpty) {
      query = query.ilike('order_code', '%${search.trim()}%');
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List<dynamic>)
        .map((row) => OrderHistoryEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<int> getPendingOrderCount() async {
    final result = await _client.rpc('get_pending_order_count');
    final count = int.tryParse(result.toString());
    if (count == null) {
      throw const FormatException('The pending order count was invalid.');
    }
    return count;
  }

  Future<OrderHistoryEntry?> getOrderById(String orderId) async {
    final row = await _client
        .from('orders')
        .select(
          'id, user_id, order_code, total, status, points_earned, created_at, items, order_items(id, deal_id, deal_name, deal_category, unit_price, quantity)',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) return null;
    return OrderHistoryEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String newStatus,
  }) async {
    final result = await _client.rpc(
      'update_order_status',
      params: {'p_order_id': orderId, 'p_new_status': newStatus},
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw const FormatException('The order status service returned no result.');
  }

  Future<OrderPointsRate> getPointsRate() async {
    final row = await _client
        .from('app_settings')
        .select('points_per_unit, peso_per_unit')
        .eq('setting_key', 'order_points')
        .single();
    final pointsPerUnit = int.tryParse(
      row['points_per_unit']?.toString() ?? '',
    );
    final pesoPerUnit = double.tryParse(row['peso_per_unit']?.toString() ?? '');
    if (pointsPerUnit == null || pesoPerUnit == null || pesoPerUnit <= 0) {
      throw const FormatException('Order points settings are invalid.');
    }
    return OrderPointsRate(
      pointsPerUnit: pointsPerUnit,
      pesoPerUnit: pesoPerUnit,
    );
  }

  Stream<List<Map<String, dynamic>>> watchOrders(String userId) {
    return _client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }
}
