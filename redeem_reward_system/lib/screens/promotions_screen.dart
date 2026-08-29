import 'package:flutter/material.dart';
import '../app_state.dart';

class PromotionsScreen extends StatelessWidget {
  final List<Promotion> promotions;

  const PromotionsScreen({super.key, required this.promotions});

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
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: promotions.length,
        itemBuilder: (context, i) =>
            _PromoCard(promo: promotions[i]),
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
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          // ── Banner ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: promo.color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(promo.icon,
                    color: Colors.white.withValues(alpha: 0.8), size: 32),
                const SizedBox(height: 10),
                Text(
                  promo.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  promo.subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                ),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Valid until ${promo.validUntil}',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _claim(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: promo.color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Claim',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
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
