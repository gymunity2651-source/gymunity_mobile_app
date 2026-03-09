import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class UserRemoteDataSource {
  UserRemoteDataSource(this._client);

  final SupabaseClient _client;

  User? get currentAuthUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('''
          user_id,
          full_name,
          avatar_path,
          phone,
          country,
          onboarding_completed,
          role_id,
          roles(code)
        ''')
        .eq('user_id', userId)
        .maybeSingle();
    return data;
  }

  Future<void> upsertUser({required String id, required String email}) {
    return _client.from('users').upsert(<String, dynamic>{
      'id': id,
      'email': email,
      'is_active': true,
      'last_login_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> upsertProfile({
    required String userId,
    String? fullName,
    bool? onboardingCompleted,
  }) {
    final payload = <String, dynamic>{'user_id': userId};

    if (fullName != null && fullName.trim().isNotEmpty) {
      payload['full_name'] = fullName.trim();
    }
    if (onboardingCompleted != null) {
      payload['onboarding_completed'] = onboardingCompleted;
    }

    return _client.from('profiles').upsert(payload);
  }

  Future<void> updateRole({required String userId, required int roleId}) {
    return _client
        .from('profiles')
        .update(<String, dynamic>{
          'role_id': roleId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  Future<void> markOnboardingCompleted(String userId) {
    return _client
        .from('profiles')
        .update(<String, dynamic>{
          'onboarding_completed': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  Future<void> updateAvatarPath({
    required String userId,
    required String avatarPath,
  }) {
    return _client
        .from('profiles')
        .update(<String, dynamic>{
          'avatar_path': avatarPath,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String extension,
  }) async {
    final filePath =
        'avatars/$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );
    return filePath;
  }
}
