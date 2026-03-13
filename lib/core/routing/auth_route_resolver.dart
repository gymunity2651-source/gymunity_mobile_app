import '../../app/routes.dart';
import '../../features/user/domain/entities/app_role.dart';
import '../../features/user/domain/entities/profile_entity.dart';
import '../../features/user/domain/repositories/user_repository.dart';

class AuthRouteResolver {
  AuthRouteResolver(this._userRepository);

  final UserRepository _userRepository;

  Future<String> resolveInitialRoute() async {
    final currentUser = await _userRepository.getCurrentUser();
    if (currentUser == null) return AppRoutes.welcome;
    final profile = await _userRepository.getProfile();
    return _resolveByProfile(profile);
  }

  Future<String> resolveAfterAuth() async {
    final currentUser = await _userRepository.getCurrentUser();
    if (currentUser == null) return AppRoutes.login;
    final profile = await _userRepository.getProfile();
    return _resolveByProfile(profile);
  }

  String routeForRoleDashboard(AppRole role) {
    switch (role) {
      case AppRole.member:
        return AppRoutes.memberHome;
      case AppRole.coach:
        return AppRoutes.coachDashboard;
      case AppRole.seller:
        return AppRoutes.sellerDashboard;
    }
  }

  String routeForRoleOnboarding(AppRole role) {
    switch (role) {
      case AppRole.member:
        return AppRoutes.memberOnboarding;
      case AppRole.coach:
        return AppRoutes.coachOnboarding;
      case AppRole.seller:
        return AppRoutes.sellerOnboarding;
    }
  }

  String _resolveByProfile(ProfileEntity? profile) {
    if (profile == null) {
      return AppRoutes.roleSelection;
    }
    final role = profile.role;
    if (role == null) {
      return AppRoutes.roleSelection;
    }
    if (!profile.onboardingCompleted) {
      return routeForRoleOnboarding(role);
    }
    return routeForRoleDashboard(role);
  }
}
