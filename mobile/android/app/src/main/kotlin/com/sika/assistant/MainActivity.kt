package com.sika.assistant

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.gertonargent/overlay"
    private val SIKA_CHANNEL = "com.gertonargent/sika"
    private val SIKA_CHANNEL_V2 = "com.sika.assistant/voice"
    private val OVERLAY_PERMISSION_REQUEST = 1001

    private var sikaReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // SIKA MethodChannels
        val sikaChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIKA_CHANNEL)
        val sikaChannelV2 = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIKA_CHANNEL_V2)

        sikaReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent == null) return

                if (intent.action == "com.gertonargent.SIKA_COMMAND" || intent.action == "com.sika.assistant.SIKA_COMMAND") {
                    val cmd = intent.getStringExtra("command") ?: ""
                    Log.d("SikaReceiver", "Command received: $cmd")
                    sikaChannel.invokeMethod("onSikaCommand", cmd)
                    sikaChannelV2.invokeMethod("onSikaCommand", cmd)
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("com.gertonargent.SIKA_COMMAND")
            addAction("com.sika.assistant.SIKA_COMMAND")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(sikaReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(sikaReceiver, filter)
        }

        // MethodChannel Handlers
        val sikaHandler = MethodChannel.MethodCallHandler { call, result ->
            when (call.method) {
                "startSikaService" -> {
                    startSikaServiceV2()
                    result.success(true)
                }
                "stopSikaService" -> {
                    stopSikaServiceV2()
                    result.success(true)
                }
                "isSikaServiceRunning" -> {
                    result.success(SikaWakeWordServiceV2.isRunning)
                }
                "getUserFirstname" -> {
                    try {
                        val prefs = getSharedPreferences("sika_prefs", Context.MODE_PRIVATE)
                        result.success(prefs.getString("user_firstname", null))
                    } catch (e: Exception) {
                        result.error("err", e.message, null)
                    }
                }
                "setUserFirstname" -> {
                    try {
                        val firstname = call.argument<String>("firstname") ?: ""
                        val prefs = getSharedPreferences("sika_prefs", Context.MODE_PRIVATE)
                        prefs.edit().putString("user_firstname", firstname).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("err", e.message, null)
                    }
                }
                "readPendingTransactions" -> {
                    val prefs = getSharedPreferences("sika_prefs", Context.MODE_PRIVATE)
                    result.success(prefs.getString("pending_transactions", "[]"))
                }
                "addPendingTransaction" -> {
                    try {
                        val txJson = call.argument<String>("transaction") ?: return@MethodCallHandler
                        val prefs = getSharedPreferences("sika_prefs", Context.MODE_PRIVATE)
                        val existing = prefs.getString("pending_transactions", "[]") ?: "[]"

                        val array = org.json.JSONArray(existing)
                        array.put(org.json.JSONObject(txJson))

                        prefs.edit().putString("pending_transactions", array.toString()).apply()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("err", e.message, null)
                    }
                }
                "clearPendingTransactions" -> {
                    val prefs = getSharedPreferences("sika_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("pending_transactions", "[]").apply()
                    result.success(true)
                }
                "showSikaOverlay" -> {
                    val message = call.argument<String>("message") ?: "Sika vous écoute..."
                    showSikaOverlayV2(message)
                    result.success(true)
                }
                "hideSikaOverlay" -> {
                    hideSikaOverlayV2()
                    result.success(true)
                }
                "checkMicrophonePermission" -> {
                    result.success(hasMicrophonePermission())
                }
                else -> result.notImplemented()
            }
        }

        sikaChannel.setMethodCallHandler(sikaHandler)
        sikaChannelV2.setMethodCallHandler(sikaHandler)
    }

    override fun onResume() {
        super.onResume()
        if (canDrawOverlays() && hasMicrophonePermission()) {
            startSikaServiceV2()
        }
    }

    override fun onDestroy() {
        try {
            sikaReceiver?.let {
                unregisterReceiver(it)
                sikaReceiver = null
            }
        } catch (_: Exception) {}
        super.onDestroy()
    }

    private fun startSikaServiceV2() {
        if (!canDrawOverlays()) {
            requestOverlayPermission()
            return
        }
        val intent = Intent(this, SikaWakeWordServiceV2::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
    }

    private fun stopSikaServiceV2() {
        val intent = Intent(this, SikaWakeWordServiceV2::class.java)
        intent.action = SikaWakeWordServiceV2.ACTION_STOP_LISTENING
        startService(intent)
    }

    private fun showSikaOverlayV2(message: String) {
        if (!canDrawOverlays()) {
            requestOverlayPermission()
            return
        }
        val intent = Intent(this, SikaOverlayServiceV2::class.java)
        intent.putExtra(SikaOverlayServiceV2.EXTRA_MESSAGE, message)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
    }

    private fun hideSikaOverlayV2() {
        val intent = Intent(this, SikaOverlayServiceV2::class.java)
        intent.action = SikaOverlayServiceV2.ACTION_HIDE_OVERLAY
        startService(intent)
    }

    private fun hasMicrophonePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            Settings.canDrawOverlays(this)
        else true
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST)
        }
    }
}
