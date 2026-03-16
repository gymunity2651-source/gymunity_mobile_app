import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/ai_chat/data/repositories/chat_repository_impl.dart';
import '../../features/ai_chat/domain/repositories/chat_repository.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/coach/data/repositories/coach_repository_impl.dart';
import '../../features/coach/domain/repositories/coach_repository.dart';
import '../../features/member/data/repositories/member_repository_impl.dart';
import '../../features/member/domain/repositories/member_repository.dart';
import '../../features/monetization/data/repositories/billing_repository_impl.dart';
import '../../features/monetization/data/repositories/entitlement_repository_impl.dart';
import '../../features/monetization/domain/repositories/billing_repository.dart';
import '../../features/monetization/domain/repositories/entitlement_repository.dart';
import '../../features/news/data/repositories/news_repository_impl.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../../features/planner/data/repositories/planner_repository_impl.dart';
import '../../features/planner/domain/repositories/planner_repository.dart';
import '../../features/seller/data/repositories/seller_repository_impl.dart';
import '../../features/seller/domain/repositories/seller_repository.dart';
import '../../features/store/data/repositories/store_repository_impl.dart';
import '../../features/store/domain/repositories/store_repository.dart';
import '../../features/user/data/datasources/user_remote_data_source.dart';
import '../../features/user/data/repositories/user_repository_impl.dart';
import '../../features/user/domain/entities/app_role.dart';
import '../../features/user/domain/entities/profile_entity.dart';
import '../../features/user/domain/repositories/user_repository.dart';
import '../config/app_config.dart';
import '../routing/auth_route_resolver.dart';
import '../supabase/auth_callback_ingress.dart';
import '../supabase/supabase_initializer.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  final config = AppConfig.current;
  final configError = config.validationErrorMessage;
  if (configError != null) {
    throw StateError(configError);
  }

  if (!SupabaseInitializer.isInitialized) {
    throw StateError(
      'Supabase has not finished initializing yet. Return to the splash screen and wait for startup to complete before using authentication.',
    );
  }

  return Supabase.instance.client;
});

final authCallbackIngressProvider = Provider<AuthCallbackIngress>((ref) {
  return PlatformAuthCallbackIngress.instance;
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRemoteDataSource(client);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  );
});

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UserRemoteDataSource(client);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(
    remoteDataSource: ref.watch(userRemoteDataSourceProvider),
  );
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StoreRepositoryImpl(client);
});

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CoachRepositoryImpl(client);
});

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MemberRepositoryImpl(client);
});

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PlannerRepositoryImpl(client);
});

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SellerRepositoryImpl(client);
});

final inAppPurchaseProvider = Provider<InAppPurchase>((ref) {
  return InAppPurchase.instance;
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepositoryImpl(ref.watch(inAppPurchaseProvider));
});

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EntitlementRepositoryImpl(client);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatRepositoryImpl(client);
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NewsRepositoryImpl(client);
});

final authSessionProvider = StreamProvider<AuthSession?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchSession();
});

final currentUserProfileProvider = FutureProvider<ProfileEntity?>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getProfile();
});

final appRoleProvider = Provider<AppRole?>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  return profile?.role;
});

final authRouteResolverProvider = Provider<AuthRouteResolver>((ref) {
  return AuthRouteResolver(ref.watch(userRepositoryProvider));
});
