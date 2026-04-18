import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/features/member/domain/entities/member_profile_entity.dart';
import 'package:my_app/features/planner/domain/entities/planner_builder_entities.dart';
import 'package:my_app/features/planner/domain/services/planner_builder_question_factory.dart';

void main() {
  const factory = PlannerBuilderQuestionFactory();

  test('saved profile preselects goal, experience, and weekly days', () {
    final result = factory.build(
      const PlannerBuilderKnownContext(
        profile: MemberProfileEntity(
          userId: 'member-1',
          goal: 'weight_loss',
          experienceLevel: 'beginner',
          trainingFrequency: '3_4_days_per_week',
          trainingPlace: 'home',
        ),
      ),
    );

    expect(
      result.answers[PlannerBuilderField.goal]?.stringValue,
      'weight_loss',
    );
    expect(
      result.answers[PlannerBuilderField.experienceLevel]?.stringValue,
      'beginner',
    );
    expect(result.answers[PlannerBuilderField.daysPerWeek]?.intValue, 4);
    expect(
      result.answers[PlannerBuilderField.equipment]?.stringListValue,
      contains('bodyweight'),
    );
  });

  test('training frequency parser handles onboarding values', () {
    expect(
      PlannerBuilderQuestionFactory.parseTrainingFrequency('1_2_days_per_week'),
      2,
    );
    expect(
      PlannerBuilderQuestionFactory.parseTrainingFrequency('3_4_days_per_week'),
      4,
    );
    expect(
      PlannerBuilderQuestionFactory.parseTrainingFrequency('5_6_days_per_week'),
      5,
    );
    expect(PlannerBuilderQuestionFactory.parseTrainingFrequency('daily'), 6);
  });

  test('missing equipment and session minutes produce required steps', () {
    final result = factory.build(
      const PlannerBuilderKnownContext(
        profile: MemberProfileEntity(
          userId: 'member-1',
          goal: 'build_muscle',
          experienceLevel: 'intermediate',
          trainingFrequency: '3_4_days_per_week',
        ),
      ),
    );

    final requiredFields = result.questions
        .where((question) => question.required)
        .map((question) => question.field)
        .toSet();

    expect(requiredFields, contains(PlannerBuilderField.sessionMinutes));
    expect(requiredFields, contains(PlannerBuilderField.equipment));
    expect(result.answers[PlannerBuilderField.sessionMinutes], isNull);
    expect(result.answers[PlannerBuilderField.equipment], isNull);
  });

  test('beginner fat-loss context adds safety and cardio questions', () {
    final result = factory.build(
      const PlannerBuilderKnownContext(
        profile: MemberProfileEntity(
          userId: 'member-1',
          goal: 'weight_loss',
          experienceLevel: 'beginner',
          trainingFrequency: '3_4_days_per_week',
          trainingPlace: 'home',
        ),
      ),
    );

    final fields = result.questions.map((question) => question.field).toSet();
    expect(fields, contains(PlannerBuilderField.limitations));
    expect(fields, contains(PlannerBuilderField.cardioPreference));
  });
}
