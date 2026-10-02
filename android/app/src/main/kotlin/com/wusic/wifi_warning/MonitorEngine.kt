package com.wusic.wifi_warning

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object MonitorEngine {
    fun snapshot(context: Context): JSONObject {
        val result = JSONObject()
            .put("timestamp", System.currentTimeMillis())
            .put("vpnActive", false)
            .put("proxyActive", false)
            .put("backgroundMonitoring", MonitorService.isRunning)
            .put("vpnSources", JSONArray())
            .put("proxySources", JSONArray())

        val errors = mutableListOf<String>()
        val vpnSources = mutableSetOf<String>()
        val proxySources = mutableSetOf<String>()
        try {
            val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                as ConnectivityManager
            val networks = manager.allNetworks
            for (network in networks) {
                val capabilities = manager.getNetworkCapabilities(network)
                if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true) {
                    vpnSources += "Android VPN 服务"
                }
                detectProxy(manager.getLinkProperties(network), proxySources, errors)
            }
            detectDefaultProxy(manager, proxySources, errors)
        } catch (error: Exception) {
            errors += "网络状态读取失败：${error.message ?: error.javaClass.simpleName}"
        }

        val wifiInfo = readWifiInfo(context, errors)
        val ssid = wifiInfo?.let { normalizeSsid(it.ssid) }
        val wifiAvailable = !ssid.isNullOrBlank()
        result
            .put("wifiAvailable", wifiAvailable)
            .put("wifiSsid", ssid)
            .put("vpnActive", vpnSources.isNotEmpty())
            .put("vpnSources", JSONArray(vpnSources.toList()))
            .put("proxyActive", proxySources.isNotEmpty())
            .put("proxySources", JSONArray(proxySources.toList()))
        if (errors.isNotEmpty()) {
            result.put("error", errors.distinct().joinToString("；"))
        }
        return result
    }

    private fun readWifiInfo(
        context: Context,
        errors: MutableList<String>
    ): WifiInfo? {
        if (!hasWifiPermission(context)) {
            errors += "缺少定位权限，无法读取 Wi-Fi 名称"
            return null
        }
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
        return try {
            manager.allNetworks.firstNotNullOfOrNull { network ->
                val capabilities = manager.getNetworkCapabilities(network)
                if (capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
                    capabilities.transportInfo as? WifiInfo
                } else {
                    null
                }
            } ?: run {
                @Suppress("DEPRECATION")
                val wifiManager = context.applicationContext
                    .getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                wifiManager.connectionInfo
            }
        } catch (error: SecurityException) {
            errors += "Wi-Fi 名称读取被系统拒绝"
            null
        } catch (error: Exception) {
            errors += "Wi-Fi 状态读取失败：${error.message ?: error.javaClass.simpleName}"
            null
        }
    }

    private fun hasWifiPermission(context: Context): Boolean {
        val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        val nearby = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return fine || nearby
    }

    private fun normalizeSsid(raw: String?): String? {
        val value = raw?.trim()?.trim('"') ?: return null
        if (value.isEmpty() || value == "<unknown ssid>" || value == "0x") return null
        return value
    }

    private fun detectDefaultProxy(
        manager: ConnectivityManager,
        sources: MutableSet<String>,
        errors: MutableList<String>
    ) {
        try {
            @Suppress("DEPRECATION")
            val proxy = manager.defaultProxy ?: return
            val host = proxy.host
            if (!host.isNullOrBlank()) sources += "系统 HTTP 代理"
            if (proxy.pacFileUrl != null) sources += "系统 PAC 代理"
        } catch (error: Exception) {
            errors += "系统代理读取失败：${error.message ?: error.javaClass.simpleName}"
        }
    }

    private fun detectProxy(
        link: LinkProperties?,
        sources: MutableSet<String>,
        errors: MutableList<String>
    ) {
        if (link == null) return
        try {
            val proxy = link.httpProxy ?: return
            if (!proxy.host.isNullOrBlank()) sources += "网络 HTTP 代理"
            if (proxy.pacFileUrl != null) sources += "网络 PAC 代理"
        } catch (error: Exception) {
            errors += "网络代理读取失败：${error.message ?: error.javaClass.simpleName}"
        }
    }
}
