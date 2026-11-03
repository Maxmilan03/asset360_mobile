package com.purpleiq.asset360_mobile

import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // HHT scanner (broadcast mode): the intent action and data extra to listen for.
    private var hhtAction: String = "com.purpleiq.asset360.SCAN"
    private var hhtExtra: String = "com.symbol.datawedge.data_string"
    private var claimHoneywell = false
    private var scanSink: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "com.purpleiq.asset360/apps")
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
                    "openAppSettings" -> {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
                        startActivity(intent)
                        result.success(true)
                    }
                    "deviceInfo" -> result.success(
                        "${Build.MANUFACTURER} ${Build.MODEL} · Android ${Build.VERSION.RELEASE}"
                    )
                    "openUrl" -> {
                        val uri = Uri.parse(call.argument<String>("url") ?: "")
                        val intent = if (uri.scheme == "mailto") Intent(Intent.ACTION_SENDTO, uri) else Intent(Intent.ACTION_VIEW, uri)
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    "openNfcSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                        } catch (e: Exception) {
                            startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.purpleiq.asset360/hht")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val action = call.argument<String>("action") ?: ""
                        val extra = call.argument<String>("extra") ?: ""
                        val claim = call.argument<Boolean>("claimHoneywell") ?: false
                        if (claimHoneywell && !claim) releaseHoneywell()
                        hhtAction = action
                        hhtExtra = extra
                        claimHoneywell = claim
                        if (scanSink != null) registerScanReceiver()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(messenger, "com.purpleiq.asset360/hht/scans")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    scanSink = events
                    registerScanReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterScanReceiver()
                    scanSink = null
                }
            })
    }

    private fun registerScanReceiver() {
        unregisterScanReceiver()
        if (hhtAction.isEmpty()) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val extras = intent.extras ?: return
                @Suppress("DEPRECATION")
                val data = extras.get(hhtExtra)?.let {
                    when (it) {
                        is ByteArray -> String(it, Charsets.UTF_8)
                        else -> it.toString()
                    }
                } ?: return
                val labelType = extras.getString("com.symbol.datawedge.label_type")
                    ?: extras.getString("codeId")
                    ?: extras.getString("aimId")
                    ?: extras.get("barcodeType")?.toString()
                scanSink?.success(mapOf("data" to data, "labelType" to labelType, "action" to intent.action))
            }
        }
        val plain = IntentFilter(hhtAction)
        // Scanner services are other apps: the receiver must be exported on Android 13+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(r, plain, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(r, plain)
        }
        receiver = r
        if (claimHoneywell) claimHoneywellScanner()
    }

    private fun unregisterScanReceiver() {
        receiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
            }
        }
        receiver = null
    }

    // Honeywell Data Collection Service intent API: claim the scanner with data intents sent to hhtAction.
    private fun claimHoneywellScanner() {
        val properties = Bundle().apply {
            putBoolean("DPR_DATA_INTENT", true)
            putString("DPR_DATA_INTENT_ACTION", hhtAction)
        }
        sendBroadcast(
            Intent("com.honeywell.aidc.action.ACTION_CLAIM_SCANNER")
                .setPackage("com.intermec.datacollectionservice")
                .putExtra("com.honeywell.aidc.extra.EXTRA_SCANNER", "dcs.scanner.imager")
                .putExtra("com.honeywell.aidc.extra.EXTRA_PROFILE", "DEFAULT")
                .putExtra("com.honeywell.aidc.extra.EXTRA_PROPERTIES", properties)
        )
    }

    private fun releaseHoneywell() {
        sendBroadcast(
            Intent("com.honeywell.aidc.action.ACTION_RELEASE_SCANNER")
                .setPackage("com.intermec.datacollectionservice")
        )
    }

    override fun onResume() {
        super.onResume()
        if (claimHoneywell && receiver != null) claimHoneywellScanner()
    }

    override fun onPause() {
        if (claimHoneywell) releaseHoneywell()
        super.onPause()
    }

    override fun onDestroy() {
        unregisterScanReceiver()
        super.onDestroy()
    }
}
