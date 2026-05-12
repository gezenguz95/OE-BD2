package com.example.obdreader2

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.example.obdreader2/auto_connect"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAutoConnectIntent" -> {
                        val triggered = intent?.getBooleanExtra("auto_connect_triggered", false) ?: false
                        val address   = intent?.getStringExtra("device_address") ?: ""
                        result.success(mapOf("triggered" to triggered, "address" to address))
                        intent?.removeExtra("auto_connect_triggered")
                        intent?.removeExtra("device_address")
                    }
                    "startForegroundService" -> {
                        OBDForegroundService.start(applicationContext)
                        result.success(null)
                    }
                    "stopForegroundService" -> {
                        OBDForegroundService.stop(applicationContext)
                        result.success(null)
                    }
                    "releaseNativeSocket" -> {
                        OBDForegroundService.instance?.releaseSocket()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        if (intent.getBooleanExtra("auto_connect_triggered", false)) {
            val address = intent.getStringExtra("device_address") ?: ""
            methodChannel?.invokeMethod("autoConnectTriggered", mapOf("address" to address))
            intent.removeExtra("auto_connect_triggered")
            intent.removeExtra("device_address")
        }
    }
}
