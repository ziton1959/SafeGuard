package com.example.child_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // The name of our "phone line" between Dart and Kotlin.
    private val CHANNEL = "safeguard/ocr"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ping" -> {
                        // Kotlin received "ping" from Dart, replies with a message.
                        result.success("pong from Kotlin!")
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}