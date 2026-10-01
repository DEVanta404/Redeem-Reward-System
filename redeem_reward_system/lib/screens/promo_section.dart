import 'package:flutter/material.dart';

import '../app_state.dart';
import 'promotions_screen.dart';

class PromoSection extends StatelessWidget {
  final List<Promotion> promotions;

  const PromoSection({super.key, required this.promotions});

  @override
  Widget build(BuildContext context) {
    final visiblePromotions = promotions
        .where((promo) => !promo.isExpired)
        .take(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  builder: (_) => PromotionsScreen(promotions: promotions),
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
        ...visiblePromotions.map((promo) => _PromoCard(promo: promo)),
      ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A342D), Color(0xFF3A2723)],
        ),
        borderRadius: BorderRadius.circular(18),
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
            right: -20,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFC19A6B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFC19A6B).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Icon(
                  promo.icon,
                  color: const Color(0xFFD4A574),
                  size: 22,
                ),
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
                        promo.category.isNotEmpty
                            ? promo.category.replaceAll('_', ' ').toUpperCase()
                            : 'PROMO',
                        style: const TextStyle(
                          color: Color(0xFFD4A574),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promo.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFFF8F2EA),
                        height: 1.25,
                      ),
                    ),
                    if (promo.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        promo.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE7DACC),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A574).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4A574).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Until ${promo.validUntil}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD4A574),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
