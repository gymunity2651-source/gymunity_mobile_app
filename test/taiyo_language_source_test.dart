import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TAIYO shared language helper normalizes app preference values', () {
    final source = File(
      'supabase/functions/_shared/taiyo_language.ts',
    ).readAsStringSync();

    expect(source, contains('normalizeTaiyoLanguage'));
    expect(source, contains('"arabic"'));
    expect(source, contains('"english"'));
    expect(source, contains('respond in Arabic'));
    expect(source, contains('respond in English'));
    expect(source, contains('Keep JSON keys in English'));
  });

  test('TAIYO planner includes response language in orchestrator input', () {
    final source = File(
      'supabase/functions/taiyo-workout-planner/engine.ts',
    ).readAsStringSync();

    expect(source, contains('languageInstructionFor'));
    expect(source, contains('response_language'));
    expect(source, contains('preferred_language'));
  });

  test('AI chat uses shared language instructions for prompts', () {
    final source = File(
      'supabase/functions/ai-chat/index.ts',
    ).readAsStringSync();

    expect(source, contains('languageInstructionFor'));
    expect(source, contains('normalizeTaiyoLanguage'));
  });

  test('TAIYO daily brief passes selected language to orchestrator input', () {
    final source = File(
      'supabase/functions/taiyo-daily-brief/engine.ts',
    ).readAsStringSync();

    expect(source, contains('languageInstructionFor'));
    expect(source, contains('normalizeTaiyoLanguage'));
    expect(source, contains('language: LanguageCode'));
    expect(source, contains('response_language'));
    expect(source, contains('memberContext.language'));
  });
}
