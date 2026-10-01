import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/main.dart';
import 'package:kapetol_app/screens/admin_dashboard_screen.dart';
import 'package:kapetol_app/screens/admin_shell.dart';
import 'package:kapetol_app/screens/edit_profile_screen.dart';
import 'package:kapetol_app/screens/home_screen.dart';
import 'package:kapetol_app/screens/profile_screen.dart';
import 'package:kapetol_app/screens/user_bottom_navigation_bar.dart';
import 'package:kapetol_app/services/cart_state.dart';
import 'package:kapetol_app/services/order_history_service.dart';
import 'package:kapetol_app/services/sales_service.dart';

void main() {
  test(
    'transactions parse earned order points without changing redemption sign',
    () {
      final earned = AppTransaction.fromMap({
        'transaction_type': 'earned',
        'points': 20,
        'points_spent': 0,
        'reward_name': 'Order KPT-218A (+20 pts)',
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(earned.points, 20);
      expect(earned.description, 'Order KPT-218A (+20 pts)');

      final redeemed = AppTransaction.fromMap({
        'transaction_type': 'redemption',
        'points_spent': 100,
        'reward_name': 'Free Espresso',
        'created_at': '2026-10-01T10:00:00Z',
      });
      expect(redeemed.points, -100);
    },
  );

  test('only an explicit profiles.role admin resolves to the admin role', () {
    expect(resolveProfileRole({'role': 'admin'}), 'admin');
    expect(resolveProfileRole({'role': 'ADMIN'}), 'admin');
    expect(resolveProfileRole({'role': 'unknown'}), 'user');
    expect(resolveProfileRole({'name': 'No role'}), 'user');
    expect(resolveProfileRole(null), 'user');
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://hlvwhxtneqdsnofhoplr.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhsdndoeHRuZXFkc25vZmhvcGxyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjQ3NTAsImV4cCI6MjA5OTcwMDc1MH0.NadYDiPM5rp_8Fgg_ikzGhR8ctk0dQ99lHZy1IKhiw4',
    );
  });

  testWidgets('shows the splash screen before the auth flow', (tester) async {
    await tester.pumpWidget(const RewardApp());

    expect(find.text('Kapetol'), findsOneWidget);
    expect(
      find.text('Fresh rewards. Better coffee. More perks.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Kapetol App'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('shows only one save button on the edit profile screen', (
    tester,
  ) async {
    final state = AppState();
    state.user = UserProfile(
      id: 'user-123',
      name: 'Dejavu',
      email: 'ativophilrod@gmail.com',
      phone: '09934301442',
      birthday: '05/31/05',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EditProfileScreen(state: state, onSaved: () {}),
      ),
    );

    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('profile does not expose admin dashboard to either role', (
    tester,
  ) async {
    final adminState = AppState();
    adminState.user = UserProfile(
      id: 'admin-1',
      name: 'Administrator',
      email: 'admin@example.com',
      phone: '',
      birthday: '',
      role: 'admin',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          state: adminState,
          onProfileUpdated: () {},
          onLoggedOut: () {},
        ),
      ),
    );

    expect(find.text('Admin Dashboard'), findsNothing);

    final userState = AppState();
    userState.user = UserProfile(
      id: 'user-2',
      name: 'Jane User',
      email: 'jane@example.com',
      phone: '',
      birthday: '',
      role: 'user',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          state: userState,
          onProfileUpdated: () {},
          onLoggedOut: () {},
        ),
      ),
    );

    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('admin shell guards non-admin access and routes to user home', (
    tester,
  ) async {
    final userState = AppState();
    userState.user = UserProfile(
      id: 'user-3',
      name: 'Jane User',
      email: 'jane@example.com',
      phone: '',
      birthday: '',
      role: 'user',
    );
    late BuildContext routeContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            routeContext = context;
            return AdminShell(
              state: userState,
              onLoggedOut: () async {},
              onUnauthorized: () =>
                  Navigator.of(routeContext).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('User Home')),
                    ),
                    (_) => false,
                  ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('User Home'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('regular user shell retains the six ordered navigation tabs', (
    tester,
  ) async {
    final state = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartState(),
        child: MaterialApp(
          home: MainScaffold(state: state, onLoggedOut: () async {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.text('Redeem'), findsOneWidget);
    expect(find.text('Deals'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.byIcon(Icons.history_outlined), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Admin Dashboard'), findsNothing);
  });

  testWidgets('six bottom navigation labels fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('Navigation test')),
          bottomNavigationBar: UserBottomNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final navigationBar = tester.getRect(find.byType(NavigationBar));
    for (final label in [
      'Home',
      'Rewards',
      'Redeem',
      'Deals',
      'History',
      'Profile',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(navigationBar.left));
      expect(rect.right, lessThanOrEqualTo(navigationBar.right));
    }
    expect(tester.takeException(), isNull);
  });

  test('membership tiers switch exactly at 500 and 1000 lifetime points', () {
    final state = AppState();
    state.lifetimePoints = 499;
    expect(state.membership, 'Bronze');
    state.lifetimePoints = 500;
    expect(state.membership, 'Silver');
    state.lifetimePoints = 999;
    expect(state.membership, 'Silver');
    state.lifetimePoints = 1000;
    expect(state.membership, 'Gold');
  });

  testWidgets('claimed Lucky Bean button is readable and visibly confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(state: AppState(), onNavigateToRedeem: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('ALREADY CLAIMED'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('ALREADY CLAIMED'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(
      button.style?.foregroundColor?.resolve({WidgetState.disabled}),
      const Color(0xFFF8F2EA),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shows the overview and organized management sections on the admin dashboard',
    (tester) async {
      final state = AppState();
      state.user = UserProfile(
        id: 'admin-2',
        name: 'Admin',
        email: 'admin@example.com',
        phone: '',
        birthday: '',
        role: 'admin',
      );
      state.points = 999723;
      state.lifetimePoints = 999723;
      var logoutCount = 0;
      state.promotions = [
        const Promotion(
          title: 'Weekend Special',
          subtitle: 'Free pastry',
          validUntil: '09/20/26',
          color: Color(0xFF2E7D32),
          icon: Icons.redeem,
          isActive: true,
        ),
        const Promotion(
          title: 'Quiet Hours',
          subtitle: '10% off',
          validUntil: '09/30/26',
          color: Color(0xFFBF360C),
          icon: Icons.access_time,
          isActive: false,
        ),
      ];
      state.rewards = [
        const RewardItem(
          name: 'Free Coffee',
          pointsCost: 150,
          icon: Icons.coffee,
          isActive: true,
        ),
      ];
      state.deals = [
        const DealItem(
          id: 'deal-1',
          name: 'Autumn Latte',
          description: 'Seasonal favorite',
          category: 'Seasonal',
          badge: 'NEW',
          icon: Icons.local_cafe,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            state: state,
            onLoggedOut: () async => logoutCount++,
            onUnauthorized: () {},
            loadSalesReport: (_) async => const SalesReport(
              summary: SalesSummary(),
              deals: [],
              rewards: [],
            ),
            loadAdminOrders:
                ({
                  required status,
                  required offset,
                  search = '',
                  limit = 50,
                }) async => const [],
            loadOrderPointsRate: () async =>
                const OrderPointsRate(pointsPerUnit: 10, pesoPerUnit: 100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Total Promotions'), findsOneWidget);
      expect(find.text('Active Promotions'), findsOneWidget);
      expect(find.text('Total Rewards'), findsOneWidget);
      expect(find.text('Active Deals'), findsOneWidget);
      expect(find.text('Promotions'), findsWidgets);
      expect(find.text('Rewards'), findsWidgets);
      expect(find.text('Deals'), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('Current Points'), findsNothing);
      expect(find.text('Membership Tiers'), findsNothing);
      expect(find.text('999723'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Promotions').first);
      await tester.pumpAndSettle();
      expect(find.text('Weekend Special'), findsOneWidget);
      expect(find.text('Free Coffee'), findsNothing);
      expect(find.text('Search deals'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Rewards').first);
      await tester.pumpAndSettle();
      expect(find.text('Free Coffee'), findsOneWidget);
      expect(find.text('Weekend Special'), findsNothing);
      expect(find.text('Search deals'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Deals').first);
      await tester.pumpAndSettle();
      expect(find.text('Search deals'), findsOneWidget);
      expect(find.text('Free Coffee'), findsNothing);
      expect(find.text('Weekend Special'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Sales').first);
      await tester.pumpAndSettle();
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('Search deals'), findsNothing);
      expect(find.text('No sales yet for this period'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(ChoiceChip, 'All').first);
      await tester.pumpAndSettle();
      expect(find.text('Weekend Special'), findsOneWidget);
      expect(find.text('Free Coffee'), findsOneWidget);
      expect(find.text('Search deals'), findsOneWidget);
      expect(find.text('Sales summary'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Orders').first);
      await tester.pumpAndSettle();
      expect(find.text('Search order code'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Pending'), findsOneWidget);
      expect(find.text('Search deals'), findsNothing);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(logoutCount, 0);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(logoutCount, 1);
    },
  );
}
