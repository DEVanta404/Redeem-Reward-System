import 'package:flutter/material.dart';
import '../app_state.dart';

class DealsScreen extends StatefulWidget {
  final AppState state;

  const DealsScreen({super.key, required this.state});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  String _selectedCategory = 'All';

  List<DealItem> get _deals => widget.state.deals;

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
                child: _DealCard(deal: deal, onOrder: () => _placeOrder(deal)),
              ),
            ),
        ],
      ),
    );
  }

  void _placeOrder(DealItem deal) {
    final orderCode =
        'KPT-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase().substring(4)}';
    final order = DealOrder(
      deal: deal,
      orderCode: orderCode,
      orderedAt: DateTime.now(),
    );
    setState(() => widget.state.dealOrders.insert(0, order));
    showDialog<void>(
      context: context,
      builder: (_) => _OrderCodeDialog(order: order),
    );
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
  final VoidCallback onOrder;

  const _DealCard({required this.deal, required this.onOrder});

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
            onPressed: onOrder,
            icon: const Icon(Icons.add_shopping_cart, size: 17),
            label: const Text('Order'),
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

class _OrderCodeDialog extends StatelessWidget {
  final DealOrder order;

  const _OrderCodeDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Text('Order ready'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            order.deal.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            width: 148,
            height: 148,
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: CustomPaint(painter: _OrderCodePainter(order.orderCode)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Show this code at the store counter',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6D5B53), fontSize: 13),
          ),
          const SizedBox(height: 8),
          SelectableText(
            order.orderCode,
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF3E2723),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _OrderCodePainter extends CustomPainter {
  final String value;

  _OrderCodePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF3E2723);
    final seed = value.codeUnits.fold(0, (total, code) => total + code);
    const cells = 17;
    final cellSize = size.width / cells;
    for (var row = 0; row < cells; row++) {
      for (var column = 0; column < cells; column++) {
        final inFinder =
            _finder(row, column, 0, 0) ||
            _finder(row, column, 0, cells - 7) ||
            _finder(row, column, cells - 7, 0);
        final filled = inFinder
            ? _finderFilled(row, column)
            : ((seed + row * 17 + column * 31) % 7 < 3);
        if (filled) {
          canvas.drawRect(
            Rect.fromLTWH(
              column * cellSize,
              row * cellSize,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }
  }

  bool _finder(int row, int column, int top, int left) =>
      row >= top && row < top + 7 && column >= left && column < left + 7;

  bool _finderFilled(int row, int column) {
    final edgeRow = row % 7 == 0 || row % 7 == 6;
    final edgeColumn = column % 7 == 0 || column % 7 == 6;
    return edgeRow ||
        edgeColumn ||
        (row % 7 >= 2 && row % 7 <= 4 && column % 7 >= 2 && column % 7 <= 4);
  }

  @override
  bool shouldRepaint(covariant _OrderCodePainter oldDelegate) =>
      oldDelegate.value != value;
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
