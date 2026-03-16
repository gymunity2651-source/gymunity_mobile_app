import '../../member/domain/entities/member_home_summary_entity.dart';
import '../../member/domain/entities/member_profile_entity.dart';

class AiEntrySuggestion {
  const AiEntrySuggestion({required this.label, required this.prompt});

  final String label;
  final String prompt;
}

List<AiEntrySuggestion> buildPersonalizedAiSuggestions({
  MemberProfileEntity? profile,
  MemberHomeSummaryEntity? summary,
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final suggestions = <AiEntrySuggestion>[];
  final goal = _goalLabel(profile?.goal);
  final activePlan = summary?.activePlan;
  final latestSession = summary?.latestSession;
  final latestWeight = summary?.latestWeightEntry;

  if (activePlan != null) {
    suggestions.add(
      AiEntrySuggestion(
        label: 'Refine current plan',
        prompt:
            'Use my current active plan "${activePlan.title}" and help me refine this week based on my recent consistency.',
      ),
    );
  }

  if (latestSession != null &&
      resolvedNow.difference(latestSession.performedAt).inDays <= 7) {
    suggestions.add(
      AiEntrySuggestion(
        label: 'Weekly check-in',
        prompt:
            'Use my recent workout history and give me a practical weekly check-in with the next adjustments I should make.',
      ),
    );
  } else {
    suggestions.add(
      AiEntrySuggestion(
        label: 'Restart this week',
        prompt:
            'Help me restart this week with a realistic ${goal.toLowerCase()} focus based on my current profile.',
      ),
    );
  }

  if (latestWeight != null) {
    suggestions.add(
      AiEntrySuggestion(
        label: 'Progress check',
        prompt:
            'Use my latest weight and activity context to tell me whether I am on track for ${goal.toLowerCase()}.',
      ),
    );
  }

  suggestions.add(
    AiEntrySuggestion(
      label: 'Build $goal plan',
      prompt:
          'I want a structured $goal plan. Reuse my saved profile details first and only ask what is still missing.',
    ),
  );

  return suggestions.take(3).toList(growable: false);
}

String _goalLabel(String? goal) {
  final normalized = goal?.trim().toLowerCase();
  switch (normalized) {
    case 'fat_loss':
    case 'lose_weight':
    case 'weight_loss':
      return 'Fat loss';
    case 'muscle_gain':
    case 'build_muscle':
      return 'Muscle gain';
    case 'strength':
      return 'Strength';
    default:
      return 'Personalized';
  }
}
