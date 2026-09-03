import 'package:flutter/material.dart';
import '../app_state.dart';

class RewardsScreen extends StatelessWidget {
  final AppState state;

  const RewardsScreen({super.key, required this.state});

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
    final recent = state.transactions.take(5).toList();

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

            // ── Recent Transactions ──────────────────────────────────
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No transactions yet.',
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
    final dateStr =
        '${_months[transaction.date.month - 1]} ${transaction.date.day}';

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
