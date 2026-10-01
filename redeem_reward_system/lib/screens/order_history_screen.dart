import 'dart:async';

import 'package:flutter/material.dart';

import '../services/currency_formatter.dart';
import '../services/order_history_service.dart';
import 'order_code_qr.dart';

typedef OrdersLoader = Future<List<OrderHistoryEntry>> Function(String userId);
typedef OrdersWatcher =
    Stream<List<Map<String, dynamic>>> Function(String userId);
typedef PointsRateLoader = Future<OrderPointsRate> Function();

class OrderHistoryScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onNavigateToDeals;
  final bool isActive;
  final OrdersLoader? loadOrders;
  final OrdersWatcher? watchOrders;
  final PointsRateLoader? loadPointsRate;
  final Future<void> Function()? onOrdersChanged;

  const OrderHistoryScreen({
    super.key,
    required this.userId,
    required this.onNavigateToDeals,
    this.isActive = true,
    this.loadOrders,
    this.watchOrders,
    this.loadPointsRate,
    this.onOrdersChanged,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  OrderHistoryService? _service;
  StreamSubscription<List<Map<String, dynamic>>>? _ordersSubscription;
  List<OrderHistoryEntry> _orders = [];
  OrderPointsRate? _pointsRate;
  Object? _error;
  bool _loading = true;

  OrderHistoryService get _orderService => _service ??= OrderHistoryService();

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _activate();
  }

  @override
  void didUpdateWidget(covariant OrderHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.isActive != widget.isActive) {
      _ordersSubscription?.cancel();
      _ordersSubscription = null;
      if (widget.userId != oldWidget.userId) _orders = [];
      if (widget.isActive) _activate();
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _activate() {
    if (widget.userId.isEmpty) {
      setState(() {
        _orders = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _ordersSubscription =
        (widget.watchOrders ?? _orderService.watchOrders)(widget.userId).listen(
          (_) => unawaited(_loadOrders(showLoading: false)),
          onError: (Object error) {
            if (mounted) setState(() => _error = error);
          },
        );
    unawaited(_loadOrders());
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    if (widget.userId.isEmpty) return;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final orders = await (widget.loadOrders ?? _orderService.getOrders)(
        widget.userId,
      );
      final pointsRate =
          await (widget.loadPointsRate ?? _orderService.getPointsRate)();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _pointsRate = pointsRate;
        _loading = false;
        _error = null;
      });
      if (widget.onOrdersChanged != null) {
        unawaited(widget.onOrdersChanged!());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: _loading ? null : _loadOrders,
            icon: const Icon(Icons.refresh, color: Color(0xFF3E2723)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: const Color(0xFF3E2723),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator(color: Color(0xFF3E2723))),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 130),
          const Icon(
            Icons.cloud_off_outlined,
            size: 46,
            color: Color(0xFFBCAAA4),
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load order history.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6D5B53)),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 130),
          const Icon(
            Icons.receipt_long_outlined,
            size: 54,
            color: Color(0xFFBCAAA4),
          ),
          const SizedBox(height: 14),
          const Text(
            'No orders yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF3E2723),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: widget.onNavigateToDeals,
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Browse Deals'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3E2723),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }
    final latestCompleted = _latestCompletedOrder;
    final hasBanner = latestCompleted != null;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      itemCount: _orders.length + (hasBanner ? 1 : 0),
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (hasBanner && index == 0) {
          return _LastOrderPointsBanner(points: latestCompleted.pointsEarned);
        }
        final order = _orders[index - (hasBanner ? 1 : 0)];
        return _OrderHistoryCard(
          order: order,
          pointsRate: _pointsRate,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _OrderDetailsSheet(order: order, pointsRate: _pointsRate),
          ),
        );
      },
    );
  }

  OrderHistoryEntry? get _latestCompletedOrder {
    for (final order in _orders) {
      if (order.status.toLowerCase() == 'completed') return order;
    }
    return null;
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final OrderHistoryEntry order;
  final OrderPointsRate? pointsRate;
  final VoidCallback onTap;

  const _OrderHistoryCard({
    required this.order,
    required this.pointsRate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(order.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: const TextStyle(
                        color: Color(0xFF3E2723),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _StatusChip(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _formatDate(order.createdAt),
                style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                order.shortSummary.isEmpty
                    ? 'Order details unavailable'
                    : order.shortSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5D4037),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (order.status.toLowerCase() != 'cancelled') ...[
                const SizedBox(height: 8),
                if (order.status.toLowerCase() == 'pending' ||
                    order.status.toLowerCase() == 'placed')
                  Text(
                    _pendingPointsText(order, pointsRate),
                    style: const TextStyle(
                      color: Color(0xFF8D6E63),
                      fontSize: 12,
                    ),
                  )
                else if (order.pointsEarned > 0)
                  _EarnedPointsChip(points: order.pointsEarned)
                else
                  const Text(
                    'No points for this order',
                    style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
                  ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: Color(0xFF8D6E63),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formatPeso(order.total),
                    style: const TextStyle(
                      color: Color(0xFF3E2723),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final OrderHistoryEntry order;
  final OrderPointsRate? pointsRate;

  const _OrderDetailsSheet({required this.order, required this.pointsRate});

  @override
  Widget build(BuildContext context) {
    final status = _statusPresentation(order.status);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F0E8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBCAAA4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Order details',
                      style: TextStyle(
                        color: Color(0xFF3E2723),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StatusChip(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${order.orderCode} · ${_formatDate(order.createdAt)}',
                style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF3E2723),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.quantity} × ${formatPeso(item.unitPrice)}',
                                    style: const TextStyle(
                                      color: Color(0xFF8D6E63),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatPeso(item.lineTotal),
                              style: const TextStyle(
                                color: Color(0xFF3E2723),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: Color(0xFF3E2723),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formatPeso(order.total),
                          style: const TextStyle(
                            color: Color(0xFF3E2723),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (order.status.toLowerCase() != 'cancelled') ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _orderPointsText(
                          order,
                          pointsRate,
                          detail: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(child: OrderCodeQr(orderCode: order.orderCode, size: 176)),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Show this code at the store counter',
                  style: TextStyle(color: Color(0xFF6D5B53), fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: SelectableText(
                  order.orderCode,
                  style: const TextStyle(
                    color: Color(0xFF3E2723),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _pendingPointsText(
  OrderHistoryEntry order,
  OrderPointsRate? pointsRate,
) {
  final points = pointsRate?.pointsForTotal(order.total) ?? 0;
  return points == 0
      ? 'No points for this order'
      : "You'll earn $points pts when this order is completed";
}

Widget _orderPointsText(
  OrderHistoryEntry order,
  OrderPointsRate? pointsRate, {
  bool detail = false,
}) {
  final status = order.status.toLowerCase();
  if (status == 'cancelled') return const SizedBox.shrink();
  if (status == 'completed') {
    if (order.pointsEarned <= 0) {
      return const Text(
        'No points for this order',
        style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
      );
    }
    if (detail) {
      return Text(
        'You earned ${order.pointsEarned} ${order.pointsEarned == 1 ? 'point' : 'points'} from this order',
        style: const TextStyle(
          color: Color(0xFF9A6B32),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );
    }
    return _EarnedPointsChip(points: order.pointsEarned);
  }
  return Text(
    _pendingPointsText(order, pointsRate),
    style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
  );
}

class _LastOrderPointsBanner extends StatelessWidget {
  final int points;

  const _LastOrderPointsBanner({required this.points});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2CF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: const Color(0xFFE7B765).withValues(alpha: 0.55),
      ),
    ),
    child: Text(
      'You got $points ${points == 1 ? 'point' : 'points'} in your last order 🎉',
      style: const TextStyle(
        color: Color(0xFF5D4037),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

class _EarnedPointsChip extends StatelessWidget {
  final int points;

  const _EarnedPointsChip({required this.points});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE7B765).withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE7B765).withValues(alpha: 0.4)),
    ),
    child: Text(
      '+$points pts',
      style: const TextStyle(
        color: Color(0xFF7B4B3A),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
}

({String label, Color color}) _statusPresentation(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return (label: 'Completed', color: const Color(0xFF2E7D32));
    case 'ready':
      return (label: 'Ready', color: const Color(0xFF2E7D32));
    case 'preparing':
      return (label: 'Preparing', color: const Color(0xFF9A6B32));
    case 'cancelled':
      return (label: 'Cancelled', color: const Color(0xFF9E4D3D));
    default:
      return (label: 'Pending', color: const Color(0xFF7B4B3A));
  }
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $meridiem';
}
