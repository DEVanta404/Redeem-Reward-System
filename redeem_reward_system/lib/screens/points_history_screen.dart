import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_state.dart';
import '../services/points_history_service.dart';

class PointsHistoryScreen extends StatefulWidget {
  final Future<void> Function(String orderId)? onOrderSelected;

  const PointsHistoryScreen({super.key, this.onOrderSelected});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen>
    with WidgetsBindingObserver {
  static const _pageSize = 20;
  final _service = PointsHistoryService();
  final _scrollController = ScrollController();
  final List<AppTransaction> _transactions = [];
  PointsHistoryFilter _filter = PointsHistoryFilter.all;
  PointsHistorySummary _summary = const PointsHistorySummary();
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    unawaited(_load(reset: true));
    _subscribe();
  }

  void _subscribe() {
    try {
      _channel = _service.watch(onChange: () => unawaited(_load(reset: true)));
    } catch (error) {
      _error = error;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    final channel = _channel;
    if (channel != null)
      unawaited(Supabase.instance.client.removeChannel(channel));
    super.dispose();
  }

  void _onScroll() {
    if (!_loading && _hasMore && _scrollController.position.extentAfter < 400) {
      unawaited(_load(reset: false));
    }
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted || _loading && !reset) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _service.loadPage(
          offset: reset ? 0 : _transactions.length,
          filter: _filter,
          limit: _pageSize,
        ),
        if (reset) _service.loadSummary(_filter),
      ]);
      final page = results.first as List<AppTransaction>;
      if (!mounted) return;
      setState(() {
        if (reset) {
          _transactions
            ..clear()
            ..addAll(page);
          _summary = results[1] as PointsHistorySummary;
        } else {
          _transactions.addAll(page);
        }
        _hasMore = page.length == _pageSize;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _selectFilter(PointsHistoryFilter filter) async {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    await _load(reset: true);
  }

  List<_TransactionGroup> _groups() {
    final now = _manilaDate(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<AppTransaction>>{};
    for (final transaction in _transactions) {
      final date = _manilaDate(transaction.date);
      final dateOnly = DateTime(date.year, date.month, date.day);
      final label = dateOnly == today
          ? 'Today'
          : dateOnly == yesterday
          ? 'Yesterday'
          : '${_month(date.month)} ${date.day}, ${date.year}';
      groups.putIfAbsent(label, () => []).add(transaction);
    }
    return groups.entries
        .map((entry) => _TransactionGroup(entry.key, entry.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final rowCount = groups.fold<int>(
      0,
      (sum, group) => sum + group.items.length,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text(
          'Points History',
          style: TextStyle(
            color: Color(0xFF3E2723),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Wrap(
              spacing: 8,
              children: PointsHistoryFilter.values.map((filter) {
                final selected = filter == _filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: selected,
                  onSelected: (_) => _selectFilter(filter),
                  selectedColor: const Color(0xFF3E2723),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF5D4037),
                    fontWeight: FontWeight.w600,
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF3E2723),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 6,
                children: [
                  _SummaryValue(
                    label: 'Total earned',
                    value: '+${_summary.earned}',
                    color: const Color(0xFF9BE0A2),
                  ),
                  _SummaryValue(
                    label: 'Total redeemed',
                    value: '-${_summary.redeemed}',
                    color: const Color(0xFFFFA8A0),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              color: const Color(0xFF3E2723),
              child: _loading && _transactions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 140),
                        Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF3E2723),
                          ),
                        ),
                      ],
                    )
                  : _error != null && _transactions.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        const Center(
                          child: Text(
                            'Could not load points history.',
                            style: TextStyle(color: Color(0xFF795548)),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => _load(reset: true),
                            child: const Text('Try again'),
                          ),
                        ),
                      ],
                    )
                  : rowCount == 0
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.history, size: 52, color: Color(0xFFBCAAA4)),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'No activity yet',
                            style: TextStyle(
                              color: Color(0xFF3E2723),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: groups.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, groupIndex) {
                        if (groupIndex == groups.length) {
                          return Padding(
                            padding: const EdgeInsets.all(18),
                            child: Center(
                              child: _error == null
                                  ? const CircularProgressIndicator(
                                      color: Color(0xFF3E2723),
                                    )
                                  : TextButton(
                                      onPressed: () => _load(reset: false),
                                      child: const Text(
                                        'Could not load more. Tap to retry.',
                                      ),
                                    ),
                            ),
                          );
                        }
                        final group = groups[groupIndex];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                              child: Text(
                                group.label,
                                style: const TextStyle(
                                  color: Color(0xFF5D4037),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            ...group.items.map(
                              (transaction) => PointsActivityRow(
                                transaction: transaction,
                                onTap: transaction.orderId == null
                                    ? null
                                    : () => widget.onOrderSelected?.call(
                                        transaction.orderId!,
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class PointsActivityRow extends StatelessWidget {
  final AppTransaction transaction;
  final VoidCallback? onTap;

  const PointsActivityRow({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final earned = transaction.type == 'earned' || transaction.points > 0;
    final value = transaction.points.abs();
    final color = earned ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final date = _manilaDate(transaction.date);
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  earned
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: const TextStyle(
                        color: Color(0xFF3E2723),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _time(date),
                      style: const TextStyle(
                        color: Color(0xFF8D6E63),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${earned ? '+' : '-'}$value',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF8D6E63),
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

class _TransactionGroup {
  final String label;
  final List<AppTransaction> items;

  const _TransactionGroup(this.label, this.items);
}

DateTime _manilaDate(DateTime value) =>
    value.toUtc().add(const Duration(hours: 8));

String _month(int month) => const [
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
][month - 1];

String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
