import '../persistence/offline_action_queue.dart';

abstract class OfflineActionExecutor {
  Future<void> execute(OfflineAction action);
}

class NoopOfflineActionExecutor implements OfflineActionExecutor {
  const NoopOfflineActionExecutor();

  @override
  Future<void> execute(OfflineAction action) async {
    // Offline actions are intentionally safe/idempotent by construction. The
    // default executor completes unknown local-only actions; feature modules can
    // override this provider with typed repository-backed handlers.
  }
}
