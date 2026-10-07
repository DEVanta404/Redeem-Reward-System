import 'package:flutter/material.dart';

import '../services/cart_state.dart';
import '../services/currency_formatter.dart';

class OrderSummaryCard extends StatelessWidget {
  final List<CartItem> items;
  final double subtotal;
  final String? paymentMethod;
  final int? pointsToEarn;
  final ValueChanged<String>? onIncrement;
  final ValueChanged<String>? onDecrement;
  final ValueChanged<String>? onRemove;
  final VoidCallback? onAcceptUpdatedPrices;
  final bool readOnly;

  const OrderSummaryCard({
    super.key,
    required this.items,
    required this.subtotal,
    this.paymentMethod,
    this.pointsToEarn,
    this.onIncrement,
    this.onDecrement,
    this.onRemove,
    this.onAcceptUpdatedPrices,
    this.readOnly = true,
  });

  int get _itemCount => items.fold(0, (count, item) => count + item.quantity);

  @override
  Widget build(BuildContext context) {
    final hasPriceChanges = items.any((item) => item.previousUnitPrice != null);
    final unavailable = items.any((item) => !item.isAvailable);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Order summary',
                  style: TextStyle(
                    color: Color(0xFFFFF5E5),
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E5).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_itemCount ${_itemCount == 1 ? 'item' : 'items'}',
                  style: const TextStyle(
                    color: Color(0xFFFFF5E5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Your order is empty',
                  style: TextStyle(color: Color(0xFFFFF5E5)),
                ),
              ),
            )
          else
            ...items.map(_itemRow),
          Divider(
            height: 20,
            color: const Color(0xFFFFF5E5).withValues(alpha: 0.34),
          ),
          _totalRow('Subtotal', subtotal),
          const SizedBox(height: 5),
          _totalRow('Total', subtotal, isTotal: true),
          if (paymentMethod != null) ...[
            const SizedBox(height: 10),
            _secondaryRow('Payment mode', paymentMethod!),
          ],
          if (pointsToEarn != null) ...[
            const SizedBox(height: 8),
            Text(
              pointsToEarn == 0
                  ? 'No points for orders under ₱100'
                  : "You'll earn $pointsToEarn pts with this order",
              style: const TextStyle(
                color: Color(0xFFFFD180),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
          if (hasPriceChanges) ...[
            const SizedBox(height: 9),
            const Text(
              'Review updated prices before continuing.',
              style: TextStyle(
                color: Color(0xFFFFD180),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onAcceptUpdatedPrices != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAcceptUpdatedPrices,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFD180),
                  ),
                  child: const Text('Use updated prices'),
                ),
              ),
          ],
          if (unavailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Remove unavailable items before placing your order.',
              style: TextStyle(
                color: Color(0xFFFFAB91),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(CartItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 1, right: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD180).withValues(alpha: 0.19),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            item.name.trim().isEmpty ? '•' : item.name.trim()[0].toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFFFD180),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFF5E5),
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'x${item.quantity} · ${formatPeso(item.unitPrice)} each',
                style: TextStyle(
                  color: const Color(0xFFFFF5E5).withValues(alpha: 0.82),
                  fontSize: 12,
                ),
              ),
              if (item.previousUnitPrice != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Price updated from ${formatPeso(item.previousUnitPrice!)} to ${formatPeso(item.unitPrice)}',
                  style: const TextStyle(
                    color: Color(0xFFFFD180),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (!item.isAvailable) ...[
                const SizedBox(height: 4),
                const Text(
                  'No longer available',
                  style: TextStyle(
                    color: Color(0xFFFFAB91),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPeso(item.lineTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFFFF5E5),
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (!readOnly && onIncrement != null && onDecrement != null) ...[
                const SizedBox(height: 3),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _stepButton(
                      tooltip: 'Decrease quantity',
                      icon: Icons.remove_circle_outline,
                      onPressed: item.quantity > 1
                          ? () => onDecrement!(item.id)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Color(0xFFFFF5E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _stepButton(
                      tooltip: 'Increase quantity',
                      icon: Icons.add_circle_outline,
                      onPressed: item.quantity < CartState.maxQuantity
                          ? () => onIncrement!(item.id)
                          : null,
                    ),
                  ],
                ),
                if (onRemove != null)
                  GestureDetector(
                    onTap: () => onRemove!(item.id),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Remove',
                        style: TextStyle(
                          color: Color(0xFFFFAB91),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stepButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 26,
    height: 28,
    child: IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: const Color(0xFFFFD180),
      disabledColor: const Color(0xFFFFF5E5).withValues(alpha: 0.3),
    ),
  );

  Widget _totalRow(String label, double amount, {bool isTotal = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: const Color(0xFFFFF5E5).withValues(alpha: isTotal ? 1 : 0.86),
          fontSize: isTotal ? 16 : 13,
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      Text(
        formatPeso(amount),
        style: TextStyle(
          color: const Color(0xFFFFF5E5),
          fontSize: isTotal ? 20 : 14,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  Widget _secondaryRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(color: const Color(0xFFFFF5E5).withValues(alpha: 0.82)),
      ),
      Text(value, style: const TextStyle(color: Color(0xFFFFF5E5))),
    ],
  );
}
