import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/lifecycle/lifecycle_flush_registry.dart';

void main() {
  test('flushes every registered callback', () async {
    final registry = LifecycleFlushRegistry();
    final calls = <String>[];

    registry.register('a', () async => calls.add('a'));
    registry.register('b', () async => calls.add('b'));

    await registry.flushAll();

    expect(calls, ['a', 'b']);
  });

  test('one failing callback does not block later callbacks', () async {
    final registry = LifecycleFlushRegistry();
    final calls = <String>[];

    registry.register('bad', () async => throw StateError('failed'));
    registry.register('good', () async => calls.add('good'));

    await registry.flushAll();

    expect(calls, ['good']);
  });

  test('unregistered callbacks are not flushed', () async {
    final registry = LifecycleFlushRegistry();
    var calls = 0;

    registry.register('draft', () async => calls++);
    registry.unregister('draft');
    await registry.flushAll();

    expect(calls, 0);
  });
}
