import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/main.dart';
import 'package:kapetol_app/screens/admin_dashboard_screen.dart';
import 'package:kapetol_app/screens/edit_profile_screen.dart';
import 'package:kapetol_app/screens/profile_screen.dart';

void main() {
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
    expect(find.text('Fresh rewards. Better coffee. More perks.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Kapetol App'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('shows only one save button on the edit profile screen', (tester) async {
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

  testWidgets('shows admin dashboard button only for admin users', (tester) async {
    final adminState = AppState();
    adminState.user = UserProfile(
      id: 'admin-1',
      name: 'Administrator',
      email: 'kapetoladmin@thekapetol.com',
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

    expect(find.text('Admin Dashboard'), findsOneWidget);

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

  testWidgets('shows the overview and organized management sections on the admin dashboard', (tester) async {
    final state = AppState();
    state.user = UserProfile(
      id: 'admin-2',
      name: 'Admin',
      email: 'admin@example.com',
      phone: '',
      birthday: '',
      role: 'admin',
    );
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
        home: AdminDashboardScreen(state: state),
      ),
    );
    await tester.pump();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Total Promotions'), findsOneWidget);
    expect(find.text('Active Promotions'), findsOneWidget);
    expect(find.text('Total Rewards'), findsOneWidget);
    expect(find.text('Active Deals'), findsOneWidget);
    expect(find.text('Promotions'), findsWidgets);
    expect(find.text('Rewards'), findsWidgets);
    expect(find.text('Deals'), findsWidgets);
  });
}
