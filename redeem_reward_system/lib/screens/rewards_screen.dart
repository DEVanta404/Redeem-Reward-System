import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/points_overview_service.dart';
import '../services/supabase_profiles.dart';
import '../widgets/points_overview_card.dart';
import 'points_history_screen.dart';
import 'promo_section.dart';

class RewardsScreen extends StatefulWidget {
  final AppState state;
  final bool isActive;
  final VoidCallback? onSeeAll;

  const RewardsScreen({
    super.key,
    required this.state,
    this.isActive = true,
    this.onSeeAll,
  });

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _overviewService = PointsOverviewService();
  RealtimeChannel? _transactionsChannel;
  String? _subscribedUserId;
  PointsOverview? _overview;
  PointsChartPeriod _chartPeriod = PointsChartPeriod.week;
  bool _overviewLoading = true;
  Object? _overviewError;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _subscribeToTransactions();
    if (widget.isActive) unawaited(_refreshAll());
  }

  @override
  void didUpdateWidget(covariant RewardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final userChanged = oldWidget.state.user.id != widget.state.user.id;
    if (userChanged) {
      _removeTransactionsSubscription();
      state.transactions = [];
      _overview = null;
      _overviewError = null;
      _overviewLoading = true;
      _subscribeToTransactions();
      if (widget.isActive) {
        unawaited(_refreshAll());
      }
    }
    if (!userChanged && widget.isActive && !oldWidget.isActive) {
      unawaited(_refreshAll());
    }
  }

  @override
  void dispose() {
    _removeTransactionsSubscription();
    super.dispose();
  }

  void _subscribeToTransactions() {
    final userId = state.user.id;
    if (userId.isEmpty) return;
    _subscribedUserId = userId;
    _transactionsChannel = Supabase.instance.client
        .channel('rewards-transactions-$userId-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => unawaited(_refreshAll()),
        )
        .subscribe();
  }

  void _removeTransactionsSubscription() {
    final channel = _transactionsChannel;
    _transactionsChannel = null;
    _subscribedUserId = null;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_refreshTransactions(), _loadOverview()]);
  }

  Future<void> _loadOverview() async {
    if (state.user.id.isEmpty || state.user.id != _subscribedUserId) {
      if (mounted) {
        setState(() {
          _overview = null;
          _overviewLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _overviewLoading = true;
        _overviewError = null;
      });
    }
    try {
      final overview = await _overviewService.load(period: _chartPeriod);
      if (!mounted || state.user.id != _subscribedUserId) return;
      state.points = overview.balance;
      state.lifetimePoints = overview.lifetimeEarned;
      setState(() {
        _overview = overview;
        _overviewLoading = false;
        _overviewError = null;
      });
    } catch (error) {
      debugPrint('Failed to load points overview: $error');
      if (!mounted) return;
      setState(() {
        _overviewLoading = false;
        _overviewError = error;
      });
    }
  }

  Future<void> _changeChartPeriod(PointsChartPeriod period) async {
    if (period == _chartPeriod) return;
    setState(() => _chartPeriod = period);
    await _loadOverview();
  }

  Future<void> _refreshTransactions() async {
    final userId = state.user.id;
    if (userId.isEmpty) return;
    try {
      final transactions = await SupabaseProfilesService()
          .getRecentTransactionsStrict(userId: userId, limit: 10);
      if (!mounted || state.user.id != userId || _subscribedUserId != userId) {
        return;
      }
      setState(() => state.transactions = transactions);
    } catch (error) {
      debugPrint('Failed to refresh recent points activity: $error');
      if (mounted && widget.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recent activity could not be refreshed.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = state.transactions.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Rewards',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: const Color(0xFF3E2723),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MembershipTiers(lifetimePoints: state.lifetimePoints),
              const SizedBox(height: 16),
              if (_overviewLoading && _overview == null)
                const _PointsOverviewLoading()
              else if (_overviewError != null && _overview == null)
                _PointsOverviewError(onRetry: _loadOverview)
              else if (_overview != null)
                PointsOverviewCard(
                  overview: _overview!,
                  period: _chartPeriod,
                  onPeriodChanged: _changeChartPeriod,
                  onViewHistory:
                      widget.onSeeAll ??
                      () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const PointsHistoryScreen(),
                        ),
                      ),
                ),
              const SizedBox(height: 16),

              PromoSection(promotions: state.promotions),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  if (recent.isNotEmpty)
                    TextButton(
                      onPressed:
                          widget.onSeeAll ??
                          () => Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const PointsHistoryScreen(),
                            ),
                          ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8D6E63),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'See all',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No activity yet.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              if (recent.isNotEmpty)
                ...recent.map((t) => _TransactionTile(transaction: t)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsOverviewLoading extends StatelessWidget {
  const _PointsOverviewLoading();

  @override
  Widget build(BuildContext context) => Container(
    height: 116,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    alignment: Alignment.center,
    child: const CircularProgressIndicator(color: Color(0xFF3E2723)),
  );
}

class _PointsOverviewError extends StatelessWidget {
  final VoidCallback onRetry;

  const _PointsOverviewError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        const Text(
          'Points overview could not be loaded.',
          style: TextStyle(color: Color(0xFF5D4037)),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

// ─── Membership Tiers Widget ─────────────────────────────────────────────────

class _MembershipTiers extends StatelessWidget {
  final int lifetimePoints;
  const _MembershipTiers({required this.lifetimePoints});

  String get _currentTierName =>
      MembershipTier.forLifetimePoints(lifetimePoints).name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Membership Tiers',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF3E2723),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: MembershipTier.values.map((tier) {
              final isReached = lifetimePoints >= tier.minimumLifetimePoints;
              final isCurrent = tier.name == _currentTierName;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReached
                            ? tier.color.withValues(alpha: 0.13)
                            : Colors.grey.withValues(alpha: 0.07),
                        border: isCurrent
                            ? Border.all(color: tier.color, width: 2.5)
                            : null,
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        color: isReached ? tier.color : Colors.grey[300],
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tier.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrent ? tier.color : Colors.grey,
                      ),
                    ),
                    Text(
                      '${tier.minimumLifetimePoints}+ pts',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Tile ────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  const _TransactionTile({required this.transaction});

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final isEarned = transaction.points > 0;
    final color = isEarned ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final date = transaction.date.toUtc().add(const Duration(hours: 8));
    final dateStr = '${_months[date.month - 1]} ${date.day}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEarned ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF3E2723),
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '${isEarned ? '+' : ''}${transaction.points}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
