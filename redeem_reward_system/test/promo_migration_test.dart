import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kapetol_app/app_state.dart';
import 'package:kapetol_app/main.dart' show supabaseAnonKey, supabaseUrl;
import 'package:kapetol_app/screens/home_screen.dart';
import 'package:kapetol_app/screens/rewards_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  });

  testWidgets(
    'promo section is on Rewards and See all still opens Promotions',
    (tester) async {
      final state = AppState()
        ..promotions = [
          const Promotion(
            id: 'weekend-feature',
            title: 'Weekend Feature',
            subtitle: 'A seasonal coffee special',
            validUntil: '10/31/26',
            color: Color(0xFF2E7D32),
            icon: Icons.star,
            category: 'ANNOUNCEMENT',
          ),
        ];

      await tester.pumpWidget(MaterialApp(home: RewardsScreen(state: state)));
      await tester.pump();

      expect(find.text("Today's Promo"), findsOneWidget);
      expect(find.text('Weekend Feature'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Recent Activity')).dy,
        greaterThan(tester.getTopLeft(find.text('Weekend Feature')).dy),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.text('Promotions'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(state: state, onNavigateToRedeem: () {}),
        ),
      );
      await tester.pump();
      expect(find.text("Today's Promo"), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
