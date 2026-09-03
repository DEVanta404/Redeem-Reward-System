import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rewards_screen.dart';
import 'services/supabase_profiles.dart';
import 'screens/redeem_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/daily_rewards_service.dart';

const supabaseUrl = 'https://hlvwhxtneqdsnofhoplr.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhsdndoeHRuZXFkc25vZmhvcGxyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjQ3NTAsImV4cCI6MjA5OTcwMDc1MH0.NadYDiPM5rp_8Fgg_ikzGhR8ctk0dQ99lHZy1IKhiw4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  runApp(const RewardApp());
}

class RewardApp extends StatelessWidget {
  const RewardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapetol App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E2723)),
        useMaterial3: true,
      ),
      home: const AppFlow(),
    );
  }
}

enum AppPhase { splash, auth, home }

class AppFlow extends StatefulWidget {
  const AppFlow({super.key});

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  AppPhase _phase = AppPhase.splash;
  final AppState _state = AppState();

  void _resetUserState() {
    _state.user = UserProfile(
      id: '',
      name: 'New Customer',
      email: 'newcustomer@email.com',
      phone: '',
      birthday: '',
      avatarPath: '',
      avatarUrl: '',
      role: 'user',
    );
    _state.points = 0;
    _state.lifetimePoints = 0;
    _state.pointsEarnedToday = 0;
    _state.transactions = [];
    _state.rewards = [];
    _state.promotions = [];
    _state.dailyRewardStreak = 0;
    _state.lastDailyRewardDate = null;
    _state.dailyRewardClaimedToday = false;
  }

  @override
  void initState() {
    super.initState();

    // Keep the splash screen for both user types, but transition directly
    // to home for returning users so the auth screen never flashes.
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      if (Supabase.instance.client.auth.currentUser != null) {
        _goHome();
        return;
      }

      setState(() => _phase = AppPhase.auth);
    });
  }

  Future<void> _syncProfileFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _resetUserState();
      return;
    }

    final profile = await SupabaseProfilesService().getProfile(user.id);
    if (!mounted) return;

    if (profile != null) {
      final name = profile['name']?.toString() ?? '';
      final email = profile['email']?.toString() ?? '';
      final phone = profile['phone']?.toString() ?? '';
      final birthday = profile['birthday']?.toString() ?? '';
      final points = int.tryParse(profile['points']?.toString() ?? '0') ?? 0;
      final lifetimePoints =
          int.tryParse(profile['lifetime_points']?.toString() ?? '') ?? points;
      final userId = profile['id']?.toString() ?? '';
      final avatarUrl = profile['avatar_url']?.toString() ?? '';
      final role = profile['role']?.toString() ?? 'user';

      debugPrint(
        'Loaded profile from Supabase: name=$name, email=$email, birthday=$birthday, points=$points, role=$role, avatarUrl=$avatarUrl',
      );

      if (name.isNotEmpty) {
        final service = SupabaseProfilesService();
        final promotions = await service.getPromotions(activeOnly: true);
        final rewards = await service.getRewards(activeOnly: true);
        final transactions = await service.getRecentTransactions(
          userId: userId,
        );
        final pointsEarnedToday = await DailyRewardsService()
            .getTodaysRewardPoints(userId);

        setState(() {
          _state.user = _state.user.copyWith(
            id: userId,
            name: name,
            email: email.isNotEmpty ? email : _state.user.email,
            phone: phone,
            birthday: birthday,
            avatarPath: '',
            avatarUrl: avatarUrl,
            role: role,
          );
          _state.points = points;
          _state.lifetimePoints = lifetimePoints;
          if (pointsEarnedToday != null) {
            _state.pointsEarnedToday = pointsEarnedToday;
          }
          _state.transactions = transactions;
          _state.promotions = promotions;
          _state.rewards = rewards;
        });
      }
    } else {
      _resetUserState();
    }
  }

  Future<void> _goHome() async {
    _resetUserState();
    await _syncProfileFromSupabase();
    if (!mounted) return;
    setState(() => _phase = AppPhase.home);
  }

  Future<void> _goAuth() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    _resetUserState();
    setState(() => _phase = AppPhase.auth);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case AppPhase.splash:
        return SplashScreen(
          onFinished: () {
            if (Supabase.instance.client.auth.currentUser != null) {
              _goHome();
              return;
            }
            setState(() => _phase = AppPhase.auth);
          },
        );
      case AppPhase.auth:
        return AuthScreen(onAuthenticated: _goHome);
      case AppPhase.home:
        return MainScaffold(state: _state, onLoggedOut: _goAuth);
    }
  }
}

class MainScaffold extends StatefulWidget {
  final AppState state;
  final VoidCallback onLoggedOut;

  const MainScaffold({
    super.key,
    required this.state,
    required this.onLoggedOut,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        state: widget.state,
        onNavigateToRedeem: () => setState(() => _index = 2),
      ),
      RewardsScreen(state: widget.state),
      RedeemScreen(state: widget.state, onRedeem: _refresh),
      DealsScreen(state: widget.state),
      ProfileScreen(
        state: widget.state,
        onProfileUpdated: _refresh,
        onLoggedOut: widget.onLoggedOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF3E2723).withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF3E2723)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star, color: Color(0xFF3E2723)),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.redeem),
            selectedIcon: Icon(Icons.redeem, color: Color(0xFF3E2723)),
            label: 'Redeem',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer, color: Color(0xFF3E2723)),
            label: 'Deals',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF3E2723)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
