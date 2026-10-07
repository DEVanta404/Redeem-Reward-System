import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/order_history_service.dart';
import '../services/payment_method.dart';
import '../services/currency_formatter.dart';
import 'order_code_qr.dart';

class OrderStatusCopy {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const OrderStatusCopy(this.title, this.subtitle, this.icon, this.color);

  static OrderStatusCopy forStatus(String status) =>
      switch (status.toLowerCase()) {
        'completed' => const OrderStatusCopy(
          'Order completed',
          'Thank you! Enjoy your order.',
          Icons.check_circle,
          Color(0xFF2E7D32),
        ),
        'cancelled' => const OrderStatusCopy(
          'Order cancelled',
          'This order was cancelled.',
          Icons.cancel_outlined,
          Color(0xFF9E6A64),
        ),
        _ => const OrderStatusCopy(
          'Wait for your ticket to be called',
          'Show this code at the counter when your number is called.',
          Icons.hourglass_top_rounded,
          Color(0xFF8D6E35),
        ),
      };
}

class OrderReceiptScreen extends StatelessWidget {
  final OrderHistoryEntry order;
  final VoidCallback? onDone;

  const OrderReceiptScreen({super.key, required this.order, this.onDone});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F0E8),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF5F0E8),
      foregroundColor: const Color(0xFF3E2723),
      title: const Text('Order receipt'),
    ),
    body: OrderReceiptView(order: order),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: FilledButton(
        onPressed: onDone ?? () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF3E2723),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Done'),
      ),
    ),
  );
}

class OrderReceiptView extends StatefulWidget {
  final OrderHistoryEntry order;
  final bool listenForUpdates;
  final int pendingPoints;

  const OrderReceiptView({
    super.key,
    required this.order,
    this.listenForUpdates = true,
    this.pendingPoints = 0,
  });

  @override
  State<OrderReceiptView> createState() => _OrderReceiptViewState();
}

class _OrderReceiptViewState extends State<OrderReceiptView>
    with WidgetsBindingObserver {
  late OrderHistoryEntry _order;
  RealtimeChannel? _channel;
  Object? _refreshError;
  bool _orderMissing = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant OrderReceiptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _unsubscribe();
      _order = widget.order;
      _subscribe();
    } else if (oldWidget.order != widget.order) {
      _order = widget.order;
    }
  }

  void _subscribe() {
    if (!widget.listenForUpdates || _order.id.isEmpty) return;
    _channel = Supabase.instance.client
        .channel('receipt-order-${_order.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _order.id,
          ),
          callback: (payload) {
            if (!mounted || payload.newRecord.isEmpty) return;
            setState(() {
              _order = _order.copyWith(
                status: payload.newRecord['status']?.toString(),
                pointsEarned: int.tryParse(
                  payload.newRecord['points_earned']?.toString() ?? '',
                ),
                paymentMethod: payload.newRecord['payment_method']?.toString(),
                paymentStatus: payload.newRecord['payment_status']?.toString(),
                amountTendered: double.tryParse(
                  payload.newRecord['amount_tendered']?.toString() ?? '',
                ),
                changeAmount: double.tryParse(
                  payload.newRecord['change_amount']?.toString() ?? '',
                ),
                paymentReference: payload.newRecord['payment_reference']
                    ?.toString(),
                paidAt: DateTime.tryParse(
                  payload.newRecord['paid_at']?.toString() ?? '',
                ),
              );
            });
          },
        )
        .subscribe();
  }

  void _unsubscribe() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(_removeChannel(channel));
    }
  }

  Future<void> _removeChannel(RealtimeChannel channel) async {
    await Supabase.instance.client.removeChannel(channel);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshOrder());
      _unsubscribe();
      _subscribe();
    }
  }

  Future<void> _refreshOrder() async {
    if (_order.id.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('orders')
          .select(
            'id, user_id, order_code, total, subtotal, status, points_earned, created_at, items, payment_method, payment_status, amount_tendered, change_amount, payment_reference, paid_at, receipt_no, order_items(id, deal_id, deal_name, deal_category, unit_price, quantity)',
          )
          .eq('id', _order.id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() => _orderMissing = true);
      } else {
        setState(() {
          _order = OrderHistoryEntry.fromMap(row);
          _orderMissing = false;
          _refreshError = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _refreshError = error);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusCopy = OrderStatusCopy.forStatus(_order.status);
    final paymentMethod = PaymentMethod.fromValue(_order.paymentMethod);
    final isCash = paymentMethod == PaymentMethod.cash;
    final hasPaymentSnapshot =
        _order.amountTendered != null || _order.changeAmount != null;
    final completed = _order.status.toLowerCase() == 'completed';
    final cancelled = _order.status.toLowerCase() == 'cancelled';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              if (_refreshError != null || _orderMissing)
                MaterialBanner(
                  content: Text(
                    _orderMissing
                        ? 'This order is no longer available. Showing saved receipt details.'
                        : 'Could not refresh the receipt. ${_refreshError.toString()}',
                  ),
                  leading: const Icon(Icons.wifi_off),
                  actions: [
                    if (!_orderMissing)
                      TextButton(
                        onPressed: _refreshOrder,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              Icon(statusCopy.icon, size: 34, color: statusCopy.color),
              const SizedBox(height: 8),
              Text(
                statusCopy.title,
                textAlign: TextAlign.center,
                softWrap: true,
                style: const TextStyle(
                  color: Color(0xFF3E2723),
                  fontSize: 21,
                  height: 1.18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                statusCopy.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6D5B53)),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFA),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'KAPETOL APP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF3E2723),
                        fontSize: 19,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Life happens, Coffee helps.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_order.orderCode}  ·  ${_dateTime(_order.createdAt)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6D5B53),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 17),
                    const _ReceiptDivider(),
                    const SizedBox(height: 12),
                    ..._order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${item.quantity}x ${item.name}',
                              style: const TextStyle(
                                color: Color(0xFF3E2723),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '@ ${formatPeso(item.unitPrice)}',
                                  style: const TextStyle(
                                    color: Color(0xFF8D6E63),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  formatPeso(item.lineTotal),
                                  style: const TextStyle(
                                    color: Color(0xFF3E2723),
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _ReceiptDivider(),
                    const SizedBox(height: 10),
                    _totalRow('Subtotal', _order.subtotal),
                    _totalRow('Total', _order.total, bold: true),
                    _labelRow('Payment mode', paymentMethod.label),
                    if (hasPaymentSnapshot) ...[
                      _labelRow(
                        completed ? 'Amount tendered' : 'Planned amount',
                        _order.amountTendered == null
                            ? 'Pay at counter'
                            : formatPeso(_order.amountTendered!),
                      ),
                      if (isCash)
                        _labelRow(
                          'Change',
                          formatPeso(_order.changeAmount ?? 0),
                        ),
                    ] else if (!isCash && !completed) ...[
                      _labelRow('Amount tendered', 'Pay at counter'),
                      if (!completed) _labelRow('Change', formatPeso(0)),
                    ],
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: completed
                              ? const Color(0xFFE4F1E4)
                              : cancelled
                              ? const Color(0xFFF1E6E4)
                              : const Color(0xFFFFF2D6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          completed
                              ? 'Paid'
                              : cancelled
                              ? 'Cancelled - no payment'
                              : 'Unpaid - pay at counter',
                          style: TextStyle(
                            color: completed
                                ? const Color(0xFF2E7D32)
                                : cancelled
                                ? const Color(0xFF9E6A64)
                                : const Color(0xFF8D6E35),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _ReceiptDivider(),
                    const SizedBox(height: 14),
                    const Text(
                      'Show this code at the store counter',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6D5B53), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: OrderCodeQr(
                        orderCode: _order.orderCode,
                        size: 164,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your ticket number',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      _order.orderCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF3E2723),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _ReceiptDivider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Thank you for your order!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF3E2723),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      completed
                          ? 'You earned ${_order.pointsEarned} pts'
                          : "You'll earn ${_order.pointsEarned > 0 ? _order.pointsEarned : widget.pendingPoints} pts when this order is completed",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8D6E63),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF3E2723),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          formatPeso(value),
          style: TextStyle(
            color: const Color(0xFF3E2723),
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  Widget _labelRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6D5B53))),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF3E2723),
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = (constraints.maxWidth / 7).floor();
      return Text(
        List.filled(count, '-').join(),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          color: Color(0xFFBCAAA4),
          fontSize: 11,
          height: 0.8,
          letterSpacing: 1,
        ),
      );
    },
  );
}

String _dateTime(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
