import 'package:flutter/foundation.dart';

import '../app_state.dart';

class CartItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final double unitPrice;
  final bool isAvailable;

  const CartItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    this.isAvailable = true,
  });

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({
    String? name,
    String? category,
    int? quantity,
    double? unitPrice,
    bool? isAvailable,
  }) => CartItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    isAvailable: isAvailable ?? this.isAvailable,
  );
}

class CartState extends ChangeNotifier {
  static const int maxQuantity = 10;

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => List.unmodifiable(_items.values);
  bool get isEmpty => _items.isEmpty;
  int get totalItemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);
  double get subtotal =>
      _items.values.fold(0, (total, item) => total + item.lineTotal);
  bool get hasUnavailableItems =>
      _items.values.any((item) => !item.isAvailable);

  bool add(DealItem deal) {
    final current = _items[deal.id];
    if (current != null && current.quantity >= maxQuantity) return false;

    _items[deal.id] = current == null
        ? CartItem(
            id: deal.id,
            name: deal.name,
            category: deal.category,
            quantity: 1,
            unitPrice: deal.price,
            isAvailable: deal.isActive,
          )
        : current.copyWith(quantity: current.quantity + 1);
    notifyListeners();
    return true;
  }

  List<String> refreshDeals(List<DealItem> deals) {
    final byId = {for (final deal in deals) deal.id: deal};
    final changedPrices = <String>[];
    var changed = false;

    for (final entry in _items.entries.toList()) {
      final current = entry.value;
      final deal = byId[current.id];
      if (deal == null) {
        if (current.isAvailable) {
          _items[entry.key] = current.copyWith(isAvailable: false);
          changed = true;
        }
        continue;
      }

      if (current.unitPrice != deal.price) changedPrices.add(deal.name);
      if (current.unitPrice != deal.price ||
          current.name != deal.name ||
          current.category != deal.category ||
          current.isAvailable != deal.isActive) {
        _items[entry.key] = current.copyWith(
          name: deal.name,
          category: deal.category,
          unitPrice: deal.price,
          isAvailable: deal.isActive,
        );
        changed = true;
      }
    }

    if (changed) notifyListeners();
    return changedPrices;
  }

  void increment(String id) {
    final current = _items[id];
    if (current == null || current.quantity >= maxQuantity) return;
    _items[id] = current.copyWith(quantity: current.quantity + 1);
    notifyListeners();
  }

  void decrement(String id) {
    final current = _items[id];
    if (current == null || current.quantity <= 1) return;
    _items[id] = current.copyWith(quantity: current.quantity - 1);
    notifyListeners();
  }

  void remove(String id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
