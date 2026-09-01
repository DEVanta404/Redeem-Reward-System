import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/supabase_profiles.dart';

class PromotionsScreen extends StatefulWidget {
  final List<Promotion> promotions;

  const PromotionsScreen({super.key, required this.promotions});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with WidgetsBindingObserver {
  late List<Promotion> _currentPromotions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPromotions = widget.promotions;
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
      _refreshPromotions();
    }
  }

  Future<void> _refreshPromotions() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    try {
      final promotions = await SupabaseProfilesService()
          .getPromotionsWithClaimStatus(activeOnly: true);
      if (mounted) {
        setState(() {
          _currentPromotions = promotions;
          _isLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Failed to refresh promotions: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out expired promotions and sort (unclaimed first, then claimed)
    final activePromotions = _currentPromotions
        .where((p) => !p.isExpired)
        .toList();

    // Sort: unclaimed first, then claimed
    activePromotions.sort((a, b) {
      if (a.claimedByCurrentUser != b.claimedByCurrentUser) {
        return a.claimedByCurrentUser ? 1 : -1;
      }
      return 0;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Promotions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3E2723),
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E2723)),
      ),
      body: activePromotions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 52,
                      color: Color(0xFF8D6E63),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Available Promotion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
              itemCount: activePromotions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _PromoCard(
                promo: activePromotions[i],
                onClaimed: _refreshPromotions,
              ),
            ),
    );
  }
}

class _PromoCard extends StatefulWidget {
  final Promotion promo;
  final VoidCallback? onClaimed;
  const _PromoCard({required this.promo, this.onClaimed});

  @override
  State<_PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<_PromoCard> {
  @override
  Widget build(BuildContext context) {
    final badgeLabel = (widget.promo.category.isNotEmpty)
        ? widget.promo.category.replaceAll('_', ' ').toUpperCase()
        : 'PROMO';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A342D),
            const Color(0xFF3A2723),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C1D1A).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF5D4037).withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC19A6B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFC19A6B).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(widget.promo.icon, color: const Color(0xFFD4A574), size: 25),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B8B7E).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFC19A6B).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              color: Color(0xFFD4A574),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.promo.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF8F2EA),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        if (widget.promo.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.promo.subtitle,
                            style: const TextStyle(
                              color: Color(0xFFE7DACC),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E8CD).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEAD8B2).withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A574).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Color(0xFFD4A574),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Valid until',
                      style: TextStyle(
                        color: Color(0xFFE7DACC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.promo.validUntil,
                      style: const TextStyle(
                        color: Color(0xFFD4A574),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: widget.promo.claimedByCurrentUser ? null : () => _claim(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.promo.claimedByCurrentUser ? Colors.grey : const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(112, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                    ),
                    child: Text(
                      widget.promo.claimedByCurrentUser ? 'Claimed' : 'Claim',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _claim() async {
    // Capture context before async operation to avoid async gap warning
    final context = this.context;
    final service = SupabaseProfilesService();
    final success = await service.claimPromotion(widget.promo.id);

    if (!mounted) return;

    if (success) {
      // Refresh promotions from database to get updated claim status
      widget.onClaimed?.call();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('${widget.promo.title} claimed!'),
            ],
          ),
          backgroundColor: widget.promo.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to claim promotion. Please try again.'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
