import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/services/cart_state.dart';

void main() {
  const latte = DealItem(
    id: 'latte',
    name: 'Oat Latte',
    description: '',
    category: 'Drinks',
    badge: 'NEW',
    icon: Icons.local_cafe,
  );
  const pastry = DealItem(
    id: 'pastry',
    name: 'Butter Croissant',
    description: '',
    category: 'Food',
    badge: 'FRESH',
    icon: Icons.bakery_dining,
  );

  test('adds distinct deals and caps each quantity at ten', () {
    final cart = CartState();
    addTearDown(cart.dispose);

    expect(cart.add(latte), isTrue);
    expect(cart.add(pastry), isTrue);
    for (var i = 1; i < CartState.maxQuantity; i++) {
      expect(cart.add(latte), isTrue);
    }

    expect(cart.add(latte), isFalse);
    expect(cart.totalItemCount, 11);
    expect(cart.items.map((item) => item.id), containsAll(['latte', 'pastry']));
    expect(cart.items.firstWhere((item) => item.id == 'latte').quantity, 10);
  });

  test(
    'decrement keeps quantity at one and remove and clear empty the cart',
    () {
      final cart = CartState();
      addTearDown(cart.dispose);

      cart.add(latte);
      cart.decrement(latte.id);
      expect(cart.items.single.quantity, 1);

      cart.increment(latte.id);
      cart.decrement(latte.id);
      expect(cart.items.single.quantity, 1);

      cart.remove(latte.id);
      expect(cart.isEmpty, isTrue);

      cart.add(latte);
      cart.clear();
      expect(cart.totalItemCount, 0);
    },
  );

  test('refreshes cart prices and marks deactivated deals unavailable', () {
    final cart = CartState();
    addTearDown(cart.dispose);
    final pricedLatte = latte.copyWith(price: 125.5);

    cart.add(latte);
    expect(cart.refreshDeals([pricedLatte]), ['Oat Latte']);
    expect(cart.items.single.unitPrice, 125.5);
    expect(cart.subtotal, 125.5);

    cart.refreshDeals([]);
    expect(cart.items.single.isAvailable, isFalse);
    expect(cart.hasUnavailableItems, isTrue);
  });

  test('deal price survives JSON serialization and deserialization', () {
    const deal = DealItem(
      id: 'priced-latte',
      name: 'Priced Latte',
      description: '',
      category: 'Drinks',
      badge: 'NEW',
      icon: Icons.local_cafe,
      price: 120.5,
    );

    expect(DealItem.fromJson(deal.toJson()).price, 120.5);
  });
}
