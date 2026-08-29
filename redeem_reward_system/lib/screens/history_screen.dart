import 'package:flutter/material.dart';
import '../app_state.dart';

class HistoryScreen extends StatelessWidget {
  final AppState state;

  const HistoryScreen({super.key, required this.state});

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  List<_Group> _groupByDate(List<AppTransaction> transactions) {
    final map = <String, List<AppTransaction>>{};
    for (final t in transactions) {
      final key = '${_months[t.date.month - 1]} ${t.date.day}';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map.entries
        .map((e) => _Group(label: e.key, items: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(state.transactions);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('History',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        centerTitle: false,
      ),
      body: state.transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No transactions yet.',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        group.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF5D4037),
                        ),
                      ),
                    ),
                    ...group.items.map((t) => _HistoryTile(transaction: t)),
                  ],
                );
              },
            ),
    );
  }
}

class _Group {
  final String label;
  final List<AppTransaction> items;
  _Group({required this.label, required this.items});
}

class _HistoryTile extends StatelessWidget {
  final AppTransaction transaction;
  const _HistoryTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isEarned = transaction.points > 0;
    final color =
        isEarned ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isEarned ? Icons.coffee : Icons.card_giftcard,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              transaction.description,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3E2723)),
            ),
          ),
          Text(
            '${isEarned ? '+' : ''}${transaction.points}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
