Map<String, dynamic> buildCoachOfferPlanPreview({
  required String title,
  required String summary,
  required int durationWeeks,
  required int sessionsPerWeek,
  required String difficultyLevel,
  List<String> equipmentTags = const <String>[],
}) {
  final normalizedWeeks = durationWeeks < 1 ? 1 : durationWeeks;
  final normalizedSessions = sessionsPerWeek.clamp(1, 7);
  final weeklyStructure = List<Map<String, dynamic>>.generate(
    normalizedWeeks,
    (weekIndex) => <String, dynamic>{
      'week_number': weekIndex + 1,
      'days': List<Map<String, dynamic>>.generate(normalizedSessions, (
        sessionIndex,
      ) {
        final dayNumber = _sessionDayNumber(sessionIndex, normalizedSessions);
        final focus = _sessionFocus(sessionIndex);
        return <String, dynamic>{
          'week_number': weekIndex + 1,
          'day_number': dayNumber,
          'label': 'Session ${sessionIndex + 1}',
          'focus': focus,
          'tasks': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'workout',
              'title': '$focus Workout',
              'instructions':
                  'Follow the structured $focus session. Adjust loads gradually and keep form strict.',
              'duration_minutes': 50,
              'is_required': true,
            },
            <String, dynamic>{
              'type': 'recovery',
              'title': 'Recovery Review',
              'instructions':
                  'Log how the session felt and note any recovery concerns before the next check-in.',
              'duration_minutes': 10,
              'is_required': false,
            },
          ],
        };
      }),
    },
  );

  return <String, dynamic>{
    'title': title.trim().isEmpty ? 'Coach Starter Plan' : title.trim(),
    'summary': summary.trim().isEmpty
        ? 'A structured coach-led starter plan with consistent weekly sessions.'
        : summary.trim(),
    'duration_weeks': normalizedWeeks,
    'level': difficultyLevel.trim().isEmpty
        ? 'beginner'
        : difficultyLevel.trim().toLowerCase(),
    'safety_notes': <String>[
      'Scale intensity based on recovery and movement quality.',
      if (equipmentTags.isNotEmpty)
        'Plan assumes access to: ${equipmentTags.join(', ')}.',
    ],
    'rest_guidance':
        'Keep at least one full recovery window between hard sessions when possible.',
    'nutrition_guidance':
        'Match food intake to the training load and recovery demands of the week.',
    'hydration_guidance':
        'Hydrate before training and replace fluids consistently after each session.',
    'sleep_guidance':
        'Aim for stable sleep timing to support adherence and recovery.',
    'weekly_structure': weeklyStructure,
  };
}

int _sessionDayNumber(int sessionIndex, int sessionsPerWeek) {
  if (sessionsPerWeek == 1) {
    return 1;
  }
  final spacing = 6 / (sessionsPerWeek - 1);
  return (1 + (sessionIndex * spacing)).round().clamp(1, 7);
}

String _sessionFocus(int sessionIndex) {
  const focusOrder = <String>[
    'Strength',
    'Conditioning',
    'Upper Body',
    'Lower Body',
    'Mobility',
    'Core',
    'Recovery',
  ];
  return focusOrder[sessionIndex % focusOrder.length];
}
