import 'package:flutter/material.dart';

import '../services/currency_formatter.dart';
import '../services/order_history_service.dart';

class AdminOrdersSection extends StatefulWidget {
  final Future<void> Function()? onOrderUpdated;
  final Future<List<OrderHistoryEntry>> Function({
    required String status,
    required int offset,
    String search,
    int limit,
  })?
  loadOrders;
  final Future<Map<String, dynamic>> Function({
    required String orderId,
    required String newStatus,
  })?
  updateStatus;
  final Future<OrderPointsRate> Function()? loadPointsRate;

  const AdminOrdersSection({
    super.key,
    this.onOrderUpdated,
    this.loadOrders,
    this.updateStatus,
    this.loadPointsRate,
  });

  @override
  State<AdminOrdersSection> createState() => AdminOrdersSectionState();
}

class AdminOrdersSectionState extends State<AdminOrdersSection> {
  static const _pageSize = 50;
  static const _filters = ['Pending', 'Completed', 'Cancelled', 'All'];

  OrderHistoryService? _service;
  final TextEditingController _searchController = TextEditingController();
  List<OrderHistoryEntry> _orders = [];
  OrderPointsRate? _pointsRate;
  String _status = 'Pending';
  String _search = '';
  Object? _error;
  String? _processingOrderId;
  bool _loading = true;
  bool _hasMore = false;

  OrderHistoryService get _orderService => _service ??= OrderHistoryService();

  @override
  void initState() {
    super.initState();
    _loadOrders(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> refresh() => _loadOrders(reset: true);

  Future<bool> openOrderById(String orderId) async {
    final order = await _orderService.getOrderById(orderId);
    if (!mounted || order == null) return false;
    _showDetails(order);
    return true;
  }

  Future<void> _loadOrders({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _orders = [];
      });
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      _pointsRate ??=
          await (widget.loadPointsRate ?? _orderService.getPointsRate)();
      final offset = reset ? 0 : _orders.length;
      final page = await (widget.loadOrders ?? _orderService.getAdminOrders)(
        status: _status,
        offset: offset,
        search: _search,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _orders = page;
        } else {
          _orders = [..._orders, ...page];
        }
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _changeFilter(String filter) async {
    if (_status == filter) return;
    setState(() => _status = filter);
    await _loadOrders(reset: true);
  }

  Future<void> _confirmStatusChange(
    OrderHistoryEntry order,
    String newStatus,
  ) async {
    if (_processingOrderId != null || order.status != 'pending') return;
    final isComplete = newStatus == 'completed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isComplete ? 'Complete this order?' : 'Cancel this order?'),
        content: Text(
          isComplete
              ? 'This will complete ${order.orderCode} and award ${_pointsFor(order)} points.'
              : 'This will cancel ${order.orderCode}. No points will be awarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep pending'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: isComplete
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF8D6E63),
            ),
            child: Text(isComplete ? 'Mark completed' : 'Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingOrderId = order.id);
    try {
      await (widget.updateStatus ?? _orderService.updateOrderStatus)(
        orderId: order.id,
        newStatus: newStatus,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await _loadOrders(reset: true);
      await widget.onOrderUpdated?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isComplete
                ? '${order.orderCode} completed. ${_pointsFor(order)} points awarded.'
                : '${order.orderCode} cancelled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order update failed: $error')));
    } finally {
      if (mounted) setState(() => _processingOrderId = null);
    }
  }

  int _pointsFor(OrderHistoryEntry order) =>
      _pointsRate?.pointsForTotal(order.total) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final selected = filter == _status;
              return ChoiceChip(
                label: Text(filter),
                selected: selected,
                onSelected: (_) => _changeFilter(filter),
                selectedColor: const Color(0xFF3E2723),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF3E2723)
                      : const Color(0xFFE2D8CC),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF5D4037),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _search = value.trim();
            _loadOrders(reset: true);
          },
          decoration: InputDecoration(
            hintText: 'Search order code',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF7B4B3A)),
            suffixIcon: IconButton(
              tooltip: 'Search orders',
              onPressed: () {
                _search = _searchController.text.trim();
                _loadOrders(reset: true);
              },
              icon: const Icon(Icons.arrow_forward, color: Color(0xFF3E2723)),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2D8CC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2D8CC)),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
          ),
        ),
        const SizedBox(height: 14),
        if (_loading && _orders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 38),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF3E2723)),
            ),
          )
        else if (_error != null)
          _OrdersError(onRetry: refresh)
        else if (_orders.isEmpty)
          const _OrdersEmpty()
        else ...[
          ..._orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AdminOrderCard(
                order: order,
                onTap: () => _showDetails(order),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF3E2723)),
              ),
            )
          else if (_hasMore)
            Center(
              child: TextButton.icon(
                onPressed: () => _loadOrders(reset: false),
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3E2723),
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _showDetails(OrderHistoryEntry order) {
    final status = _orderStatus(order.status);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F0E8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _OrderStatusChip(label: status.label, color: status.color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatOrderDate(order.createdAt),
                  style: const TextStyle(
                    color: Color(0xFF8D6E63),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}x ${item.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF3E2723),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${formatPeso(item.unitPrice)} each · ${formatPeso(item.lineTotal)}',
                          style: const TextStyle(
                            color: Color(0xFF6D5B53),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order total',
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
                const SizedBox(height: 8),
                Text(
                  order.status == 'pending'
                      ? 'Customer will earn ${_pointsFor(order)} points when completed.'
                      : 'Points earned: ${order.pointsEarned}',
                  style: const TextStyle(
                    color: Color(0xFF8D6E63),
                    fontSize: 12,
                  ),
                ),
                if (order.status != 'pending')
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'This order can no longer be changed.',
                      style: TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            order.status == 'pending' &&
                                _processingOrderId != order.id
                            ? () => _confirmStatusChange(order, 'cancelled')
                            : null,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel order'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8D6E63),
                          side: const BorderSide(color: Color(0xFFBCAAA4)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            order.status == 'pending' &&
                                _processingOrderId != order.id
                            ? () => _confirmStatusChange(order, 'completed')
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark completed'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final OrderHistoryEntry order;
  final VoidCallback onTap;

  const _AdminOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _orderStatus(order.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _OrderStatusChip(label: status.label, color: status.color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatOrderDate(order.createdAt),
                style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
              ),
              const SizedBox(height: 9),
              Text(
                order.shortSummary.isEmpty
                    ? 'Order details unavailable'
                    : order.shortSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF5D4037), fontSize: 12),
              ),
              const SizedBox(height: 9),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.itemCount} items',
                    style: const TextStyle(
                      color: Color(0xFF8D6E63),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    formatPeso(order.total),
                    style: const TextStyle(
                      color: Color(0xFF3E2723),
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

class _OrdersError extends StatelessWidget {
  final VoidCallback onRetry;

  const _OrdersError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Column(
        children: [
          const Text(
            'Could not load orders.',
            style: TextStyle(color: Color(0xFF8D6E63)),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _OrderStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _OrderStatusChip({required this.label, required this.color});

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

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        'No orders found.',
        style: TextStyle(color: Color(0xFF8D6E63)),
      ),
    ),
  );
}

({String label, Color color}) _orderStatus(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return (label: 'Completed', color: const Color(0xFF2E7D32));
    case 'cancelled':
      return (label: 'Cancelled', color: const Color(0xFF9E4D3D));
    default:
      return (label: 'Pending', color: const Color(0xFF7B4B3A));
  }
}

String _formatOrderDate(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date · $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
