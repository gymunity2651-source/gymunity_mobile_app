import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_callback_utils.dart';

abstract class AuthCallbackIngress {
  Future<void> start();
  Future<Uri?> consumePendingInitialUri();
  Stream<Uri> get uriStream;
  Future<void> dispose();
}

class PlatformAuthCallbackIngress implements AuthCallbackIngress {
  PlatformAuthCallbackIngress._();

  static final PlatformAuthCallbackIngress instance =
      PlatformAuthCallbackIngress._();

  static const MethodChannel _methodChannel = MethodChannel(
    'gymunity/auth_callback',
  );
  static const EventChannel _eventChannel = EventChannel(
    'gymunity/auth_callback_events',
  );

  final AppLinks _appLinks = AppLinks();
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  StreamSubscription<dynamic>? _androidSubscription;
  StreamSubscription<Uri>? _appLinksSubscription;
  Uri? _pendingInitialUri;
  String? _lastSeenUri;
  bool _started = false;

  @override
  Stream<Uri> get uriStream => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (_isAndroid) {
      await _startAndroidIngress();
    }

    await _startAppLinksFallback();
  }

  @override
  Future<Uri?> consumePendingInitialUri() async {
    final pendingUri = _pendingInitialUri;
    _pendingInitialUri = null;
    return pendingUri;
  }

  @override
  Future<void> dispose() async {
    await _androidSubscription?.cancel();
    await _appLinksSubscription?.cancel();
    await _controller.close();
    _androidSubscription = null;
    _appLinksSubscription = null;
    _pendingInitialUri = null;
    _started = false;
  }

  Future<void> _startAndroidIngress() async {
    try {
      _androidSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic rawUri) {
          _emitLiveUri(_parseUri(rawUri));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Android auth callback stream error: $error');
        },
      );
    } on MissingPluginException catch (error) {
      debugPrint('Android auth callback stream unavailable: $error');
    } catch (error) {
      debugPrint('Android auth callback stream failed to start: $error');
    }

    try {
      final rawUri = await _methodChannel.invokeMethod<String>(
        'consumePendingCallback',
      );
      _storePendingUri(_parseUri(rawUri));
    } on MissingPluginException catch (error) {
      debugPrint('Android auth callback method unavailable: $error');
    } on PlatformException catch (error) {
      debugPrint(
        'Android auth callback method failed: ${error.message ?? error}',
      );
    } catch (error) {
      debugPrint('Android auth callback method failed: $error');
    }
  }

  Future<void> _startAppLinksFallback() async {
    try {
      _appLinksSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          _emitLiveUri(uri);
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Auth callback app_links stream error: $error');
        },
      );
    } on MissingPluginException catch (error) {
      debugPrint('Auth callback app_links unavailable: $error');
    } catch (error) {
      debugPrint('Auth callback app_links failed to start: $error');
    }

    try {
      final initialUri = await _appLinks.getInitialLink();
      _storePendingUri(initialUri);
    } on PlatformException catch (error) {
      debugPrint(
        'Auth callback app_links initial link failed: ${error.message ?? error}',
      );
    } on MissingPluginException catch (error) {
      debugPrint('Auth callback app_links initial link missing: $error');
    } catch (error) {
      debugPrint('Auth callback app_links initial link failed: $error');
    }
  }

  void _storePendingUri(Uri? uri) {
    if (!_shouldHandle(uri)) {
      return;
    }

    _pendingInitialUri ??= uri;
  }

  void _emitLiveUri(Uri? uri) {
    if (!_shouldHandle(uri)) {
      return;
    }

    _controller.add(uri!);
  }

  bool _shouldHandle(Uri? uri) {
    if (uri == null || !AuthCallbackUtils.isAuthCallback(uri)) {
      return false;
    }

    final uriString = uri.toString();
    if (_lastSeenUri == uriString) {
      return false;
    }

    _lastSeenUri = uriString;
    return true;
  }

  Uri? _parseUri(dynamic rawUri) {
    if (rawUri is! String || rawUri.trim().isEmpty) {
      return null;
    }
    return Uri.tryParse(rawUri.trim());
  }

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
}
