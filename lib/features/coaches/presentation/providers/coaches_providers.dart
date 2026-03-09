import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/coach_entity.dart';

final selectedCoachSpecialtyProvider = StateProvider<int>((ref) => 0);

final coachSpecialtiesProvider = Provider<List<String>>(
  (ref) => <String>['All', 'HIIT', 'Strength', 'Yoga', 'Nutrition', 'Crossfit'],
);

final coachListProvider = FutureProvider<List<CoachEntity>>((ref) async {
  final specialties = ref.watch(coachSpecialtiesProvider);
  final selectedIndex = ref.watch(selectedCoachSpecialtyProvider);
  final selected = specialties[selectedIndex];
  final repo = ref.watch(coachRepositoryProvider);
  final paged = await repo.listCoaches(specialty: selected);
  return paged.items;
});

