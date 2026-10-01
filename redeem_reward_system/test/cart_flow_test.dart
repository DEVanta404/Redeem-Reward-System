import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/screens/cart_screen.dart';
import 'package:kapetol_app/screens/deals_screen.dart';
import 'package:kapetol_app/services/cart_state.dart';
import 'package:kapetol_app/services/orders_service.dart';

void main() {
  testWidgets('deals add to cart and checkout shows the order QR', (
    tester,
  ) async {
    final state = AppState();
    final latteId = state.deals.first.id;
    state.deals = state.deals
        .map((deal) => deal.id == latteId ? deal.copyWith(price: 100) : deal)
        .toList();
    final cart = CartState();
    final dealEvents = StreamController<List<DealItem>>.broadcast(sync: true);
    addTearDown(dealEvents.close);

    await tester.pumpWidget(
      ChangeNotifierProvider<CartState>.value(
        value: cart,
        child: MaterialApp(
          home: DealsScreen(
            state: state,
            placeOrder: (items) async => OrderPlacement(
              orderCode: 'KPT-19JN',
              total: items.fold(
                0,
                (total, item) => total + item.unitPrice * item.quantity,
              ),
              items: items
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
            ),
            loadDeals: ({activeOnly = false}) async => state.deals
                .where((deal) => !activeOnly || deal.isActive)
                .toList(),
            watchDeals: ({activeOnly = false}) => dealEvents.stream,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add to cart').first);
    await tester.pump();

    expect(find.text('Brown Sugar Oat Latte added to cart'), findsOneWidget);
    expect(find.text('₱0.00'), findsWidgets);
    expect(find.text('Order ready'), findsNothing);
    expect(find.byType(QrImageView), findsNothing);
    expect(cart.totalItemCount, 1);

    await tester.tap(find.byTooltip('Open cart'));
    await tester.pumpAndSettle();

    expect(find.text('Your Cart'), findsOneWidget);
    expect(find.text('Special Drinks'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Place order'), findsOneWidget);
    expect(find.text('₱100.00 each · ₱100.00'), findsOneWidget);

    state.deals = state.deals
        .map((deal) => deal.id == latteId ? deal.copyWith(price: 120) : deal)
        .toList();
    dealEvents.add(state.deals);
    await tester.pump();
    expect(find.text('₱120.00 each · ₱120.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Place order'));
    await tester.pumpAndSettle();

    expect(find.text('Order ready'), findsOneWidget);
    expect(find.text('3x'), findsOneWidget);
    expect(find.text('Brown Sugar Oat Latte · ₱360.00'), findsOneWidget);
    expect(find.text('₱360.00'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Show this code at the store counter'), findsOneWidget);
    expect(state.dealOrders.single.items.single.quantity, 3);
    expect(state.dealOrders.single.total, 360);
    expect(cart.isEmpty, isTrue);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Order ready'), findsNothing);
    expect(find.text('Deals'), findsOneWidget);
  });

  testWidgets('empty cart disables checkout and offers a Deals return', (
    tester,
  ) async {
    final cart = CartState();

    await tester.pumpWidget(
      ChangeNotifierProvider<CartState>.value(
        value: cart,
        child: MaterialApp(home: CartScreen(state: AppState())),
      ),
    );

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.text('Back to Deals'), findsOneWidget);
    final placeOrder = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Place order'),
    );
    expect(placeOrder.onPressed, isNull);
  });
}
