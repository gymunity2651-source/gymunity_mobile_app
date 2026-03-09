import '../../domain/entities/app_role.dart';
import '../../domain/entities/profile_entity.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.userId,
    super.email,
    super.fullName,
    super.avatarPath,
    super.phone,
    super.country,
    super.role,
    super.onboardingCompleted,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    final roleData = map['roles'];
    String? roleCode;
    if (roleData is Map<String, dynamic>) {
      roleCode = roleData['code'] as String?;
    } else if (roleData is List && roleData.isNotEmpty) {
      final first = roleData.first;
      if (first is Map<String, dynamic>) {
        roleCode = first['code'] as String?;
      }
    }

    return ProfileModel(
      userId: map['user_id'] as String,
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      avatarPath: map['avatar_path'] as String?,
      phone: map['phone'] as String?,
      country: map['country'] as String?,
      role: appRoleFromCode(roleCode) ?? appRoleFromId(map['role_id'] as int?),
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
    );
  }
}
