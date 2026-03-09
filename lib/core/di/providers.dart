import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/ai_chat/data/repositories/chat_repository_impl.dart';
import '../../features/ai_chat/domain/repositories/chat_repository.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/coach/data/repositories/coach_repository_impl.dart';
import '../../features/coach/domain/repositories/coach_repository.dart';
import '../../features/store/data/repositories/store_repository_impl.dart';
import '../../features/store/domain/repositories/store_repository.dart';
import '../../features/user/data/datasources/user_remote_data_source.dart';
import '../../features/user/data/repositories/user_repository_impl.dart';
import '../../features/user/domain/entities/app_role.dart';
import '../../features/user/domain/entities/profile_entity.dart';
import '../../features/user/domain/repositories/user_repository.dart';
import '../config/env/env.dart';
import '../routing/auth_route_resolver.dart';
import '../supabase/auth_callback_ingress.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    final configError = Env.supabaseConfigError;
    if (configError != null) {
      throw StateError(configError);
    }
    return SupabaseClient(
      Env.supabaseUrl,
      Env.supabaseAnonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }
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

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatRepositoryImpl(client);
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
