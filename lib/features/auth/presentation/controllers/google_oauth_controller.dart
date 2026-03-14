import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/supabase/auth_callback_ingress.dart';
import '../../../../core/supabase/auth_callback_utils.dart';
import '../../domain/entities/auth_provider_type.dart';
import '../../domain/entities/auth_session.dart';
import 'auth_controller.dart';

enum AuthFlowStatus {
  idle,
  launching,
  waitingForCallback,
  completing,
  success,
  failure,
}

class AuthFlowState {
  const AuthFlowState({
    this.status = AuthFlowStatus.idle,
    this.errorMessage,
    this.resolvedRoute,
    this.activeProvider,
  });

  final AuthFlowStatus status;
  final String? errorMessage;
  final String? resolvedRoute;
  final AuthProviderType? activeProvider;

  bool get isBusy =>
      status == AuthFlowStatus.launching ||
      status == AuthFlowStatus.waitingForCallback ||
      status == AuthFlowStatus.completing;

  AuthFlowState copyWith({
    AuthFlowStatus? status,
    String? errorMessage,
    String? resolvedRoute,
    AuthProviderType? activeProvider,
    bool clearError = false,
    bool clearResolvedRoute = false,
    bool clearProvider = false,
  }) {
    return AuthFlowState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      resolvedRoute: clearResolvedRoute
          ? null
          : resolvedRoute ?? this.resolvedRoute,
      activeProvider: clearProvider
          ? null
          : activeProvider ?? this.activeProvider,
    );
  }
}

class AuthFlowController extends StateNotifier<AuthFlowState> {
  AuthFlowController(
    this._ref, {
    required AuthController authController,
    required AuthControllerState Function() readAuthControllerState,
    required AuthCallbackIngress authCallbackIngress,
    required Duration timeout,
    required Duration pollInterval,
  }) : _authController = authController,
       _readAuthControllerState = readAuthControllerState,
       _authCallbackIngress = authCallbackIngress,
       _timeout = timeout,
       _pollInterval = pollInterval,
       super(const AuthFlowState()) {
    if (AppConfig.current.validationErrorMessage == null) {
      _authSessionSubscription = _ref
          .read(authRepositoryProvider)
          .watchSession()
          .listen(_handleAuthSessionStream);
      _callbackSubscription = _authCallbackIngress.uriStream.listen(
        _handleIncomingCallbackUri,
      );
      unawaited(_initializeCallbackIngress());
    }
  }

  final Ref _ref;
  final AuthController _authController;
  final AuthControllerState Function() _readAuthControllerState;
  final AuthCallbackIngress _authCallbackIngress;
  final Duration _timeout;
  final Duration _pollInterval;
  StreamSubscription<AuthSession?>? _authSessionSubscription;
  StreamSubscription<Uri>? _callbackSubscription;
  Timer? _timeoutTimer;
  Timer? _pollTimer;
  bool _isCompleting = false;
  bool _pendingRecoveryFlow = false;
  String? _activeCallbackFingerprint;
  final Set<String> _completedCallbackFingerprints = <String>{};

  Future<bool> startOAuth(AuthProviderType provider) async {
    if (state.isBusy) {
      return false;
    }

    _resetInternalState();
    _pendingRecoveryFlow = false;
    _activeCallbackFingerprint = null;
    state = AuthFlowState(
      status: AuthFlowStatus.launching,
      activeProvider: provider,
    );

    final launched = await _authController.signInWithOAuth(provider);
    if (!launched) {
      state = AuthFlowState(
        status: AuthFlowStatus.failure,
        activeProvider: provider,
        errorMessage:
            _readAuthControllerState().errorMessage ?? _setupHintFor(provider),
      );
      return false;
    }

    _enterWaitingState();
    return true;
  }

  Future<void> handleAppResumed() async {
    if (!state.isBusy) {
      return;
    }
    await _attemptCompletion();
  }

  Future<void> handleCallbackRoute(String? routeName) async {
    final callbackUri = AuthCallbackUtils.uriFromRouteName(routeName);
    if (callbackUri == null || !AuthCallbackUtils.isAuthCallback(callbackUri)) {
      return;
    }

    await _processCallbackUri(callbackUri);
  }

  void clearOutcome() {
    if (state.status == AuthFlowStatus.success ||
        state.status == AuthFlowStatus.failure) {
      state = const AuthFlowState();
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pollTimer?.cancel();
    _authSessionSubscription?.cancel();
    _callbackSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeCallbackIngress() async {
    await _authCallbackIngress.start();
    final pendingUri = await _authCallbackIngress.consumePendingInitialUri();
    if (pendingUri != null) {
      await _processCallbackUri(pendingUri);
    }
  }

  void _enterWaitingState() {
    state = state.copyWith(
      status: AuthFlowStatus.waitingForCallback,
      clearError: true,
      clearResolvedRoute: true,
    );
    _startTimeout();
    _startPolling();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, () {
      if (state.isBusy) {
        _setFailure(
          state.activeProvider == null
              ? AppStrings.passwordRecoveryDidNotComplete
              : '${state.activeProvider!.label} sign-in did not complete. Check provider configuration and try again.',
        );
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!state.isBusy) {
        return;
      }
      unawaited(_attemptCompletion());
    });
  }

  Future<void> _attemptCompletion() async {
    if (_isCompleting || !state.isBusy) {
      return;
    }

    final session = _sessionFromCurrentClient();
    if (session == null) {
      return;
    }

    if (_pendingRecoveryFlow) {
      _completeRecoveryFlow();
      return;
    }

    await _completeWithSession(session);
  }

  void _handleAuthSessionStream(AuthSession? session) {
    if (session == null || !session.isAuthenticated || !state.isBusy) {
      return;
    }

    if (_pendingRecoveryFlow) {
      _completeRecoveryFlow();
      return;
    }

    unawaited(_completeWithSession(session));
  }

  void _handleIncomingCallbackUri(Uri uri) {
    unawaited(_processCallbackUri(uri));
  }

  Future<void> _processCallbackUri(Uri uri) async {
    if (!AuthCallbackUtils.isAuthCallback(uri)) {
      return;
    }

    final callbackFingerprint = AuthCallbackUtils.callbackFingerprint(uri);
    if (callbackFingerprint != null) {
      if (_activeCallbackFingerprint == callbackFingerprint ||
          _completedCallbackFingerprints.contains(callbackFingerprint)) {
        return;
      }
      _activeCallbackFingerprint = callbackFingerprint;
    }

    final callbackError = AuthCallbackUtils.errorMessage(uri);
    if (callbackError != null) {
      _markActiveCallbackCompleted();
      _setFailure(callbackError);
      return;
    }

    _pendingRecoveryFlow = AuthCallbackUtils.isRecoveryCallback(uri);

    if (!state.isBusy) {
      state = state.copyWith(
        activeProvider: _pendingRecoveryFlow ? null : state.activeProvider,
      );
      _enterWaitingState();
    }

    try {
      final session = await _hydrateSessionFromCallbackUri(uri);
      if (session != null) {
        if (_pendingRecoveryFlow) {
          _completeRecoveryFlow();
          return;
        }
        await _completeWithSession(session);
        return;
      }
    } catch (error) {
      _markActiveCallbackCompleted();
      _setFailure(_messageFromCallbackError(error));
      return;
    }

    await _attemptCompletion();
  }

  Future<void> _completeWithSession(AuthSession session) async {
    if (_isCompleting) {
      return;
    }

    _isCompleting = true;
    state = state.copyWith(
      status: AuthFlowStatus.completing,
      clearError: true,
      clearResolvedRoute: true,
    );

    final bootstrapped = await _authController.completeAuthenticatedSession(
      session,
    );
    if (!bootstrapped) {
      _isCompleting = false;
      _markActiveCallbackCompleted();
      _setFailure(
        _readAuthControllerState().errorMessage ??
            AppStrings.oauthSignInDidNotComplete(
              state.activeProvider?.label ?? 'Sign-in',
            ),
      );
      return;
    }

    try {
      final route = await _ref
          .read(authRouteResolverProvider)
          .resolveAfterAuth();
      _resetInternalState();
      _markActiveCallbackCompleted();
      _isCompleting = false;
      state = AuthFlowState(
        status: AuthFlowStatus.success,
        activeProvider: state.activeProvider,
        resolvedRoute: route,
      );
    } catch (error) {
      _isCompleting = false;
      _markActiveCallbackCompleted();
      _setFailure(_messageFromCallbackError(error));
    }
  }

  void _completeRecoveryFlow() {
    _resetInternalState();
    _markActiveCallbackCompleted();
    _isCompleting = false;
    state = const AuthFlowState(
      status: AuthFlowStatus.success,
      resolvedRoute: AppRoutes.resetPassword,
    );
  }

  AuthSession? _sessionFromCurrentClient() {
    Session? currentSession;
    try {
      currentSession = _ref.read(supabaseClientProvider).auth.currentSession;
    } on StateError {
      return null;
    }
    if (currentSession == null) {
      return null;
    }
    return _sessionFromSupabaseSession(currentSession);
  }

  Future<AuthSession?> _hydrateSessionFromCallbackUri(Uri uri) async {
    late final SupabaseClient client;
    try {
      client = _ref.read(supabaseClientProvider);
    } on StateError {
      return null;
    }
    final normalizedUri = AuthCallbackUtils.normalize(uri);

    try {
      final response = await client.auth.getSessionFromUrl(normalizedUri);
      return _sessionFromSupabaseSession(response.session);
    } on AuthException {
      final authCode = AuthCallbackUtils.authorizationCode(normalizedUri);
      if (authCode == null) {
        rethrow;
      }

      final response = await client.auth.exchangeCodeForSession(authCode);
      return _sessionFromSupabaseSession(response.session);
    }
  }

  AuthSession _sessionFromSupabaseSession(Session session) {
    return AuthSession(
      userId: session.user.id,
      email: session.user.email,
      fullName: _extractFullName(session.user),
      isAuthenticated: true,
    );
  }

  String? _extractFullName(User user) {
    final metadata = user.userMetadata;
    final fullName = metadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final name = metadata?['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return null;
  }

  String _messageFromCallbackError(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      return raw.replaceFirst('Exception: ', '');
    }
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    return raw;
  }

  void _setFailure(String message) {
    _resetInternalState();
    _pendingRecoveryFlow = false;
    _isCompleting = false;
    state = AuthFlowState(
      status: AuthFlowStatus.failure,
      activeProvider: state.activeProvider,
      errorMessage: message,
    );
  }

  void _resetInternalState() {
    _timeoutTimer?.cancel();
    _pollTimer?.cancel();
    _timeoutTimer = null;
    _pollTimer = null;
  }

  void _markActiveCallbackCompleted() {
    final activeFingerprint = _activeCallbackFingerprint;
    if (activeFingerprint != null) {
      _completedCallbackFingerprints.add(activeFingerprint);
    }
    _activeCallbackFingerprint = null;
  }

  String _setupHintFor(AuthProviderType provider) {
    switch (provider) {
      case AuthProviderType.google:
        return AppStrings.googleSignInSetupHint;
      case AuthProviderType.apple:
        return AppStrings.appleSignInSetupHint;
      case AuthProviderType.emailPassword:
        return AppStrings.googleSignInSetupHint;
    }
  }
}
