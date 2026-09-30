package com.purpleiq.asset360_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.purpleiq.asset360/apps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAuthenticator" -> {
                        val intent = packageManager.getLaunchIntentForPackage("com.google.android.apps.authenticator2")
                        if (intent != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
