import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/coach_entity.dart';

final selectedCoachSpecialtyProvider = StateProvider<int>((ref) => 0);
final coachSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedCoachCityProvider = StateProvider<String?>((ref) => null);
final selectedCoachLanguageProvider = StateProvider<String?>((ref) => 'arabic');
final selectedCoachGenderProvider = StateProvider<String?>((ref) => null);
final selectedCoachBudgetProvider = StateProvider<double?>((ref) => null);

final coachSpecialtiesProvider = Provider<List<String>>(
  (ref) => <String>['All', 'HIIT', 'Strength', 'Yoga', 'Nutrition', 'Crossfit'],
);

final coachListProvider = FutureProvider<List<CoachEntity>>((ref) async {
  final specialties = ref.watch(coachSpecialtiesProvider);
  final selectedIndex = ref.watch(selectedCoachSpecialtyProvider);
  final selected = specialties[selectedIndex];
  final city = ref.watch(selectedCoachCityProvider);
  final language = ref.watch(selectedCoachLanguageProvider);
  final gender = ref.watch(selectedCoachGenderProvider);
  final budget = ref.watch(selectedCoachBudgetProvider);
  final repo = ref.watch(coachRepositoryProvider);
  final paged = await repo.listCoaches(
    specialty: selected == 'All' ? null : selected,
    city: city,
    language: language,
    coachGender: gender,
    maxBudget: budget,
  );
  return paged.items;
});

final filteredCoachListProvider = Provider<List<CoachEntity>>((ref) {
  final coaches = ref.watch(coachListProvider).valueOrNull ?? const [];
  final query = ref.watch(coachSearchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) {
    return coaches;
  }

  return coaches.where((coach) {
    return coach.name.toLowerCase().contains(query) ||
        coach.specialty.toLowerCase().contains(query) ||
        coach.badge.toLowerCase().contains(query) ||
        (coach.city?.toLowerCase().contains(query) ?? false) ||
        coach.bio.toLowerCase().contains(query) ||
        coach.publicHeadline.toLowerCase().contains(query) ||
        coach.positioningStatement.toLowerCase().contains(query) ||
        coach.serviceSummary.toLowerCase().contains(query) ||
        coach.languages.any((lang) => lang.toLowerCase().contains(query));
  }).toList();
});
