import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/services/points_overview_service.dart';
import 'package:kapetol_app/widgets/order_summary_card.dart';
import 'package:kapetol_app/widgets/points_overview_card.dart';
import 'package:kapetol_app/services/cart_state.dart';

void main() {
  test(
    'membership tier thresholds use lifetime points at exact boundaries',
    () {
      expect(MembershipTier.forLifetimePoints(499).name, 'Bronze');
      expect(MembershipTier.forLifetimePoints(500).name, 'Silver');
      expect(MembershipTier.forLifetimePoints(999).name, 'Silver');
      expect(MembershipTier.forLifetimePoints(1000).name, 'Gold');
    },
  );

  test('points overview parser reads totals and six chart buckets', () {
    final overview = PointsOverview.fromResponse({
      'balance': 1350,
      'lifetime_earned': 2030,
      'total_redeemed': 680,
      'earned_this_month': 80,
      'earned_last_month': 60,
      'buckets': [
        for (var week = 0; week < 6; week++)
          {'label': 'Jun ${week + 1}', 'earned': week * 10, 'redeemed': 5},
      ],
    });

    expect(overview.balance, 1350);
    expect(overview.lifetimeEarned, 2030);
    expect(overview.totalRedeemed, 680);
    expect(overview.earnedThisMonth, 80);
    expect(overview.earnedLastMonth, 60);
    expect(overview.buckets, hasLength(6));
    expect(overview.hasChartData, isTrue);
  });

  testWidgets('tier progress handles 499, 500, 999, and 1000', (tester) async {
    for (final testCase in [
      (499, '1 pt to Silver'),
      (500, '500 pts to Gold'),
      (999, '1 pt to Gold'),
      (1000, "You've reached the top tier 🎉"),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PointsOverviewCard(
                overview: PointsOverview(
                  balance: testCase.$1,
                  lifetimeEarned: testCase.$1,
                  totalRedeemed: 0,
                  earnedThisMonth: 0,
                  earnedLastMonth: 0,
                  buckets: const [],
                ),
                period: PointsChartPeriod.week,
                onPeriodChanged: (_) {},
                onViewHistory: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(testCase.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('overview details expand and collapse with the whole header', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PointsOverviewCard(
              key: const ValueKey('expanded-overview'),
              overview: PointsOverview(
                balance: 450,
                lifetimeEarned: 700,
                totalRedeemed: 250,
                earnedThisMonth: 90,
                earnedLastMonth: 0,
                buckets: const [],
              ),
              period: PointsChartPeriod.week,
              onPeriodChanged: (_) {},
              onViewHistory: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Points Overview'), findsOneWidget);
    expect(find.text('450'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
    expect(find.text('Total redeemed'), findsNothing);
    expect(find.text('Points trend'), findsNothing);
    expect(find.text('No points activity in this period yet.'), findsNothing);
    expect(find.text('Show details'), findsOneWidget);

    await tester.tap(find.text('Points Overview'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('Total redeemed'), findsOneWidget);
    expect(find.text('Points trend'), findsOneWidget);
    expect(find.text('No points activity in this period yet.'), findsOneWidget);
    expect(find.text('New this month'), findsOneWidget);
    expect(find.text('Hide details'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PointsOverviewCard(
              key: const ValueKey('expanded-overview'),
              overview: PointsOverview(
                balance: 470,
                lifetimeEarned: 720,
                totalRedeemed: 250,
                earnedThisMonth: 110,
                earnedLastMonth: 0,
                buckets: const [],
              ),
              period: PointsChartPeriod.week,
              onPeriodChanged: (_) {},
              onViewHistory: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hide details'), findsOneWidget);
    expect(find.text('470'), findsOneWidget);

    await tester.tap(find.text('Hide details'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Total redeemed'), findsNothing);
    expect(find.text('Show details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'monthly comparison handles increases, decreases, and no change',
    (tester) async {
      for (final testCase in [
        (100, 60, '+40 vs last month', const Color(0xFF2E7D32)),
        (40, 60, '−20 vs last month', const Color(0xFF9A4D43)),
        (60, 60, 'Same as last month', const Color(0xFF8D8178)),
        (20, 0, 'New this month', const Color(0xFF2E7D32)),
        (0, 0, 'Same as last month', const Color(0xFF8D8178)),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PointsOverviewCard(
                  key: ValueKey(testCase.$3),
                  overview: PointsOverview(
                    balance: 0,
                    lifetimeEarned: 0,
                    totalRedeemed: 0,
                    earnedThisMonth: testCase.$1,
                    earnedLastMonth: testCase.$2,
                    buckets: const [],
                  ),
                  period: PointsChartPeriod.week,
                  onPeriodChanged: (_) {},
                  onViewHistory: () {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Show details'));
        await tester.pumpAndSettle();
        final indicator = tester.widget<Text>(find.text(testCase.$3));
        expect(indicator.style?.color, testCase.$4);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('points totals use thousands separators', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PointsOverviewCard(
              overview: PointsOverview(
                balance: 12345,
                lifetimeEarned: 12345,
                totalRedeemed: 12345,
                earnedThisMonth: 12345,
                earnedLastMonth: 0,
                buckets: const [],
              ),
              period: PointsChartPeriod.week,
              onPeriodChanged: (_) {},
              onViewHistory: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show details'));
    await tester.pumpAndSettle();

    expect(find.text('12,345'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared order summary includes item details and totals', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const items = [
      CartItem(
        id: 'latte',
        name: 'Brown Sugar Oat Latte',
        category: 'Coffee',
        quantity: 2,
        unitPrice: 109,
      ),
      CartItem(
        id: 'bundle',
        name: 'Coffee Break Bundle',
        category: 'Bundle',
        quantity: 1,
        unitPrice: 218,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: OrderSummaryCard(
                items: items,
                subtotal: 436,
                paymentMethod: 'Cash',
                pointsToEarn: 40,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('Brown Sugar Oat Latte'), findsOneWidget);
    expect(find.text('Coffee Break Bundle'), findsOneWidget);
    expect(find.text('x2 · ₱109.00 each'), findsOneWidget);
    expect(find.text('₱218.00'), findsWidgets);
    expect(find.text('₱436.00'), findsWidgets);
    expect(find.text("You'll earn 40 pts with this order"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shared order summary fits ten long-named items on a small screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final items = List.generate(
        10,
        (index) => CartItem(
          id: 'deal-$index',
          name: 'Seasonal Coffee Drink Number ${index + 1}',
          category: 'Coffee',
          quantity: 1,
          unitPrice: 109,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: OrderSummaryCard(
                items: items,
                subtotal: 1090,
                paymentMethod: 'Cash',
                pointsToEarn: 100,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10 items'), findsOneWidget);
      expect(find.text('Seasonal Coffee Drink Number 10'), findsOneWidget);
      expect(find.text('₱1090.00'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
