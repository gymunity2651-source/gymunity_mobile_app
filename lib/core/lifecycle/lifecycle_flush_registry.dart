typedef LifecycleFlushCallback = Future<void> Function();

class LifecycleFlushRegistry {
  final Map<String, LifecycleFlushCallback> _callbacks =
      <String, LifecycleFlushCallback>{};

  void register(String key, LifecycleFlushCallback callback) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      return;
    }
    _callbacks[normalized] = callback;
  }

  void unregister(String key) {
    _callbacks.remove(key.trim());
  }

  Future<void> flushAll() async {
    final callbacks = List<LifecycleFlushCallback>.from(_callbacks.values);
    for (final callback in callbacks) {
      try {
        await callback();
      } catch (_) {
        // One broken screen draft must not block route/workout/cart flushing.
      }
    }
  }
}
