import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/result/paged.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/repositories/coach_repository.dart';

class CoachRepositoryImpl implements CoachRepository {
  CoachRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Paged<CoachEntity>> listCoaches({
    String? specialty,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final rows = await _client.rpc(
        'list_coach_directory',
        params: <String, dynamic>{
          'specialty_filter': specialty,
          'limit_count': limit,
        },
      ) as List<dynamic>;

      return Paged<CoachEntity>(
        items: _mapCoachRows(rows),
        nextCursor: null,
      );
    } catch (_) {
      return _legacyListCoaches(specialty: specialty, limit: limit);
    }
  }

  @override
  Future<void> upsertCoachProfile({
    required String bio,
    required List<String> specialties,
    required int yearsExperience,
    required double hourlyRate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated coach found.');
    }

    try {
      await _client.from('coach_profiles').upsert(<String, dynamic>{
        'user_id': user.id,
        'bio': bio,
        'specialties': specialties,
        'years_experience': yearsExperience,
        'hourly_rate': hourlyRate,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e, st) {
      throw NetworkFailure(
        message: e.message,
        code: e.code,
        cause: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<WorkoutPlanEntity> createWorkoutPlan({
    required String memberId,
    required String source,
    required String title,
    required Map<String, dynamic> planJson,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure(message: 'No authenticated coach found.');
    }

    final row = await _client
        .from('workout_plans')
        .insert(<String, dynamic>{
          'member_id': memberId,
          'coach_id': user.id,
          'source': source,
          'title': title,
          'plan_json': planJson,
          'status': 'active',
        })
        .select('id,member_id,coach_id,source,title,status')
        .single();

    return WorkoutPlanEntity(
      id: row['id'] as String,
      memberId: row['member_id'] as String,
      coachId: row['coach_id'] as String?,
      source: row['source'] as String? ?? source,
      title: row['title'] as String? ?? title,
      status: row['status'] as String? ?? 'active',
    );
  }

  @override
  Future<List<SubscriptionEntity>> listSubscriptions() async {
    final user = _client.auth.currentUser;
    if (user == null) return <SubscriptionEntity>[];

    try {
      final rows = await _client
          .from('subscriptions')
          .select('id,member_id,coach_id,status,amount,plan_name')
          .eq('coach_id', user.id)
          .order('created_at', ascending: false);

      return (rows as List<dynamic>).map((dynamic row) {
        final map = row as Map<String, dynamic>;
        return SubscriptionEntity(
          id: map['id'] as String,
          memberId: map['member_id'] as String,
          coachId: map['coach_id'] as String,
          status: map['status'] as String? ?? '',
          amount: (map['amount'] as num?)?.toDouble() ?? 0,
          planName: map['plan_name'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return <SubscriptionEntity>[];
    }
  }

  Future<Paged<CoachEntity>> _legacyListCoaches({
    String? specialty,
    required int limit,
  }) async {
    try {
      dynamic query = _client
          .from('coach_profiles')
          .select('''
            user_id,
            bio,
            specialties,
            hourly_rate,
            rating_avg,
            rating_count,
            is_verified,
            profiles!inner(full_name)
          ''')
          .limit(limit);

      if (specialty != null && specialty.isNotEmpty && specialty != 'All') {
        query = query.contains('specialties', <String>[specialty]);
      }

      final rows = (await query) as List<dynamic>;
      return Paged<CoachEntity>(
        items: _mapCoachRows(rows),
        nextCursor: null,
      );
    } catch (_) {
      return const Paged<CoachEntity>(
        items: <CoachEntity>[
          CoachEntity(
            id: 'demo-1',
            name: 'Alex Rivera',
            specialty: 'STRENGTH & CONDITIONING',
            rateLabel: '\$55/hr',
            rating: '4.9',
            reviewsLabel: '120+ Reviews',
            badge: 'Elite Certified',
          ),
          CoachEntity(
            id: 'demo-2',
            name: 'Sarah Jenkins',
            specialty: 'YOGA & MINDFULNESS',
            rateLabel: '\$45/hr',
            rating: '5.0',
            reviewsLabel: '85 Reviews',
            badge: 'Vinyasa Master',
          ),
          CoachEntity(
            id: 'demo-3',
            name: 'Marcus Thorne',
            specialty: 'HIIT & ATHLETICS',
            rateLabel: '\$60/hr',
            rating: '4.8',
            reviewsLabel: '210 Reviews',
            badge: 'Pro Athlete Coach',
          ),
        ],
      );
    }
  }

  List<CoachEntity> _mapCoachRows(List<dynamic> rows) {
    return rows.map((dynamic row) {
      final map = row as Map<String, dynamic>;
      final profile = map['profiles'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      final specialtyList =
          (map['specialties'] as List<dynamic>? ?? <dynamic>[]).cast<String>();
      final hourlyRate = (map['hourly_rate'] as num?)?.toDouble() ?? 0;
      final ratingAvg = (map['rating_avg'] as num?)?.toDouble() ?? 0;
      final ratingCount = map['rating_count'] as int? ?? 0;
      final isVerified = map['is_verified'] as bool? ?? true;
      final fullName =
          map['full_name'] as String? ?? profile['full_name'] as String?;

      return CoachEntity(
        id: map['user_id'] as String,
        name: fullName ?? 'Coach',
        specialty:
            (specialtyList.isNotEmpty ? specialtyList.join(' & ') : 'Fitness')
                .toUpperCase(),
        rateLabel: '\$${hourlyRate.toStringAsFixed(0)}/hr',
        rating: ratingAvg.toStringAsFixed(1),
        reviewsLabel: '$ratingCount Reviews',
        badge: isVerified ? 'Verified Coach' : 'New Coach',
      );
    }).toList();
  }
}
