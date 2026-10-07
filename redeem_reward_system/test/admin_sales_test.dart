import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/screens/admin_sales_section.dart';
import 'package:kapetol_app/services/sales_service.dart';

void main() {
  testWidgets('sales report shows aggregates and changes date range', (
    tester,
  ) async {
    final requestedPeriods = <SalesPeriod>[];
    const report = SalesReport(
      summary: SalesSummary(
        totalOrders: 4,
        totalDealsOrdered: 9,
        totalRevenue: 1080,
        totalRewardsClaimed: 2,
      ),
      deals: [
        DealSalesRow(
          name: 'Oat Latte',
          category: 'Drinks',
          unitsSold: 6,
          revenue: 720,
        ),
      ],
      rewards: [
        RewardClaimsRow(name: 'Free Espresso', claims: 2, pointsRedeemed: 200),
      ],
      paymentMethods: [
        PaymentMethodSalesRow(
          paymentMethod: 'cash',
          paidOrders: 3,
          revenue: 780,
        ),
        PaymentMethodSalesRow(
          paymentMethod: 'gcash',
          paidOrders: 1,
          revenue: 300,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminSalesSection(
              loadReport: (period) async {
                requestedPeriods.add(period);
                return report;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPeriods.first, SalesPeriod.last7Days);
    expect(find.text('Total orders'), findsOneWidget);
    expect(find.text('Total deals ordered'), findsOneWidget);
    expect(find.text('₱1080.00'), findsOneWidget);
    expect(find.text('Oat Latte'), findsOneWidget);
    expect(find.text('Free Espresso'), findsOneWidget);
    expect(find.text('Revenue by payment method'), findsOneWidget);
    expect(find.text('3 paid orders'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
    await tester.pumpAndSettle();
    expect(requestedPeriods.last, SalesPeriod.today);
  });

  testWidgets('empty report shows sales empty states and compact summary', (
    tester,
  ) async {
    const report = SalesReport(summary: SalesSummary(), deals: [], rewards: []);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminSalesSection(loadReport: (_) async => report),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No sales yet for this period'), findsNWidgets(3));
    expect(find.text('All time'), findsOneWidget);
  });
}
