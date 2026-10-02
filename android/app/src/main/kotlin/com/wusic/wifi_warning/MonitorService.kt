package com.wusic.wifi_warning

import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class MonitorService : Service() {
    companion object {
        const val ACTION_START = "com.wusic.wifi_warning.START_MONITOR"
        const val ACTION_STOP = "com.wusic.wifi_warning.STOP_MONITOR"
        const val ACTION_EVALUATE = "com.wusic.wifi_warning.EVALUATE"
        const val ACTION_ACK = "com.wusic.wifi_warning.ACKNOWLEDGE"
        const val ACTION_SNAPSHOT = "com.wusic.wifi_warning.SNAPSHOT"
        const val EXTRA_SNAPSHOT = "snapshot"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var alertLatched = false
    private var lastMessage = ""
    private lateinit var connectivityManager: ConnectivityManager

    private val heartbeat = object : Runnable {
        override fun run() {
            evaluate()
            handler.postDelayed(this, 15_000L)
        }
    }

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = evaluateSoon()
        override fun onLost(network: Network) = evaluateSoon()
        override fun onCapabilitiesChanged(
            network: Network,
            networkCapabilities: NetworkCapabilities
        ) = evaluateSoon()
    }

    private val systemReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) = evaluateSoon()
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        connectivityManager = getSystemService(ConnectivityManager::class.java)
        MonitorNotifications.createChannels(this)
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
            addAction(Intent.ACTION_DATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(systemReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(systemReceiver, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_ACK -> {
                alertLatched = true
                AlertSoundPlayer.stop(this)
                getSystemService(NotificationManager::class.java).cancel(
                    MonitorNotifications.ALERT_ID
                )
                return START_STICKY
            }
        }
        startForeground(
            MonitorNotifications.MONITOR_ID,
            MonitorNotifications.foreground(this, "正在检测 Wi-Fi、VPN 和规则时间")
        )
        evaluate()
        handler.removeCallbacks(heartbeat)
        handler.postDelayed(heartbeat, 15_000L)
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        runCatching { connectivityManager.unregisterNetworkCallback(networkCallback) }
        runCatching { unregisterReceiver(systemReceiver) }
        AlertSoundPlayer.stop(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun evaluateSoon() {
        handler.removeCallbacks(heartbeat)
        handler.post { evaluate() }
        handler.postDelayed(heartbeat, 15_000L)
    }

    private fun evaluate() {
        val config = ConfigRepository.load(this)
        val snapshot = MonitorEngine.snapshot(this)
        val json = snapshot.toString()
        sendBroadcast(
            Intent(ACTION_SNAPSHOT)
                .setPackage(packageName)
                .putExtra(EXTRA_SNAPSHOT, json)
        )
        val evaluation = RuleEvaluator.evaluate(config, snapshot)
        if (!evaluation.shouldAlert) {
            alertLatched = false
            lastMessage = ""
            AlertSoundPlayer.stop(this)
            getSystemService(NotificationManager::class.java).cancel(
                MonitorNotifications.ALERT_ID
            )
            return
        }
        if (alertLatched) return
        alertLatched = true
        val ssid = snapshot.optString("wifiSsid", "")
        lastMessage = buildString {
            if (ssid.isNotBlank()) append("当前 Wi-Fi：").append(ssid).append('\n')
            if (evaluation.networkMatched) append("当前 Wi-Fi 命中网络规则")
            if (evaluation.networkMatched && evaluation.timeMatched) append('\n')
            if (evaluation.timeMatched) append("当前时间命中时间规则")
        }.trim()
        val overlayEnabled = config.optBoolean("overlayEnabled", false)
        getSystemService(NotificationManager::class.java).notify(
            MonitorNotifications.ALERT_ID,
            MonitorNotifications.alert(this, lastMessage, overlayEnabled)
        )
        AlertSoundPlayer.start(this)
        if (overlayEnabled) {
            runCatching {
                startActivity(
                    Intent(this, WarningActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        .putExtra("message", lastMessage)
                )
            }
        }
    }
}

