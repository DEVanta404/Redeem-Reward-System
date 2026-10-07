import 'package:flutter/material.dart';

import '../services/currency_formatter.dart';
import '../services/sales_service.dart';

class AdminSalesSection extends StatefulWidget {
  final bool compact;
  final Future<SalesReport> Function(SalesPeriod period)? loadReport;

  const AdminSalesSection({super.key, this.compact = false, this.loadReport});

  @override
  AdminSalesSectionState createState() => AdminSalesSectionState();
}

class AdminSalesSectionState extends State<AdminSalesSection> {
  SalesPeriod _period = SalesPeriod.last7Days;
  SalesReport? _report;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> refresh() => _load();

  Future<void> _load({SalesPeriod? period}) async {
    if (period != null) _period = period;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await (widget.loadReport ?? SalesService().getReport)(
        _period,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: SalesPeriod.values.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final period = SalesPeriod.values[index];
              final selected = period == _period;
              return ChoiceChip(
                label: Text(period.label),
                selected: selected,
                onSelected: (_) => _load(period: period),
                selectedColor: const Color(0xFF3E2723),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF3E2723)
                      : const Color(0xFFE2D8CC),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF5D4037),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF3E2723)),
            ),
          )
        else if (_error != null)
          _ErrorState(error: _error!, onRetry: refresh)
        else ...[
          _SummaryGrid(summary: _report!.summary),
          const SizedBox(height: 22),
          _buildPaymentMethods(),
          const SizedBox(height: 20),
          _buildDeals(),
          const SizedBox(height: 20),
          _buildRewards(),
        ],
      ],
    );
  }

  Widget _buildCompact() {
    if (_loading) {
      return const _SectionCard(
        child: SizedBox(
          height: 56,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF3E2723)),
          ),
        ),
      );
    }
    if (_error != null) {
      return _SectionCard(
        child: _ErrorState(error: _error!, onRetry: refresh),
      );
    }

    final summary = _report?.summary ?? const SalesSummary();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sales summary',
                style: TextStyle(
                  color: Color(0xFF3E2723),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _period.label,
                style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompactMetric(label: 'Orders', value: '${summary.totalOrders}'),
              _CompactMetric(
                label: 'Deals ordered',
                value: '${summary.totalDealsOrdered}',
              ),
              _CompactMetric(
                label: 'Revenue',
                value: formatPeso(summary.totalRevenue),
              ),
              _CompactMetric(
                label: 'Rewards claimed',
                value: '${summary.totalRewardsClaimed}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeals() {
    final rows = _report!.deals;
    return _SalesList(
      title: 'Deals ordered',
      isEmpty: rows.isEmpty,
      children: rows
          .map(
            (row) => _SalesLine(
              title: row.name,
              subtitle: row.category,
              trailing: '${row.unitsSold} units · ${formatPeso(row.revenue)}',
            ),
          )
          .toList(),
    );
  }

  Widget _buildPaymentMethods() {
    final rows = _report!.paymentMethods;
    return _SalesList(
      title: 'Revenue by payment method',
      isEmpty: rows.every((row) => row.paidOrders == 0),
      children: rows
          .map(
            (row) => _SalesLine(
              title: switch (row.paymentMethod) {
                'gcash' => 'GCash',
                'maya' => 'Maya',
                'card' => 'Card',
                _ => 'Cash',
              },
              subtitle: '${row.paidOrders} paid orders',
              trailing: formatPeso(row.revenue),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRewards() {
    final rows = _report!.rewards;
    return _SalesList(
      title: 'Rewards claimed',
      isEmpty: rows.isEmpty,
      children: rows
          .map(
            (row) => _SalesLine(
              title: row.name,
              subtitle: '${row.claims} claims',
              trailing: '${row.pointsRedeemed} pts redeemed',
            ),
          )
          .toList(),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final SalesSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricCard(
              width: width,
              label: 'Total orders',
              value: '${summary.totalOrders}',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF7B4B3A),
            ),
            _MetricCard(
              width: width,
              label: 'Total deals ordered',
              value: '${summary.totalDealsOrdered}',
              icon: Icons.local_cafe_outlined,
              color: const Color(0xFF5D4037),
            ),
            _MetricCard(
              width: width,
              label: 'Total revenue',
              value: formatPeso(summary.totalRevenue),
              icon: Icons.payments_outlined,
              color: const Color(0xFF2E7D32),
            ),
            _MetricCard(
              width: width,
              label: 'Total rewards claimed',
              value: '${summary.totalRewardsClaimed}',
              icon: Icons.redeem_outlined,
              color: const Color(0xFF9A6B32),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6D5B53), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CompactMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF6D5B53), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  final String title;
  final bool isEmpty;
  final List<Widget> children;

  const _SalesList({
    required this.title,
    required this.isEmpty,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3E2723),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Text(
                  'No sales yet for this period',
                  style: TextStyle(color: Color(0xFF8D6E63), fontSize: 13),
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _SalesLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _SalesLine({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDE4DA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3E2723),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8D6E63),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF5D4037),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DED0)),
      ),
      child: child,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Sales data could not be loaded.',
          style: TextStyle(color: Color(0xFF8D6E63)),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
