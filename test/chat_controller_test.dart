import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/di/providers.dart';
import 'package:my_app/core/error/app_failure.dart';
import 'package:my_app/features/ai_chat/presentation/providers/chat_controller.dart';

import 'test_doubles.dart';

void main() {
  test(
    'ChatController exposes AppFailure messages without debug wrapper',
    () async {
      final chatRepository = FakeChatRepository()
        ..sendMessageError = const AuthFailure(
          message: 'Please sign in again to use TAIYO.',
        );

      final container = ProviderContainer(
        overrides: <Override>[
          chatRepositoryProvider.overrideWithValue(chatRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(chatControllerProvider.notifier);
      final result = await controller.sendMessage(
        sessionId: 'session-1',
        message: 'Hello',
      );

      expect(result, isNull);
      expect(
        container.read(chatControllerProvider).errorMessage,
        'Please sign in again to use TAIYO.',
      );
    },
  );
}
