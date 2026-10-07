import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/cart_state.dart';
import '../services/currency_formatter.dart';
import '../services/orders_service.dart';
import '../services/supabase_profiles.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final AppState state;
  final Future<OrderPlacement> Function(List<CartItem>)? placeOrder;
  final DealsLoader? loadDeals;

  const CartScreen({
    super.key,
    required this.state,
    this.placeOrder,
    this.loadDeals,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isPlacingOrder = false;
  bool _refreshingDeals = true;
  Object? _dealRefreshError;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCurrentDeals());
  }

  Future<void> _refreshCurrentDeals() async {
    final cart = context.read<CartState>();
    if (cart.isEmpty) {
      setState(() => _refreshingDeals = false);
      return;
    }

    setState(() {
      _refreshingDeals = true;
      _dealRefreshError = null;
    });
    try {
      final deals =
          await (widget.loadDeals ?? SupabaseProfilesService().getDeals)(
            activeOnly: true,
          );
      if (!mounted) return;
      final changedPrices = cart.refreshDeals(deals);
      final unavailable = cart.items
          .where((item) => !item.isAvailable)
          .map((item) => item.name)
          .toList();
      setState(() => _refreshingDeals = false);
      if (changedPrices.isNotEmpty) {
        _showCartMessage(
          'Updated price${changedPrices.length == 1 ? '' : 's'}: ${changedPrices.join(', ')}',
        );
      }
      if (unavailable.isNotEmpty) {
        _showCartMessage(
          'Unavailable deal${unavailable.length == 1 ? '' : 's'}: ${unavailable.join(', ')}. Remove to continue.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dealRefreshError = error;
        _refreshingDeals = false;
      });
    }
  }

  void _showCartMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Your Cart',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
      ),
      body: Column(
        children: [
          if (_refreshingDeals) const LinearProgressIndicator(minHeight: 2),
          if (_dealRefreshError != null)
            MaterialBanner(
              content: const Text('Could not refresh current deal prices.'),
              leading: const Icon(Icons.wifi_off, color: Color(0xFF8D6E63)),
              actions: [
                TextButton(
                  onPressed: _refreshCurrentDeals,
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCart(context)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemTile(
                        item: item,
                        onDecrement: () => cart.decrement(item.id),
                        onIncrement: () => cart.increment(item.id),
                        onRemove: () => cart.remove(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!cart.isEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(
                      color: Color(0xFF6D5B53),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatPeso(cart.subtotal),
                    style: const TextStyle(
                      color: Color(0xFF3E2723),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed:
                  cart.isEmpty ||
                      _isPlacingOrder ||
                      _refreshingDeals ||
                      _dealRefreshError != null ||
                      cart.hasUnavailableItems
                  ? null
                  : () => _placeOrder(context, cart),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Place order'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF3E2723),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBCAAA4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: Color(0xFFBCAAA4),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: Color(0xFF3E2723),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.local_offer_outlined),
              label: const Text('Back to Deals'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3E2723),
                side: const BorderSide(color: Color(0xFF3E2723)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(BuildContext context, CartState cart) async {
    if (_isPlacingOrder || cart.isEmpty) return;

    setState(() => _isPlacingOrder = true);
    try {
      final placed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CheckoutScreen(
            cart: cart,
            loadDeals: widget.loadDeals,
            legacyPlaceOrder: widget.placeOrder,
            onOrderPlaced: (placement) {
              widget.state.dealOrders.insert(
                0,
                DealOrder(
                  items: placement.items
                      .map(
                        (item) => DealOrderItem(
                          id: item.id,
                          name: item.name,
                          category: item.category,
                          quantity: item.quantity,
                          unitPrice: item.unitPrice,
                        ),
                      )
                      .toList(),
                  total: placement.total,
                  orderCode: placement.orderCode,
                  orderedAt: placement.createdAt,
                ),
              );
            },
          ),
        ),
      );
      if (placed == true && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: const TextStyle(
                    color: Color(0xFF8D6E63),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatPeso(item.unitPrice)} each · ${formatPeso(item.lineTotal)}',
                  style: const TextStyle(
                    color: Color(0xFF5D4037),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!item.isAvailable) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Unavailable. Remove to continue.',
                    style: TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: item.quantity > 1 ? onDecrement : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: const Color(0xFF5D4037),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${item.quantity}',
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: item.quantity < CartState.maxQuantity
                ? onIncrement
                : null,
            icon: const Icon(Icons.add_circle_outline),
            color: const Color(0xFF5D4037),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Remove ${item.name}',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            color: const Color(0xFF9E4D3D),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
