import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notifications_service.dart';

enum _NotificationFilter {
  all('All'),
  orders('Orders'),
  promos('Promos'),
  rewards('Rewards');

  final String label;
  const _NotificationFilter(this.label);

  List<String>? get types => switch (this) {
    all => null,
    orders => [
      'order_placed',
      'order_completed',
      'order_cancelled',
      'new_order_admin',
    ],
    promos => ['promo_new', 'promo_ending'],
    rewards => ['points_earned', 'reward_redeemed', 'streak_ready'],
  };
}

class NotificationsScreen extends StatefulWidget {
  final bool isAdmin;
  final Future<void> Function(AppNotification notification)?
  onNotificationSelected;

  const NotificationsScreen({
    super.key,
    this.isAdmin = false,
    this.onNotificationSelected,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  static const _pageSize = 50;
  final _service = NotificationsService();
  final List<AppNotification> _notifications = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _hasMore = false;
  bool _markingAll = false;
  Object? _error;
  Timer? _refreshTimer;
  _NotificationFilter _filter = _NotificationFilter.all;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  List<AppNotification> get _visibleNotifications {
    final types = _filter.types;
    return types == null
        ? _notifications
        : _notifications.where((item) => types.contains(item.type)).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(reset: true);
    _subscribe();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(reset: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribe() {
    final userId = _userId;
    if (userId == null) return;
    _channel = Supabase.instance.client
        .channel('notifications-screen-$userId-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        .subscribe();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(
      const Duration(milliseconds: 250),
      () => _load(reset: true),
    );
  }

  Future<void> _load({required bool reset}) async {
    if (!mounted) return;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      final page = await _service.load(
        offset: reset ? 0 : _notifications.length,
        limit: _pageSize,
        types: _filter.types,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _notifications
            ..clear()
            ..addAll(page);
        } else {
          _notifications.addAll(page);
        }
        _hasMore = page.length == _pageSize;
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

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          final item = _notifications[i];
          if (!item.isRead) {
            _notifications[i] = AppNotification(
              id: item.id,
              userId: item.userId,
              type: item.type,
              title: item.title,
              body: item.body,
              data: item.data,
              isRead: true,
              createdAt: item.createdAt,
            );
          }
        }
        _markingAll = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      _showError('Could not mark notifications as read. Please try again.');
    }
  }

  Future<void> _open(AppNotification notification) async {
    try {
      if (!notification.isRead) await _service.markRead(notification.id);
      if (!mounted) return;
      final index = _notifications.indexWhere(
        (item) => item.id == notification.id,
      );
      if (index >= 0 && !notification.isRead) {
        setState(() {
          _notifications[index] = AppNotification(
            id: notification.id,
            userId: notification.userId,
            type: notification.type,
            title: notification.title,
            body: notification.body,
            data: notification.data,
            isRead: true,
            createdAt: notification.createdAt,
          );
        });
      }
      if (mounted && widget.onNotificationSelected != null) {
        Navigator.of(context).pop();
      }
      await widget.onNotificationSelected?.call(notification);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not open this notification. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  IconData _iconFor(String type) => switch (type) {
    'welcome' => Icons.local_cafe_outlined,
    'order_placed' || 'new_order_admin' => Icons.receipt_long_outlined,
    'order_completed' => Icons.check_circle_outline,
    'order_cancelled' => Icons.cancel_outlined,
    'points_earned' => Icons.stars_outlined,
    'reward_redeemed' => Icons.card_giftcard_outlined,
    'promo_new' => Icons.local_offer_outlined,
    'promo_ending' => Icons.hourglass_bottom_outlined,
    'streak_ready' => Icons.local_fire_department_outlined,
    _ => Icons.notifications_outlined,
  };

  List<_NotificationGroup> _groups(List<AppNotification> notifications) {
    final today = _manilaDate(DateTime.now());
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayItems = <AppNotification>[];
    final earlierItems = <AppNotification>[];
    for (final item in notifications) {
      final date = _manilaDate(item.createdAt);
      if (DateTime(date.year, date.month, date.day) == todayDate) {
        todayItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }
    return [
      if (todayItems.isNotEmpty) _NotificationGroup('Today', todayItems),
      if (earlierItems.isNotEmpty) _NotificationGroup('Earlier', earlierItems),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Admin Notifications' : 'Notifications',
          style: const TextStyle(
            color: Color(0xFF3E2723),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _markingAll ? null : _markAllRead,
            child: _markingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Mark all as read',
                    style: TextStyle(color: Color(0xFF3E2723)),
                  ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        color: const Color(0xFF3E2723),
        child: _loading && _notifications.isEmpty
            ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 180),
                  Center(
                    child: CircularProgressIndicator(color: Color(0xFF3E2723)),
                  ),
                ],
              )
            : _error != null && _notifications.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  const Center(
                    child: Text(
                      'Could not load notifications.',
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
            : _visibleNotifications.isEmpty
            ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  _buildFilters(),
                  SizedBox(height: 140),
                  Icon(
                    _notifications.isEmpty
                        ? Icons.notifications_none
                        : Icons.filter_list_off,
                    size: 54,
                    color: Color(0xFF8D6E63),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      _notifications.isEmpty
                          ? 'No notifications yet'
                          : 'No matching notifications',
                      style: TextStyle(
                        color: Color(0xFF3E2723),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _buildFilters(),
                  for (final group in _groups(_visibleNotifications)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                      child: Text(
                        group.label,
                        style: const TextStyle(
                          color: Color(0xFF5D4037),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ...group.items.map((item) => Card(
                    color: item.isRead ? Colors.white : const Color(0xFFFFFBF6),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: item.isRead
                            ? const Color(0xFFE2D8CC)
                            : const Color(0xFFBCAAA4),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _open(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF3E2723),
                              child: Icon(
                                _iconFor(item.type),
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            color: Color(0xFF3E2723),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead)
                                        const DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Color(0xFFC62828),
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox(width: 9, height: 9),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      color: Color(0xFF5D4037),
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notificationAge(item.createdAt),
                                    style: const TextStyle(
                                      color: Color(0xFF8D6E63),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                  ],
                  if (_hasMore)
                    Center(
                      child: TextButton(
                        onPressed: _loading ? null : () => _load(reset: false),
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Load more'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Row(
      children: _NotificationFilter.values.map((filter) {
        final selected = _filter == filter;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(filter.label),
            selected: selected,
            showCheckmark: false,
            selectedColor: const Color(0xFF3E2723),
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF5D4037),
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) {
              if (_filter == filter) return;
              setState(() {
                _filter = filter;
                _notifications.clear();
                _hasMore = false;
              });
              _load(reset: true);
            },
          ),
        );
      }).toList(),
    ),
  );
}

class _NotificationGroup {
  final String label;
  final List<AppNotification> items;
  const _NotificationGroup(this.label, this.items);
}

DateTime _manilaDate(DateTime value) =>
    value.toUtc().add(const Duration(hours: 8));
