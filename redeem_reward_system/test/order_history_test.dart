import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kapetol_app/screens/order_history_screen.dart';
import 'package:kapetol_app/services/order_history_service.dart';

void main() {
  test('order point rate awards only complete 100-peso units', () {
    const rate = OrderPointsRate(pointsPerUnit: 10, pesoPerUnit: 100);
    expect(rate.pointsForTotal(99), 0);
    expect(rate.pointsForTotal(100), 10);
    expect(rate.pointsForTotal(109), 10);
    expect(rate.pointsForTotal(218), 20);
  });

  final placedAt = DateTime(2026, 9, 30, 14, 5);
  final firstOrder = OrderHistoryEntry(
    id: 'order-1',
    orderCode: 'KPT-19JN',
    total: 360,
    status: 'placed',
    createdAt: placedAt,
    items: const [
      OrderHistoryItem(
        dealId: 'latte',
        name: 'Brown Sugar Oat Latte',
        category: 'Special Drinks',
        quantity: 2,
        unitPrice: 120,
      ),
      OrderHistoryItem(
        dealId: 'bundle',
        name: 'Coffee Break Bundle',
        category: 'Bundles',
        quantity: 1,
        unitPrice: 120,
      ),
    ],
  );

  testWidgets('history shows owner orders and snapshot detail QR', (
    tester,
  ) async {
    final changes = StreamController<List<Map<String, dynamic>>>.broadcast(
      sync: true,
    );
    addTearDown(changes.close);
    var currentOrder = firstOrder;
    var requestedUserId = '';
    var rewardRefreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: OrderHistoryScreen(
          userId: 'user-1',
          onNavigateToDeals: () {},
          loadOrders: (userId) async {
            requestedUserId = userId;
            return [currentOrder];
          },
          watchOrders: (_) => changes.stream,
          loadPointsRate: () async =>
              const OrderPointsRate(pointsPerUnit: 10, pesoPerUnit: 100),
          onOrdersChanged: () async => rewardRefreshCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedUserId, 'user-1');
    expect(find.text('KPT-19JN'), findsOneWidget);
    expect(
      find.text('2x Brown Sugar Oat Latte, 1x Coffee Break Bundle'),
      findsOneWidget,
    );
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('₱360.00'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(
      find.text("You'll earn 30 pts when this order is completed"),
      findsOneWidget,
    );

    await tester.tap(find.text('KPT-19JN'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('2 × ₱120.00'), findsOneWidget);
    expect(find.text('₱240.00'), findsOneWidget);
    expect(find.text('Show this code at the store counter'), findsOneWidget);
    Navigator.of(tester.element(find.byType(QrImageView))).pop();
    await tester.pumpAndSettle();

    currentOrder = OrderHistoryEntry(
      id: firstOrder.id,
      orderCode: firstOrder.orderCode,
      total: firstOrder.total,
      status: 'completed',
      pointsEarned: 30,
      createdAt: firstOrder.createdAt,
      items: firstOrder.items,
    );
    changes.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('+30 pts'), findsOneWidget);
    expect(
      find.text('You got 30 points in your last order 🎉'),
      findsOneWidget,
    );
    expect(rewardRefreshCount, greaterThan(0));
  });

  testWidgets('history empty state navigates to Deals', (tester) async {
    var navigated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OrderHistoryScreen(
          userId: 'user-2',
          onNavigateToDeals: () => navigated = true,
          loadOrders: (_) async => const [],
          watchOrders: (_) => const Stream.empty(),
          loadPointsRate: () async =>
              const OrderPointsRate(pointsPerUnit: 10, pesoPerUnit: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No orders yet'), findsOneWidget);
    await tester.tap(find.text('Browse Deals'));
    expect(navigated, isTrue);
  });
}
