import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/screens/admin_orders_section.dart';
import 'package:kapetol_app/services/order_history_service.dart';

void main() {
  final orders = <OrderHistoryEntry>[
    OrderHistoryEntry(
      id: 'pending-1',
      userId: 'customer-1',
      orderCode: 'KPT-218A',
      total: 218,
      status: 'pending',
      createdAt: DateTime(2026, 10, 1, 10),
      items: const [
        OrderHistoryItem(
          dealId: 'latte',
          name: 'Oat Latte',
          category: 'Drinks',
          quantity: 2,
          unitPrice: 109,
        ),
      ],
    ),
    OrderHistoryEntry(
      id: 'completed-1',
      userId: 'customer-1',
      orderCode: 'KPT-DONE',
      total: 100,
      status: 'completed',
      pointsEarned: 10,
      createdAt: DateTime(2026, 9, 30, 10),
      items: const [],
    ),
    OrderHistoryEntry(
      id: 'cancelled-1',
      userId: 'customer-2',
      orderCode: 'KPT-CANCEL',
      total: 99,
      status: 'cancelled',
      createdAt: DateTime(2026, 9, 29, 10),
      items: const [],
    ),
  ];

  testWidgets('Admin Orders filters, searches, and completes exactly once', (
    tester,
  ) async {
    var updateCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminOrdersSection(
              loadOrders:
                  ({
                    required status,
                    required offset,
                    search = '',
                    limit = 50,
                  }) async {
                    var filtered =
                        orders.where((order) {
                            final statusMatches =
                                status == 'All' ||
                                order.status == status.toLowerCase();
                            final queryMatches =
                                search.isEmpty ||
                                order.orderCode.toLowerCase().contains(
                                  search.toLowerCase(),
                                );
                            return statusMatches && queryMatches;
                          }).toList()
                          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    return filtered.skip(offset).take(limit).toList();
                  },
              loadPointsRate: () async =>
                  const OrderPointsRate(pointsPerUnit: 10, pesoPerUnit: 100),
              updateStatus: ({required orderId, required newStatus}) async {
                updateCount++;
                final index = orders.indexWhere((order) => order.id == orderId);
                final old = orders[index];
                orders[index] = OrderHistoryEntry(
                  id: old.id,
                  userId: old.userId,
                  orderCode: old.orderCode,
                  total: old.total,
                  status: newStatus,
                  pointsEarned: newStatus == 'completed' ? 20 : 0,
                  createdAt: old.createdAt,
                  items: old.items,
                );
                return {'status': newStatus, 'points_earned': 20};
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KPT-218A'), findsOneWidget);
    expect(find.text('KPT-DONE'), findsNothing);
    expect(find.text('KPT-CANCEL'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(find.text('KPT-DONE'), findsOneWidget);
    expect(find.text('KPT-218A'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '218');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('KPT-218A'), findsOneWidget);
    expect(find.text('KPT-DONE'), findsNothing);

    await tester.tap(find.text('KPT-218A'));
    await tester.pumpAndSettle();
    expect(
      find.text('Customer will earn 20 points when completed.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Mark completed').last);
    await tester.pumpAndSettle();
    expect(find.text('Complete this order?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark completed').last);
    await tester.pumpAndSettle();

    expect(updateCount, 1);
    expect(find.text('KPT-218A'), findsNothing);
    expect(find.text('No orders found.'), findsOneWidget);
  });

  testWidgets('cancelling an under-100 order awards no points and locks it', (
    tester,
  ) async {
    var order = OrderHistoryEntry(
      id: 'pending-99',
      userId: 'customer-99',
      orderCode: 'KPT-99AA',
      total: 99,
      status: 'pending',
      createdAt: DateTime(2026, 10, 1),
      items: const [],
    );
    var updateCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminOrdersSection(
              loadOrders:
                  ({
                    required status,
                    required offset,
                    search = '',
                    limit = 50,
                  }) async =>
                      status == 'All' || order.status == status.toLowerCase()
                      ? [order]
                      : const [],
              loadPointsRate: () async =>
                  const OrderPointsRate(pointsPerUnit: 10, pesoPerUnit: 100),
              updateStatus: ({required orderId, required newStatus}) async {
                updateCount++;
                order = OrderHistoryEntry(
                  id: order.id,
                  userId: order.userId,
                  orderCode: order.orderCode,
                  total: order.total,
                  status: newStatus,
                  pointsEarned: 0,
                  createdAt: order.createdAt,
                  items: order.items,
                );
                return {'status': newStatus, 'points_earned': 0};
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('KPT-99AA'));
    await tester.pumpAndSettle();
    expect(
      find.text('Customer will earn 0 points when completed.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order').last);
    await tester.pumpAndSettle();
    expect(updateCount, 1);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cancelled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KPT-99AA'));
    await tester.pumpAndSettle();
    expect(find.text('Points earned: 0'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Mark completed'),
          )
          .onPressed,
      isNull,
    );
    expect(updateCount, 1);
  });
}
