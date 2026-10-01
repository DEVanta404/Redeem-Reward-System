import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/cart_state.dart';
import '../services/currency_formatter.dart';
import '../services/orders_service.dart';
import '../services/supabase_profiles.dart';
import 'cart_screen.dart';

class DealsScreen extends StatefulWidget {
  final AppState state;
  final Future<OrderPlacement> Function(List<CartItem>)? placeOrder;
  final DealsLoader? loadDeals;
  final DealsWatcher? watchDeals;
  final bool isActive;

  const DealsScreen({
    super.key,
    required this.state,
    this.placeOrder,
    this.loadDeals,
    this.watchDeals,
    this.isActive = true,
  });

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String _selectedCategory = 'All';
  StreamSubscription<List<DealItem>>? _dealSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _activateDeals();
  }

  @override
  void didUpdateWidget(covariant DealsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      _activateDeals();
    } else {
      _dealSubscription?.cancel();
      _dealSubscription = null;
    }
  }

  void _activateDeals() {
    if (widget.watchDeals != null) {
      _dealSubscription = widget.watchDeals!(activeOnly: true).listen(
        _applyDeals,
        onError: (Object error) => debugPrint('Deals realtime error: $error'),
      );
    } else {
      _dealSubscription = SupabaseProfilesService()
          .streamDeals(activeOnly: true)
          .listen(
            _applyDeals,
            onError: (Object error) =>
                debugPrint('Deals realtime error: $error'),
          );
    }
    unawaited(_refreshDeals());
  }

  @override
  void dispose() {
    _dealSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshDeals() async {
    try {
      final deals =
          await (widget.loadDeals ?? SupabaseProfilesService().getDeals)(
            activeOnly: true,
          );
      _applyDeals(deals);
    } catch (error) {
      debugPrint('Failed to refresh deals: $error');
    }
  }

  void _applyDeals(List<DealItem> deals) {
    widget.state.deals = deals;
    final changedPrices = context.read<CartState>().refreshDeals(deals);
    if (mounted) setState(() {});
    if (mounted && changedPrices.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Updated price${changedPrices.length == 1 ? '' : 's'}: ${changedPrices.join(', ')}',
            ),
          ),
        );
    }
  }

  List<DealItem> get _deals =>
      widget.state.deals.where((deal) => deal.isActive).toList();

  List<String> get _categories {
    final categories = _deals.map((deal) => deal.category).toSet().toList();
    return ['All', ...categories];
  }

  List<DealItem> get _visibleDeals => _selectedCategory == 'All'
      ? _deals
      : _deals.where((deal) => deal.category == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    final categories = _categories;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Deals',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        centerTitle: false,
        actions: [
          Consumer<CartState>(
            builder: (context, cart, child) => IconButton(
              tooltip: 'Open cart',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CartScreen(
                    state: widget.state,
                    placeOrder: widget.placeOrder,
                    loadDeals: widget.loadDeals,
                  ),
                ),
              ),
              icon: Badge(
                isLabelVisible: cart.totalItemCount > 0,
                label: Text('${cart.totalItemCount}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          const _DealsIntro(),
          const SizedBox(height: 18),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
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
          const SizedBox(height: 18),
          if (_visibleDeals.isEmpty)
            const _EmptyDeals()
          else
            ..._visibleDeals.map(
              (deal) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DealCard(
                  deal: deal,
                  onAddToCart: () => _addToCart(deal),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addToCart(DealItem deal) {
    final added = context.read<CartState>().add(deal);
    final message = added
        ? '${deal.name} added to cart'
        : 'Maximum quantity of ${CartState.maxQuantity} reached';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DealsIntro extends StatelessWidget {
  const _DealsIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A342D), Color(0xFF3E2723)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E2723).withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Something good is brewing',
                  style: TextStyle(
                    color: Color(0xFFF8F2EA),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Order in the app and show your code at the counter.',
                  style: TextStyle(
                    color: Color(0xFFE7DACC),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: Color(0xFFD4A574), size: 17),
                    SizedBox(width: 6),
                    Text(
                      'Fast pickup at the store',
                      style: TextStyle(color: Color(0xFFD4A574), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.local_cafe, color: Color(0xFFD4A574), size: 54),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final DealItem deal;
  final VoidCallback onAddToCart;

  const _DealCard({required this.deal, required this.onAddToCart});

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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(deal.icon, color: const Color(0xFF795548), size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deal.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3E2723),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatPeso(deal.price),
                  style: const TextStyle(
                    color: Color(0xFF3E2723),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  deal.badge,
                  style: const TextStyle(
                    color: Color(0xFFB07A3E),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                if (deal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    deal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  deal.category,
                  style: const TextStyle(
                    color: Color(0xFF9A6B32),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAddToCart,
            icon: const Icon(Icons.add_shopping_cart, size: 17),
            label: const Text('Add to cart'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDeals extends StatelessWidget {
  const _EmptyDeals();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.local_offer_outlined, size: 52, color: Color(0xFFBCAAA4)),
          SizedBox(height: 12),
          Text(
            'No deals available right now.',
            style: TextStyle(color: Color(0xFF8D6E63)),
          ),
        ],
      ),
    );
  }
}
