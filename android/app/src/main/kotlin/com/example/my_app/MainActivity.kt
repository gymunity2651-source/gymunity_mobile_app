package com.example.my_app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CALLBACK_METHOD_CHANNEL = "gymunity/auth_callback"
        private const val CALLBACK_EVENT_CHANNEL = "gymunity/auth_callback_events"
        private const val CALLBACK_SCHEME = "gymunity"
        private const val CALLBACK_HOST = "auth-callback"
    }

    private var pendingCallbackUri: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        storeCallbackIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val callbackUri = extractCallbackUri(intent) ?: return
        pendingCallbackUri = callbackUri
        eventSink?.success(callbackUri)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALLBACK_METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingCallback" -> {
                    result.success(pendingCallbackUri)
                    pendingCallbackUri = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALLBACK_EVENT_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun storeCallbackIntent(intent: Intent?) {
        val callbackUri = extractCallbackUri(intent) ?: return
        pendingCallbackUri = callbackUri
    }

    private fun extractCallbackUri(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) {
            return null
        }

        val data = intent.data ?: return null
        if (!matchesAuthCallback(data)) {
            return null
        }

        return data.toString()
    }

    private fun matchesAuthCallback(uri: Uri): Boolean {
        if (uri.scheme != CALLBACK_SCHEME || uri.host != CALLBACK_HOST) {
            return false
        }

        val hasQueryTokens = uri.queryParameterNames.any {
            it == "code" || it == "access_token" || it == "refresh_token" || it == "error"
        }
        val fragment = uri.fragment.orEmpty()
        val hasFragmentTokens = fragment.contains("code=") ||
            fragment.contains("access_token=") ||
            fragment.contains("refresh_token=") ||
            fragment.contains("error=")

        return hasQueryTokens || hasFragmentTokens
    }
}
