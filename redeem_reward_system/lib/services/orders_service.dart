import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import 'cart_state.dart';
import 'payment_method.dart';

class OrderPlacement {
  final String orderCode;
  final String orderId;
  final double total;
  final List<DealOrderItem> items;
  final DateTime? orderedAt;
  final String paymentMethod;
  final String paymentStatus;
  final double? amountTendered;
  final double? changeAmount;
  final String? paymentReference;
  final int pointsToEarn;

  const OrderPlacement({
    required this.orderCode,
    this.orderId = '',
    required this.total,
    required this.items,
    this.orderedAt,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'unpaid',
    this.amountTendered,
    this.changeAmount,
    this.paymentReference,
    this.pointsToEarn = 0,
  });

  DateTime get createdAt => orderedAt ?? DateTime.now();
}

class OrdersService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<OrderPlacement> placeOrder(List<CartItem> items) async {
    final total = items.fold<double>(0, (sum, item) => sum + item.lineTotal);
    return placeOrderWithPayment(
      items,
      paymentMethod: PaymentMethod.cash,
      cashAmount: total,
    );
  }

  Future<OrderPlacement> placeOrderWithPayment(
    List<CartItem> items, {
    required PaymentMethod paymentMethod,
    required double? cashAmount,
  }) async {
    if (items.isEmpty) throw ArgumentError('Cannot place an empty order.');

    final response = await _client.rpc(
      'place_order',
      params: {
        'p_items': items
            .map((item) => {'id': item.id, 'quantity': item.quantity})
            .toList(growable: false),
        'p_payment_method': paymentMethod.value,
        'p_cash_amount': paymentMethod == PaymentMethod.cash ? cashAmount : null,
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
      orderId: result['order_id']?.toString() ?? '',
      total: double.tryParse(result['total']?.toString() ?? '') ?? 0,
      items: orderItems,
      orderedAt:
          DateTime.tryParse(result['created_at']?.toString() ?? '') ??
          DateTime.now(),
      paymentMethod:
          result['payment_method']?.toString() ?? paymentMethod.value,
      paymentStatus: result['payment_status']?.toString() ?? 'unpaid',
      amountTendered: double.tryParse(
        result['amount_tendered']?.toString() ?? '',
      ),
      changeAmount: double.tryParse(result['change_amount']?.toString() ?? ''),
      pointsToEarn:
          int.tryParse(result['points_to_earn']?.toString() ?? '') ?? 0,
    );
  }

  Future<Map<String, dynamic>> completeOrderWithPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double? amountReceived,
    String? reference,
  }) async {
    final result = await _client.rpc(
      'complete_order_with_payment',
      params: {
        'p_order_id': orderId,
        'p_payment_method': paymentMethod.value,
        'p_amount_received': amountReceived,
        'p_reference': reference,
      },
    );
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw const FormatException('The payment service returned no receipt.');
  }
}
