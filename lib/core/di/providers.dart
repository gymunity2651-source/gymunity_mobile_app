import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/ai_coach/data/repositories/ai_coach_repository_impl.dart';
import '../../features/ai_coach/domain/repositories/ai_coach_repository.dart';
import '../../features/ai_chat/data/repositories/chat_repository_impl.dart';
import '../../features/ai_chat/domain/repositories/chat_repository.dart';
import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/launch_state_store.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/controllers/launch_context_resolver.dart';
import '../../features/auth/presentation/controllers/splash_timing_policy.dart';
import '../../features/coach/data/repositories/coach_repository_impl.dart';
import '../../features/coach/data/repositories/coach_payment_repository_impl.dart';
import '../../features/coach/domain/repositories/coach_payment_repository.dart';
import '../../features/coach/domain/repositories/coach_repository.dart';
import '../../features/coach_member_insights/data/repositories/coach_member_insights_repository_impl.dart';
import '../../features/coach_member_insights/domain/repositories/coach_member_insights_repository.dart';
import '../../features/member/data/repositories/member_repository_impl.dart';
import '../../features/member/domain/repositories/member_repository.dart';
import '../../features/monetization/data/repositories/billing_repository_impl.dart';
import '../../features/monetization/data/repositories/entitlement_repository_impl.dart';
import '../../features/monetization/domain/repositories/billing_repository.dart';
import '../../features/monetization/domain/repositories/entitlement_repository.dart';
import '../../features/news/data/repositories/news_repository_impl.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../../features/nutrition/data/repositories/nutrition_repository_impl.dart';
import '../../features/nutrition/domain/repositories/nutrition_repository.dart';
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
import '../persistence/app_state_persistence_service.dart';
import '../persistence/local_json_store.dart';
import '../routing/app_navigation_state_store.dart';
import '../routing/app_route_observer.dart';
import '../routing/auth_route_resolver.dart';
import '../supabase/auth_callback_ingress.dart';
import '../supabase/supabase_initializer.dart';

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final launchStateStoreProvider = Provider<LaunchStateStore>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  if (preferences == null) {
    return _NoopLaunchStateStore();
  }
  return SharedPreferencesLaunchStateStore(preferences);
});

final appStatePersistenceServiceProvider =
    FutureProvider<AppStatePersistenceService>((ref) async {
      Directory baseDirectory;
      try {
        baseDirectory = await getApplicationSupportDirectory();
      } catch (_) {
        baseDirectory = Directory.systemTemp;
      }
      final stateDirectory = Directory(
        '${baseDirectory.path}${Platform.pathSeparator}gymunity_local_state',
      );
      return AppStatePersistenceService(FileLocalJsonStore(stateDirectory));
    });

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

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AdminRepositoryImpl(client);
});

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StoreRepositoryImpl(client);
});

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CoachRepositoryImpl(client);
});

final coachPaymentRepositoryProvider = Provider<CoachPaymentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CoachPaymentRepositoryImpl(client);
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

final aiCoachRepositoryProvider = Provider<AiCoachRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AiCoachRepositoryImpl(client);
});

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NewsRepositoryImpl(client);
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NutritionRepositoryImpl(client);
});

final coachMemberInsightsRepositoryProvider =
    Provider<CoachMemberInsightsRepository>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return CoachMemberInsightsRepositoryImpl(client);
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
  return AuthRouteResolver(
    ref.watch(userRepositoryProvider),
    navigationStateStore: ref.watch(appNavigationStateStoreProvider),
    plannerRepositoryReader: () => ref.read(plannerRepositoryProvider),
    chatRepositoryReader: () => ref.read(chatRepositoryProvider),
    aiCoachRepositoryReader: () => ref.read(aiCoachRepositoryProvider),
  );
});

final launchContextResolverProvider = Provider<LaunchContextResolver>((ref) {
  return LaunchContextResolver(
    userRepository: ref.watch(userRepositoryProvider),
    navigationStateStore: ref.watch(appNavigationStateStoreProvider),
    launchStateStore: ref.watch(launchStateStoreProvider),
  );
});

final splashTimingPolicyProvider = Provider<SplashTimingPolicy>((ref) {
  return const SplashTimingPolicy();
});

final appNavigationStateStoreProvider = Provider<AppNavigationStateStore>((
  ref,
) {
  final preferences = ref.watch(sharedPreferencesProvider);
  if (preferences == null) {
    return _NoopAppNavigationStateStore();
  }
  return SharedPreferencesAppNavigationStateStore(
    preferences,
    currentUserIdReader: () async {
      return (await ref.read(userRepositoryProvider).getCurrentUser())?.id;
    },
  );
});

final appRouteObserverProvider = Provider<AppRouteObserver>((ref) {
  return AppRouteObserver(ref.watch(appNavigationStateStoreProvider));
});

class _NoopLaunchStateStore implements LaunchStateStore {
  @override
  Future<bool> hasCompletedFirstLaunch() async => true;

  @override
  Future<void> markFirstLaunchComplete() async {}
}

class _NoopAppNavigationStateStore implements AppNavigationStateStore {
  @override
  Future<void> clearLastSafeRoute() async {}

  @override
  Future<void> clearUserScopedState() async {}

  @override
  Future<SavedRouteState?> readLastSafeRoute() async => null;

  @override
  Future<int?> readLastTabIndex(String area) async => null;

  @override
  Future<void> saveLastSafeRoute(
    String routeName, {
    Map<String, dynamic>? params,
  }) async {}

  @override
  Future<void> saveLastTabIndex(String area, int index) async {}
}
