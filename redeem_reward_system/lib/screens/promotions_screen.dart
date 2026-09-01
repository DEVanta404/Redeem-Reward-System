import 'package:flutter/material.dart';
import '../app_state.dart';

class PromotionsScreen extends StatefulWidget {
  final List<Promotion> promotions;

  const PromotionsScreen({super.key, required this.promotions});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
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
      body: widget.promotions.isEmpty
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
              itemCount: widget.promotions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _PromoCard(
                promo: widget.promotions[i],
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
    final accent = promo.color;
    final badgeLabel = (promo.category.isNotEmpty)
        ? promo.category.replaceAll('_', ' ').toUpperCase()
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
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(promo.icon, color: accent, size: 25),
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
                            color: const Color(0xFF7D9180).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF9AC29F).withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: const TextStyle(
                              color: Color(0xFFB7E0C0),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          promo.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFF8F2EA),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        if (promo.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            promo.subtitle,
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
                        color: const Color(0xFFFFD881).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Color(0xFFFFD881),
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
                      promo.validUntil,
                      style: const TextStyle(
                        color: Color(0xFFFFD881),
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
                    onPressed: () => _claim(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(112, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      shadowColor: const Color(0xFF2E7D32).withValues(alpha: 0.2),
                    ),
                    child: const Text(
                      'Claim',
                      style: TextStyle(
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

  void _claim(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${promo.title} claimed!'),
          ],
        ),
        backgroundColor: promo.color,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
