import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/persistence/app_state_persistence_service.dart';
import 'package:my_app/core/persistence/local_json_store.dart';
import 'package:my_app/core/persistence/offline_action_queue.dart';
import 'package:my_app/core/persistence/persisted_cart_store.dart';
import 'package:my_app/core/persistence/persisted_workout_state_store.dart';

void main() {
  late Directory directory;
  late FileLocalJsonStore jsonStore;
  late AppStatePersistenceService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gymunity_state_test_');
    jsonStore = FileLocalJsonStore(directory);
    service = AppStatePersistenceService(jsonStore);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('saves and reads selected tab by user and area', () async {
    await service.tabs.saveSelectedTab(
      userId: 'user-a',
      area: 'member_home',
      index: 2,
    );

    expect(
      await service.tabs.readSelectedTab(userId: 'user-a', area: 'member_home'),
      2,
    );
    expect(
      await service.tabs.readSelectedTab(userId: 'user-b', area: 'member_home'),
      isNull,
    );
  });

  test('ignores invalid tab index', () async {
    await service.tabs.saveSelectedTab(
      userId: 'user-a',
      area: 'member_home',
      index: -1,
    );

    expect(
      await service.tabs.readSelectedTab(userId: 'user-a', area: 'member_home'),
      isNull,
    );
  });

  test('saves reads isolates and clears form drafts', () async {
    await service.drafts.saveDraft(
      userId: 'user-a',
      draftType: 'product',
      draftId: 'new',
      data: <String, dynamic>{'name': 'Protein', 'quantity': 2},
    );

    expect(
      await service.drafts.readDraft(
        userId: 'user-a',
        draftType: 'product',
        draftId: 'new',
      ),
      containsPair('name', 'Protein'),
    );
    expect(
      await service.drafts.readDraft(
        userId: 'user-b',
        draftType: 'product',
        draftId: 'new',
      ),
      isNull,
    );

    await service.drafts.clearDraft(
      userId: 'user-a',
      draftType: 'product',
      draftId: 'new',
    );
    expect(
      await service.drafts.readDraft(
        userId: 'user-a',
        draftType: 'product',
        draftId: 'new',
      ),
      isNull,
    );
  });

  test('corrupted draft JSON does not crash and is cleared', () async {
    await jsonStore.writeMap('drafts.user-a.product.new', <String, dynamic>{
      'schemaVersion': 1,
      'savedAt': 'not-a-date',
      'data': <String, dynamic>{'name': 'bad'},
    });

    expect(
      await service.drafts.readDraft(
        userId: 'user-a',
        draftType: 'product',
        draftId: 'new',
      ),
      isNull,
    );
    expect(await jsonStore.readMap('drafts.user-a.product.new'), isNull);
  });

  test('saves restores and clears cart items per user', () async {
    await service.cart.saveCartItems('user-a', <PersistedCartItem>[
      PersistedCartItem(productId: 'p1', quantity: 2),
    ]);

    expect(await service.cart.readCartItems('user-a'), hasLength(1));
    expect(await service.cart.readCartItems('user-b'), isEmpty);

    await service.cart.clearCart('user-a');
    expect(await service.cart.readCartItems('user-a'), isEmpty);
  });

  test('revalidates unavailable products out of the cart', () async {
    await service.cart.saveCartItems('user-a', <PersistedCartItem>[
      PersistedCartItem(productId: 'available', quantity: 1),
      PersistedCartItem(productId: 'missing', quantity: 1),
    ]);

    final result = await service.cart.revalidateCart(
      userId: 'user-a',
      isProductAvailable: (productId) async => productId == 'available',
    );

    expect(result.validItems.map((item) => item.productId), ['available']);
    expect(result.removedProductIds, ['missing']);
    expect(
      (await service.cart.readCartItems(
        'user-a',
      )).map((item) => item.productId),
      ['available'],
    );
  });

  test('saves and clears active workout state based on validity', () async {
    await service.workouts.saveActiveWorkoutState(
      'user-a',
      ActiveWorkoutLocalState(
        sessionId: 'session-1',
        planId: 'plan-1',
        dayId: 'day-1',
        currentExerciseIndex: 3,
        completedExerciseIds: const <String>['ex-1'],
        restTimerRemainingSeconds: 30,
      ),
    );

    final restored = await service.workouts.restoreActiveWorkoutState(
      'user-a',
      isStillActive: (state) async => state.sessionId == 'session-1',
    );

    expect(restored?.currentExerciseIndex, 3);
    expect(
      await service.workouts.restoreActiveWorkoutState(
        'user-a',
        isStillActive: (_) async => false,
      ),
      isNull,
    );
    expect(await service.workouts.readActiveWorkoutState('user-a'), isNull);
  });

  test(
    'stores last AI session and prompt draft without auto sending',
    () async {
      await service.ai.saveLastSessionId('user-a', 'chat-1');
      await service.ai.savePromptDraft('user-a', 'draft prompt');

      expect(
        await service.ai.restoreLastSessionId(
          'user-a',
          belongsToCurrentUser: (sessionId) async => sessionId == 'chat-1',
        ),
        'chat-1',
      );
      expect(await service.ai.readPromptDraft('user-a'), 'draft prompt');
      expect(service.ai.autoSendPromptDrafts, isFalse);

      expect(
        await service.ai.restoreLastSessionId(
          'user-a',
          belongsToCurrentUser: (_) async => false,
        ),
        isNull,
      );
      expect(await service.ai.readLastSessionId('user-a'), isNull);
    },
  );

  test('saves restores and clears onboarding state by role', () async {
    await service.onboarding.saveStep(
      userId: 'user-a',
      role: 'member',
      stepIndex: 2,
      partialData: <String, dynamic>{'goal': 'strength'},
    );

    expect(
      (await service.onboarding.readStep(
        userId: 'user-a',
        role: 'member',
      ))?.stepIndex,
      2,
    );
    expect(
      await service.onboarding.readStep(userId: 'user-a', role: 'coach'),
      isNull,
    );

    await service.onboarding.clearIncompatibleRoleState(
      userId: 'user-a',
      activeRole: 'coach',
    );
    expect(
      await service.onboarding.readStep(userId: 'user-a', role: 'member'),
      isNull,
    );
  });

  test(
    'offline queue rejects unsafe actions and retries with limits',
    () async {
      expect(
        () => service.offlineQueue.enqueue(
          OfflineAction.create(
            userId: 'user-a',
            type: OfflineActionType.payment,
            payload: const <String, dynamic>{},
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      final action = OfflineAction.create(
        id: 'action-1',
        userId: 'user-a',
        type: OfflineActionType.preferenceUpdate,
        payload: const <String, dynamic>{'language': 'arabic'},
      );
      await service.offlineQueue.enqueue(action);

      var attempts = 0;
      await service.offlineQueue.retryPendingActions(
        userId: 'user-a',
        handler: (pending) async {
          attempts++;
          expect(pending.id, 'action-1');
        },
      );

      expect(attempts, 1);
      expect(await service.offlineQueue.pendingActions('user-a'), isEmpty);
    },
  );

  test('offline queue keeps missing upload file as failed state', () async {
    await service.offlineQueue.enqueue(
      OfflineAction.create(
        id: 'upload-1',
        userId: 'user-a',
        type: OfflineActionType.uploadMetadata,
        payload: const <String, dynamic>{'filePath': 'missing-file.jpg'},
      ),
    );

    await service.offlineQueue.retryPendingActions(
      userId: 'user-a',
      handler: (_) async {},
    );

    final pending = await service.offlineQueue.pendingActions('user-a');
    expect(pending.single.lastFailureReason, contains('Missing upload file'));
  });

  test(
    'logout clears user scoped state but keeps device preferences',
    () async {
      await service.tabs.saveSelectedTab(
        userId: 'user-a',
        area: 'member_home',
        index: 1,
      );
      await service.drafts.saveDraft(
        userId: 'user-a',
        draftType: 'profile',
        draftId: 'edit',
        data: const <String, dynamic>{'name': 'A'},
      );
      await service.cart.saveCartItems('user-a', <PersistedCartItem>[
        PersistedCartItem(productId: 'p1', quantity: 1),
      ]);
      await service.preferences.saveDevicePreference('language', 'arabic');

      await service.clearUserScopedState('user-a');

      expect(
        await service.tabs.readSelectedTab(
          userId: 'user-a',
          area: 'member_home',
        ),
        isNull,
      );
      expect(
        await service.drafts.readDraft(
          userId: 'user-a',
          draftType: 'profile',
          draftId: 'edit',
        ),
        isNull,
      );
      expect(await service.cart.readCartItems('user-a'), isEmpty);
      expect(
        await service.preferences.readDevicePreference('language'),
        'arabic',
      );
    },
  );
}
