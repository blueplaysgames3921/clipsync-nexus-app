package com.clipsync.nexus

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = ClipboardMonitorService.METHOD_CHANNEL
    private var monitorService: ClipboardMonitorService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {

                "startMonitoring" -> {
                    startClipboardService()
                    result.success(null)
                }

                "stopMonitoring" -> {
                    stopService(Intent(this, ClipboardMonitorService::class.java))
                    result.success(null)
                }

                "getRichText" -> {
                    // Return HTML clipboard content if available
                    val cm = getSystemService(android.content.ClipboardManager::class.java)
                    val clip = cm?.primaryClip
                    val html = clip?.getItemAt(0)?.htmlText
                    result.success(html)
                }

                "getActiveWindow" -> {
                    // Return our own package name as the host app context.
                    // Full foreground-app detection requires PACKAGE_USAGE_STATS
                    // permission which needs user grant in Settings → Special App Access.
                    result.success(applicationContext.packageName)
                }

                else -> result.notImplemented()
            }
        }

        // Start service immediately
        startClipboardService()
    }

    private fun startClipboardService() {
        val intent = Intent(this, ClipboardMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
