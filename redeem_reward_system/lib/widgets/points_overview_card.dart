import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/points_overview_service.dart';

class PointsOverviewCard extends StatefulWidget {
  final PointsOverview overview;
  final PointsChartPeriod period;
  final ValueChanged<PointsChartPeriod> onPeriodChanged;
  final VoidCallback onViewHistory;

  const PointsOverviewCard({
    super.key,
    required this.overview,
    required this.period,
    required this.onPeriodChanged,
    required this.onViewHistory,
  });

  @override
  State<PointsOverviewCard> createState() => _PointsOverviewCardState();
}

class _PointsOverviewCardState extends State<PointsOverviewCard> {
  static const _animationDuration = Duration(milliseconds: 250);
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final tier = MembershipTier.forLifetimePoints(overview.lifetimeEarned);
    final nextTierIndex = MembershipTier.values.indexOf(tier) + 1;
    final nextTier = nextTierIndex < MembershipTier.values.length
        ? MembershipTier.values[nextTierIndex]
        : null;
    final remaining = nextTier == null
        ? 0
        : nextTier.minimumLifetimePoints - overview.lifetimeEarned;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Tooltip(
            message: _expanded ? 'Hide details' : 'Show details',
            child: Semantics(
              button: true,
              label: _expanded
                  ? 'Hide points overview details'
                  : 'Show points overview details',
              hint: _expanded
                  ? 'Collapse statistics and points trend'
                  : 'Expand statistics and points trend',
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Points Overview',
                          style: TextStyle(
                            color: Color(0xFF3E2723),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _expanded ? 'Hide details' : 'Show details',
                        style: const TextStyle(
                          color: Color(0xFF6D4C41),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: _animationDuration,
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF6D4C41),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: 'Current balance',
                  value: _formatPoints(overview.balance),
                  accent: const Color(0xFF3E2723),
                  prominent: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewMetric(
                  label: 'Lifetime earned',
                  value: _formatPoints(overview.lifetimeEarned),
                  accent: const Color(0xFF6D4C41),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tier progress',
                  style: TextStyle(
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _tierProgressLabel(nextTier: nextTier, remaining: remaining),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF6D4C41),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TierProgress(value: overview.lifetimeEarned),
          AnimatedSize(
            duration: _animationDuration,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _OverviewMetric(
                              label: 'Total redeemed',
                              value: _formatPoints(overview.totalRedeemed),
                              accent: const Color(0xFF9A4D43),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _OverviewMetric(
                              label: 'Earned this month',
                              value: _formatPoints(overview.earnedThisMonth),
                              accent: const Color(0xFF2E7D32),
                              supportingText: _monthComparison(overview),
                              supportingColor: _monthComparisonColor(overview),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Points trend',
                              style: TextStyle(
                                color: Color(0xFF3E2723),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SegmentedButton<PointsChartPeriod>(
                            segments: PointsChartPeriod.values
                                .map(
                                  (option) => ButtonSegment<PointsChartPeriod>(
                                    value: option,
                                    label: Text(option.label),
                                  ),
                                )
                                .toList(),
                            selected: {widget.period},
                            onSelectionChanged: (selection) =>
                                widget.onPeriodChanged(selection.first),
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              textStyle: WidgetStateProperty.all(
                                const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? Colors.white
                                    : const Color(0xFF5D4037),
                              ),
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? const Color(0xFF5D4037)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (overview.hasChartData)
                        _PointsTrendChart(buckets: overview.buckets)
                      else
                        Container(
                          height: 112,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F5F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No points activity in this period yet.',
                            style: TextStyle(
                              color: Color(0xFF795548),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: Color(0xFF6D8E61), label: 'Earned'),
                          SizedBox(width: 18),
                          _LegendDot(
                            color: Color(0xFFC77768),
                            label: 'Redeemed',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: widget.onViewHistory,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6D4C41),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View points history',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _tierProgressLabel({
    required MembershipTier? nextTier,
    required int remaining,
  }) {
    if (nextTier == null) return "You've reached the top tier 🎉";
    return '$remaining ${remaining == 1 ? 'pt' : 'pts'} to ${nextTier.name}';
  }

  String _monthComparison(PointsOverview overview) {
    if (overview.earnedLastMonth == 0) {
      return overview.earnedThisMonth == 0
          ? 'Same as last month'
          : 'New this month';
    }
    final difference = overview.earnedThisMonth - overview.earnedLastMonth;
    if (difference == 0) return 'Same as last month';
    return '${difference > 0 ? '+' : '−'}${_formatPoints(difference.abs())} vs last month';
  }

  Color _monthComparisonColor(PointsOverview overview) {
    if (overview.earnedThisMonth == overview.earnedLastMonth) {
      return const Color(0xFF8D8178);
    }
    return overview.earnedThisMonth > overview.earnedLastMonth
        ? const Color(0xFF2E7D32)
        : const Color(0xFF9A4D43);
  }
}

class _OverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool prominent;
  final String? supportingText;
  final Color? supportingColor;

  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.accent,
    this.prominent = false,
    this.supportingText,
    this.supportingColor,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF6D5B53), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: prominent ? 23 : 18,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (supportingText != null) ...[
          const SizedBox(height: 3),
          Text(
            supportingText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: supportingColor ?? const Color(0xFF6D5B53),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );
}

class _TierProgress extends StatelessWidget {
  final int value;

  const _TierProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    final progress = (value.clamp(0, 1000) / 1000).toDouble();
    return Column(
      children: [
        SizedBox(
          height: 18,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: const Color(0xFFEDE6DC),
                    color: const Color(0xFFD49A42),
                  ),
                ),
                for (final tier in MembershipTier.values)
                  Positioned(
                    left:
                        (constraints.maxWidth *
                                tier.minimumLifetimePoints /
                                1000)
                            .clamp(0, constraints.maxWidth - 10)
                            .toDouble(),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: value >= tier.minimumLifetimePoints
                            ? tier.color
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: tier.color, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: MembershipTier.values
              .map(
                (tier) => Text(
                  tier.name,
                  style: TextStyle(
                    color: value >= tier.minimumLifetimePoints
                        ? tier.color
                        : const Color(0xFF8D8178),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _PointsTrendChart extends StatelessWidget {
  final List<PointsOverviewBucket> buckets;

  const _PointsTrendChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maximum = buckets.fold<int>(
      0,
      (value, bucket) => [
        value,
        bucket.earned,
        bucket.redeemed,
      ].reduce((a, b) => a > b ? a : b),
    );
    return SizedBox(
      height: 122,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buckets.map((bucket) {
          final earnedHeight = maximum == 0
              ? 0.0
              : 72 * bucket.earned / maximum;
          final redeemedHeight = maximum == 0
              ? 0.0
              : 72 * bucket.redeemed / maximum;
          return Expanded(
            child: Tooltip(
              message:
                  '${bucket.label}: +${bucket.earned} earned, -${bucket.redeemed} redeemed',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bar(earnedHeight, const Color(0xFF6D8E61)),
                        const SizedBox(width: 3),
                        _bar(redeemedHeight, const Color(0xFFC77768)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    bucket.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6D5B53),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bar(double height, Color color) => Container(
    width: 8,
    height: height.clamp(0, 72).toDouble(),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: Color(0xFF6D5B53), fontSize: 11),
      ),
    ],
  );
}

String _formatPoints(int value) {
  final digits = value.abs().toString();
  final result = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) result.write(',');
    result.write(digits[i]);
  }
  return '${value < 0 ? '−' : ''}$result';
}
