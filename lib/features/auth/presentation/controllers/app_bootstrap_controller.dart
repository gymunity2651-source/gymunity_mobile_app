import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/supabase/auth_deep_link_bootstrap.dart';
import '../../../../core/supabase/supabase_initializer.dart';

enum AppBootstrapStatus {
  loading,
  authenticated,
  unauthenticated,
  configError,
  backendError,
  deletedAccount,
}

class AppBootstrapState {
  const AppBootstrapState({
    this.status = AppBootstrapStatus.loading,
    this.routeName,
    this.message,
  });

  final AppBootstrapStatus status;
  final String? routeName;
  final String? message;

  bool get isTerminalError =>
      status == AppBootstrapStatus.configError ||
      status == AppBootstrapStatus.backendError ||
      status == AppBootstrapStatus.deletedAccount;

  AppBootstrapState copyWith({
    AppBootstrapStatus? status,
    String? routeName,
    String? message,
    bool clearRoute = false,
    bool clearMessage = false,
  }) {
    return AppBootstrapState(
      status: status ?? this.status,
      routeName: clearRoute ? null : routeName ?? this.routeName,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class AppBootstrapController extends StateNotifier<AppBootstrapState> {
  AppBootstrapController(this._ref) : super(const AppBootstrapState()) {
    unawaited(load());
  }

  final Ref _ref;

  Future<void> load() async {
    state = const AppBootstrapState(status: AppBootstrapStatus.loading);

    final configError = AppConfig.current.validationErrorMessage;
    if (configError != null) {
      state = AppBootstrapState(
        status: AppBootstrapStatus.configError,
        message: configError,
      );
      return;
    }

    try {
      await SupabaseInitializer.initialize();
      await AuthDeepLinkBootstrap.instance.start();

      final currentUser = await _ref
          .read(userRepositoryProvider)
          .getCurrentUser();
      if (currentUser == null) {
        state = const AppBootstrapState(
          status: AppBootstrapStatus.unauthenticated,
          routeName: AppRoutes.welcome,
        );
        return;
      }

      final accountStatus = await _ref
          .read(userRepositoryProvider)
          .getAccountStatus(userId: currentUser.id);
      if (accountStatus.isDeletedLike) {
        await _ref.read(authRepositoryProvider).logout();
        state = const AppBootstrapState(
          status: AppBootstrapStatus.deletedAccount,
          message:
              'This GymUnity account has been deleted or deactivated. Contact support if you need help.',
        );
        return;
      }

      final route = await _ref
          .read(authRouteResolverProvider)
          .resolveInitialRoute();
      state = AppBootstrapState(
        status: route == AppRoutes.welcome
            ? AppBootstrapStatus.unauthenticated
            : AppBootstrapStatus.authenticated,
        routeName: route,
      );
    } on AppFailure catch (error) {
      state = AppBootstrapState(
        status: AppBootstrapStatus.backendError,
        message: error.message,
      );
    } catch (error) {
      state = AppBootstrapState(
        status: AppBootstrapStatus.backendError,
        message: _messageFromError(error),
      );
    }
  }

  String _messageFromError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    return 'GymUnity could not finish loading your account state.';
  }
}
