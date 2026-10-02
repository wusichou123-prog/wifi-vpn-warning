package com.wusic.wifi_warning

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val config = ConfigRepository.load(context)
        if (!config.optBoolean("backgroundMonitoring", false)) return
        val service = Intent(context, MonitorService::class.java)
            .setAction(MonitorService.ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(service)
        } else {
            context.startService(service)
        }
    }
}
