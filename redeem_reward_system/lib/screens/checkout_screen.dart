import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/cart_state.dart';
import '../services/currency_formatter.dart';
import '../services/order_history_service.dart';
import '../services/orders_service.dart';
import '../services/payment_method.dart';
import '../services/supabase_profiles.dart';
import '../widgets/order_summary_card.dart';
import 'order_receipt_screen.dart';

typedef CheckoutDealLoader =
    Future<List<DealItem>> Function({bool activeOnly});

class CheckoutScreen extends StatefulWidget {
  final CartState cart;
  final CheckoutDealLoader? loadDeals;
  final Future<OrderPlacement> Function(List<CartItem>)? legacyPlaceOrder;
  final ValueChanged<OrderPlacement>? onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.cart,
    this.loadDeals,
    this.legacyPlaceOrder,
    this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _amountCap = 1000000.0;
  final _amountController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _refreshing = true;
  bool _submitting = false;
  Object? _refreshError;
  String? _priceNotice;
  OrderHistoryEntry? _placedOrder;

  CartState get _cart => widget.cart;

  @override
  void initState() {
    super.initState();
    _refreshPrices();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrices() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      final before = {
        for (final item in _cart.items) item.id: (item.name, item.unitPrice),
      };
      final deals = await (widget.loadDeals ?? SupabaseProfilesService().getDeals)(
        activeOnly: true,
      );
      if (!mounted) return;
      _cart.refreshDeals(deals);
      final changed = _cart.items
          .where((item) {
            final old = before[item.id];
            return old != null &&
                (old.$1 != item.name || old.$2 != item.unitPrice);
          })
          .map((item) => item.name)
          .toList();
      final unavailable = _cart.items
          .where((item) => !item.isAvailable)
          .map((item) => item.name)
          .toList();
      setState(() {
        _priceNotice = [
          if (changed.isNotEmpty)
            'Prices or item details changed and have been refreshed: ${changed.join(', ')}.',
          if (unavailable.isNotEmpty)
            'Unavailable deals must be removed before ordering: ${unavailable.join(', ')}.',
        ].join(' ');
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshError = error;
        _refreshing = false;
      });
    }
  }

  double? get _cashAmount {
    final raw = _amountController.text.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(raw)) return null;
    final amount = double.tryParse(raw);
    if (amount == null || amount > _amountCap) return null;
    return amount;
  }

  bool get _valid {
    if (_refreshing || _refreshError != null || _cart.isEmpty ||
        _cart.hasUnavailableItems ||
        _cart.hasUnresolvedPriceChanges) {
      return false;
    }
    if (_method != PaymentMethod.cash) return true;
    final amount = _cashAmount;
    return amount != null && amount >= _cart.subtotal;
  }

  List<double> get _quickAmounts {
    final total = _cart.subtotal;
    final values = <double>{};
    if (total <= _amountCap) values.add(total);
    for (final value in [100.0, 200.0, 500.0, 1000.0]) {
      if (value >= total && value <= _amountCap) values.add(value);
    }
    final roundUp = ((total / 100).ceil() * 100).toDouble();
    if (roundUp > total && roundUp <= _amountCap) values.add(roundUp);
    return values.toList()..sort();
  }

  Future<void> _confirmOrder() async {
    if (!_valid || _submitting || _placedOrder != null) return;
    final cashAmount = _method == PaymentMethod.cash ? _cashAmount : null;
    final change = cashAmount == null ? 0 : cashAmount - _cart.subtotal;
    final summary = _method == PaymentMethod.cash
        ? 'Total ${formatPeso(_cart.subtotal)}, paying with Cash (${formatPeso(cashAmount!)}, change ${formatPeso(change)}).'
        : 'Total ${formatPeso(_cart.subtotal)}, paying with ${_method.label} at the counter.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Place this order?'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _refreshPrices();
    if (!mounted) return;
    if (_refreshError != null || _cart.hasUnavailableItems) return;
    if (_priceNotice?.isNotEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The order changed. Review the updated total and confirm again.'),
        ),
      );
      return;
    }
    if (_method == PaymentMethod.cash &&
        (_cashAmount == null || _cashAmount! < _cart.subtotal)) {
      setState(() {});
      return;
    }

    setState(() => _submitting = true);
    try {
      final placement = widget.legacyPlaceOrder != null
          ? await widget.legacyPlaceOrder!(_cart.items)
          : await OrdersService().placeOrderWithPayment(
              _cart.items,
              paymentMethod: _method,
              cashAmount: cashAmount,
            );
      widget.onOrderPlaced?.call(placement);
      final receiptItems = placement.items
          .map(
            (item) => OrderHistoryItem(
              dealId: item.id,
              name: item.name,
              category: item.category,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          )
          .toList();
      final receipt = OrderHistoryEntry(
        id: placement.orderId,
        orderCode: placement.orderCode,
        total: placement.total,
        subtotal: placement.total,
        status: 'pending',
        pointsEarned: placement.pointsToEarn,
        createdAt: placement.createdAt,
        items: receiptItems,
        paymentMethod: placement.paymentMethod == 'cash' &&
                widget.legacyPlaceOrder != null
            ? _method.value
            : placement.paymentMethod,
        paymentStatus: placement.paymentStatus,
        amountTendered: placement.amountTendered ??
            (_method == PaymentMethod.cash ? cashAmount : null),
        changeAmount: placement.changeAmount ??
            (_method == PaymentMethod.cash
                ? (cashAmount! - placement.total)
                : null),
      );
      _cart.clear();
      if (!mounted) return;
      setState(() {
        _placedOrder = receipt;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final placedOrder = _placedOrder;
    if (placedOrder != null) {
      return OrderReceiptScreen(
        order: placedOrder,
        onDone: () => Navigator.of(context).pop(true),
      );
    }
    final parsedAmount = _cashAmount;
    final belowTotal =
        _method == PaymentMethod.cash &&
        parsedAmount != null &&
        parsedAmount < _cart.subtotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        foregroundColor: const Color(0xFF3E2723),
        title: const Text('Checkout'),
      ),
      body: _refreshing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3E2723)),
            )
          : _refreshError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not refresh the current deal prices.'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _refreshPrices,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
              children: [
                if (_priceNotice?.isNotEmpty == true) ...[
                  _notice(_priceNotice!),
                  const SizedBox(height: 14),
                ],
                OrderSummaryCard(
                  items: _cart.items,
                  subtotal: _cart.subtotal,
                  paymentMethod: _method.label,
                  pointsToEarn: (_cart.subtotal / 100).floor() * 10,
                  onAcceptUpdatedPrices: _cart.acceptUpdatedPrices,
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'Payment mode',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PaymentMethod.values
                        .map(
                          (method) => ChoiceChip(
                            label: Text(method.label),
                            selected: _method == method,
                            onSelected: _submitting
                                ? null
                                : (_) => setState(() {
                                    _method = method;
                                    _amountController.clear();
                                  }),
                            selectedColor: const Color(0xFF3E2723),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _method == method
                                  ? Colors.white
                                  : const Color(0xFF5D4037),
                              fontWeight: FontWeight.w600,
                            ),
                            showCheckmark: false,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_method == PaymentMethod.cash)
                  _section(
                    title: "Amount you'll pay",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _amountController,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '₱ ',
                            hintText: 'Enter amount',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2D8CC),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _quickAmounts
                              .map(
                                (amount) => ActionChip(
                                  label: Text(
                                    amount == _cart.subtotal
                                        ? 'Exact amount'
                                        : formatPeso(amount),
                                  ),
                                  onPressed: _submitting
                                      ? null
                                      : () {
                                          _amountController.text = amount
                                              .toStringAsFixed(2);
                                          setState(() {});
                                        },
                                  backgroundColor: Colors.white,
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF5D4037),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          belowTotal
                              ? 'Amount must be at least ${formatPeso(_cart.subtotal)}.'
                              : 'Change: ${parsedAmount == null || parsedAmount < _cart.subtotal ? '—' : formatPeso(parsedAmount - _cart.subtotal)}',
                          style: TextStyle(
                            color: belowTotal
                                ? const Color(0xFFB3261E)
                                : const Color(0xFF3E2723),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Maximum cash amount: ₱1,000,000.00. Enter up to 2 decimal places.',
                          style: TextStyle(
                            color: Color(0xFF8D6E63),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_method == PaymentMethod.gcash ||
                    _method == PaymentMethod.maya)
                  _notice(
                    'Pay at the counter using ${_method.label}. Show your code to the cashier.',
                  )
                else
                  _notice('Pay at the counter using Card. No payment is processed in the app.'),
              ],
            ),
      bottomNavigationBar: placedOrder != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: FilledButton(
                onPressed: _valid && !_submitting ? _confirmOrder : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF3E2723),
                  disabledBackgroundColor: const Color(0xFFBCAAA4),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm order'),
              ),
            ),
    );
  }

  Widget _section({required String title, required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF3E2723),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _notice(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2D6),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4C98A)),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Color(0xFF5D4037), fontSize: 13),
    ),
  );
}
