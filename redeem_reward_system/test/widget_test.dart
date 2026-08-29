import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/main.dart';
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
}
