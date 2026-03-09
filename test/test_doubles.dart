import 'dart:async';

import 'package:my_app/core/supabase/auth_callback_ingress.dart';
import 'package:my_app/core/result/paged.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_message_entity.dart';
import 'package:my_app/features/ai_chat/domain/entities/chat_session_entity.dart';
import 'package:my_app/features/ai_chat/domain/repositories/chat_repository.dart';
import 'package:my_app/features/auth/domain/entities/auth_session.dart';
import 'package:my_app/features/auth/domain/entities/otp_flow.dart';
import 'package:my_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:my_app/features/coach/domain/entities/coach_entity.dart';
import 'package:my_app/features/coach/domain/entities/subscription_entity.dart';
import 'package:my_app/features/coach/domain/entities/workout_plan_entity.dart';
import 'package:my_app/features/coach/domain/repositories/coach_repository.dart';
import 'package:my_app/features/store/domain/entities/order_entity.dart';
import 'package:my_app/features/store/domain/entities/product_entity.dart';
import 'package:my_app/features/store/domain/repositories/store_repository.dart';
import 'package:my_app/features/user/domain/entities/app_role.dart';
import 'package:my_app/features/user/domain/entities/profile_entity.dart';
import 'package:my_app/features/user/domain/entities/user_entity.dart';
import 'package:my_app/features/user/domain/repositories/user_repository.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSession loginResult = const AuthSession.unauthenticated();
  AuthSession registerResult = const AuthSession.unauthenticated();
  AuthSession verifyOtpResult = const AuthSession.unauthenticated();
  Stream<AuthSession?> sessionStream = const Stream<AuthSession?>.empty();
  bool signInWithGoogleResult = true;

  Object? loginError;
  Object? registerError;
  Object? verifyOtpError;
  Object? sendOtpError;
  Object? resetPasswordError;
  Object? signInWithGoogleError;
  int signInWithGoogleCalls = 0;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResult;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult;
  }

  @override
  Future<bool> signInWithGoogle() async {
    signInWithGoogleCalls++;
    if (signInWithGoogleError != null) throw signInWithGoogleError!;
    return signInWithGoogleResult;
  }

  @override
  Future<void> sendOtp({
    required String email,
    required OtpFlowMode mode,
  }) async {
    if (sendOtpError != null) throw sendOtpError!;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    if (resetPasswordError != null) throw resetPasswordError!;
  }

  @override
  Future<AuthSession> verifyOtp({
    required String email,
    required String token,
    required OtpFlowMode mode,
  }) async {
    if (verifyOtpError != null) throw verifyOtpError!;
    return verifyOtpResult;
  }

  @override
  Stream<AuthSession?> watchSession() => sessionStream;

  @override
  Future<void> logout() async {}
}

class FakeAuthCallbackIngress implements AuthCallbackIngress {
  Uri? pendingInitialUri;
  bool started = false;
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get uriStream => _controller.stream;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<Uri?> consumePendingInitialUri() async {
    final uri = pendingInitialUri;
    pendingInitialUri = null;
    return uri;
  }

  Future<void> emit(Uri uri) async {
    _controller.add(uri);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeUserRepository implements UserRepository {
  UserEntity? currentUser;
  ProfileEntity? profile;

  Object? profileError;
  Object? saveRoleError;
  Object? completeOnboardingError;

  AppRole? savedRole;
  int ensureUserCalls = 0;
  int completeOnboardingCalls = 0;

  @override
  Future<UserEntity?> getCurrentUser() async => currentUser;

  @override
  Future<ProfileEntity?> getProfile() async {
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<void> ensureUserAndProfile({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    ensureUserCalls++;
  }

  @override
  Future<void> saveRole(AppRole role) async {
    if (saveRoleError != null) throw saveRoleError!;
    savedRole = role;
  }

  @override
  Future<void> completeOnboarding() async {
    if (completeOnboardingError != null) throw completeOnboardingError!;
    completeOnboardingCalls++;
  }

  @override
  Future<String> uploadAvatar({
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    return 'avatar.$extension';
  }
}

class FakeCoachRepository implements CoachRepository {
  List<CoachEntity> coaches = const <CoachEntity>[];
  Object? upsertError;

  @override
  Future<Paged<CoachEntity>> listCoaches({
    String? specialty,
    String? cursor,
    int limit = 20,
  }) async {
    return Paged<CoachEntity>(items: coaches);
  }

  @override
  Future<void> upsertCoachProfile({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
  }) async {
    if (upsertError != null) throw upsertError!;
  }

  @override
  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  }) async {
    return WorkoutPlanEntity(
      id: 'plan-1',
      memberId: memberId,
      coachId: 'coach-1',
      source: source,
      title: title,
      status: 'active',
    );
  }

  @override
  Future<List<SubscriptionEntity>> listSubscriptions() async {
    return const <SubscriptionEntity>[];
  }
}

class FakeStoreRepository implements StoreRepository {
  List<ProductEntity> products = const <ProductEntity>[];

  @override
  Future<Paged<ProductEntity>> listProducts({
    String? category,
    String? cursor,
    int limit = 20,
  }) async {
    return Paged<ProductEntity>(items: products);
  }

  @override
  Future<void> createOrUpdateProduct({
    String? productId,
    required String title,
    required String description,
    required String category,
    required double price,
    required int stockQty,
    List<String> imagePaths = const <String>[],
  }) async {}

  @override
  Future<String> uploadProductImage({
    required String productId,
    required List<int> bytes,
    String extension = 'jpg',
  }) async {
    return '$productId.$extension';
  }

  @override
  Future<OrderEntity> placeOrder({
    required String sellerId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String currency = 'USD',
  }) async {
    return OrderEntity(
      id: 'order-1',
      memberId: 'member-1',
      sellerId: sellerId,
      status: 'pending',
      totalAmount: totalAmount,
      currency: currency,
    );
  }

  @override
  Future<List<OrderEntity>> listMyOrders() async {
    return const <OrderEntity>[];
  }
}

class FakeChatRepository implements ChatRepository {
  final List<ChatSessionEntity> sessions = <ChatSessionEntity>[];
  final Map<String, List<ChatMessageEntity>> _messages =
      <String, List<ChatMessageEntity>>{};
  final Map<String, StreamController<List<ChatMessageEntity>>> _controllers =
      <String, StreamController<List<ChatMessageEntity>>>{};

  Object? createSessionError;
  Object? sendMessageError;
  int _counter = 0;

  @override
  Future<List<ChatSessionEntity>> listSessions() async => sessions;

  @override
  Future<ChatSessionEntity> createSession({String? title}) async {
    if (createSessionError != null) throw createSessionError!;
    _counter++;
    final session = ChatSessionEntity(
      id: 'session-$_counter',
      userId: 'user-1',
      title: title ?? 'New chat',
      updatedAt: DateTime(2026, 3, 8),
    );
    sessions.add(session);
    _messages.putIfAbsent(session.id, () => <ChatMessageEntity>[]);
    _controllerFor(session.id).add(_messages[session.id]!);
    return session;
  }

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String sessionId) {
    final controller = _controllerFor(sessionId);
    controller.add(_messages[sessionId] ?? <ChatMessageEntity>[]);
    return controller.stream;
  }

  @override
  Future<ChatMessageEntity> sendMessage({
    required String sessionId,
    required String message,
  }) async {
    if (sendMessageError != null) throw sendMessageError!;
    final list = _messages.putIfAbsent(sessionId, () => <ChatMessageEntity>[]);
    list.add(
      ChatMessageEntity(
        id: 'user-${list.length}',
        sessionId: sessionId,
        sender: 'user',
        content: message,
        createdAt: DateTime(2026, 3, 8, 12, 0),
      ),
    );
    final response = ChatMessageEntity(
      id: 'assistant-${list.length}',
      sessionId: sessionId,
      sender: 'assistant',
      content: 'Handled: $message',
      createdAt: DateTime(2026, 3, 8, 12, 1),
    );
    list.add(response);
    _controllerFor(sessionId).add(List<ChatMessageEntity>.from(list));
    return response;
  }

  List<ChatMessageEntity> messagesFor(String sessionId) {
    return List<ChatMessageEntity>.from(_messages[sessionId] ?? const []);
  }

  StreamController<List<ChatMessageEntity>> _controllerFor(String sessionId) {
    return _controllers.putIfAbsent(
      sessionId,
      () => StreamController<List<ChatMessageEntity>>.broadcast(),
    );
  }
}
