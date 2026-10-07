import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/supabase_profiles.dart';
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
  RealtimeChannel? _transactionsChannel;
  String? _subscribedUserId;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _subscribeToTransactions();
    if (widget.isActive) unawaited(_refreshTransactions());
  }

  @override
  void didUpdateWidget(covariant RewardsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.user.id != widget.state.user.id) {
      _removeTransactionsSubscription();
      _subscribeToTransactions();
    }
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(_refreshTransactions());
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
          callback: (_) => unawaited(_refreshTransactions()),
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

  Color get _membershipColor {
    switch (state.membership) {
      case 'Gold':
        return const Color(0xFFFFA000);
      case 'Silver':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF795548);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary card ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3E2723).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Points',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.points}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.arrow_upward,
                              color: Color(0xFF80CBC4),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+${state.pointsEarnedToday} Today',
                              style: const TextStyle(
                                color: Color(0xFF80CBC4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 80,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  Column(
                    children: [
                      const Text(
                        'Membership',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        Icons.workspace_premium,
                        color: _membershipColor,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.membership,
                        style: TextStyle(
                          color: _membershipColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Membership Tiers ─────────────────────────────────────
            _MembershipTiers(lifetimePoints: state.lifetimePoints),
            const SizedBox(height: 24),

            PromoSection(promotions: state.promotions),
            const SizedBox(height: 12),

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
                    onPressed: widget.onSeeAll ??
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
              )
            else
              ...recent.map((t) => _TransactionTile(transaction: t)),
          ],
        ),
      ),
    );
  }
}

// ─── Membership Tiers Widget ─────────────────────────────────────────────────

class _TierData {
  final String name;
  final int minPoints;
  final Color color;
  const _TierData(this.name, this.minPoints, this.color);
}

class _MembershipTiers extends StatelessWidget {
  final int lifetimePoints;
  const _MembershipTiers({required this.lifetimePoints});

  static const _tiers = [
    _TierData('Bronze', 0, Color(0xFF795548)),
    _TierData('Silver', 500, Color(0xFF9E9E9E)),
    _TierData('Gold', 1000, Color(0xFFFFA000)),
  ];

  String get _currentTierName {
    if (lifetimePoints >= 1000) return 'Gold';
    if (lifetimePoints >= 500) return 'Silver';
    return 'Bronze';
  }

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
            children: _tiers.map((tier) {
              final isReached = lifetimePoints >= tier.minPoints;
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
                      '${tier.minPoints}+ pts',
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
    final dateStr =
        '${_months[date.month - 1]} ${date.day}';

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
