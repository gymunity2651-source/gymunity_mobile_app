import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/supabase/auth_callback_ingress.dart';
import '../../../../core/supabase/auth_callback_utils.dart';
import '../../domain/entities/auth_session.dart';
import 'auth_controller.dart';

enum GoogleOAuthStatus {
  idle,
  launching,
  waitingForCallback,
  completing,
  success,
  failure,
}

class GoogleOAuthState {
  const GoogleOAuthState({
    this.status = GoogleOAuthStatus.idle,
    this.errorMessage,
    this.resolvedRoute,
  });

  final GoogleOAuthStatus status;
  final String? errorMessage;
  final String? resolvedRoute;

  bool get isBusy =>
      status == GoogleOAuthStatus.launching ||
      status == GoogleOAuthStatus.waitingForCallback ||
      status == GoogleOAuthStatus.completing;

  GoogleOAuthState copyWith({
    GoogleOAuthStatus? status,
    String? errorMessage,
    String? resolvedRoute,
    bool clearError = false,
    bool clearResolvedRoute = false,
  }) {
    return GoogleOAuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      resolvedRoute: clearResolvedRoute
          ? null
          : resolvedRoute ?? this.resolvedRoute,
    );
  }
}

class GoogleOAuthController extends StateNotifier<GoogleOAuthState> {
  GoogleOAuthController(
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
       super(const GoogleOAuthState()) {
    _authSessionSubscription = _ref
        .read(authRepositoryProvider)
        .watchSession()
        .listen(_handleAuthSessionStream);
    _callbackSubscription = _authCallbackIngress.uriStream.listen(
      _handleIncomingCallbackUri,
    );
    unawaited(_initializeCallbackIngress());
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
  String? _activeCallbackFingerprint;
  final Set<String> _completedCallbackFingerprints = <String>{};

  Future<bool> startGoogleOAuth() async {
    if (state.isBusy) {
      return false;
    }

    _resetInternalState();
    _activeCallbackFingerprint = null;
    state = const GoogleOAuthState(status: GoogleOAuthStatus.launching);

    final launched = await _authController.signInWithGoogle();
    if (!launched) {
      state = GoogleOAuthState(
        status: GoogleOAuthStatus.failure,
        errorMessage:
            _readAuthControllerState().errorMessage ??
            AppStrings.googleSignInSetupHint,
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
    if (state.status == GoogleOAuthStatus.success ||
        state.status == GoogleOAuthStatus.failure) {
      state = const GoogleOAuthState();
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
    state = const GoogleOAuthState(
      status: GoogleOAuthStatus.waitingForCallback,
    );
    _startTimeout();
    _startPolling();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, () {
      if (state.isBusy) {
        _setFailure(AppStrings.googleSignInDidNotComplete);
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

    await _completeWithSession(session);
  }

  void _handleAuthSessionStream(AuthSession? session) {
    if (session == null || !session.isAuthenticated || !state.isBusy) {
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

    if (!state.isBusy) {
      _enterWaitingState();
    }

    try {
      final session = await _hydrateSessionFromCallbackUri(uri);
      if (session != null) {
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
      status: GoogleOAuthStatus.completing,
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
            AppStrings.googleSignInDidNotComplete,
      );
      return;
    }

    final route = await _ref.read(authRouteResolverProvider).resolveAfterAuth();
    _resetInternalState();
    _markActiveCallbackCompleted();
    _isCompleting = false;
    state = GoogleOAuthState(
      status: GoogleOAuthStatus.success,
      resolvedRoute: route,
    );
  }

  AuthSession? _sessionFromCurrentClient() {
    final currentSession = _ref
        .read(supabaseClientProvider)
        .auth
        .currentSession;
    if (currentSession == null) {
      return null;
    }
    return _sessionFromSupabaseSession(currentSession);
  }

  Future<AuthSession?> _hydrateSessionFromCallbackUri(Uri uri) async {
    final client = _ref.read(supabaseClientProvider);
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
    return raw;
  }

  void _setFailure(String message) {
    _resetInternalState();
    _isCompleting = false;
    state = GoogleOAuthState(
      status: GoogleOAuthStatus.failure,
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
    final fingerprint = _activeCallbackFingerprint;
    if (fingerprint != null) {
      _completedCallbackFingerprints.add(fingerprint);
    }
    _activeCallbackFingerprint = null;
  }
}
