package com.clipsync.nexus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that monitors the Android clipboard for changes.
 * Sends clip data back to Flutter via MethodChannel.
 */
class ClipboardMonitorService : Service() {

    companion object {
        const val CHANNEL_ID   = "clipsync_monitor"
        const val NOTIF_ID     = 1001
        const val METHOD_CHANNEL = "com.clipsync.nexus/clipboard"
    }

    private lateinit var clipboardManager: ClipboardManager
    private var methodChannel: MethodChannel? = null
    private var lastClipHash: Int = 0

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        onClipboardChanged()
    }

    override fun onCreate() {
        super.onCreate()
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())
        clipboardManager.addPrimaryClipChangedListener(clipListener)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        clipboardManager.removePrimaryClipChangedListener(clipListener)
        super.onDestroy()
    }

    // ── CLIP CHANGE ───────────────────────────────────────────────────────

    private fun onClipboardChanged() {
        val clip = clipboardManager.primaryClip ?: return
        if (clip.itemCount == 0) return

        val item = clip.getItemAt(0)
        val text = item.text?.toString() ?: ""
        val html = item.htmlText ?: ""

        // Deduplicate
        val hash = (text + html).hashCode()
        if (hash == lastClipHash) return
        lastClipHash = hash

        // Get source app (Android 10+ only)
        val sourceApp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            clipboardManager.primaryClipDescription?.label?.toString() ?: "Unknown"
        } else "Unknown"

        val data = mapOf(
            "text"      to text,
            "html"      to html,
            "sourceApp" to sourceApp,
            "bundleId"  to ""  // Package name available via ActivityManager in MainActivity
        )

        // Post back to Flutter on main thread
        android.os.Handler(mainLooper).post {
            methodChannel?.invokeMethod("onClipboardChange", data)
        }
    }

    // ── METHOD CHANNEL SETUP ──────────────────────────────────────────────

    fun attachChannel(channel: MethodChannel) {
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> result.success(null)
                "stopMonitoring"  -> { stopSelf(); result.success(null) }
                else              -> result.notImplemented()
            }
        }
    }

    // ── NOTIFICATION ──────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Clipboard Monitor",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "ClipSync Nexus background clipboard monitoring"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("ClipSync Nexus")
            .setContentText("Monitoring clipboard")
            .setSmallIcon(android.R.drawable.ic_menu_clipboard)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }
}
