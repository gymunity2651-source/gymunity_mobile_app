import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/account_status.dart';

class UserRemoteDataSource {
  UserRemoteDataSource(this._client);

  final SupabaseClient _client;

  User? get currentAuthUser => _client.auth.currentUser;

  Future<AccountStatus> fetchAccountStatus(String userId) async {
    final data = await _client
        .from('users')
        .select('is_active,deleted_at')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      return AccountStatus.missing;
    }

    final deletedAt = data['deleted_at'] as String?;
    if (deletedAt != null && deletedAt.trim().isNotEmpty) {
      return AccountStatus.deleted;
    }

    final isActive = data['is_active'] as bool? ?? true;
    return isActive ? AccountStatus.active : AccountStatus.inactive;
  }

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
          deleted_at,
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

  Future<void> updateProfileDetails({
    required String userId,
    required String fullName,
    String? phone,
    String? country,
  }) {
    return _client
        .from('profiles')
        .update(<String, dynamic>{
          'full_name': fullName,
          'phone': phone,
          'country': country,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String extension,
  }) async {
    final filePath = 'avatars/$userId/avatar.$extension';
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
