import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('member home bottom navigation labels use generated localization', () {
    final source = File(
      'lib/features/member/presentation/screens/member_home_screen.dart',
    ).readAsStringSync();

    expect(source, contains('context.l10n'));
    expect(source, contains('l10n.homeTab'));
    expect(source, contains('l10n.coachesTab'));
    expect(source, contains('l10n.taiyoTab'));
    expect(source, contains('l10n.newsTab'));
    expect(source, contains('l10n.profileTab'));
    expect(source, isNot(contains("label: 'HOME'")));
    expect(source, isNot(contains("label: 'COACHES'")));
    expect(source, isNot(contains("label: 'NEWS'")));
    expect(source, isNot(contains("label: 'PROFILE'")));
  });

  test('member home content priority labels use generated localization', () {
    final source = File(
      'lib/features/member/presentation/screens/member_home_content.dart',
    ).readAsStringSync();

    for (final key in <String>[
      'l10n.notifications',
      'l10n.gymunityMember',
      'l10n.wellnessCollective',
      'l10n.welcomeBack',
      'l10n.memberHeroSubtitle',
      'l10n.whatMattersNow',
      'l10n.whatMattersNowSubtitle',
      'l10n.quickActions',
      'l10n.dailyStreak',
      'l10n.loading',
      'l10n.unavailable',
      'l10n.oneDayActive',
      'l10n.daysActive',
      'l10n.activeCoaches',
      'l10n.latestWeight',
      'l10n.currentPlan',
      'l10n.live',
      'l10n.none',
    ]) {
      expect(source, contains(key), reason: 'Missing $key');
    }

    for (final hardcoded in <String>[
      "'Notifications'",
      "'GymUnity Member'",
      "'WELLNESS COLLECTIVE'",
      "'Welcome back,'",
      "'What Matters Now'",
      "'Quick Actions'",
      "'DAILY STREAK'",
      "'Loading...'",
      "'Unavailable'",
      "'1 Day Active'",
      "'ACTIVE COACHES'",
      "'LATEST WEIGHT'",
      "'CURRENT PLAN'",
    ]) {
      expect(source, isNot(contains(hardcoded)), reason: hardcoded);
    }
  });
}
