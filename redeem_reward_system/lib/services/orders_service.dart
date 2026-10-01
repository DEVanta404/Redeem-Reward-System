import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import 'cart_state.dart';

class OrderPlacement {
  final String orderCode;
  final double total;
  final List<DealOrderItem> items;

  const OrderPlacement({
    required this.orderCode,
    required this.total,
    required this.items,
  });
}

class OrdersService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<OrderPlacement> placeOrder(List<CartItem> items) async {
    if (items.isEmpty) throw ArgumentError('Cannot place an empty order.');

    final response = await _client.rpc(
      'place_order',
      params: {
        'p_items': items
            .map((item) => {'id': item.id, 'quantity': item.quantity})
            .toList(growable: false),
      },
    );

    final result = response is List && response.isNotEmpty
        ? response.first
        : response;
    if (result is! Map) {
      throw const FormatException('The order service returned no order code.');
    }

    final orderCode = result['order_code']?.toString();
    if (orderCode == null || orderCode.isEmpty) {
      throw const FormatException('The order service returned no order code.');
    }
    final rawItems = result['items'];
    final orderItems = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) {
                final row = Map<String, dynamic>.from(item);
                return DealOrderItem(
                  id: row['id']?.toString() ?? '',
                  name:
                      row['deal_name']?.toString() ??
                      row['name']?.toString() ??
                      'Deal',
                  category: row['category']?.toString() ?? 'General',
                  quantity:
                      int.tryParse(row['quantity']?.toString() ?? '') ?? 0,
                  unitPrice:
                      double.tryParse(row['unit_price']?.toString() ?? '') ?? 0,
                );
              })
              .toList(growable: false)
        : const <DealOrderItem>[];

    return OrderPlacement(
      orderCode: orderCode,
      total: double.tryParse(result['total']?.toString() ?? '') ?? 0,
      items: orderItems,
    );
  }
}
