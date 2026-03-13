import '../entities/app_role.dart';
import '../entities/account_status.dart';
import '../entities/profile_entity.dart';
import '../entities/user_entity.dart';

abstract class UserRepository {
  Future<UserEntity?> getCurrentUser();

  Future<AccountStatus> getAccountStatus({String? userId});

  Future<ProfileEntity?> getProfile();

  Future<void> ensureUserAndProfile({
    required String userId,
    required String email,
    String? fullName,
  });

  Future<void> saveRole(AppRole role);

  Future<void> completeOnboarding();

  Future<void> updateProfileDetails({
    required String fullName,
    String? phone,
    String? country,
  });

  Future<String> uploadAvatar({
    required List<int> bytes,
    String extension = 'jpg',
  });
}
