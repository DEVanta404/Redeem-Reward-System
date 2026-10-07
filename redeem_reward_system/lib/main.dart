import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';
import 'services/cart_state.dart';
import 'screens/admin_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/rewards_screen.dart';
import 'services/supabase_profiles.dart';
import 'screens/redeem_screen.dart';
import 'screens/deals_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/user_bottom_navigation_bar.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'services/daily_rewards_service.dart';
import 'screens/password_update_screen.dart';
import 'screens/notifications_screen.dart';
import 'services/notifications_service.dart';

const supabaseUrl = 'https://hlvwhxtneqdsnofhoplr.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhsdndoeHRuZXFkc25vZmhvcGxyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxMjQ3NTAsImV4cCI6MjA5OTcwMDc1MH0.NadYDiPM5rp_8Fgg_ikzGhR8ctk0dQ99lHZy1IKhiw4';

String resolveProfileRole(Map<String, dynamic>? profile) =>
    profile?['role']?.toString().trim().toLowerCase() == 'admin'
    ? 'admin'
    : 'user';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  runApp(const RewardApp());
}

class RewardApp extends StatefulWidget {
  const RewardApp({super.key});

  @override
  State<RewardApp> createState() => _RewardAppState();
}

class _RewardAppState extends State<RewardApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final CartState _cart = CartState();
  AppState _state = AppState();
  StreamSubscription<AuthState>? _authSubscription;
  String? _resolvingUserId;
  String? _activeUserId;
  int _resolutionId = 0;
  bool _sessionResolved = false;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _authSubscription = _client.auth.onAuthStateChange.listen(
      _handleAuthState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Auth state stream failed: $error');
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = _client.auth.currentSession;
      if (mounted && session != null) unawaited(_resolveSession(session));
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cart.dispose();
    super.dispose();
  }

  void _handleAuthState(AuthState authState) {
    if (authState.event == AuthChangeEvent.initialSession) {
      final session = authState.session;
      if (session != null) unawaited(_resolveSession(session));
      return;
    }

    if (authState.event == AuthChangeEvent.signedOut ||
        authState.session == null) {
      _handleSignedOut();
      return;
    }

    unawaited(_resolveSession(authState.session!));
  }

  Future<void> _resolveSession(Session session) async {
    final userId = session.user.id;
    if (_resolvingUserId == userId ||
        (_sessionResolved && _activeUserId == userId)) {
      return;
    }

    final requestId = ++_resolutionId;
    _resolvingUserId = userId;
    _sessionResolved = false;
    _replaceRoot(const _RoleLoadingScreen());
    _resetUserState();

    try {
      final profile = await SupabaseProfilesService().getProfile(userId);
      if (!mounted || requestId != _resolutionId) return;

      final role = resolveProfileRole(profile);
      final email = profile?['email']?.toString() ?? session.user.email ?? '';
      final name = profile?['name']?.toString().trim().isNotEmpty == true
          ? profile!['name'].toString()
          : email.split('@').first;

      _state.user = UserProfile(
        id: userId,
        name: name.isEmpty ? 'New Customer' : name,
        email: email,
        phone: profile?['phone']?.toString() ?? '',
        birthday: profile?['birthday']?.toString() ?? '',
        avatarUrl: profile?['avatar_url']?.toString() ?? '',
        role: role,
      );

      if (role == 'admin') {
        _state.points = 0;
        _state.lifetimePoints = 0;
        _state.pointsEarnedToday = 0;
        _state.transactions = [];
      } else {
        _state.points = int.tryParse(profile?['points']?.toString() ?? '') ?? 0;
        _state.lifetimePoints =
            int.tryParse(profile?['lifetime_points']?.toString() ?? '') ??
            _state.points;
        final service = SupabaseProfilesService();
        _state.promotions = await service.getPromotions(activeOnly: true);
        _state.rewards = await service.getRewards(activeOnly: true);
        try {
          _state.deals = await service.getDeals(activeOnly: true);
        } catch (error) {
          debugPrint(
            'Using built-in deals until Supabase deals are available: $error',
          );
        }
        _state.transactions = await service.getRecentTransactions(
          userId: userId,
        );
        _state.pointsEarnedToday =
            await DailyRewardsService().getTodaysRewardPoints(userId) ?? 0;
      }

      if (!mounted || requestId != _resolutionId) return;
      _activeUserId = userId;
      _resolvingUserId = null;
      _sessionResolved = true;
      final mustChangePassword =
          profile?['must_change_password'] == true ||
          profile?['must_change_password']?.toString().toLowerCase() == 'true';
      if (mustChangePassword) {
        _replaceRoot(
          ForcedPasswordUpdateScreen(
            email: email,
            displayName: name,
            onSignOut: _signOut,
            onPasswordUpdated: () async {
              _replaceRoot(_buildRoleShell(role));
            },
          ),
        );
      } else {
        _replaceRoot(_buildRoleShell(role));
      }
    } catch (error) {
      if (!mounted || requestId != _resolutionId) return;
      _resolvingUserId = null;
      _replaceRoot(
        _RoleLoadFailureScreen(
          onRetry: () => _resolveSession(session),
          onSignOut: _signOut,
        ),
      );
      debugPrint('Failed to resolve the signed-in profile role: $error');
    }
  }

  void _onSplashFinished() {
    final session = _client.auth.currentSession;
    if (session == null) {
      _replaceRoot(_buildAuthScreen());
    } else {
      unawaited(_resolveSession(session));
    }
  }

  void _handleSignedOut() {
    if (_activeUserId == null && _resolvingUserId == null && _sessionResolved) {
      return;
    }
    _resolutionId++;
    _activeUserId = null;
    _resolvingUserId = null;
    _sessionResolved = true;
    _resetUserState();
    _replaceRoot(_buildAuthScreen());
  }

  void _resetUserState() {
    _cart.clear();
    _state = AppState();
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();
    if (_client.auth.currentSession == null) _handleSignedOut();
  }

  Widget _buildAuthScreen() => AuthScreen(
    onAuthenticated: () async {
      final session = _client.auth.currentSession;
      if (session != null) await _resolveSession(session);
    },
  );

  Widget _buildUserShell() =>
      MainScaffold(state: _state, onLoggedOut: _signOut);

  Widget _buildRoleShell(String role) => role == 'admin'
      ? AdminShell(
          state: _state,
          onLoggedOut: _signOut,
          onUnauthorized: _routeUnauthorizedAdmin,
        )
      : _buildUserShell();

  void _routeUnauthorizedAdmin() {
    if (_client.auth.currentSession == null) {
      _handleSignedOut();
    } else {
      _replaceRoot(_buildUserShell());
    }
  }

  void _replaceRoot(Widget screen) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _replaceRoot(screen);
      });
      return;
    }

    navigator.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CartState>.value(
      value: _cart,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Kapetol App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E2723)),
          useMaterial3: true,
        ),
        home: SplashScreen(onFinished: _onSplashFinished),
      ),
    );
  }
}

class _RoleLoadingScreen extends StatelessWidget {
  const _RoleLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F0E8),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF3E2723))),
    );
  }
}

class _RoleLoadFailureScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  const _RoleLoadFailureScreen({
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load your account',
                style: TextStyle(
                  color: Color(0xFF3E2723),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF795548)),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
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

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _index = 0;
  int _unreadNotificationCount = 0;
  RealtimeChannel? _notificationChannel;
  Timer? _notificationRefreshTimer;
  late final NotificationsService _notificationsService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationsService = NotificationsService();
    if (widget.state.user.id.isNotEmpty) _refreshUnreadCount();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRefreshTimer?.cancel();
    final channel = _notificationChannel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) _refreshUnreadCount();
  }

  void _subscribeToNotifications() {
    final userId = widget.state.user.id;
    if (userId.isEmpty) return;
    _notificationChannel = Supabase.instance.client
        .channel('user-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (Supabase.instance.client.auth.currentUser?.id != userId) return;
            _scheduleUnreadRefresh();
            if (!mounted) return;
            final row = payload.newRecord;
            final title = row['title']?.toString() ?? 'New notification';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(title),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: _openNotifications,
                ),
              ),
            );
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
            callback: (_) {
              if (Supabase.instance.client.auth.currentUser?.id == userId) {
                _scheduleUnreadRefresh();
              }
            },
          )
        .subscribe();
  }

  void _scheduleUnreadRefresh() {
    _notificationRefreshTimer?.cancel();
    _notificationRefreshTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_refreshUnreadCount()),
    );
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final count = await _notificationsService.unreadCount();
      if (!mounted || Supabase.instance.client.auth.currentUser?.id !=
          widget.state.user.id) {
        return;
      }
      setState(() => _unreadNotificationCount = count);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications are temporarily unavailable.')),
      );
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          onNotificationSelected: (notification) async {
            if (notification.type == 'order_placed' ||
                notification.type == 'order_completed' ||
                notification.type == 'order_cancelled') {
              setState(() => _index = 4);
            } else if (notification.type == 'reward_redeemed') {
              setState(() => _index = 1);
            }
          },
        ),
      ),
    );
    if (mounted) await _refreshUnreadCount();
  }

  void _refresh() => setState(() {});

  Future<void> _refreshUserRewardsState() async {
    final userId = widget.state.user.id;
    if (userId.isEmpty) return;

    try {
      final service = SupabaseProfilesService();
      final profile = await service.getProfile(userId);
      final transactions = await service.getRecentTransactions(userId: userId);
      if (!mounted || widget.state.user.id != userId || profile == null) return;

      setState(() {
        widget.state.points =
            int.tryParse(profile['points']?.toString() ?? '') ??
            widget.state.points;
        widget.state.lifetimePoints =
            int.tryParse(profile['lifetime_points']?.toString() ?? '') ??
            widget.state.lifetimePoints;
        widget.state.transactions = transactions;
      });
    } catch (error) {
      debugPrint('Failed to refresh points after order update: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        state: widget.state,
        onNavigateToRedeem: () => setState(() => _index = 2),
        unreadNotificationCount: _unreadNotificationCount,
        onOpenNotifications: _openNotifications,
      ),
      RewardsScreen(state: widget.state),
      RedeemScreen(state: widget.state, onRedeem: _refresh),
      DealsScreen(state: widget.state, isActive: _index == 3),
      OrderHistoryScreen(
        userId: widget.state.user.id,
        isActive: _index == 4,
        onNavigateToDeals: () => setState(() => _index = 3),
        onOrdersChanged: _refreshUserRewardsState,
      ),
      ProfileScreen(
        state: widget.state,
        onProfileUpdated: _refresh,
        onLoggedOut: widget.onLoggedOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: UserBottomNavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
