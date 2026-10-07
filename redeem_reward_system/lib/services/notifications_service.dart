import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final rawData = map['data'];
    return AppNotification(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Notification',
      body: map['body']?.toString() ?? '',
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      isRead: map['is_read'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NotificationsService {
  final SupabaseClient _client;

  NotificationsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Sign in to view notifications.');
    return userId;
  }

  Future<List<AppNotification>> load({
    required int offset,
    int limit = 50,
  }) async {
    final rows = await _client
        .from('notifications')
        .select(
          'id, user_id, type, title, body, data, is_read, created_at',
        )
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List)
        .map(
          (row) => AppNotification.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }

  Future<int> unreadCount() async {
    final result = await _client.rpc('get_unread_notification_count');
    final count = int.tryParse(result.toString());
    if (count == null) {
      throw const FormatException('The unread notification count was invalid.');
    }
    return count;
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _userId)
        .eq('is_read', false);
  }
}

String notificationAge(DateTime createdAt, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(createdAt);
  if (difference.isNegative || difference.inSeconds < 60) return 'Just now';
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min ago';
  }
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  if (difference.inDays < 7) return '${difference.inDays} days ago';
  return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}
