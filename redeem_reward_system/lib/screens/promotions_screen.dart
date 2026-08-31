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
        title: const Text('Promotions',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
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
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: widget.promotions.length,
              itemBuilder: (context, i) =>
                  _PromoCard(promo: widget.promotions[i]),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE6D8C9),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Icon(promo.icon, color: accent, size: 26),
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
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          (promo.category.isNotEmpty)
                              ? promo.category.replaceAll('_', ' ').toUpperCase()
                              : 'PROMO',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        promo.title,
                        style: const TextStyle(
                          color: Color(0xFF3E2723),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (promo.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          promo.subtitle,
                          style: const TextStyle(
                            color: Color(0xFF6D4C41),
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8DF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: const Color(0xFF5D4037),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Valid until',
                        style: TextStyle(
                          color: Color(0xFF5D4037),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    promo.validUntil,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                ElevatedButton(
                  onPressed: () => _claim(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
