import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/app_role.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_data_source.dart';
import '../models/profile_model.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({required UserRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  final UserRemoteDataSource _remoteDataSource;

  @override
  Future<UserEntity?> getCurrentUser() async {
    final user = _remoteDataSource.currentAuthUser;
    if (user == null || user.email == null) return null;
    return UserEntity(id: user.id, email: user.email!);
  }

  @override
  Future<AccountStatus> getAccountStatus({String? userId}) async {
    final targetUserId = userId ?? _remoteDataSource.currentAuthUser?.id;
    if (targetUserId == null || targetUserId.isEmpty) {
      return AccountStatus.missing;
    }

    try {
      return await _remoteDataSource.fetchAccountStatus(targetUserId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to read account status.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<ProfileEntity?> getProfile() async {
    final user = _remoteDataSource.currentAuthUser;
    if (user == null) return null;

    try {
      final profileJson = await _remoteDataSource.fetchProfile(user.id);
      if (profileJson == null) return null;
      final enriched = Map<String, dynamic>.from(profileJson)
        ..['email'] = user.email;
      return ProfileModel.fromMap(enriched);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to fetch profile.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> ensureUserAndProfile({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    try {
      final accountStatus = await _remoteDataSource.fetchAccountStatus(userId);
      if (accountStatus.isDeletedLike) {
        throw const AccountDeletedFailure(
          message:
              'This account has been deleted or deactivated. Contact support if you need assistance.',
        );
      }
      await _remoteDataSource.upsertUser(id: userId, email: email);
      await _remoteDataSource.upsertProfile(userId: userId, fullName: fullName);
    } on AccountDeletedFailure {
      rethrow;
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to bootstrap user profile.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> saveRole(AppRole role) async {
    final user = _remoteDataSource.currentAuthUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }

    try {
      await _remoteDataSource.updateRole(userId: user.id, roleId: role.roleId);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to save role.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> completeOnboarding() async {
    final user = _remoteDataSource.currentAuthUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }
    try {
      await _remoteDataSource.markOnboardingCompleted(user.id);
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to complete onboarding.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> updateProfileDetails({
    required String fullName,
    String? phone,
    String? country,
  }) async {
    final user = _remoteDataSource.currentAuthUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }
    try {
      await _remoteDataSource.updateProfileDetails(
        userId: user.id,
        fullName: fullName,
        phone: phone,
        country: country,
      );
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw NetworkFailure(
        message: 'Unable to update profile details.',
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<String> uploadAvatar({
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    final user = _remoteDataSource.currentAuthUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated user found.');
    }
    try {
      final path = await _remoteDataSource.uploadAvatar(
        userId: user.id,
        bytes: bytes,
        extension: extension,
      );
      await _remoteDataSource.updateAvatarPath(
        userId: user.id,
        avatarPath: path,
      );
      return path;
    } on StorageException catch (e, st) {
      throw StorageFailure(
        message: e.message,
        code: e.statusCode?.toString(),
        cause: e,
        stackTrace: st,
      );
    } catch (e, st) {
      throw StorageFailure(
        message: 'Unable to upload avatar image.',
        cause: e,
        stackTrace: st,
      );
    }
  }
}
