import 'package:flutter/material.dart';
import '../app_state.dart';

class RedeemScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onRedeem;

  const RedeemScreen({super.key, required this.state, required this.onRedeem});

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when returning to this screen
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('Redeem Rewards',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Available points banner ────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF3E2723),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Color(0xFFFFA000), size: 22),
                const SizedBox(width: 8),
                Text(
                  'Available: ${widget.state.points} pts',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ],
            ),
          ),

          // ── Reward cards ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: widget.state.rewards.length,
              itemBuilder: (context, i) {
                final reward = widget.state.rewards[i];
                final canRedeem = widget.state.points >= reward.pointsCost;
                return _RewardCard(
                  reward: reward,
                  canRedeem: canRedeem,
                  onRedeem: () => _confirmRedeem(context, reward),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRedeem(BuildContext context, RewardItem reward) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Redemption',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723).withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(reward.icon,
                  size: 40, color: const Color(0xFF3E2723)),
            ),
            const SizedBox(height: 12),
            Text(reward.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'This will deduct ${reward.pointsCost} pts from your balance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining: ${widget.state.points - reward.pointsCost} pts',
              style: const TextStyle(
                  color: Color(0xFFFFA000), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.state.redeemReward(reward);
              if (!context.mounted) return;
              widget.onRedeem();
              _showSuccess(context, reward);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context, RewardItem reward) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${reward.name} redeemed!'),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── Reward Card ─────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  final RewardItem reward;
  final bool canRedeem;
  final VoidCallback onRedeem;

  const _RewardCard({
    required this.reward,
    required this.canRedeem,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: canRedeem
            ? Border.all(
                color: const Color(0xFF3E2723).withValues(alpha: 0.15))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canRedeem
                  ? const Color(0xFF3E2723).withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              reward.icon,
              color: canRedeem
                  ? const Color(0xFF3E2723)
                  : Colors.grey[400],
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: canRedeem
                        ? const Color(0xFF3E2723)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.stars,
                        color: canRedeem
                            ? const Color(0xFFFFA000)
                            : Colors.grey[400],
                        size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${reward.pointsCost} pts',
                      style: TextStyle(
                        color: canRedeem
                            ? const Color(0xFFFFA000)
                            : Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canRedeem ? onRedeem : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  canRedeem ? const Color(0xFF3E2723) : Colors.grey[200],
              foregroundColor:
                  canRedeem ? Colors.white : Colors.grey[500],
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              canRedeem ? 'Redeem' : 'Locked',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
