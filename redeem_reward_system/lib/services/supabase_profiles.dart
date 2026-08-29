import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfilesService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String?> uploadAvatar({
    required String userId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      return null;
    }

    try {
      final extension = file.path.split('.').last.toLowerCase();
      final safeExt = extension.isEmpty ? 'jpg' : extension;
      final storagePath = '$userId/profile.$safeExt';

      final bytes = await file.readAsBytes();
      final storage = _client.storage.from('avatars');

      await storage.uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );

      final url = storage.getPublicUrl(storagePath);
      debugPrint('Generated avatar URL: $url');
      return url;
    } on StorageException catch (error) {
      debugPrint('Avatar upload failed. Bucket may not exist: $error');
      return null;
    } catch (error) {
      debugPrint('Unexpected avatar upload error: $error');
      return null;
    }
  }

  Future<bool> createOrUpdateProfile({
    required String userId,
    required String email,
    String? fullName,
    String? username,
    String? phone,
    String? birthday,
    String? avatarUrl,
  }) async {
    debugPrint("========== createOrUpdateProfile ==========");
    debugPrint("userId: $userId");
    debugPrint("email: $email");
    final Map<String, dynamic> payload = {
      'id': userId,
      'name': username ?? fullName ?? email.split('@').first,
      'email': email,
    };
    if (phone != null) {
      payload['phone'] = phone;
    }
    if (birthday != null && birthday.trim().isNotEmpty) {
      payload['birthday'] = birthday;
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      payload['avatar_url'] = avatarUrl;
    }
    debugPrint("payload: $payload");
    debugPrint("avatarUrl being saved: $avatarUrl");

    try {
      final existing = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        payload['points'] = 0;
        payload.putIfAbsent('phone', () => '');
        await _client.from('profiles').insert(payload);
      } else {
        final updatePayload = {
          'email': email,
          'name': payload['name'],
        };
        if (phone != null) {
          updatePayload['phone'] = phone;
        }
        if (birthday != null && birthday.trim().isNotEmpty) {
          updatePayload['birthday'] = birthday;
        }
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          updatePayload['avatar_url'] = avatarUrl;
        }
        debugPrint('Updating profile with payload: $updatePayload');
        debugPrint('avatarUrl in updatePayload: ${updatePayload['avatar_url']}');
        
        final updateResult = await _client
            .from('profiles')
            .update(updatePayload)
            .eq('id', userId)
            .select();
        
        debugPrint('Update result: $updateResult');
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint('====================================');
      debugPrint('PROFILE INSERT ERROR');
      debugPrint(error.toString());
      debugPrint(stackTrace.toString());
      debugPrint('====================================');
      rethrow;
    }
  }

  Future<void> updatePoints({required String userId, required int points}) async {
    try {
      await _client.from('profiles').update({'points': points}).eq('id', userId);
    } catch (error) {
      debugPrint('Failed to update points for $userId: $error');
      rethrow;
    }
  }

  /// Optional: subscribe to realtime updates for a profile's row.
  Stream<List<Map<String, dynamic>>> streamProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.cast<Map<String, dynamic>>());
  }

  Future<String?> getEmailByName(String username) async {
    try {
      print("Searching username: '$username'");

      final response = await _client
          .from('profiles')
          .select('email')
          .eq('name', username)
          .maybeSingle();

      print('Query result: $response');

      return response == null ? null : response['email']?.toString();
    } catch (error) {
      debugPrint('Email lookup failed: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProfileByEmail(String email) async {
    try {
      return await _client
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();
    } catch (error) {
      debugPrint('Profile by email lookup failed: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (error) {
      debugPrint('Profile fetch failed: $error');
      return null;
    }
  }
}
