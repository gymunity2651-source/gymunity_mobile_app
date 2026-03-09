import 'app_role.dart';

class ProfileEntity {
  const ProfileEntity({
    required this.userId,
    this.email,
    this.fullName,
    this.avatarPath,
    this.phone,
    this.country,
    this.role,
    this.onboardingCompleted = false,
  });

  final String userId;
  final String? email;
  final String? fullName;
  final String? avatarPath;
  final String? phone;
  final String? country;
  final AppRole? role;
  final bool onboardingCompleted;

  ProfileEntity copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? avatarPath,
    String? phone,
    String? country,
    AppRole? role,
    bool? onboardingCompleted,
  }) {
    return ProfileEntity(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarPath: avatarPath ?? this.avatarPath,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      role: role ?? this.role,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

