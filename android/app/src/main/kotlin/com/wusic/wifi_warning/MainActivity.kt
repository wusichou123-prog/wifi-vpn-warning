package com.wusic.wifi_warning

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false
    private val snapshotReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val snapshot = intent?.getStringExtra(MonitorService.EXTRA_SNAPSHOT) ?: return
            eventSink?.success(snapshot)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "wifi_warning/monitor"
        ).setMethodCallHandler(::handleMethodCall)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "wifi_warning/monitor_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerSnapshotReceiver()
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                unregisterSnapshotReceiver()
            }
        })
    }

    private fun handleMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "loadConfig" -> result.success(ConfigRepository.loadRaw(this))
            "saveConfig" -> {
                val raw = call.argument<String>("json")
                if (raw == null) {
                    result.error("INVALID_CONFIG", "缺少配置 JSON", null)
                    return
                }
                runCatching {
                    ConfigRepository.save(this, raw)
                    val enabled = ConfigRepository.load(this)
                        .optBoolean("backgroundMonitoring", false)
                    setMonitoringEnabled(enabled)
                }.onSuccess { result.success(null) }
                    .onFailure { result.error("SAVE_FAILED", it.message, null) }
            }
            "getSnapshot" -> result.success(MonitorEngine.snapshot(this))
            "setMonitoringEnabled" -> {
                setMonitoringEnabled(call.argument<Boolean>("enabled") == true)
                result.success(null)
            }
            "setStartAtLogin" -> result.success(null)
            "requestPermissions" -> {
                requestRequiredPermissions()
                result.success(permissionStatus())
            }
            "openOverlaySettings" -> {
                runCatching {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                    )
                }
                result.success(null)
            }
            "showAlert" -> {
                val title = call.argument<String>("title") ?: "网络安全警告"
                val message = call.argument<String>("message") ?: ""
                getSystemService(NotificationManager::class.java).notify(
                    MonitorNotifications.ALERT_ID,
                    MonitorNotifications.alert(this, message, false)
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf<String>()
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            permissions += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.NEARBY_WIFI_DEVICES
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                permissions += Manifest.permission.NEARBY_WIFI_DEVICES
            }
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                permissions += Manifest.permission.POST_NOTIFICATIONS
            }
        }
        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), 9001)
        }
    }

    private fun permissionStatus(): Map<String, Boolean> {
        val location = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.NEARBY_WIFI_DEVICES
                ) == PackageManager.PERMISSION_GRANTED)
        val notifications = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        val overlay = Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            Settings.canDrawOverlays(this)
        return mapOf(
            "locationGranted" to location,
            "notificationGranted" to notifications,
            "overlayGranted" to overlay
        )
    }

    private fun setMonitoringEnabled(enabled: Boolean) {
        val intent = Intent(this, MonitorService::class.java)
        if (enabled) {
            intent.action = MonitorService.ACTION_START
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } else {
            intent.action = MonitorService.ACTION_STOP
            stopService(intent)
        }
    }

    private fun registerSnapshotReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(MonitorService.ACTION_SNAPSHOT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(snapshotReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(snapshotReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterSnapshotReceiver() {
        if (!receiverRegistered) return
        runCatching { unregisterReceiver(snapshotReceiver) }
        receiverRegistered = false
    }

    override fun onDestroy() {
        unregisterSnapshotReceiver()
        super.onDestroy()
    }
}
