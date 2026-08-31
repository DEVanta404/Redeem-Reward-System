import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../services/daily_rewards_service.dart';
import 'promotions_screen.dart';
import 'daily_reward_slot_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onNavigateToRedeem;

  const HomeScreen({
    super.key,
    required this.state,
    required this.onNavigateToRedeem,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DailyRewardsService _dailyRewardsService;
  int _dailyStreak = 0;
  bool _canClaimToday = false;
  bool _isLuckyDay = false;
  late Timer _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  DateTime? _rewardResetAt;

  @override
  void initState() {
    super.initState();
    _dailyRewardsService = DailyRewardsService();
    _loadDailyRewardState();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        if (_rewardResetAt != null) {
          final claimTime = _rewardResetAt!.subtract(const Duration(hours: 20));
          _timeRemaining = DailyRewardsService.getCooldownRemainingForClaim(
            claimTime: claimTime,
            now: DateTime.now(),
          );
          _canClaimToday = _timeRemaining == Duration.zero;
        } else {
          _timeRemaining = Duration.zero;
          _canClaimToday = true;
        }
      });
    });
  }

  Future<void> _loadDailyRewardState() async {
    if (widget.state.user.id.isEmpty) return;

    try {
      final streak = await _dailyRewardsService.calculateStreak(
        widget.state.user.id,
      );
      final lastClaim = await _dailyRewardsService.getLastClaim(
        widget.state.user.id,
      );
      final latestClaimInCooldown = await _dailyRewardsService.getTodaysClaim(
        widget.state.user.id,
      );

      setState(() {
        _dailyStreak = streak.currentStreak;
        _isLuckyDay = (streak.currentStreak + 1) % 7 == 0;
        widget.state.dailyRewardStreak = streak.currentStreak;

        if (lastClaim != null) {
          _rewardResetAt = lastClaim.claimedAt.add(const Duration(hours: 20));
        } else {
          _rewardResetAt = null;
        }

        _canClaimToday = latestClaimInCooldown == null;
        widget.state.dailyRewardClaimedToday = !_canClaimToday;

        if (lastClaim != null) {
          debugPrint('LAST_CLAIM_FROM_DB: ${lastClaim.claimedAt.toUtc()}');
          debugPrint('NOW: ${DateTime.now().toUtc()}');
          debugPrint(
            'DB_REMAINING: ${DailyRewardsService.getCooldownRemainingForClaim(claimTime: lastClaim.claimedAt, now: DateTime.now())}',
          );
        }

        if (_canClaimToday) {
          _timeRemaining = Duration.zero;
        } else if (_rewardResetAt != null && lastClaim != null) {
          _timeRemaining = DailyRewardsService.getCooldownRemainingForClaim(
            claimTime: lastClaim.claimedAt,
            now: DateTime.now(),
          );
        } else {
          _timeRemaining = Duration.zero;
        }
      });
    } catch (e) {
      debugPrint('Error loading daily reward state: $e');
    }
  }

  Future<void> _claimDailyReward() async {
    // ============================================================
    // Ask Supabase to perform the ENTIRE claim operation.
    // ============================================================
    try {
      final result = await _dailyRewardsService.claimDailyReward();
      if (result == null) {
        throw Exception('No reward result returned from Supabase.');
      }

      debugPrint('=== DAILY REWARD CLAIM RESPONSE ===');
      debugPrint('Result: $result');

      final reward =
          int.tryParse(result['reward_points']?.toString() ?? '') ?? 0;
      final streakDay =
          int.tryParse(result['streak_day']?.toString() ?? '') ?? 1;
      final newPoints =
          int.tryParse(result['new_points']?.toString() ?? '') ??
          widget.state.points;
      final claimedAtValue = result['claimed_at'];
      final claimedAt = claimedAtValue is String
          ? DateTime.tryParse(claimedAtValue)?.toLocal() ?? DateTime.now()
          : DateTime.now();

      debugPrint('Reward from Supabase: $reward');
      debugPrint('Streak from Supabase: $streakDay');
      debugPrint('New points from Supabase: $newPoints');
      debugPrint('Claimed at from Supabase: ${claimedAt.toUtc()}');
      debugPrint('Now: ${DateTime.now().toUtc()}');
      debugPrint(
        'Computed remaining: ${DailyRewardsService.getCooldownRemainingForClaim(claimTime: claimedAt, now: DateTime.now())}',
      );

      // ============================================================
      // Always trust the server-issued values from Supabase.
      // ============================================================
      widget.state.points = newPoints;
      _rewardResetAt = claimedAt.add(const Duration(hours: 20));
      _timeRemaining = DailyRewardsService.getCooldownRemainingForClaim(
        claimTime: claimedAt,
        now: DateTime.now(),
      );

      // ============================================================
      // Show the existing animation using the server-issued reward.
      // ============================================================
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyRewardSlotScreen(
            rewardAmount: reward,
            isLuckyDay: streakDay == 7,
            onRewardClaimed: () async {
              if (!mounted) return false;
              setState(() {
                widget.state.points = newPoints;
                widget.state.pointsEarnedToday += reward;
              });
              await _loadDailyRewardState();
              return true;
            },
          ),
        ),
      );

      if (!mounted) return;
      await _loadDailyRewardState();
    } on PostgrestException catch (error) {
      debugPrint('Daily reward database error: $error');
      if (!mounted) return;
      setState(() {
        _canClaimToday = true;
      });
      if (error.message.contains('DAILY_REWARD_ALREADY_CLAIMED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already claimed your daily reward today!'),
          ),
        );
        await _loadDailyRewardState();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not claim reward: ${error.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error claiming daily reward: $e');
      if (!mounted) return;
      setState(() {
        _canClaimToday = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while claiming your reward.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.state.nextReward;
    final ptsAway = next.pointsCost - widget.state.points;
    final progress = (widget.state.points / next.pointsCost).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF795548),
                        ),
                      ),
                      Text(
                        widget.state.user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E2723),
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3E2723),
                    radius: 24,
                    backgroundImage:
                        widget.state.user.avatarUrl.trim().isNotEmpty
                        ? NetworkImage(widget.state.user.avatarUrl)
                        : (widget.state.user.avatarPath.trim().isNotEmpty
                              ? FileImage(File(widget.state.user.avatarPath))
                              : null),
                    child:
                        (widget.state.user.avatarUrl.trim().isEmpty &&
                            widget.state.user.avatarPath.trim().isEmpty)
                        ? Text(
                            widget.state.user.name.isNotEmpty
                                ? widget.state.user.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Points Card ─────────────────────────────────────────
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
                      color: const Color(0xFF3E2723).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Points',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFA000,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFFFFA000,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            widget.state.membership,
                            style: const TextStyle(
                              color: Color(0xFFFFCA28),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${widget.state.points}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8, left: 8),
                          child: Text(
                            'pts',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+${widget.state.pointsEarnedToday}',
                              style: const TextStyle(
                                color: Color(0xFF80CBC4),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'today',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${next.pointsCost} pts',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFFA000),
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ptsAway > 0
                          ? '🎯 Only $ptsAway pts away from ${next.name}'
                          : '🎉 You can redeem ${next.name}!',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick Cards ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.emoji_events,
                      label: 'Next Reward',
                      value: next.name,
                      color: const Color(0xFFFFA000),
                      onTap: widget.onNavigateToRedeem,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      icon: Icons.trending_up,
                      label: 'Points Today',
                      value: '+${widget.state.pointsEarnedToday} pts',
                      color: const Color(0xFF43A047),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Daily Reward Card ───────────────────────────────────
              _buildDailyRewardCard(),
              const SizedBox(height: 24),

              // ── Today's Promo ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Today's Promo",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PromotionsScreen(
                          promotions: widget.state.promotions,
                        ),
                      ),
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(color: Color(0xFFFFA000)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...widget.state.promotions
                  .take(2)
                  .map((p) => _PromoCard(promo: p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRewardCard() {
    final streakText = _dailyStreak == 0
        ? 'Start your streak!'
        : 'Day $_dailyStreak';
    final streakEmoji = _isLuckyDay && _dailyStreak > 0 ? '🌟' : '🔥';
    final timeStr = _dailyRewardsService.formatTimeRemaining(_timeRemaining);
    final bool isLucky = _isLuckyDay && _dailyStreak > 0;
    final bool isUrgent = !_canClaimToday && _timeRemaining.inHours < 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLucky
              ? const [Color(0xFF7B4F2B), Color(0xFF5D341D)]
              : const [Color(0xFF4E342E), Color(0xFF3E2723)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLucky
              ? const Color(0xFFF7D57A).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.10),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLucky ? const Color(0xFFF7D57A) : const Color(0xFF3E2723))
                .withValues(alpha: isLucky ? 0.38 : 0.22),
            blurRadius: isLucky ? 18 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 4),
          const Text(
            '☕ Lucky Bean',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Give it a spin!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFE9D8C5),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$streakEmoji Current Streak',
                style: const TextStyle(fontSize: 12, color: Color(0xFFE9D8C5)),
              ),
              const SizedBox(width: 8),
              Text(
                streakText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (i) {
              final isFilled = i < _dailyStreak;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  isFilled ? '★' : '☆',
                  style: TextStyle(
                    fontSize: 16,
                    color: isFilled
                        ? const Color(0xFFF6D58D)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUrgent
                  ? const Color(0xFFF7D57A).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isUrgent
                    ? const Color(0xFFF7D57A).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 12,
                  color: isUrgent
                      ? const Color(0xFFF7D57A)
                      : const Color(0xFFE9D8C5),
                ),
                const SizedBox(width: 6),
                Text(
                  _canClaimToday ? 'Next reward in' : 'Reset in',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isUrgent
                        ? const Color(0xFFF9E7A7)
                        : const Color(0xFFE9D8C5),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _canClaimToday ? 'Now' : timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? const Color(0xFFFFF4CC) : Colors.white,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLucky
                    ? const Color(0xFFF7D57A)
                    : const Color(0xFFE7B765),
                foregroundColor: const Color(0xFF3E2723),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _canClaimToday ? _claimDailyReward : null,
              child: Text(
                _canClaimToday ? 'CLAIM REWARD' : 'ALREADY CLAIMED',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3E2723),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Promotion promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: promo.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(promo.icon, color: promo.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  promo.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF3E2723),
                  ),
                ),
                Text(
                  promo.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: promo.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Until ${promo.validUntil}',
              style: TextStyle(
                fontSize: 10,
                color: promo.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
